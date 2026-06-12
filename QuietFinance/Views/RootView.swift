import SwiftUI
import SwiftData

struct RootView: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var undo: UndoStash
    @State private var columnVisibility: NavigationSplitViewVisibility = .automatic
    @Environment(\.modelContext) private var context
    @Query(sort: \Snapshot.date, order: .reverse) private var snapshots: [Snapshot]
    @Query private var people: [Person]
    @Query private var countries: [Country]
    @Query private var types: [AssetType]
    @Query private var accounts: [Account]
    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            Group {
                if app.iconOnlySidebar {
                    Sidebar()
                        .navigationSplitViewColumnWidth(30)
                } else {
                    Sidebar()
                        .navigationSplitViewColumnWidth(min: 200, ideal: app.sidebarWidth, max: 360)
                }
            }
            .toolbar(removing: .sidebarToggle)
        } detail: {
            VStack(spacing: 0) {
                if let reason = QuietFinanceApp.safeModeReason {
                    SafeModeBanner(reason: reason)
                        .zIndex(11)
                }
                TopBar()
                    .zIndex(10)
                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.lBg)
                    .zIndex(0)
            }
            .frame(minWidth: 780)
            .navigationTitle("")
            .toolbar(removing: .title)
            .toolbar {
                ToolbarItem(placement: .navigation) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            columnVisibility = (columnVisibility == .detailOnly) ? .all : .detailOnly
                        }
                    } label: {
                        Image(systemName: "sidebar.left")
                    }
                    .keyboardShortcut("s", modifiers: .command)
                    .help(columnVisibility == .detailOnly ? "Show sidebar (⌘S)" : "Hide sidebar (⌘S)")
                }
                ToolbarItem(placement: .navigation) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            app.iconOnlySidebar.toggle()
                        }
                    } label: {
                        Image(systemName: app.iconOnlySidebar ? "sidebar.squares.left" : "rectangle.compress.vertical")
                    }
                    .disabled(columnVisibility == .detailOnly)
                    .help(app.iconOnlySidebar ? "Expand sidebar" : "Collapse to icons")
                }
                ToolbarSpacer(.fixed, placement: .navigation)
                ToolbarItem(placement: .navigation) {
                    HStack(spacing: 10) {
                        Image(app.appIconChoice.assetName)
                            .resizable()
                            .interpolation(.high)
                            .frame(width: 30, height: 30)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.lLine, lineWidth: 1))
                        Text("Quiet Finance")
                            .font(Typo.serifNum(15))
                            .foregroundStyle(Color.lInk)
                            .lineLimit(1)
                        Text("v\(AppInfo.versionString)")
                            .font(Typo.eyebrow)
                            .textCase(.uppercase)
                            .tracking(1.0)
                            .foregroundStyle(Color.lInk3)
                            .lineLimit(1)
                    }
                    .help("Quiet Finance v\(AppInfo.versionString)")
                }
                .sharedBackgroundVisibility(.hidden)
            }
        }
        .navigationSplitViewStyle(.balanced)
        .frame(minWidth: 1000, minHeight: 640)
        .background(Color.lBg)
        .environment(\.compactMode, app.compactMode)
        .environment(\.useModernDesign, app.useModernDesign)
        .environment(\.stealthMode, app.stealthMode)
        .overlay(alignment: .bottom) {
            VStack(spacing: 8) {
                AppToastView()
                UndoToast()
            }
        }
        .focusedSceneValue(\.appState, app)
        .focusedSceneValue(\.undoStash, undo)
        .focusedSceneValue(\.sceneModelContext, context)
        .focusedSceneValue(\.restoreDelete) {
            undo.restore(
                context: context,
                people: people,
                countries: countries,
                types: types,
                accounts: accounts,
                snapshots: snapshots
            )
        }
        .onAppear {
            if app.activeSnapshotID == nil, let latest = snapshots.first {
                app.activeSnapshotID = latest.id
            }
            MenuBarController.shared.setDisplayCurrency(app.displayCurrency)
            MenuBarController.shared.setStealth(app.stealthMode)
        }
        .onChange(of: app.displayCurrency) { _, c in
            MenuBarController.shared.setDisplayCurrency(c)
        }
        .onChange(of: app.stealthMode) { _, on in
            MenuBarController.shared.setStealth(on)
        }
        .onChange(of: snapshots.count) { _, _ in
            MenuBarController.shared.refresh()
        }
        .sheet(isPresented: $app.commandPaletteOpen) {
            CommandPalette()
                .environmentObject(app)
        }
        .background(
            Button("") { app.commandPaletteOpen = true }
                .keyboardShortcut("k", modifiers: .command)
                .opacity(0)
                .frame(width: 0, height: 0)
        )
    }

    @ViewBuilder
    private var content: some View {
        switch app.selectedScreen {
        case .dashboard:  scrollable { DashboardView() }
        case .breakdown:  scrollable { BreakdownView() }
        case .trends:     scrollable { TrendsView() }
        case .snapshots:  scrollable { SnapshotListView() }
        case .diff:       scrollable { SnapshotDiffView() }
        case .reports:    scrollable { ReportsView() }
        case .settings:   scrollable { SettingsView() }
        case .accounts:   paged { AccountsView() }
        case .people:     paged { PeopleView() }
        case .countries:  paged { CountriesView() }
        case .assetTypes: paged { AssetTypesView() }
        case .receivables: paged { ReceivablesView() }
        }
    }

    @ViewBuilder
    private func scrollable<V: View>(@ViewBuilder _ v: () -> V) -> some View {
        let h: CGFloat = app.compactMode ? 20 : 32
        let top: CGFloat = app.compactMode ? 14 : 24
        let bot: CGFloat = app.compactMode ? 24 : 40
        ScrollView(.vertical) {
            v()
                .padding(.horizontal, h)
                .padding(.top, top)
                .padding(.bottom, bot)
                .frame(maxWidth: 1400, alignment: .topLeading)
                .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }

    @ViewBuilder
    private func paged<V: View>(@ViewBuilder _ v: () -> V) -> some View {
        let h: CGFloat = app.compactMode ? 20 : 32
        let top: CGFloat = app.compactMode ? 14 : 24
        let bot: CGFloat = app.compactMode ? 12 : 20
        v()
            .padding(.horizontal, h)
            .padding(.top, top)
            .padding(.bottom, bot)
            .frame(maxWidth: 1400, alignment: .topLeading)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

/// Non-modal warning shown when the app launched into in-memory safe mode
/// because the on-disk store couldn't be opened.
private struct SafeModeBanner: View {
    let reason: String
    @EnvironmentObject var app: AppState
    @State private var dismissed = false

    var body: some View {
        if !dismissed {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                Text(reason)
                    .font(Typo.sans(12, weight: .medium))
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 12)
                Button("Open Settings") { app.selectedScreen = .settings }
                    .buttonStyle(.plain)
                    .font(Typo.sans(12, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .overlay(Capsule().stroke(.white.opacity(0.6), lineWidth: 1))
                Button { dismissed = true } label: {
                    Image(systemName: "xmark").font(.system(size: 10, weight: .bold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white.opacity(0.85))
                .help("Dismiss")
            }
            .padding(.horizontal, 16).padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.lLoss)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Safe mode warning. \(reason)")
        }
    }
}

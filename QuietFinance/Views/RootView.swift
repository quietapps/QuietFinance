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
        .overlay(alignment: .bottom) { UndoToast() }
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

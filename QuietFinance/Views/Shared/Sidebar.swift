import SwiftUI
import SwiftData
import Combine

struct Sidebar: View {
    @EnvironmentObject var app: AppState
    @Query private var liveAccounts: [Account]
    @Query private var liveSnapshots: [Snapshot]
    @Query private var livePeople: [Person]
    @Query private var liveCountries: [Country]

    private var liveIDs: Set<UUID> {
        var s = Set<UUID>()
        liveAccounts.forEach  { s.insert($0.id) }
        liveSnapshots.forEach { s.insert($0.id) }
        livePeople.forEach    { s.insert($0.id) }
        liveCountries.forEach { s.insert($0.id) }
        return s
    }

    private struct NavItem: Identifiable, Hashable {
        let screen: Screen
        let label: String
        let icon: String
        var id: Screen { screen }
    }
    private struct NavGroup { let section: String; let items: [NavItem] }

    private let groups: [NavGroup] = [
        NavGroup(section: "Overview", items: [
            NavItem(screen: .dashboard, label: "Net Worth", icon: "chart.bar.doc.horizontal"),
            NavItem(screen: .trends, label: "Trends", icon: "waveform.path.ecg"),
            NavItem(screen: .snapshots, label: "Historical", icon: "chart.line.uptrend.xyaxis"),
            NavItem(screen: .diff, label: "Diff", icon: "arrow.left.arrow.right"),
            NavItem(screen: .reports, label: "Reports", icon: "doc.text.magnifyingglass"),
        ]),
        NavGroup(section: "Breakdown", items: [
            NavItem(screen: .breakdown, label: "By Allocation", icon: "square.grid.2x2"),
            NavItem(screen: .people, label: "By Person", icon: "person.2"),
            NavItem(screen: .countries, label: "By Country", icon: "globe"),
            NavItem(screen: .assetTypes, label: "By Asset Type", icon: "square.stack.3d.up"),
        ]),
        NavGroup(section: "Data", items: [
            NavItem(screen: .accounts, label: "All Assets", icon: "list.bullet"),
            NavItem(screen: .receivables, label: "Receivables", icon: "hourglass"),
        ]),
    ]

    private let settingsItem = NavItem(screen: .settings, label: "Settings", icon: "gearshape")

    private var selection: Binding<Screen?> {
        Binding(
            get: { app.selectedScreen },
            set: { if let v = $0 { app.selectedScreen = v } }
        )
    }

    var body: some View {
        if app.iconOnlySidebar {
            iconOnlyBody
        } else {
            fullBody
        }
    }

    // MARK: Full

    private var fullBody: some View {
        List(selection: selection) {
            ForEach(groups, id: \.section) { g in
                Section(g.section) {
                    ForEach(g.items) { item in
                        Label(item.label, systemImage: item.icon)
                            .tag(item.screen)
                    }
                }
            }

            let recents = app.recentItems
            if !recents.isEmpty {
                Section {
                    let alive = liveIDs
                    ForEach(recents) { item in
                        recentRow(item, isDeleted: !alive.contains(item.entityID))
                    }
                } header: {
                    HStack {
                        Text("Recent")
                        Spacer()
                        Button {
                            app.recentItemsRaw = ""
                            app.objectWillChange.send()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(Color.lInk4)
                        }
                        .buttonStyle(.plain)
                        .pointerStyle(.link)
                        .help("Clear recent")
                    }
                }
            }

            Section {
                Label(settingsItem.label, systemImage: settingsItem.icon)
                    .tag(settingsItem.screen)
            }
        }
        .listStyle(.sidebar)
    }

    // MARK: Icon-only

    private var iconOnlyBody: some View {
        VStack(spacing: 14) {
            Spacer().frame(height: 4)
            ForEach(Array(groups.enumerated()), id: \.offset) { idx, g in
                if idx > 0 {
                    Divider().padding(.horizontal, 8)
                }
                ForEach(g.items) { item in
                    iconButton(item)
                }
            }

            Spacer(minLength: 0)

            Divider().padding(.horizontal, 8)
            iconButton(settingsItem)
                .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.bar)
    }

    private func iconButton(_ item: NavItem) -> some View {
        let active = app.selectedScreen == item.screen
        return Button {
            app.selectedScreen = item.screen
        } label: {
            Image(systemName: item.icon)
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(active ? Color.lInk : Color.lInk3)
                .frame(width: 30, height: 30)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(active ? Color.lInk.opacity(0.10) : Color.clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(active ? Color.lLine : Color.clear, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .pointerStyle(.link)
        .help(item.label)
    }

    // MARK: Shared bits

    @ViewBuilder
    private func recentRow(_ item: AppState.RecentItem, isDeleted: Bool) -> some View {
        Button {
            guard !isDeleted else { return }
            switch item.kind {
            case .account:
                app.pendingFocusAccountID = item.entityID
                app.selectedScreen = .accounts
            case .snapshot:
                app.activeSnapshotID = item.entityID
                app.selectedScreen = .snapshots
            case .person:
                app.pendingFocusPersonID = item.entityID
                app.selectedScreen = .people
            case .country:
                app.pendingFocusCountryID = item.entityID
                app.selectedScreen = .countries
            }
        } label: {
            Label {
                Text(item.label)
                    .strikethrough(isDeleted, color: Color.lInk4)
                    .foregroundStyle(isDeleted ? Color.lInk4 : Color.lInk2)
                    .lineLimit(1)
            } icon: {
                Image(systemName: iconFor(item.kind))
                    .foregroundStyle(isDeleted ? Color.lInk4 : Color.lInk3)
            }
        }
        .buttonStyle(.plain)
        .pointerStyle(isDeleted ? .default : .link)
        .disabled(isDeleted)
        .help(isDeleted ? "Deleted — restore via Edit ▸ Recently Deleted" : "")
    }

    private func iconFor(_ k: AppState.RecentKind) -> String {
        switch k {
        case .account:  return "creditcard"
        case .snapshot: return "calendar"
        case .person:   return "person.crop.circle"
        case .country:  return "flag"
        }
    }

}

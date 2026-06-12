import SwiftUI
import SwiftData

/// ⌘K palette: jump to a screen, switch active snapshot, open an account
/// or fire a quick action. Keyboard-first — arrow keys navigate, Return
/// fires the highlighted item, Esc dismisses. Fuzzy-matched, with recents
/// surfaced on an empty query.
struct CommandPalette: View {
    @EnvironmentObject var app: AppState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.useModernDesign) private var modern
    @Query(sort: \Snapshot.date, order: .reverse) private var snapshots: [Snapshot]
    @Query(sort: \Account.name) private var accounts: [Account]
    @Query(sort: \Person.name) private var people: [Person]
    @Query(sort: \Country.code) private var countries: [Country]

    @State private var query: String = ""
    @State private var selection: Int = 0
    @FocusState private var focused: Bool

    enum Kind: String { case recent, screen, snapshot, account, person, country, action }

    struct Item: Identifiable {
        let id: String           // stable — drives recents persistence
        let kind: Kind
        let title: String
        let subtitle: String
        let icon: String
        let action: () -> Void
    }

    private var allItems: [Item] {
        var out: [Item] = []
        let allScreens: [(Screen, String, String, String)] = [
            (.dashboard, "Net Worth", "house", "screen.dashboard"),
            (.trends, "Trends", "waveform.path.ecg", "screen.trends"),
            (.snapshots, "Historical · Snapshots", "chart.line.uptrend.xyaxis", "screen.snapshots"),
            (.diff, "Diff · Money Flow", "arrow.left.arrow.right", "screen.diff"),
            (.reports, "Reports", "doc.text.magnifyingglass", "screen.reports"),
            (.breakdown, "By Allocation", "square.grid.2x2", "screen.breakdown"),
            (.people, "By Person", "person.2", "screen.people"),
            (.countries, "By Country", "globe", "screen.countries"),
            (.assetTypes, "By Asset Type", "square.stack.3d.up", "screen.assetTypes"),
            (.accounts, "All Assets", "list.bullet", "screen.accounts"),
            (.receivables, "Receivables", "hourglass", "screen.receivables"),
            (.settings, "Settings", "gearshape", "screen.settings"),
        ]
        for (s, label, icon, key) in allScreens {
            out.append(Item(id: key, kind: .screen, title: label, subtitle: "Screen", icon: icon) {
                app.selectedScreen = s
            })
        }
        for s in snapshots.prefix(40) {
            out.append(Item(id: "snapshot.\(s.id.uuidString)", kind: .snapshot, title: s.label,
                           subtitle: "Snapshot · \(Fmt.date(s.date))",
                           icon: s.isLocked ? "lock.fill" : "pencil") {
                app.activeSnapshotID = s.id
                app.selectedScreen = .snapshots
            })
        }
        for a in accounts.prefix(80) {
            let det = [a.person?.name, a.assetType?.name, a.country?.name]
                .compactMap { $0 }.joined(separator: " · ")
            out.append(Item(id: "account.\(a.id.uuidString)", kind: .account, title: a.name,
                           subtitle: "Account · \(det)",
                           icon: "creditcard") {
                app.pendingFocusAccountID = a.id
                app.selectedScreen = .accounts
                app.touchRecent(.account, id: a.id, label: a.name)
            })
        }
        for p in people {
            out.append(Item(id: "person.\(p.id.uuidString)", kind: .person, title: p.name,
                           subtitle: "Person · \(p.accounts.count) accounts",
                           icon: "person.crop.circle") {
                app.pendingFocusPersonID = p.id
                app.selectedScreen = .people
            })
        }
        for c in countries {
            out.append(Item(id: "country.\(c.id.uuidString)", kind: .country, title: "\(c.flag) \(c.name)",
                           subtitle: "Country · \(c.code)",
                           icon: "flag") {
                app.pendingFocusCountryID = c.id
                app.selectedScreen = .countries
            })
        }
        out.append(contentsOf: actionItems)
        return out
    }

    private var actionItems: [Item] {
        var out: [Item] = []
        out.append(Item(id: "action.newSnapshot", kind: .action, title: "New Snapshot",
                       subtitle: "Action · capture this quarter",
                       icon: "plus.circle") {
            app.newSnapshotRequested = true
            app.selectedScreen = .snapshots
        })
        out.append(Item(id: "action.newAccount", kind: .action, title: "New Account",
                       subtitle: "Action · add an asset or liability",
                       icon: "plus.rectangle.on.rectangle") {
            app.newAccountRequested = true
            app.selectedScreen = .accounts
        })
        out.append(Item(id: "action.toggleTheme", kind: .action, title: "Toggle Theme",
                       subtitle: "Action · system → light → dark",
                       icon: "circle.lefthalf.filled") {
            switch app.theme {
            case .system: app.theme = .light
            case .light:  app.theme = .dark
            case .dark:   app.theme = .system
            }
        })
        out.append(Item(id: "action.toggleStealth", kind: .action,
                       title: app.stealthMode ? "Disable Stealth Mode" : "Enable Stealth Mode",
                       subtitle: "Action · blur every amount",
                       icon: app.stealthMode ? "eye" : "eye.slash") {
            app.stealthMode.toggle()
        })
        out.append(Item(id: "action.toggleCompact", kind: .action,
                       title: app.compactMode ? "Disable Compact Mode" : "Enable Compact Mode",
                       subtitle: "Action · tighter spacing for laptops",
                       icon: "rectangle.compress.vertical") {
            app.compactMode.toggle()
        })
        out.append(Item(id: "action.exportHistory", kind: .action, title: "Export Full History CSV",
                       subtitle: "Action · via Settings",
                       icon: "square.and.arrow.up") {
            app.pendingSettingsAction = .exportHistoryCSV
            app.selectedScreen = .settings
        })
        out.append(Item(id: "action.importCSV", kind: .action, title: "Import CSV…",
                       subtitle: "Action · via Settings",
                       icon: "square.and.arrow.down") {
            app.pendingSettingsAction = .importCSV
            app.selectedScreen = .settings
        })
        out.append(Item(id: "action.openSettings", kind: .action, title: "Open Settings",
                       subtitle: "Action",
                       icon: "gearshape") {
            app.selectedScreen = .settings
        })
        out.append(Item(id: "action.showWelcome", kind: .action, title: "Show Welcome Guide",
                       subtitle: "Action · replay first-run intro",
                       icon: "hand.wave") {
            app.welcomeCompleted = false
        })
        return out
    }

    /// Empty query → recents (palette actions + entity recents), then a short
    /// default list. Non-empty → fuzzy-ranked.
    private var filtered: [Item] {
        let q = query.trimmingCharacters(in: .whitespaces)
        let items = allItems
        guard !q.isEmpty else {
            var out: [Item] = []
            var seen = Set<String>()
            let byID = Dictionary(items.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
            for actionID in app.paletteRecentActionIDs {
                if let item = byID[actionID], !seen.contains(item.id) {
                    out.append(recentBadged(item)); seen.insert(item.id)
                }
            }
            for recent in app.recentItems {
                let key = "\(recent.kind.rawValue).\(recent.entityID.uuidString)"
                if let item = byID[key], !seen.contains(item.id) {
                    out.append(recentBadged(item)); seen.insert(item.id)
                }
            }
            for item in items where !seen.contains(item.id) {
                out.append(item); seen.insert(item.id)
                if out.count >= 20 { break }
            }
            return out
        }
        return items
            .compactMap { item -> (Item, Double)? in
                FuzzyMatch.score(query: q, candidate: "\(item.title) \(item.subtitle)")
                    .map { (item, $0) }
            }
            .sorted { $0.1 > $1.1 }
            .prefix(40)
            .map { $0.0 }
    }

    private func recentBadged(_ item: Item) -> Item {
        Item(id: item.id, kind: .recent, title: item.title,
             subtitle: item.subtitle, icon: "clock.arrow.circlepath",
             action: item.action)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "command")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.lInk3)
                TextField("Jump to anything — screens, accounts, actions…", text: $query)
                    .textFieldStyle(.plain)
                    .font(Typo.sans(15))
                    .foregroundStyle(Color.lInk)
                    .focused($focused)
                    .onSubmit { fire() }
                Spacer()
                Text("esc")
                    .font(Typo.mono(9, weight: .medium))
                    .foregroundStyle(Color.lInk3)
                    .padding(.horizontal, 5).padding(.vertical, 1)
                    .overlay(RoundedRectangle(cornerRadius: modern ? 4 : 999).stroke(Color.lLine, lineWidth: 1))
            }
            .padding(.horizontal, 16).padding(.vertical, 14)
            Divider().overlay(Color.lLine)

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        let items = filtered
                        if items.isEmpty {
                            Text("No matches.")
                                .font(Typo.serifItalic(13))
                                .foregroundStyle(Color.lInk3)
                                .padding(20)
                        }
                        ForEach(Array(items.enumerated()), id: \.element.id) { idx, it in
                            row(idx: idx, item: it)
                                .id(idx)
                                .onTapGesture { selection = idx; fire() }
                        }
                    }
                }
                .frame(maxHeight: 420)
                .onChange(of: selection) { _, new in
                    proxy.scrollTo(new, anchor: .center)
                }
            }

            Divider().overlay(Color.lLine)
            HStack(spacing: 12) {
                hintKey("↑↓")
                Text("navigate").font(Typo.mono(10)).foregroundStyle(Color.lInk3)
                hintKey("↩")
                Text("open").font(Typo.mono(10)).foregroundStyle(Color.lInk3)
                Spacer()
                Text("\(filtered.count) matches")
                    .font(Typo.eyebrow).tracking(1.2)
                    .foregroundStyle(Color.lInk3)
            }
            .padding(.horizontal, 14).padding(.vertical, 8)
            .background(Color.lSunken.opacity(0.5))
        }
        .frame(width: 640)
        .background(Color.lPanel)
        .clipShape(RoundedRectangle(cornerRadius: modern ? 16 : 12))
        .overlay(RoundedRectangle(cornerRadius: modern ? 16 : 12).stroke(Color.lLine, lineWidth: modern ? 0.5 : 1))
        .shadow(color: .black.opacity(modern ? 0.18 : 0.35), radius: modern ? 32 : 24, y: 10)
        .onAppear { focused = true }
        .onChange(of: query) { _, _ in selection = 0 }
        .background(
            // Hidden buttons handle arrow keys + Return + Esc
            VStack {
                Button("") { moveSelection(-1) }
                    .keyboardShortcut(.upArrow, modifiers: [])
                Button("") { moveSelection(1) }
                    .keyboardShortcut(.downArrow, modifiers: [])
                Button("") { fire() }
                    .keyboardShortcut(.defaultAction)
                Button("") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .opacity(0)
            .frame(width: 0, height: 0)
        )
    }

    private func moveSelection(_ delta: Int) {
        let n = filtered.count
        guard n > 0 else { return }
        selection = (selection + delta + n) % n
    }

    private func fire() {
        let items = filtered
        guard !items.isEmpty, selection >= 0, selection < items.count else { return }
        let item = items[selection]
        if item.id.hasPrefix("action.") { app.touchPaletteAction(item.id) }
        item.action()
        dismiss()
    }

    @ViewBuilder
    private func row(idx: Int, item: Item) -> some View {
        let active = idx == selection
        HStack(spacing: 12) {
            Image(systemName: item.icon)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(active ? (modern ? Color.lAccent : Color.lInk) : Color.lInk3)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 1) {
                Text(item.title)
                    .font(Typo.sans(13.5, weight: .semibold))
                    .foregroundStyle(Color.lInk)
                    .lineLimit(1)
                Text(item.subtitle)
                    .font(Typo.sans(11))
                    .foregroundStyle(Color.lInk3)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            Text(item.kind.rawValue.uppercased())
                .font(Typo.eyebrow).tracking(1.2)
                .foregroundStyle(Color.lInk4)
        }
        .padding(.horizontal, 16).padding(.vertical, 9)
        .background(active ? (modern ? Color.lAccent.opacity(0.10) : Color.lInk.opacity(0.08)) : Color.clear)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private func hintKey(_ s: String) -> some View {
        Text(s)
            .font(Typo.mono(9, weight: .medium))
            .foregroundStyle(Color.lInk3)
            .padding(.horizontal, 4).padding(.vertical, 1)
            .overlay(RoundedRectangle(cornerRadius: modern ? 4 : 999).stroke(Color.lLine, lineWidth: 1))
    }
}

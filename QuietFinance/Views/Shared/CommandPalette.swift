import SwiftUI
import SwiftData

/// ⌘K palette: jump to a screen, switch active snapshot, open an account
/// or fire a quick action. Keyboard-first — arrow keys navigate, Return
/// fires the highlighted item, Esc dismisses.
struct CommandPalette: View {
    @EnvironmentObject var app: AppState
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Snapshot.date, order: .reverse) private var snapshots: [Snapshot]
    @Query(sort: \Account.name) private var accounts: [Account]
    @Query(sort: \Person.name) private var people: [Person]
    @Query(sort: \Country.code) private var countries: [Country]

    @State private var query: String = ""
    @State private var selection: Int = 0
    @FocusState private var focused: Bool

    enum Kind: String { case screen, snapshot, account, person, country, action }

    struct Item: Identifiable {
        let id = UUID()
        let kind: Kind
        let title: String
        let subtitle: String
        let icon: String
        let action: () -> Void
    }

    private var allItems: [Item] {
        var out: [Item] = []
        let allScreens: [(Screen, String, String)] = [
            (.dashboard, "Net Worth", "house"),
            (.trends, "Trends", "waveform.path.ecg"),
            (.snapshots, "Historical · Snapshots", "chart.line.uptrend.xyaxis"),
            (.diff, "Diff", "arrow.left.arrow.right"),
            (.reports, "Reports", "doc.text.magnifyingglass"),
            (.breakdown, "By Allocation", "square.grid.2x2"),
            (.people, "By Person", "person.2"),
            (.countries, "By Country", "globe"),
            (.assetTypes, "By Asset Type", "square.stack.3d.up"),
            (.accounts, "All Assets", "list.bullet"),
            (.receivables, "Receivables", "hourglass"),
            (.settings, "Settings", "gearshape"),
        ]
        for (s, label, icon) in allScreens {
            out.append(Item(kind: .screen, title: label, subtitle: "Screen", icon: icon) {
                app.selectedScreen = s
            })
        }
        for s in snapshots.prefix(40) {
            out.append(Item(kind: .snapshot, title: s.label,
                           subtitle: "Snapshot · \(Fmt.date(s.date))",
                           icon: s.isLocked ? "lock.fill" : "pencil") {
                app.activeSnapshotID = s.id
                app.selectedScreen = .snapshots
            })
        }
        for a in accounts.prefix(80) {
            let det = [a.person?.name, a.assetType?.name, a.country?.name]
                .compactMap { $0 }.joined(separator: " · ")
            out.append(Item(kind: .account, title: a.name,
                           subtitle: "Account · \(det)",
                           icon: "creditcard") {
                app.pendingFocusAccountID = a.id
                app.selectedScreen = .accounts
            })
        }
        for p in people {
            out.append(Item(kind: .person, title: p.name,
                           subtitle: "Person · \(p.accounts.count) accounts",
                           icon: "person.crop.circle") {
                app.pendingFocusPersonID = p.id
                app.selectedScreen = .people
            })
        }
        for c in countries {
            out.append(Item(kind: .country, title: "\(c.flag) \(c.name)",
                           subtitle: "Country · \(c.code)",
                           icon: "flag") {
                app.pendingFocusCountryID = c.id
                app.selectedScreen = .countries
            })
        }
        // Actions
        out.append(Item(kind: .action, title: "New Snapshot",
                       subtitle: "Action · capture this quarter",
                       icon: "plus.circle") {
            app.newSnapshotRequested = true
            app.selectedScreen = .snapshots
        })
        out.append(Item(kind: .action, title: "Open Settings",
                       subtitle: "Action",
                       icon: "gearshape") {
            app.selectedScreen = .settings
        })
        return out
    }

    private var filtered: [Item] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return Array(allItems.prefix(20)) }
        return allItems.filter {
            $0.title.lowercased().contains(q)
                || $0.subtitle.lowercased().contains(q)
        }.prefix(40).map { $0 }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "command")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.lInk3)
                TextField("Jump to…", text: $query)
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
                    .overlay(Capsule().stroke(Color.lLine, lineWidth: 1))
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
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.lLine, lineWidth: 1))
        .shadow(color: .black.opacity(0.35), radius: 24, y: 10)
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
        items[selection].action()
        dismiss()
    }

    @ViewBuilder
    private func row(idx: Int, item: Item) -> some View {
        let active = idx == selection
        HStack(spacing: 12) {
            Image(systemName: item.icon)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(active ? Color.lInk : Color.lInk3)
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
        .background(active ? Color.lInk.opacity(0.08) : Color.clear)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private func hintKey(_ s: String) -> some View {
        Text(s)
            .font(Typo.mono(9, weight: .medium))
            .foregroundStyle(Color.lInk3)
            .padding(.horizontal, 4).padding(.vertical, 1)
            .overlay(Capsule().stroke(Color.lLine, lineWidth: 1))
    }
}

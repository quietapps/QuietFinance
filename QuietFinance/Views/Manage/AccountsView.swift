import SwiftUI
import SwiftData

struct AccountsView: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var undo: UndoStash
    @Environment(\.modelContext) private var context
    @Query(sort: \Account.name) private var accounts: [Account]
    @Query(sort: \Snapshot.date) private var snapshots: [Snapshot]
    @State private var editing: Account?
    @State private var detailing: Account?
    @State private var creatingNew: Bool = false
    @State private var showInactive: Bool = true
    @State private var historyAccount: Account?
    @State private var confirmDelete: Account?
    @State private var cachedTrends: [UUID: [Double]] = [:]
    @State private var selectionMode: Bool = false
    @State private var selection: Set<UUID> = []
    @State private var bulkEditing: Bool = false
    @State private var merging: Bool = false
    @StateObject private var sizer = ColumnSizer(tableID: "accounts", specs: [
        ColumnSpec(id: "drag",    title: "",        minWidth: 24,  defaultWidth: 28,  resizable: false, sortable: false),
        ColumnSpec(id: "name",    title: "Name",    minWidth: 140, defaultWidth: 240, flex: true),
        ColumnSpec(id: "person",  title: "Person",  minWidth: 90,  defaultWidth: 130),
        ColumnSpec(id: "country", title: "Country", minWidth: 70,  defaultWidth: 100),
        ColumnSpec(id: "type",    title: "Type",    minWidth: 100, defaultWidth: 140),
        ColumnSpec(id: "ccy",     title: "Ccy",     minWidth: 44,  defaultWidth: 60),
        ColumnSpec(id: "trend",   title: "12mo",    minWidth: 70,  defaultWidth: 90),
        ColumnSpec(id: "unreal",  title: "Unrealized", minWidth: 100, defaultWidth: 130, alignment: .trailing),
        ColumnSpec(id: "status",  title: "Status",  minWidth: 70,  defaultWidth: 100),
        ColumnSpec(id: "actions", title: "",        minWidth: 170, defaultWidth: 170, alignment: .trailing, resizable: false, sortable: false),
    ])

    private var visible: [Account] {
        let filtered = showInactive ? accounts : accounts.filter(\.isActive)
        // Default ordering: user-defined sortIndex, then name as tiebreaker.
        let base = filtered.sorted {
            if $0.sortIndex != $1.sortIndex { return $0.sortIndex < $1.sortIndex }
            return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
        return sizer.sorted(base, comparators: [
            "name":    { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending },
            "person":  { ($0.person?.name ?? "").localizedCaseInsensitiveCompare($1.person?.name ?? "") == .orderedAscending },
            "country": { ($0.country?.code ?? "") < ($1.country?.code ?? "") },
            "type":    { ($0.assetType?.name ?? "").localizedCaseInsensitiveCompare($1.assetType?.name ?? "") == .orderedAscending },
            "ccy":     { $0.nativeCurrency.rawValue < $1.nativeCurrency.rawValue },
            "trend":   { trendGrowth($0) < trendGrowth($1) },
            "unreal":  { unrealizedGain($0) < unrealizedGain($1) },
            "status":  { ($0.isActive ? 0 : 1) < ($1.isActive ? 0 : 1) },
        ])
    }

    private func trendGrowth(_ a: Account) -> Double {
        guard let series = cachedTrends[a.id], let first = series.first, let last = series.last, first != 0 else { return 0 }
        return (last - first) / abs(first)
    }

    private func unrealizedGain(_ a: Account) -> Double {
        guard a.costBasis > 0, let cur = latestNativeValue(a) else { return -.infinity }
        return cur - a.costBasis
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            header
            if accounts.isEmpty {
                EditorialEmpty(
                    eyebrow: "Data · Accounts",
                    title: "No accounts",
                    titleItalic: "tracked yet.",
                    body: "An account is any vessel that holds value — a checking account, a brokerage, a property, a loan. Add one to begin.",
                    detail: "Accounts carry owner, country, and asset type. Values live on snapshots.",
                    ctaLabel: "New Account",
                    cta: { creatingNew = true },
                    illustration: "list.bullet.rectangle"
                )
            } else {
                if selectionMode { selectionBar }
                tablePanel
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .sheet(item: $editing) { AccountEditorSheet(existing: $0) }
        .sheet(isPresented: $creatingNew) { AccountEditorSheet(existing: nil) }
        .sheet(item: $historyAccount) { AccountHistoryView(account: $0) }
        .sheet(item: $detailing) { AccountDetailSheet(account: $0) }
        .sheet(isPresented: $bulkEditing) {
            BulkEditAccountsSheet(accountIDs: selection) {
                selection.removeAll()
                selectionMode = false
            }
        }
        .sheet(isPresented: $merging) {
            MergeAccountsSheet(candidateIDs: Array(selection)) {
                selection.removeAll()
                selectionMode = false
            }
        }
        .confirmationDialog("Delete \(confirmDelete?.name ?? "")?",
                            isPresented: Binding(get: { confirmDelete != nil }, set: { if !$0 { confirmDelete = nil } }),
                            titleVisibility: .visible) {
            Button("Delete permanently", role: .destructive) {
                if let a = confirmDelete {
                    let cap = undo.capture(account: a)
                    context.delete(a)
                    do {
                        try context.save()
                        undo.stash(.account(cap))
                    } catch {
                        context.rollback()
                    }
                }
                confirmDelete = nil
            }
            .keyboardShortcut(.defaultAction)
            Button("Cancel", role: .cancel) { confirmDelete = nil }
        } message: {
            Text("Account and all \(confirmDelete?.values.count ?? 0) historical values across snapshots will be deleted. You have 10 seconds to undo.")
        }
        .onAppear {
            recomputeTrends()
            consumePendingFocus()
        }
        .onChange(of: app.pendingFocusAccountID) { _, _ in consumePendingFocus() }
        .onChange(of: editing?.id) { _, id in
            if let a = editing, let id { app.touchRecent(.account, id: id, label: a.name) }
        }
        .onChange(of: detailing?.id) { _, id in
            if let a = detailing, let id { app.touchRecent(.account, id: id, label: a.name) }
        }
        .onChange(of: snapshots.count) { _, _ in recomputeTrends() }
        .onChange(of: accounts.count) { _, _ in recomputeTrends() }
        .onChange(of: app.displayCurrency) { _, _ in recomputeTrends() }
    }

    /// Latest native value of `a` from its most-recent snapshot row.
    private func latestNativeValue(_ a: Account) -> Double? {
        guard let v = a.values
            .compactMap({ av -> (Date, Double)? in
                guard let s = av.snapshot else { return nil }
                return (s.date, av.nativeValue)
            })
            .max(by: { $0.0 < $1.0 }) else { return nil }
        return v.1
    }

    @ViewBuilder
    private func unrealizedCell(_ a: Account) -> some View {
        if a.costBasis <= 0 {
            Text("—")
                .font(Typo.mono(11))
                .foregroundStyle(Color.lInk4)
        } else if let cur = latestNativeValue(a) {
            let gain = cur - a.costBasis
            let pct = a.costBasis == 0 ? 0 : gain / a.costBasis * 100
            VStack(alignment: .trailing, spacing: 1) {
                Text("\(gain >= 0 ? "+" : "−")\(Fmt.currency(abs(gain), a.nativeCurrency))")
                    .font(Typo.mono(11.5, weight: .semibold))
                    .foregroundStyle(gain >= 0 ? Color.lGain : Color.lLoss)
                Text("\(gain >= 0 ? "+" : "−")\(String(format: "%.1f", abs(pct)))%")
                    .font(Typo.mono(9.5))
                    .foregroundStyle(Color.lInk3)
            }
            .help("Cost basis \(Fmt.currency(a.costBasis, a.nativeCurrency)) → Current \(Fmt.currency(cur, a.nativeCurrency))")
            .stealthAmount()
        } else {
            Text("no data")
                .font(Typo.mono(10))
                .foregroundStyle(Color.lInk4)
        }
    }

    private func consumePendingFocus() {
        guard let id = app.pendingFocusAccountID,
              let a = accounts.first(where: { $0.id == id }) else { return }
        detailing = a
        app.pendingFocusAccountID = nil
    }

    private func recomputeTrends() {
        let cutoff = Calendar.current.date(byAdding: .month, value: -12, to: .now) ?? .distantPast
        let recent = snapshots.filter { $0.date >= cutoff }.sorted { $0.date < $1.date }
        var out: [UUID: [Double]] = [:]
        for a in accounts {
            let series = recent.compactMap { s -> Double? in
                guard let v = s.values.first(where: { $0.account?.id == a.id }) else { return nil }
                return CurrencyConverter.netDisplayValue(for: v, in: app.displayCurrency)
            }
            out[a.id] = series
        }
        cachedTrends = out
    }

    private var header: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text("DATA · ALL ACCOUNTS")
                    .font(Typo.eyebrow).tracking(1.5).foregroundStyle(Color.lInk3)
                HStack(spacing: 8) {
                    Text("Accounts").font(Typo.serifNum(32))
                    Text("— \(visible.count)").font(Typo.serifItalic(28))
                        .foregroundStyle(Color.lInk3)
                }
                .foregroundStyle(Color.lInk)
            }
            Spacer()
            Toggle("", isOn: $showInactive)
                .toggleStyle(.switch)
                .labelsHidden()
            Text("Show retired")
                .font(Typo.sans(12))
                .foregroundStyle(Color.lInk2)
            GhostButton(action: {
                selectionMode.toggle()
                if !selectionMode { selection.removeAll() }
            }) {
                Text(selectionMode ? "Done" : "Select")
            }
            PrimaryButton(action: { creatingNew = true }) {
                HStack(spacing: 5) {
                    Image(systemName: "plus").font(.system(size: 10, weight: .bold))
                    Text("New Account")
                }
            }
        }
    }

    private var selectionBar: some View {
        HStack(spacing: 12) {
            Text("\(selection.count) selected")
                .font(Typo.sans(12, weight: .medium))
                .foregroundStyle(Color.lInk2)
            Spacer()
            GhostButton(action: { selection = Set(visible.map(\.id)) }) {
                Text("Select all")
            }
            GhostButton(action: { selection.removeAll() }) {
                Text("Clear")
            }
            .disabled(selection.isEmpty)
            GhostButton(action: { bulkEditing = true }) {
                Text("Bulk Edit…")
            }
            .disabled(selection.isEmpty)
            GhostButton(action: { merging = true }) {
                Text("Merge…")
            }
            .disabled(selection.count != 2)
        }
        .padding(.horizontal, 4)
    }

    private var tablePanel: some View {
        Panel {
            VStack(spacing: 0) {
                PanelHead(title: "All accounts", meta: "\(visible.count) visible")
                ResizableHeader(sizer: sizer)
                ScrollView(.vertical) {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(visible.enumerated()), id: \.element.id) { idx, a in
                            row(a, idx: idx)
                            if idx < visible.count - 1 {
                                Divider().overlay(Color.lLine)
                            }
                        }
                    }
                }
            }
        }
        .frame(maxHeight: .infinity)
    }

    private func row(_ a: Account, idx: Int) -> some View {
        HStack(spacing: 0) {
            if selectionMode {
                Toggle("", isOn: Binding(
                    get: { selection.contains(a.id) },
                    set: { isOn in
                        if isOn { selection.insert(a.id) } else { selection.remove(a.id) }
                    }
                ))
                .toggleStyle(.checkbox)
                .labelsHidden()
                .padding(.trailing, 8)
            }
            ResizableCell(sizer: sizer, colID: "name") {
                HStack(spacing: 6) {
                    Text(a.name)
                        .font(Typo.sans(13, weight: .medium))
                        .foregroundStyle(Color.lInk)
                        .lineLimit(1)
                    if !a.groupName.isEmpty {
                        Text(a.groupName)
                            .font(Typo.eyebrow).tracking(1.0)
                            .foregroundStyle(Color.lInk2)
                            .padding(.horizontal, 5).padding(.vertical, 1)
                            .overlay(Capsule().stroke(Color.lLine, lineWidth: 1))
                    }
                    if AccountAnalysis.isStale(a) {
                        Text("STALE")
                            .font(Typo.eyebrow).tracking(1.0)
                            .foregroundStyle(Color.lLoss)
                            .padding(.horizontal, 5).padding(.vertical, 1)
                            .overlay(Capsule().stroke(Color.lLoss.opacity(0.5), lineWidth: 1))
                            .help("Last 3 snapshot values identical. Click to review.")
                    }
                    if a.person?.includeInNetWorth == false {
                        Text("OFF NW")
                            .font(Typo.eyebrow).tracking(1.0)
                            .foregroundStyle(Color.lInk3)
                            .padding(.horizontal, 5).padding(.vertical, 1)
                            .overlay(Capsule().stroke(Color.lInk3.opacity(0.5), lineWidth: 1))
                            .help("Owner excluded from net worth — tracked but not aggregated.")
                    }
                    Spacer(minLength: 0)
                }
            }
            ResizableCell(sizer: sizer, colID: "person") {
                HStack(spacing: 6) {
                    if let p = a.person {
                        Avatar(text: String(p.name.prefix(1)),
                               color: Color.fromHex(p.colorHex) ?? Palette.fallback(for: p.name),
                               size: 18)
                        Text(p.name)
                            .font(Typo.sans(12))
                            .foregroundStyle(Color.lInk2)
                            .lineLimit(1)
                    } else {
                        Text("—").foregroundStyle(Color.lInk3)
                    }
                    Spacer(minLength: 0)
                }
            }
            ResizableCell(sizer: sizer, colID: "country") {
                HStack(spacing: 4) {
                    Text(a.country?.flag ?? "")
                        .font(.system(size: 14))
                    Text(a.country?.code ?? "—")
                        .font(Typo.mono(11))
                        .foregroundStyle(Color.lInk2)
                    Spacer(minLength: 0)
                }
            }
            ResizableCell(sizer: sizer, colID: "type") {
                Text(a.assetType?.name ?? "Unknown type")
                    .font(Typo.sans(12))
                    .foregroundStyle(a.assetType == nil ? Color.lLoss : Color.lInk2)
                    .lineLimit(1)
            }
            ResizableCell(sizer: sizer, colID: "ccy") {
                Text(a.nativeCurrency.rawValue)
                    .font(Typo.mono(11))
                    .foregroundStyle(Color.lInk3)
            }
            ResizableCell(sizer: sizer, colID: "trend") {
                let series = cachedTrends[a.id] ?? []
                let up = series.count >= 2 ? (series.last! >= series.first!) : true
                Sparkline(values: series,
                          stroke: series.count < 2 ? Color.lInk3 : (up ? Color.lGain : Color.lLoss),
                          fill: (up ? Color.lGain : Color.lLoss).opacity(0.08))
                    .frame(height: 18)
            }
            ResizableCell(sizer: sizer, colID: "unreal") {
                unrealizedCell(a)
            }
            ResizableCell(sizer: sizer, colID: "status") {
                HStack {
                    Pill(text: a.isActive ? "active" : "retired", emphasis: a.isActive)
                    Spacer(minLength: 0)
                }
            }
            ResizableCell(sizer: sizer, colID: "actions") {
                HStack(spacing: 6) {
                    Button {
                        app.togglePinnedAccount(a.id)
                    } label: {
                        Image(systemName: app.isPinnedAccount(a.id) ? "star.fill" : "star")
                            .font(.system(size: 11))
                            .foregroundStyle(app.isPinnedAccount(a.id) ? Color.lGain : Color.lInk3)
                    }
                    .buttonStyle(.plain)
                    .pointerStyle(.link)
                    .help(app.isPinnedAccount(a.id) ? "Unpin from dashboard watchlist" : "Pin to dashboard watchlist")
                    GhostButton(action: { detailing = a }) {
                        Image(systemName: "rectangle.and.text.magnifyingglass")
                            .font(.system(size: 10, weight: .bold))
                    }
                    GhostButton(action: { editing = a }) { Text("Edit") }
                    Menu {
                        Button("Open detail…") { detailing = a }
                        Button("Show History") { historyAccount = a }
                        Button(a.isActive ? "Archive (Retire)" : "Reactivate") {
                            a.isActive.toggle()
                            try? context.save()
                        }
                        Divider()
                        Button("Delete permanently…", role: .destructive) {
                            confirmDelete = a
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Color.lInk2)
                            .frame(width: 24, height: 24)
                            .overlay(Circle().stroke(Color.lLine, lineWidth: 1))
                    }
                    .menuStyle(.borderlessButton)
                    .menuIndicator(.hidden)
                    .fixedSize()
                    .pointerStyle(.link)
                }
            }
        }
        .padding(.horizontal, 18).padding(.vertical, 10)
        .background(rowBackground(a, idx: idx))
        .dropDestination(for: String.self) { items, _ in
            handleDrop(items, before: a)
            return true
        }
        .rowClickable {
            if selectionMode {
                if selection.contains(a.id) { selection.remove(a.id) } else { selection.insert(a.id) }
            } else {
                editing = a
            }
        }
    }

    private func rowBackground(_ a: Account, idx: Int) -> Color {
        if selectionMode && selection.contains(a.id) {
            return Color.lInk.opacity(0.06)
        }
        return idx.isMultiple(of: 2) ? Color.clear : Color.lSunken.opacity(0.5)
    }

    @ViewBuilder
    private func dragHandle(for a: Account, enabled: Bool) -> some View {
        let img = Image(systemName: "line.3.horizontal")
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(enabled ? Color.lInk3 : Color.lInk4.opacity(0.4))
            .frame(maxWidth: .infinity, alignment: .center)
            .contentShape(Rectangle())
            .help(enabled ? "Drag to reorder" : "Clear column sort to enable drag-reorder")
        if enabled {
            img.draggable(a.id.uuidString)
        } else {
            img
        }
    }

    private func handleDrop(_ items: [String], before target: Account) {
        guard let idStr = items.first,
              let draggedID = UUID(uuidString: idStr),
              draggedID != target.id,
              let dragged = accounts.first(where: { $0.id == draggedID }) else { return }
        var ordered = accounts.sorted { lhs, rhs in
            if lhs.sortIndex != rhs.sortIndex { return lhs.sortIndex < rhs.sortIndex }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
        ordered.removeAll { $0.id == draggedID }
        if let idx = ordered.firstIndex(where: { $0.id == target.id }) {
            ordered.insert(dragged, at: idx)
        } else {
            ordered.append(dragged)
        }
        for (i, acc) in ordered.enumerated() { acc.sortIndex = i + 1 }
        try? context.save()
    }
}

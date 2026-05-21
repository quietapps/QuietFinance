import SwiftUI
import SwiftData

enum GroupKey: String, CaseIterable, Identifiable {
    case category = "Category"
    case person   = "Person"
    case country  = "Country"
    case assetType = "Type"
    case group    = "Group"
    var id: String { rawValue }
}

struct Filter: Hashable, Identifiable {
    let id = UUID()
    let key: GroupKey
    let label: String
    let matchValue: String
}

struct PendingFilter: Equatable {
    let key: GroupKey
    let matchValue: String
    let label: String
}

struct BreakdownView: View {
    @EnvironmentObject var app: AppState
    @Query(sort: \Snapshot.date, order: .reverse) private var snapshots: [Snapshot]
    @State private var groupBy: GroupKey = .category
    @State private var filters: [Filter] = []
    @State private var hovered: TreemapTile?
    @State private var historyAccount: Account?
    @State private var detailAccount: Account?
    @Query private var accounts: [Account]

    @State private var cachedSorted: [Row] = []
    @State private var cachedTiles: [TreemapTile] = []
    @State private var cachedTotal: Double = 0
    @State private var cachedMagnitude: Double = 0
    @State private var tableSearch: String = ""
    @StateObject private var sizer = ColumnSizer(tableID: "breakdown", specs: [
        ColumnSpec(id: "account", title: "Account", minWidth: 140, defaultWidth: 260, flex: true),
        ColumnSpec(id: "owner",   title: "Owner",   minWidth: 90,  defaultWidth: 150),
        ColumnSpec(id: "country", title: "Country", minWidth: 55,  defaultWidth: 80),
        ColumnSpec(id: "type",    title: "Type",    minWidth: 100, defaultWidth: 150),
        ColumnSpec(id: "native",  title: "Native",  minWidth: 90,  defaultWidth: 130, alignment: .trailing),
        ColumnSpec(id: "display", title: "Display", minWidth: 90,  defaultWidth: 130, alignment: .trailing),
        ColumnSpec(id: "pct",     title: "%",       minWidth: 50,  defaultWidth: 70,  alignment: .trailing),
    ])

    var body: some View {
        Group {
            if snapshots.isEmpty {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    EditorialEmpty(
                        eyebrow: "Breakdown · Allocation",
                        title: "Nothing",
                        titleItalic: "to allocate.",
                        body: "Allocation needs at least one snapshot to slice. Create a snapshot, record balances, then return here to see the treemap and table.",
                        detail: "Filter by person, country, or asset type once data exists.",
                        ctaLabel: "Create first snapshot",
                        cta: {
                            app.newSnapshotRequested = true
                            app.selectedScreen = .snapshots
                        },
                        illustration: "square.grid.2x2"
                    )
                }
            } else {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    Panel { treemapSection }
                    Panel { tableSection }
                }
            }
        }
        .sheet(item: $historyAccount) { AccountHistoryView(account: $0) }
        .sheet(item: $detailAccount) { AccountDetailSheet(account: $0) }
        .onAppear {
            consumePending()
            recompute()
        }
        .onChange(of: app.pendingBreakdownFilter) { _, _ in consumePending() }
        .onChange(of: app.activeSnapshotID) { _, _ in recompute() }
        .onChange(of: app.displayCurrency) { _, _ in recompute() }
        .onChange(of: groupBy) { _, _ in recompute() }
        .onChange(of: filters) { _, _ in recompute() }
        .onChange(of: snapshots.count) { _, _ in recompute() }
        .onChange(of: app.includeIlliquidInNetWorth) { _, _ in recompute() }
    }

    private func consumePending() {
        guard let pf = app.pendingBreakdownFilter else { return }
        app.pendingBreakdownFilter = nil
        groupBy = pf.key
        let newFilter = Filter(key: pf.key, label: pf.label, matchValue: pf.matchValue)
        if !filters.contains(where: { $0.key == newFilter.key && $0.matchValue == newFilter.matchValue }) {
            filters.append(newFilter)
        }
    }

    private func recompute() {
        let rows = computeRows()
        let sorted = rows.sorted { $0.display > $1.display }
        let total = rows.reduce(0) { $0 + $1.display }
        let magnitude = rows.reduce(0) { $0 + abs($1.display) }
        let tiles = computeTiles(from: rows)
        cachedSorted = sorted
        cachedTotal = total
        cachedMagnitude = magnitude
        cachedTiles = tiles

        let uniqueCcy = Array(Set(rows.map { $0.currency.rawValue })).sorted()
        sizer.setTitle("native", uniqueCcy.isEmpty ? nil : "Native (\(uniqueCcy.joined(separator: "/")))")
        sizer.setTitle("display", "Display (\(app.displayCurrency.rawValue))")
    }

    private var active: Snapshot? {
        guard let id = app.activeSnapshotID else { return snapshots.first }
        return snapshots.first { $0.id == id }
    }

    // MARK: header

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("BREAKDOWN")
                        .font(Typo.eyebrow).tracking(1.5)
                        .foregroundStyle(Color.lInk3)
                    HStack(spacing: 8) {
                        Text("Allocation").font(Typo.serifNum(32))
                        Text("— grouped by \(groupBy.rawValue.lowercased())")
                            .font(Typo.serifItalic(28))
                            .foregroundStyle(Color.lInk3)
                    }
                    .foregroundStyle(Color.lInk)
                }
                Spacer()
                SegControl<GroupKey>(
                    options: GroupKey.allCases.map { (label: $0.rawValue, value: $0) },
                    selection: $groupBy
                )
            }

            if !filters.isEmpty {
                HStack(spacing: 6) {
                    Text("FILTERS")
                        .font(Typo.eyebrow).tracking(1.2)
                        .foregroundStyle(Color.lInk3)
                    ForEach(filters) { f in
                        HStack(spacing: 4) {
                            Text("\(f.key.rawValue) · \(f.label)")
                                .font(Typo.mono(10.5, weight: .medium))
                            Button {
                                filters.removeAll { $0.id == f.id }
                            } label: { Image(systemName: "xmark").font(.system(size: 8, weight: .bold)) }
                            .buttonStyle(.plain)
                            .pointerStyle(.link)
                        }
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .foregroundStyle(Color.lInk2)
                        .overlay(Capsule().stroke(Color.lLine, lineWidth: 1))
                    }
                    GhostButton(action: { filters.removeAll() }) { Text("Clear") }
                }
            }
        }
    }

    // MARK: treemap

    private func computeRows() -> [Row] {
        guard let s = active else { return [] }
        let target = app.displayCurrency
        let rate = s.usdToInrRate
        let inc = app.includeIlliquidInNetWorth
        return s.values.compactMap { v -> Row? in
            guard let acc = v.account else { return nil }
            if !inc && (acc.assetType?.category.isIlliquid ?? false) { return nil }
            let personName = acc.person?.name ?? "—"
            let countryName = acc.country?.name ?? ""
            let r = Row(
                id: v.id,
                accountID: acc.id,
                name: acc.name,
                person: personName,
                personColor: Color.fromHex(acc.person?.colorHex) ?? Palette.fallback(for: personName),
                country: "\(acc.country?.flag ?? "") \(acc.country?.code ?? "")",
                countryName: countryName,
                countryColor: Color.fromHex(acc.country?.colorHex) ?? Palette.fallback(for: acc.country?.code ?? countryName),
                category: acc.assetType?.category.rawValue ?? "",
                assetType: acc.assetType?.name ?? "—",
                currency: acc.nativeCurrency,
                nativeValue: v.nativeValue,
                display: CurrencyConverter.convert(
                    nativeValue: v.nativeValue,
                    from: acc.nativeCurrency,
                    to: target,
                    usdToInrRate: rate
                ),
                institution: acc.institution,
                notes: acc.notes,
                groupName: acc.groupName
            )
            for f in filters {
                switch f.key {
                case .category where r.category != f.matchValue: return nil
                case .person where r.person != f.matchValue: return nil
                case .country where r.countryName != f.matchValue: return nil
                case .assetType where r.assetType != f.matchValue: return nil
                default: break
                }
            }
            return r
        }
    }

    private func computeTiles(from rows: [Row]) -> [TreemapTile] {
        let groups = Dictionary(grouping: rows) { row in
            switch groupBy {
            case .category:  return row.category
            case .person:    return row.person
            case .country:   return row.countryName
            case .assetType: return row.assetType
            case .group:     return row.groupName.isEmpty ? "Ungrouped" : row.groupName
            }
        }
        return groups.map { (groupLabel, groupRows) in
            let magSum = groupRows.map { abs($0.display) }.reduce(0, +)
            let color = colorFor(group: groupLabel, key: groupBy, sample: groupRows.first)
            let groupDebt = !groupRows.isEmpty && groupRows.allSatisfy { $0.category == AssetCategory.debt.rawValue }
            let children = groupRows.sorted { abs($0.display) > abs($1.display) }
                .map { r in
                    TreemapTile(
                        label: r.name,
                        value: max(abs(r.display), 0.01),
                        color: color,
                        accountID: r.accountID,
                        nativeValue: r.nativeValue,
                        nativeCurrency: r.currency,
                        isDebt: r.category == AssetCategory.debt.rawValue
                    )
                }
            return TreemapTile(label: groupLabel,
                               value: max(magSum, 0.01),
                               color: color,
                               isDebt: groupDebt,
                               children: children)
        }
        .sorted { $0.value > $1.value }
    }

    private func colorFor(group: String, key: GroupKey, sample: Row?) -> Color {
        switch key {
        case .category:
            if let cat = AssetCategory(rawValue: group) { return Palette.color(for: cat) }
        case .person:
            if let sample { return sample.personColor }
        case .country:
            if let sample { return sample.countryColor }
        case .assetType:
            break
        case .group:
            break
        }
        return Palette.fallback(for: group)
    }

    private var treemapSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            PanelHead(title: "Distribution", meta: Fmt.compact(cachedTotal, app.displayCurrency))
            VStack(alignment: .leading, spacing: 10) {
                if cachedTiles.isEmpty {
                    filterEmptyState
                } else {
                    StackedBarsView(
                        groups: cachedTiles,
                        currency: app.displayCurrency,
                        total: cachedMagnitude,
                        onTap: { tile in handleTap(tile) },
                        onHover: { tile in hovered = tile }
                    )
                }

                if let h = hovered {
                    HStack {
                        Text(h.label).font(Typo.sans(12, weight: .semibold))
                        Text("·").foregroundStyle(Color.lInk4)
                        Text(Fmt.currency(h.value, app.displayCurrency))
                            .font(Typo.mono(12, weight: .medium))
                    }
                    .foregroundStyle(Color.lInk2)
                } else {
                    Text("Click group to filter · click account for history")
                        .font(Typo.serifItalic(13))
                        .foregroundStyle(Color.lInk3)
                }
            }
            .padding(18)
        }
    }

    @ViewBuilder
    private var filterEmptyState: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("No accounts match current filters")
                .font(Typo.sans(13, weight: .semibold))
                .foregroundStyle(Color.lInk)
            Text(filters.isEmpty
                 ? "Active snapshot has no values to display."
                 : "Remove a filter or switch groupings to see data.")
                .font(Typo.serifItalic(12.5))
                .foregroundStyle(Color.lInk3)
            if !filters.isEmpty {
                GhostButton(action: { filters.removeAll() }) { Text("Clear filters") }
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(24)
        .background(Color.lSunken)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.lLine, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func handleTap(_ tile: TreemapTile) {
        if let accountID = tile.accountID, let acc = accounts.first(where: { $0.id == accountID }) {
            historyAccount = acc
            return
        }
        let isParent = !tile.children.isEmpty
        if isParent {
            let newFilter = Filter(key: groupBy, label: tile.label, matchValue: tile.label)
            if !filters.contains(where: { $0.key == newFilter.key && $0.matchValue == newFilter.matchValue }) {
                filters.append(newFilter)
            }
        }
    }

    // MARK: table

    private struct Row: Identifiable {
        let id: UUID
        let accountID: UUID
        let name: String
        let person: String
        let personColor: Color
        let country: String
        let countryName: String
        let countryColor: Color
        let category: String
        let assetType: String
        let currency: Currency
        let nativeValue: Double
        let display: Double
        let institution: String
        let notes: String
        let groupName: String
    }

    private var filteredRows: [Row] {
        let q = tableSearch.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return cachedSorted }
        return cachedSorted.filter { r in
            r.name.lowercased().contains(q)
                || r.person.lowercased().contains(q)
                || r.countryName.lowercased().contains(q)
                || r.assetType.lowercased().contains(q)
                || r.category.lowercased().contains(q)
                || r.institution.lowercased().contains(q)
                || r.notes.lowercased().contains(q)
        }
    }

    private var sortedFilteredRows: [Row] {
        let total = cachedTotal
        return sizer.sorted(filteredRows, comparators: [
            "account": { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending },
            "owner":   { $0.person.localizedCaseInsensitiveCompare($1.person) == .orderedAscending },
            "country": { $0.country < $1.country },
            "type":    { $0.assetType.localizedCaseInsensitiveCompare($1.assetType) == .orderedAscending },
            "native":  { $0.nativeValue < $1.nativeValue },
            "display": { $0.display < $1.display },
            "pct":     { (total > 0 ? $0.display / total : 0) < (total > 0 ? $1.display / total : 0) },
        ])
    }

    private var tableSection: some View {
        let rows = sortedFilteredRows
        let total = cachedTotal
        return VStack(spacing: 0) {
            PanelHead(title: "Accounts", meta: "\(rows.count) of \(cachedSorted.count)")
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.lInk3)
                TextField("Search name, owner, country, type, institution, notes", text: $tableSearch)
                    .textFieldStyle(.plain)
                    .font(Typo.sans(12))
                    .foregroundStyle(Color.lInk)
                if !tableSearch.isEmpty {
                    Button { tableSearch = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.lInk3)
                    }
                    .buttonStyle(.plain)
                    .pointerStyle(.link)
                }
            }
            .padding(.horizontal, 18).padding(.vertical, 8)
            .overlay(Rectangle().frame(height: 1).foregroundStyle(Color.lLine), alignment: .bottom)
            VStack(spacing: 0) {
                ResizableHeader(sizer: sizer)
                if rows.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(tableSearch.isEmpty && filters.isEmpty
                             ? "No accounts in active snapshot."
                             : "No accounts match search or filters.")
                            .font(Typo.sans(12.5, weight: .medium))
                            .foregroundStyle(Color.lInk2)
                        if !tableSearch.isEmpty || !filters.isEmpty {
                            Text("Try clearing search or removing a filter.")
                                .font(Typo.serifItalic(12))
                                .foregroundStyle(Color.lInk3)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 18).padding(.vertical, 20)
                }
                ForEach(Array(rows.enumerated()), id: \.element.id) { i, r in
                    HStack(spacing: 0) {
                        ResizableCell(sizer: sizer, colID: "account") {
                            Text(r.name).font(Typo.sans(12.5, weight: .medium))
                                .foregroundStyle(Color.lInk)
                                .lineLimit(1)
                        }
                        ResizableCell(sizer: sizer, colID: "owner") {
                            HStack(spacing: 5) {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(r.personColor).frame(width: 6, height: 12)
                                Text(r.person).font(Typo.sans(12))
                                    .lineLimit(1)
                                Spacer(minLength: 0)
                            }
                            .foregroundStyle(Color.lInk2)
                        }
                        ResizableCell(sizer: sizer, colID: "country") {
                            Text(r.country).font(.system(size: 13))
                                .lineLimit(1)
                        }
                        ResizableCell(sizer: sizer, colID: "type") {
                            Text(r.assetType).font(Typo.sans(12))
                                .foregroundStyle(Color.lInk2)
                                .lineLimit(1)
                        }
                        ResizableCell(sizer: sizer, colID: "native") {
                            Text(Fmt.currency(r.nativeValue, r.currency))
                                .font(Typo.mono(12))
                                .foregroundStyle(Color.lInk2)
                        }
                        ResizableCell(sizer: sizer, colID: "display") {
                            Text(Fmt.compact(r.display, app.displayCurrency))
                                .font(Typo.mono(12, weight: .semibold))
                        }
                        ResizableCell(sizer: sizer, colID: "pct") {
                            Text(total > 0 ? String(format: "%.1f%%", r.display / total * 100) : "—")
                                .font(Typo.mono(11))
                                .foregroundStyle(Color.lInk3)
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(i.isMultiple(of: 2) ? Color.clear : Color.lSunken.opacity(0.5))
                    .contentShape(Rectangle())
                    .onTapGesture(count: 2) {
                        if let acc = accounts.first(where: { $0.id == r.accountID }) {
                            detailAccount = acc
                        }
                    }
                    .pointerStyle(.link)

                    if i < rows.count - 1 {
                        Divider().overlay(Color.lLine)
                    }
                }
            }
        }
    }
}

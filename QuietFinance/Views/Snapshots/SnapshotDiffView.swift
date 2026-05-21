import SwiftUI
import SwiftData

struct SnapshotDiffView: View {
    @EnvironmentObject var app: AppState
    @Query(sort: \Snapshot.date, order: .reverse) private var snapshots: [Snapshot]

    @State private var aID: UUID?
    @State private var bID: UUID?
    @State private var cachedRows: [Row] = []
    @State private var cachedTotalA: Double = 0
    @State private var cachedTotalB: Double = 0
    @State private var cachedAddedCount: Int = 0
    @State private var cachedDroppedCount: Int = 0
    @State private var sortMode: SortMode = .absDelta
    @State private var showZeros: Bool = false
    @StateObject private var sizer = ColumnSizer(tableID: "snapshotDiff", specs: [
        ColumnSpec(id: "account", title: "Account", minWidth: 140, defaultWidth: 260, flex: true),
        ColumnSpec(id: "owner",   title: "Owner",   minWidth: 80,  defaultWidth: 120),
        ColumnSpec(id: "country", title: "Country", minWidth: 60,  defaultWidth: 80),
        ColumnSpec(id: "type",    title: "Type",    minWidth: 90,  defaultWidth: 130),
        ColumnSpec(id: "from",    title: "From",    minWidth: 90,  defaultWidth: 120, alignment: .trailing),
        ColumnSpec(id: "to",      title: "To",      minWidth: 90,  defaultWidth: 120, alignment: .trailing),
        ColumnSpec(id: "dAbs",    title: "Δ abs",   minWidth: 100, defaultWidth: 130, alignment: .trailing),
        ColumnSpec(id: "dPct",    title: "Δ %",     minWidth: 70,  defaultWidth: 90,  alignment: .trailing),
    ])

    private enum SortMode: String, CaseIterable, Identifiable {
        case absDelta = "Δ abs"
        case pctDelta = "Δ %"
        case name     = "Name"
        case valueB   = "Value"
        var id: String { rawValue }
    }

    private struct Row: Identifiable, Equatable {
        let id: UUID
        let name: String
        let person: String
        let country: String
        let countryFlag: String
        let type: String
        let valA: Double
        let valB: Double
        let diff: Double
        let pct: Double
        let status: Status
        enum Status: String, Equatable { case same, added, dropped }
    }

    private var snapA: Snapshot? { snapshots.first { $0.id == aID } }
    private var snapB: Snapshot? { snapshots.first { $0.id == bID } }

    var body: some View {
        Group {
            if snapshots.count < 2 {
                EditorialEmpty(
                    eyebrow: "Overview · Diff",
                    title: "Needs",
                    titleItalic: "two snapshots.",
                    body: "A diff compares account balances between two moments. Capture at least two snapshots to see what moved, arrived, or vanished.",
                    ctaLabel: "New snapshot",
                    cta: {
                        app.newSnapshotRequested = true
                        app.selectedScreen = .snapshots
                    },
                    illustration: "arrow.left.arrow.right"
                )
            } else {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    pickerRow
                    kpiRow
                    Panel { sankeySection }
                    Panel { tableSection }
                }
            }
        }
        .onAppear { initPickers(); recompute() }
        .onChange(of: aID) { _, _ in recompute() }
        .onChange(of: bID) { _, _ in recompute() }
        .onChange(of: app.displayCurrency) { _, _ in recompute() }
        .onChange(of: sortMode) { _, _ in recompute() }
        .onChange(of: showZeros) { _, _ in recompute() }
        .onChange(of: snapshots.count) { _, _ in initPickers(); recompute() }
        .onChange(of: app.includeIlliquidInNetWorth) { _, _ in recompute() }
    }

    private func initPickers() {
        guard snapshots.count >= 2 else { return }
        if aID == nil || !snapshots.contains(where: { $0.id == aID }) {
            aID = snapshots[1].id
        }
        if bID == nil || !snapshots.contains(where: { $0.id == bID }) {
            bID = snapshots[0].id
        }
    }

    // MARK: header

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("OVERVIEW · DIFF")
                .font(Typo.eyebrow).tracking(1.5).foregroundStyle(Color.lInk3)
            HStack(spacing: 8) {
                Text("Snapshot diff").font(Typo.serifNum(32))
                Text("— what moved").font(Typo.serifItalic(28))
                    .foregroundStyle(Color.lInk3)
            }
            .foregroundStyle(Color.lInk)
        }
    }

    private var pickerRow: some View {
        HStack(alignment: .center, spacing: 12) {
            snapshotPicker(label: "FROM", binding: $aID)
            Image(systemName: "arrow.right")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.lInk3)
            snapshotPicker(label: "TO", binding: $bID)
            Spacer()
            HStack(spacing: 6) {
                Toggle("", isOn: $showZeros).toggleStyle(.switch).labelsHidden()
                Text("Show unchanged")
                    .font(Typo.sans(12)).foregroundStyle(Color.lInk2)
            }
            SegControl<SortMode>(
                options: SortMode.allCases.map { (label: $0.rawValue, value: $0) },
                selection: $sortMode
            )
            GhostButton(action: swap) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.left.arrow.right").font(.system(size: 10, weight: .bold))
                    Text("Swap")
                }
            }
        }
    }

    private func snapshotPicker(label: String, binding: Binding<UUID?>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(Typo.eyebrow).tracking(1.3).foregroundStyle(Color.lInk3)
            Menu {
                ForEach(snapshots) { s in
                    Button(s.label) { binding.wrappedValue = s.id }
                }
            } label: {
                HStack(spacing: 6) {
                    Text(snapshots.first(where: { $0.id == binding.wrappedValue })?.label ?? "—")
                        .font(Typo.mono(12, weight: .semibold))
                        .foregroundStyle(Color.lInk)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(Color.lInk3)
                }
                .padding(.horizontal, 10).padding(.vertical, 6)
                .overlay(Capsule().stroke(Color.lLine, lineWidth: 1))
            }
            .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
        }
    }

    private func swap() {
        let t = aID; aID = bID; bID = t
    }

    // MARK: kpi

    private var kpiRow: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 12) {
            KPICard(label: "From total",
                    value: Fmt.compact(cachedTotalA, app.displayCurrency),
                    sub: snapA?.label)
            KPICard(label: "To total",
                    value: Fmt.compact(cachedTotalB, app.displayCurrency),
                    sub: snapB?.label)
            KPICard(label: "Net change",
                    value: signed(cachedTotalB - cachedTotalA),
                    sub: pctText(cachedTotalA, cachedTotalB),
                    valueColor: (cachedTotalB - cachedTotalA) >= 0 ? .lGain : .lLoss)
            KPICard(label: "Changes",
                    value: "\(cachedRows.filter { $0.diff != 0 }.count)",
                    sub: "\(cachedAddedCount) added · \(cachedDroppedCount) dropped")
        }
    }

    private func signed(_ v: Double) -> String {
        let sym = v >= 0 ? "+" : "−"
        return "\(sym)\(Fmt.compact(abs(v), app.displayCurrency))"
    }

    private func pctText(_ a: Double, _ b: Double) -> String {
        guard a != 0 else { return "—" }
        let p = (b - a) / abs(a) * 100
        return "\(p >= 0 ? "+" : "−")\(String(format: "%.2f", abs(p)))% total"
    }

    // MARK: sankey

    private var sankeyFlows: [SankeyFlow] {
        cachedRows.compactMap { r in
            let status: SankeyFlow.Status
            switch r.status {
            case .same:    status = .same
            case .added:   status = .added
            case .dropped: status = .dropped
            }
            // Skip rows where both sides are zero — nothing to draw.
            if r.valA == 0 && r.valB == 0 { return nil }
            return SankeyFlow(id: r.id, name: r.name,
                              valA: max(r.valA, 0), valB: max(r.valB, 0),
                              status: status)
        }
    }

    private var sankeySection: some View {
        VStack(alignment: .leading, spacing: 0) {
            PanelHead(title: "Money flow",
                      meta: "\(sankeyFlows.count) accounts")
            if sankeyFlows.isEmpty {
                Text("Nothing to flow.")
                    .font(Typo.serifItalic(13))
                    .foregroundStyle(Color.lInk3)
                    .padding(18)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                SnapshotSankeyView(
                    flows: sankeyFlows,
                    labelA: snapA?.label ?? "From",
                    labelB: snapB?.label ?? "To"
                )
                .frame(height: max(280, CGFloat(sankeyFlows.count) * 24))
                .padding(.horizontal, 18).padding(.vertical, 14)
            }
        }
    }

    // MARK: table

    private var sortedRows: [Row] {
        sizer.sorted(cachedRows, comparators: [
            "account": { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending },
            "owner":   { $0.person.localizedCaseInsensitiveCompare($1.person) == .orderedAscending },
            "country": { $0.country < $1.country },
            "type":    { $0.type.localizedCaseInsensitiveCompare($1.type) == .orderedAscending },
            "from":    { $0.valA < $1.valA },
            "to":      { $0.valB < $1.valB },
            "dAbs":    { $0.diff < $1.diff },
            "dPct":    { $0.pct < $1.pct },
        ])
    }

    private var tableSection: some View {
        VStack(spacing: 0) {
            PanelHead(title: "Account-level diff",
                      meta: "\(cachedRows.count) rows")
            ResizableHeader(sizer: sizer)
            if cachedRows.isEmpty {
                Text("No differences in range.")
                    .font(Typo.serifItalic(13))
                    .foregroundStyle(Color.lInk3)
                    .padding(18)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ScrollView(.vertical) {
                    LazyVStack(spacing: 0) {
                        let rows = sortedRows
                        ForEach(Array(rows.enumerated()), id: \.element.id) { idx, r in
                            row(r, idx: idx)
                            if idx < rows.count - 1 {
                                Divider().overlay(Color.lLine)
                            }
                        }
                    }
                }
            }
        }
    }

    private func row(_ r: Row, idx: Int) -> some View {
        HStack(spacing: 0) {
            ResizableCell(sizer: sizer, colID: "account") {
                HStack(spacing: 6) {
                    if r.status == .added {
                        Text("NEW").font(Typo.mono(9, weight: .bold))
                            .foregroundStyle(Color.lGain)
                            .padding(.horizontal, 4).padding(.vertical, 1)
                            .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color.lGain, lineWidth: 1))
                    } else if r.status == .dropped {
                        Text("GONE").font(Typo.mono(9, weight: .bold))
                            .foregroundStyle(Color.lLoss)
                            .padding(.horizontal, 4).padding(.vertical, 1)
                            .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color.lLoss, lineWidth: 1))
                    }
                    Text(r.name)
                        .font(Typo.sans(12.5, weight: .medium))
                        .foregroundStyle(Color.lInk)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                }
            }
            ResizableCell(sizer: sizer, colID: "owner") {
                Text(r.person).font(Typo.sans(12))
                    .foregroundStyle(Color.lInk2)
                    .lineLimit(1)
            }
            ResizableCell(sizer: sizer, colID: "country") {
                HStack(spacing: 4) {
                    Text(r.countryFlag).font(.system(size: 13))
                    Text(r.country).font(Typo.mono(11)).foregroundStyle(Color.lInk2)
                    Spacer(minLength: 0)
                }
            }
            ResizableCell(sizer: sizer, colID: "type") {
                Text(r.type).font(Typo.sans(12))
                    .foregroundStyle(Color.lInk2)
                    .lineLimit(1)
            }
            ResizableCell(sizer: sizer, colID: "from") {
                Text(r.valA == 0 && r.status == .added ? "—" : Fmt.compact(r.valA, app.displayCurrency))
                    .font(Typo.mono(12))
                    .foregroundStyle(Color.lInk3)
            }
            ResizableCell(sizer: sizer, colID: "to") {
                Text(r.valB == 0 && r.status == .dropped ? "—" : Fmt.compact(r.valB, app.displayCurrency))
                    .font(Typo.mono(12, weight: .medium))
                    .foregroundStyle(Color.lInk)
            }
            ResizableCell(sizer: sizer, colID: "dAbs") {
                Text(signedDiff(r.diff))
                    .font(Typo.mono(12, weight: .semibold))
                    .foregroundStyle(r.diff == 0 ? Color.lInk3 : (r.diff > 0 ? Color.lGain : Color.lLoss))
            }
            ResizableCell(sizer: sizer, colID: "dPct") {
                Text(pctCell(r))
                    .font(Typo.mono(12, weight: .medium))
                    .foregroundStyle(r.diff == 0 ? Color.lInk3 : (r.diff > 0 ? Color.lGain : Color.lLoss))
            }
        }
        .padding(.horizontal, 18).padding(.vertical, 10)
        .background(idx.isMultiple(of: 2) ? Color.clear : Color.lSunken.opacity(0.5))
    }

    private func signedDiff(_ v: Double) -> String {
        if v == 0 { return "—" }
        let sym = v >= 0 ? "+" : "−"
        return "\(sym)\(Fmt.compact(abs(v), app.displayCurrency))"
    }

    private func pctCell(_ r: Row) -> String {
        switch r.status {
        case .added:   return "new"
        case .dropped: return "−100%"
        case .same:
            if r.valA == 0 { return r.diff == 0 ? "—" : "∞" }
            let sym = r.pct >= 0 ? "+" : "−"
            return "\(sym)\(String(format: "%.1f", abs(r.pct)))%"
        }
    }

    // MARK: compute

    private func recompute() {
        guard let a = snapA, let b = snapB else {
            cachedRows = []; cachedTotalA = 0; cachedTotalB = 0
            cachedAddedCount = 0; cachedDroppedCount = 0
            return
        }
        let target = app.displayCurrency
        let inc = app.includeIlliquidInNetWorth

        func value(_ v: AssetValue) -> Double {
            CurrencyConverter.netDisplayValue(for: v, in: target, includeIlliquid: inc)
        }

        struct Bucket { var sum: Double = 0; var acc: Account? }
        var mapA: [UUID: Bucket] = [:]
        var mapB: [UUID: Bucket] = [:]
        for v in a.values {
            guard let acc = v.account else { continue }
            if !inc && (acc.assetType?.category.isIlliquid ?? false) { continue }
            mapA[acc.id, default: Bucket(acc: acc)].sum += value(v)
        }
        for v in b.values {
            guard let acc = v.account else { continue }
            if !inc && (acc.assetType?.category.isIlliquid ?? false) { continue }
            mapB[acc.id, default: Bucket(acc: acc)].sum += value(v)
        }

        let ids = Set(mapA.keys).union(mapB.keys)
        var rows: [Row] = []
        var addedCount = 0
        var droppedCount = 0
        for id in ids {
            let ba = mapA[id]
            let bb = mapB[id]
            let acc = bb?.acc ?? ba?.acc
            guard let acc else { continue }
            let vA = ba?.sum ?? 0
            let vB = bb?.sum ?? 0
            let diff = vB - vA
            let status: Row.Status
            if ba == nil { status = .added; addedCount += 1 }
            else if bb == nil { status = .dropped; droppedCount += 1 }
            else { status = .same }
            let pct = vA == 0 ? 0 : (diff / abs(vA)) * 100
            if !showZeros && status == .same && diff == 0 { continue }
            rows.append(Row(
                id: acc.id,
                name: acc.name,
                person: acc.person?.name ?? "—",
                country: acc.country?.code ?? "—",
                countryFlag: acc.country?.flag ?? "",
                type: acc.assetType?.name ?? "—",
                valA: vA, valB: vB,
                diff: diff, pct: pct,
                status: status
            ))
        }
        switch sortMode {
        case .absDelta: rows.sort { abs($0.diff) > abs($1.diff) }
        case .pctDelta: rows.sort { abs($0.pct) > abs($1.pct) }
        case .name:     rows.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .valueB:   rows.sort { $0.valB > $1.valB }
        }
        cachedRows = rows
        cachedTotalA = mapA.values.reduce(0) { $0 + $1.sum }
        cachedTotalB = mapB.values.reduce(0) { $0 + $1.sum }
        cachedAddedCount = addedCount
        cachedDroppedCount = droppedCount
    }
}

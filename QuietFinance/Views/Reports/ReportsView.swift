import SwiftUI
import SwiftData
import Charts

struct ReportsView: View {
    @EnvironmentObject var app: AppState
    @Query(sort: \Snapshot.date, order: .reverse) private var snapshots: [Snapshot]

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            PageHero(eyebrow: "OVERVIEW · ANALYSIS",
                     title: "Reports",
                     titleItalic: "— change over time")

            if snapshots.count < 2 {
                EditorialEmpty(
                    eyebrow: "Reports · Analysis",
                    title: "Need at least two",
                    titleItalic: "snapshots.",
                    body: "Quarter-over-quarter, year-over-year, CAGR, and drift charts all need a series. Lock a second snapshot to unlock reports.",
                    detail: nil,
                    ctaLabel: nil,
                    cta: nil,
                    illustration: "doc.text.magnifyingglass"
                )
            } else {
                periodComparePanel
                heatmapPanel
                cagrDriftPanel
                assetTypeDrilldownPanel
            }
        }
    }

    // MARK: - Helpers

    private var inc: Bool { app.includeIlliquidInNetWorth }
    private var ccy: Currency { app.displayCurrency }

    private func total(_ s: Snapshot) -> Double {
        s.totalsValues.reduce(0) { $0 + CurrencyConverter.netDisplayValue(for: $1, in: ccy, includeIlliquid: inc) }
    }

    private func categoryBuckets(_ s: Snapshot) -> [String: Double] {
        var out: [String: Double] = [:]
        for v in s.totalsValues {
            guard let cat = v.account?.assetType?.category else { continue }
            if !inc && cat.isIlliquid { continue }
            let dv = CurrencyConverter.netDisplayValue(for: v, in: ccy, includeIlliquid: inc)
            out[cat.rawValue, default: 0] += dv
        }
        return out
    }

    private func categoriesUnion(_ a: [String: Double], _ b: [String: Double]) -> [String] {
        let set = Set(a.keys).union(b.keys)
        return AssetCategory.allCases.compactMap { set.contains($0.rawValue) ? $0.rawValue : nil }
    }

    // MARK: - Period compare (QoQ + YoY)

    @State private var compareMode: CompareMode = .qoq
    enum CompareMode: String, CaseIterable, Identifiable {
        case qoq = "QoQ", yoy = "YoY", custom = "Custom"
        var id: String { rawValue }
    }

    private var sortedAsc: [Snapshot] { snapshots.sorted { $0.date < $1.date } }

    /// Picks two snapshots based on mode. Returns (older, newer).
    private var comparePair: (Snapshot, Snapshot)? {
        let asc = sortedAsc
        guard let last = asc.last else { return nil }
        switch compareMode {
        case .qoq:
            guard asc.count >= 2 else { return nil }
            return (asc[asc.count - 2], last)
        case .yoy:
            // Find snapshot closest to (last.date - 1 year)
            let target = Calendar.current.date(byAdding: .year, value: -1, to: last.date) ?? last.date
            let prior = asc.dropLast().min(by: { abs($0.date.timeIntervalSince(target)) < abs($1.date.timeIntervalSince(target)) })
            guard let prior else { return nil }
            return (prior, last)
        case .custom:
            guard let aID = customA, let bID = customB,
                  let a = snapshots.first(where: { $0.id == aID }),
                  let b = snapshots.first(where: { $0.id == bID }) else { return nil }
            return a.date < b.date ? (a, b) : (b, a)
        }
    }

    @State private var customA: UUID?
    @State private var customB: UUID?

    private var periodComparePanel: some View {
        Panel {
            VStack(spacing: 0) {
                PanelHead(title: "Period comparison", meta: comparePair.map { "\($0.0.label) → \($0.1.label)" } ?? "—")
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 8) {
                        SegControl<CompareMode>(
                            options: CompareMode.allCases.map { ($0.rawValue, $0) },
                            selection: $compareMode
                        )
                        Spacer()
                        if compareMode == .custom {
                            customPickers
                        }
                    }
                    if let pair = comparePair {
                        compareSummary(pair.0, pair.1)
                        Divider().overlay(Color.lLine)
                        compareCategoryTable(pair.0, pair.1)
                    } else {
                        Text("Not enough history for this comparison.")
                            .font(Typo.serifItalic(12))
                            .foregroundStyle(Color.lInk3)
                    }
                }
                .padding(18)
            }
        }
    }

    private var customPickers: some View {
        HStack(spacing: 6) {
            Menu {
                ForEach(snapshots) { s in
                    Button(s.label) { customA = s.id }
                }
            } label: {
                Text(customA.flatMap { id in snapshots.first { $0.id == id }?.label } ?? "Pick A")
                    .font(Typo.mono(11))
            }
            .menuStyle(.borderlessButton).fixedSize()
            Text("vs").font(Typo.mono(10)).foregroundStyle(Color.lInk3)
            Menu {
                ForEach(snapshots) { s in
                    Button(s.label) { customB = s.id }
                }
            } label: {
                Text(customB.flatMap { id in snapshots.first { $0.id == id }?.label } ?? "Pick B")
                    .font(Typo.mono(11))
            }
            .menuStyle(.borderlessButton).fixedSize()
        }
    }

    private func compareSummary(_ a: Snapshot, _ b: Snapshot) -> some View {
        let ta = total(a)
        let tb = total(b)
        let delta = tb - ta
        let pct = ta == 0 ? 0 : delta / abs(ta)
        let days = max(1, Calendar.current.dateComponents([.day], from: a.date, to: b.date).day ?? 1)
        return HStack(alignment: .top, spacing: 24) {
            stat("FROM", a.label, Fmt.compact(ta, ccy))
            stat("TO",   b.label, Fmt.compact(tb, ccy))
            stat("Δ NET", Fmt.signedDelta(delta, ccy), Fmt.percent(pct, fractionDigits: 2),
                 tint: delta >= 0 ? .lGain : .lLoss)
            stat("SPAN", "\(days) days", "")
        }
    }

    private func stat(_ eyebrow: String, _ primary: String, _ secondary: String, tint: Color = .lInk) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(eyebrow)
                .font(Typo.eyebrow).tracking(1.2)
                .foregroundStyle(Color.lInk3)
            Text(primary)
                .font(Typo.serifNum(18))
                .foregroundStyle(tint)
                .monospacedDigit()
            if !secondary.isEmpty {
                Text(secondary)
                    .font(Typo.mono(11))
                    .foregroundStyle(Color.lInk3)
            }
        }
    }

    private func compareCategoryTable(_ a: Snapshot, _ b: Snapshot) -> some View {
        let ba = categoryBuckets(a)
        let bb = categoryBuckets(b)
        let cats = categoriesUnion(ba, bb)
        let ta = max(0.0001, ba.values.reduce(0, +))
        let tb = max(0.0001, bb.values.reduce(0, +))
        return VStack(spacing: 0) {
            HStack {
                Text("CATEGORY").frame(width: 130, alignment: .leading)
                Text("WAS").frame(maxWidth: .infinity, alignment: .trailing)
                Text("NOW").frame(maxWidth: .infinity, alignment: .trailing)
                Text("Δ").frame(maxWidth: .infinity, alignment: .trailing)
                Text("Δ%").frame(width: 80, alignment: .trailing)
                Text("ALLOC SHIFT").frame(width: 110, alignment: .trailing)
            }
            .font(Typo.eyebrow).tracking(1.2).foregroundStyle(Color.lInk3)
            .padding(.bottom, 6)
            ForEach(cats, id: \.self) { cat in
                let av = ba[cat] ?? 0
                let bv = bb[cat] ?? 0
                let d = bv - av
                let pct = av == 0 ? (bv == 0 ? 0 : 1) : d / abs(av)
                let allocA = av / ta
                let allocB = bv / tb
                HStack {
                    HStack(spacing: 6) {
                        Circle().fill(Palette.color(for: AssetCategory(rawValue: cat) ?? .cash))
                            .frame(width: 7, height: 7)
                        Text(cat).font(Typo.sans(12, weight: .medium))
                    }
                    .frame(width: 130, alignment: .leading)
                    Text(Fmt.compact(av, ccy)).font(Typo.mono(12)).foregroundStyle(Color.lInk2)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    Text(Fmt.compact(bv, ccy)).font(Typo.mono(12, weight: .semibold)).foregroundStyle(Color.lInk)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    Text(Fmt.signedDelta(d, ccy)).font(Typo.mono(12))
                        .foregroundStyle(d >= 0 ? Color.lGain : Color.lLoss)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    Text(Fmt.percent(pct, fractionDigits: 1)).font(Typo.mono(11))
                        .foregroundStyle(Color.lInk3)
                        .frame(width: 80, alignment: .trailing)
                    Text("\(Fmt.percent(allocA, fractionDigits: 0)) → \(Fmt.percent(allocB, fractionDigits: 0))")
                        .font(Typo.mono(10))
                        .foregroundStyle(Color.lInk3)
                        .frame(width: 110, alignment: .trailing)
                }
                .padding(.vertical, 5)
                Divider().overlay(Color.lLine.opacity(0.5))
            }
        }
    }

    // MARK: - CAGR + monthly drift

    private struct DriftRow: Identifiable {
        let id = UUID()
        let category: String
        let firstValue: Double
        let lastValue: Double
        let cagr: Double
        let monthlyDrift: Double
    }

    private var driftRows: [DriftRow] {
        let asc = sortedAsc
        guard let first = asc.first, let last = asc.last, first.id != last.id else { return [] }
        let bf = categoryBuckets(first)
        let bl = categoryBuckets(last)
        let cats = categoriesUnion(bf, bl)
        let years = max(1.0/12.0, last.date.timeIntervalSince(first.date) / (365.25 * 86400))
        let months = max(1, Int((last.date.timeIntervalSince(first.date) / (30.44 * 86400)).rounded()))
        return cats.map { cat in
            let f = bf[cat] ?? 0
            let l = bl[cat] ?? 0
            let cagr: Double = {
                guard f > 0, l > 0 else { return 0 }
                return pow(l / f, 1.0 / years) - 1.0
            }()
            let drift: Double = {
                guard f != 0 else { return 0 }
                return (l - f) / abs(f) / Double(months)
            }()
            return DriftRow(category: cat, firstValue: f, lastValue: l, cagr: cagr, monthlyDrift: drift)
        }
    }

    private var cagrDriftPanel: some View {
        let rows = driftRows
        let asc = sortedAsc
        let span: String = {
            guard let f = asc.first?.label, let l = asc.last?.label else { return "—" }
            return "\(f) → \(l)"
        }()
        return Panel {
            VStack(spacing: 0) {
                PanelHead(title: "CAGR & monthly drift by category", meta: span)
                VStack(spacing: 0) {
                    HStack {
                        Text("CATEGORY").frame(width: 140, alignment: .leading)
                        Text("FIRST").frame(maxWidth: .infinity, alignment: .trailing)
                        Text("LAST").frame(maxWidth: .infinity, alignment: .trailing)
                        Text("CAGR").frame(width: 90, alignment: .trailing)
                        Text("MONTHLY Δ").frame(width: 110, alignment: .trailing)
                    }
                    .font(Typo.eyebrow).tracking(1.2).foregroundStyle(Color.lInk3)
                    .padding(.bottom, 6)
                    ForEach(rows) { r in
                        HStack {
                            HStack(spacing: 6) {
                                Circle().fill(Palette.color(for: AssetCategory(rawValue: r.category) ?? .cash))
                                    .frame(width: 7, height: 7)
                                Text(r.category).font(Typo.sans(12, weight: .medium))
                            }
                            .frame(width: 140, alignment: .leading)
                            Text(Fmt.compact(r.firstValue, ccy)).font(Typo.mono(12)).foregroundStyle(Color.lInk2)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                            Text(Fmt.compact(r.lastValue, ccy)).font(Typo.mono(12, weight: .semibold)).foregroundStyle(Color.lInk)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                            Text(Fmt.percent(r.cagr, fractionDigits: 2)).font(Typo.mono(12, weight: .semibold))
                                .foregroundStyle(r.cagr >= 0 ? Color.lGain : Color.lLoss)
                                .frame(width: 90, alignment: .trailing)
                            Text(Fmt.percent(r.monthlyDrift, fractionDigits: 2)).font(Typo.mono(12))
                                .foregroundStyle(r.monthlyDrift >= 0 ? Color.lGain : Color.lLoss)
                                .frame(width: 110, alignment: .trailing)
                        }
                        .padding(.vertical, 5)
                        Divider().overlay(Color.lLine.opacity(0.5))
                    }
                    if rows.isEmpty {
                        Text("Not enough history.")
                            .font(Typo.serifItalic(12))
                            .foregroundStyle(Color.lInk3)
                            .padding(.vertical, 12)
                    }
                }
                .padding(18)
            }
        }
    }

    // MARK: - Asset type drilldown

    @State private var drilldownTypeID: UUID?

    private var allTypesSorted: [AssetType] {
        let set = snapshots.flatMap { $0.values.compactMap { $0.account?.assetType } }
        let unique = Array(Set(set.map { $0.id })).compactMap { id in set.first { $0.id == id } }
        return unique.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private var selectedType: AssetType? {
        if let id = drilldownTypeID, let t = allTypesSorted.first(where: { $0.id == id }) { return t }
        return allTypesSorted.first
    }

    private struct TypePoint: Identifiable {
        let id = UUID()
        let date: Date
        let label: String
        let typeValue: Double
        let totalValue: Double
        var alloc: Double { totalValue == 0 ? 0 : typeValue / totalValue }
    }

    private func typeSeries(for t: AssetType) -> [TypePoint] {
        sortedAsc.map { s in
            let typeVal = s.totalsValues.reduce(0.0) { acc, v in
                guard v.account?.assetType?.id == t.id else { return acc }
                if !inc && (v.account?.assetType?.category.isIlliquid ?? false) { return acc }
                return acc + CurrencyConverter.netDisplayValue(for: v, in: ccy, includeIlliquid: inc)
            }
            let total = total(s)
            return TypePoint(date: s.date, label: s.label, typeValue: typeVal, totalValue: total)
        }
    }

    private var assetTypeDrilldownPanel: some View {
        let t = selectedType
        let series = t.map { typeSeries(for: $0) } ?? []
        return Panel {
            VStack(spacing: 0) {
                PanelHead(title: "Asset-type drilldown", meta: t?.name ?? "—")
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text("Type").font(Typo.sans(12, weight: .medium))
                        Spacer()
                        Menu {
                            ForEach(allTypesSorted) { type in
                                Button(type.name) { drilldownTypeID = type.id }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Text(t?.name ?? "Pick").font(Typo.mono(12, weight: .semibold))
                                Image(systemName: "chevron.down").font(.system(size: 8, weight: .bold))
                            }
                        }
                        .menuStyle(.borderlessButton).fixedSize()
                    }
                    if series.count >= 2 {
                        drilldownStats(series)
                        drilldownChart(series, color: t.map { Palette.color(for: $0.category) } ?? Color.lInk)
                        drilldownAllocation(series)
                    } else {
                        Text("Pick a type with at least two snapshot data points.")
                            .font(Typo.serifItalic(12))
                            .foregroundStyle(Color.lInk3)
                    }
                }
                .padding(18)
            }
        }
    }

    private func drilldownStats(_ series: [TypePoint]) -> some View {
        let first = series.first!
        let last = series.last!
        let delta = last.typeValue - first.typeValue
        let pct = first.typeValue == 0 ? 0 : delta / abs(first.typeValue)
        let allocShift = last.alloc - first.alloc
        return HStack(spacing: 24) {
            stat("FIRST", first.label, Fmt.compact(first.typeValue, ccy))
            stat("LAST",  last.label,  Fmt.compact(last.typeValue, ccy))
            stat("Δ",     Fmt.signedDelta(delta, ccy), Fmt.percent(pct, fractionDigits: 1),
                 tint: delta >= 0 ? .lGain : .lLoss)
            stat("ALLOC", Fmt.percent(last.alloc, fractionDigits: 1),
                 "\(Fmt.percent(allocShift, fractionDigits: 1)) shift",
                 tint: allocShift >= 0 ? .lGain : .lLoss)
        }
    }

    private func drilldownChart(_ series: [TypePoint], color: Color = .lInk) -> some View {
        Chart {
            ForEach(series) { p in
                AreaMark(x: .value("Date", p.date), y: .value("Value", p.typeValue))
                    .foregroundStyle(.linearGradient(colors: [color.opacity(0.25), color.opacity(0.02)],
                                                     startPoint: .top, endPoint: .bottom))
                    .interpolationMethod(.monotone)
                LineMark(x: .value("Date", p.date), y: .value("Value", p.typeValue))
                    .foregroundStyle(color)
                    .lineStyle(StrokeStyle(lineWidth: 1.4, lineCap: .round, lineJoin: .round))
                    .interpolationMethod(.monotone)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { _ in
                AxisGridLine().foregroundStyle(Color.lLine.opacity(0.4))
                AxisValueLabel().font(Typo.mono(10)).foregroundStyle(Color.lInk3)
            }
        }
        .chartXAxis {
            AxisMarks { _ in
                AxisGridLine().foregroundStyle(Color.lLine.opacity(0.3))
                AxisValueLabel(format: .dateTime.month(.abbreviated).year(.twoDigits))
                    .font(Typo.mono(10)).foregroundStyle(Color.lInk3)
            }
        }
        .frame(height: 160)
    }

    private func drilldownAllocation(_ series: [TypePoint]) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text("ALLOCATION HISTORY")
                    .font(Typo.eyebrow).tracking(1.2)
                    .foregroundStyle(Color.lInk3)
                Spacer()
            }
            .padding(.bottom, 6)
            ForEach(series) { p in
                HStack {
                    Text(p.label).font(Typo.sans(11))
                        .foregroundStyle(Color.lInk2)
                        .frame(width: 110, alignment: .leading)
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Rectangle().fill(Color.lLine.opacity(0.3))
                            Rectangle().fill(Color.lInk).frame(width: max(0, geo.size.width * p.alloc))
                        }
                    }
                    .frame(height: 6)
                    .clipShape(RoundedRectangle(cornerRadius: 2))
                    Text(Fmt.percent(p.alloc, fractionDigits: 1))
                        .font(Typo.mono(11, weight: .semibold))
                        .foregroundStyle(Color.lInk)
                        .frame(width: 60, alignment: .trailing)
                    Text(Fmt.compact(p.typeValue, ccy))
                        .font(Typo.mono(11))
                        .foregroundStyle(Color.lInk3)
                        .frame(width: 90, alignment: .trailing)
                }
                .padding(.vertical, 4)
            }
        }
    }

    // MARK: - Heatmap (quarters × categories, QoQ Δ%)

    private struct HeatCell {
        let quarterKey: String      // e.g. "2025-Q1"
        let quarterLabel: String    // display label
        let category: String
        let pct: Double             // delta vs prior quarter, in display ccy.
        let abs: Double             // absolute delta
        let value: Double           // current bucket value
    }

    /// Groups snapshots into calendar quarters, picks the latest snapshot in each
    /// quarter as that quarter's representative datapoint. Returns chronological list.
    private var quarterSnapshots: [(key: String, label: String, snapshot: Snapshot)] {
        let cal = Calendar.current
        var byKey: [String: Snapshot] = [:]
        for s in sortedAsc {
            let comps = cal.dateComponents([.year, .month], from: s.date)
            guard let y = comps.year, let m = comps.month else { continue }
            let q = (m - 1) / 3 + 1
            let key = String(format: "%04d-Q%d", y, q)
            // Latest snapshot in quarter wins.
            if let existing = byKey[key] {
                if s.date > existing.date { byKey[key] = s }
            } else {
                byKey[key] = s
            }
        }
        return byKey.keys.sorted().map { key in
            (key: key, label: key.replacingOccurrences(of: "-", with: " "), snapshot: byKey[key]!)
        }
    }

    private var heatmapCells: [HeatCell] {
        let qs = quarterSnapshots
        guard qs.count >= 2 else { return [] }
        let cats = unionCategoriesAcrossSeries(qs.map { $0.snapshot })
        var out: [HeatCell] = []
        for i in 1..<qs.count {
            let prev = qs[i - 1].snapshot
            let cur = qs[i]
            let bp = categoryBuckets(prev)
            let bc = categoryBuckets(cur.snapshot)
            for c in cats {
                let p = bp[c] ?? 0
                let v = bc[c] ?? 0
                let d = v - p
                let pct: Double = p == 0 ? (v == 0 ? 0 : 1) : d / abs_(p)
                out.append(HeatCell(quarterKey: cur.key, quarterLabel: cur.label,
                                    category: c, pct: pct, abs: d, value: v))
            }
        }
        return out
    }

    // small helper to avoid name clash with Swift.abs in scope
    private func abs_(_ v: Double) -> Double { Swift.abs(v) }

    private func unionCategoriesAcrossSeries(_ snaps: [Snapshot]) -> [String] {
        var set = Set<String>()
        for s in snaps {
            for v in s.values {
                guard let cat = v.account?.assetType?.category else { continue }
                if !inc && cat.isIlliquid { continue }
                set.insert(cat.rawValue)
            }
        }
        return AssetCategory.allCases.compactMap { set.contains($0.rawValue) ? $0.rawValue : nil }
    }

    @ViewBuilder
    private var heatmapPanel: some View {
        let cells = heatmapCells
        let qs = quarterSnapshots
        let cats = unionCategoriesAcrossSeries(qs.map { $0.snapshot })
        let rows = Array(qs.dropFirst())  // skip first quarter (no prior to delta against)
        Panel {
            VStack(spacing: 0) {
                PanelHead(title: "QoQ heatmap", meta: "\(rows.count) quarters × \(cats.count) categories")
                if cells.isEmpty {
                    Text("Need at least two snapshots in different calendar quarters.")
                        .font(Typo.serifItalic(12))
                        .foregroundStyle(Color.lInk3)
                        .padding(18)
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        heatmapHeader(cats: cats)
                        ForEach(rows, id: \.key) { row in
                            heatmapRow(quarterKey: row.key, quarterLabel: row.label,
                                       cats: cats, cells: cells)
                        }
                        heatmapLegend
                    }
                    .padding(18)
                }
            }
        }
    }

    private func heatmapHeader(cats: [String]) -> some View {
        HStack(spacing: 4) {
            Text("PERIOD")
                .font(Typo.eyebrow).tracking(1.2)
                .foregroundStyle(Color.lInk3)
                .frame(width: 110, alignment: .leading)
            ForEach(cats, id: \.self) { c in
                HStack(spacing: 4) {
                    Circle().fill(Palette.color(for: AssetCategory(rawValue: c) ?? .cash))
                        .frame(width: 6, height: 6)
                    Text(c).font(Typo.eyebrow).tracking(1.0)
                        .foregroundStyle(Color.lInk3)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            Text("Δ TOTAL")
                .font(Typo.eyebrow).tracking(1.2)
                .foregroundStyle(Color.lInk3)
                .frame(width: 90, alignment: .trailing)
        }
    }

    private func heatmapRow(quarterKey: String, quarterLabel: String,
                            cats: [String], cells: [HeatCell]) -> some View {
        let rowCells = cells.filter { $0.quarterKey == quarterKey }
        let rowAbs = rowCells.reduce(0) { $0 + $1.abs }
        return HStack(spacing: 4) {
            Text(quarterLabel)
                .font(Typo.mono(11, weight: .semibold))
                .foregroundStyle(Color.lInk)
                .frame(width: 110, alignment: .leading)
                .lineLimit(1)
            ForEach(cats, id: \.self) { c in
                if let cell = rowCells.first(where: { $0.category == c }) {
                    heatmapCell(cell)
                } else {
                    heatmapEmptyCell()
                }
            }
            Text(Fmt.signedDelta(rowAbs, ccy))
                .font(Typo.mono(11, weight: .semibold))
                .foregroundStyle(rowAbs >= 0 ? Color.lGain : Color.lLoss)
                .frame(width: 90, alignment: .trailing)
        }
    }

    private func heatmapCell(_ c: HeatCell) -> some View {
        let pct = c.pct
        let intensity = min(1.0, abs_(pct) / 0.15) // 15% = full saturation
        let bg: Color = {
            if pct == 0 { return Color.lLine.opacity(0.3) }
            return pct > 0
                ? Color.lGain.opacity(0.15 + intensity * 0.55)
                : Color.lLoss.opacity(0.15 + intensity * 0.55)
        }()
        let label = pct == 0 ? "0%" : String(format: "%@%.1f%%", pct >= 0 ? "+" : "−", abs_(pct) * 100)
        return Text(label)
            .font(Typo.mono(10, weight: .semibold))
            .foregroundStyle(abs_(pct) > 0.05 ? Color.lInk : Color.lInk2)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(bg)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .help("\(c.category) · \(Fmt.signedDelta(c.abs, ccy)) → \(Fmt.compact(c.value, ccy))")
    }

    private func heatmapEmptyCell() -> some View {
        Text("—")
            .font(Typo.mono(10))
            .foregroundStyle(Color.lInk4)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(Color.lLine.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    private var heatmapLegend: some View {
        HStack(spacing: 10) {
            HStack(spacing: 4) {
                Rectangle().fill(Color.lLoss.opacity(0.7)).frame(width: 18, height: 8)
                    .clipShape(RoundedRectangle(cornerRadius: 2))
                Text("≤ −15%").font(Typo.mono(9)).foregroundStyle(Color.lInk3)
            }
            HStack(spacing: 4) {
                Rectangle().fill(Color.lLoss.opacity(0.25)).frame(width: 18, height: 8)
                    .clipShape(RoundedRectangle(cornerRadius: 2))
                Text("0%").font(Typo.mono(9)).foregroundStyle(Color.lInk3)
                Rectangle().fill(Color.lGain.opacity(0.25)).frame(width: 18, height: 8)
                    .clipShape(RoundedRectangle(cornerRadius: 2))
            }
            HStack(spacing: 4) {
                Rectangle().fill(Color.lGain.opacity(0.7)).frame(width: 18, height: 8)
                    .clipShape(RoundedRectangle(cornerRadius: 2))
                Text("≥ +15%").font(Typo.mono(9)).foregroundStyle(Color.lInk3)
            }
            Spacer()
            Text("Cell = QoQ Δ% in \(ccy.rawValue). Hover for absolute Δ + current value.")
                .font(Typo.serifItalic(11))
                .foregroundStyle(Color.lInk3)
        }
    }
}

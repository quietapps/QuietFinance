import SwiftUI
import SwiftData
import Charts

enum TrendRange: String, CaseIterable, Identifiable {
    case all = "All"
    case y5 = "5Y"
    case y2 = "2Y"
    case y1 = "1Y"
    var id: String { rawValue }
}

enum TrendSeries: String, CaseIterable, Identifiable {
    case total    = "Total"
    case person   = "Person"
    case country  = "Country"
    case assetType = "Type"
    case category = "Category"
    var id: String { rawValue }
}

struct TrendsView: View {
    @EnvironmentObject var app: AppState
    @Query(sort: \Snapshot.date, order: .reverse) private var snapshots: [Snapshot]
    @Query(sort: \Person.name) private var people: [Person]
    @Query(sort: \Country.name) private var countries: [Country]
    @Query(sort: \AssetType.name) private var types: [AssetType]

    @State private var filters: [Filter] = []
    @State private var range: TrendRange = .all
    @State private var seriesMode: TrendSeries = .total
    @State private var hovered: SnapshotTotal?

    @StateObject private var sizer = ColumnSizer(tableID: "trends", specs: [
        ColumnSpec(id: "snap", title: "Snapshot", minWidth: 140, defaultWidth: 260, flex: true),
        ColumnSpec(id: "date", title: "Date",     minWidth: 110, defaultWidth: 150),
        ColumnSpec(id: "val",  title: "Value",    minWidth: 100, defaultWidth: 140, alignment: .trailing),
        ColumnSpec(id: "dAbs", title: "Δ abs",    minWidth: 100, defaultWidth: 140, alignment: .trailing),
        ColumnSpec(id: "dPct", title: "Δ %",      minWidth: 70,  defaultWidth: 90,  alignment: .trailing),
    ])

    // caches
    @State private var cachedSnapshotTotals: [SnapshotTotal] = []
    @State private var cachedSeries: [SeriesLine] = []
    @State private var cachedStartTotal: Double = 0
    @State private var cachedCurrentTotal: Double = 0
    @State private var cachedDeltaAbs: Double = 0
    @State private var cachedDeltaPct: Double = 0
    @State private var cachedQoQAbs: Double = 0
    @State private var cachedQoQPct: Double = 0
    @State private var cachedCAGR: Double = 0

    struct SnapshotTotal: Identifiable, Equatable {
        let id = UUID()
        let snapshotID: UUID
        let date: Date
        let label: String
        let total: Double
    }

    struct SeriesPoint: Identifiable {
        let id = UUID()
        let date: Date
        let label: String
        let value: Double
    }

    struct SeriesLine: Identifiable {
        let id = UUID()
        let label: String
        let color: Color
        let points: [SeriesPoint]
    }

    var body: some View {
        Group {
            if snapshots.isEmpty {
                EditorialEmpty(
                    eyebrow: "Overview · Trends",
                    title: "No trajectory",
                    titleItalic: "without history.",
                    body: "Trends are drawn from two or more snapshots. Capture your first quarter to seed the series — the line appears on the second.",
                    detail: "Filter later by person, country, or asset type once you have data.",
                    ctaLabel: "Create first snapshot",
                    cta: {
                        app.newSnapshotRequested = true
                        app.selectedScreen = .snapshots
                    },
                    illustration: "waveform.path.ecg"
                )
            } else {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    kpiRow
                    Panel { chartSection }
                    forecastPanel
                    Panel { tableSection }
                }
            }
        }
        .onAppear { recompute() }
        .onChange(of: app.displayCurrency) { _, _ in recompute() }
        .onChange(of: app.includeIlliquidInNetWorth) { _, _ in recompute() }
        .onChange(of: range) { _, _ in recompute() }
        .onChange(of: seriesMode) { _, _ in recompute() }
        .onChange(of: filters) { _, _ in recompute() }
        .onChange(of: snapshots.count) { _, _ in recompute() }
    }

    // MARK: header

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("OVERVIEW · TRAJECTORY")
                        .font(Typo.eyebrow).tracking(1.5).foregroundStyle(Color.lInk3)
                    HStack(spacing: 8) {
                        Text("Trends").font(Typo.serifNum(32))
                        Text("— net worth over time")
                            .font(Typo.serifItalic(28))
                            .foregroundStyle(Color.lInk3)
                    }
                    .foregroundStyle(Color.lInk)
                }
                Spacer()
                SegControl<TrendRange>(
                    options: TrendRange.allCases.map { (label: $0.rawValue, value: $0) },
                    selection: $range
                )
            }

            HStack(spacing: 10) {
                Text("SERIES")
                    .font(Typo.eyebrow).tracking(1.2)
                    .foregroundStyle(Color.lInk3)
                SegControl<TrendSeries>(
                    options: TrendSeries.allCases.map { (label: $0.rawValue, value: $0) },
                    selection: $seriesMode
                )
                Spacer()
                filterMenu
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

    private var filterMenu: some View {
        Menu {
            Menu("Person") {
                ForEach(people, id: \.id) { p in
                    Button(p.name) { addFilter(.person, label: p.name, match: p.name) }
                }
            }
            Menu("Country") {
                ForEach(countries, id: \.id) { c in
                    Button("\(c.flag) \(c.name)") { addFilter(.country, label: c.name, match: c.name) }
                }
            }
            Menu("Asset Type") {
                ForEach(types, id: \.id) { t in
                    Button(t.name) { addFilter(.assetType, label: t.name, match: t.name) }
                }
            }
            Menu("Category") {
                ForEach(AssetCategory.allCases, id: \.self) { cat in
                    Button(cat.rawValue) { addFilter(.category, label: cat.rawValue, match: cat.rawValue) }
                }
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "plus").font(.system(size: 10, weight: .bold))
                Text("Add filter").font(Typo.sans(12, weight: .medium))
            }
            .foregroundStyle(Color.lInk)
            .padding(.horizontal, 10).padding(.vertical, 5)
            .overlay(Capsule().stroke(Color.lLine, lineWidth: 1))
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
    }

    private func addFilter(_ key: GroupKey, label: String, match: String) {
        if filters.contains(where: { $0.key == key && $0.matchValue == match }) { return }
        filters.append(Filter(key: key, label: label, matchValue: match))
    }

    // MARK: KPI row

    private var kpiRow: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 14), count: 4),
            spacing: 14
        ) {
            KPICard(
                label: "Current",
                value: Fmt.compact(cachedCurrentTotal, app.displayCurrency),
                sub: cachedSnapshotTotals.last?.label ?? "—"
            )
            KPICard(
                label: "Range change",
                value: Fmt.signedDelta(cachedDeltaAbs, app.displayCurrency),
                sub: "\(rangeLabel) · \(cachedSnapshotTotals.count) snapshots",
                valueColor: Palette.deltaColor(cachedDeltaAbs),
                deltaText: cachedDeltaPct == 0 ? nil : "\(cachedDeltaPct >= 0 ? "+" : "−")\(String(format: "%.1f", abs(cachedDeltaPct)))%",
                deltaUp: cachedDeltaPct >= 0
            )
            KPICard(
                label: "Latest QoQ",
                value: Fmt.signedDelta(cachedQoQAbs, app.displayCurrency),
                sub: "Vs previous snapshot",
                valueColor: Palette.deltaColor(cachedQoQAbs),
                deltaText: cachedQoQPct == 0 ? nil : "\(cachedQoQPct >= 0 ? "+" : "−")\(String(format: "%.1f", abs(cachedQoQPct)))%",
                deltaUp: cachedQoQPct >= 0
            )
            KPICard(
                label: "CAGR",
                value: cachedCAGR == 0 ? "—" : "\(cachedCAGR >= 0 ? "+" : "−")\(String(format: "%.2f", abs(cachedCAGR)))%",
                sub: "Annualized over range",
                valueColor: Palette.deltaColor(cachedCAGR)
            )
        }
    }

    private var rangeLabel: String {
        switch range {
        case .all: return "All time"
        case .y5:  return "Last 5 years"
        case .y2:  return "Last 2 years"
        case .y1:  return "Last year"
        }
    }

    // MARK: chart

    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            PanelHead(title: seriesMode == .total ? "Net worth" : "By \(seriesMode.rawValue.lowercased())",
                      meta: Fmt.compact(cachedCurrentTotal, app.displayCurrency))
            VStack(alignment: .leading, spacing: 10) {
                chartBody
                    .frame(height: 380)
                    .padding(.top, 4)
                if seriesMode != .total {
                    legend
                } else {
                    Text("Hover a snapshot for detail · filter to drill in")
                        .font(Typo.serifItalic(13))
                        .foregroundStyle(Color.lInk3)
                }
            }
            .padding(18)
        }
    }

    @ViewBuilder
    private var chartBody: some View {
        if cachedSnapshotTotals.isEmpty {
            emptyChart
        } else if seriesMode == .total {
            totalChart
        } else {
            multiSeriesChart
        }
    }

    private var emptyChart: some View {
        VStack(spacing: 6) {
            Text("No data in range.")
                .font(Typo.sans(14, weight: .semibold))
            Text("Adjust range or clear filters.")
                .font(Typo.serifItalic(12))
                .foregroundStyle(Color.lInk3)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var totalChart: some View {
        Chart {
            ForEach(cachedSnapshotTotals) { p in
                AreaMark(
                    x: .value("Date", p.date),
                    y: .value("Val", p.total)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(.linearGradient(
                    colors: [Color.lInk.opacity(0.18), Color.lInk.opacity(0.02)],
                    startPoint: .top, endPoint: .bottom
                ))
                LineMark(
                    x: .value("Date", p.date),
                    y: .value("Val", p.total)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(Color.lInk)
                .lineStyle(StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
                PointMark(
                    x: .value("Date", p.date),
                    y: .value("Val", p.total)
                )
                .foregroundStyle(Color.lInk)
                .symbolSize(28)
            }
            if let goal = goalDisplay() {
                RuleMark(y: .value("Goal", goal))
                    .foregroundStyle(Color.lGain.opacity(0.7))
                    .lineStyle(StrokeStyle(lineWidth: 1.4, dash: [5, 4]))
                    .annotation(position: .top, alignment: .trailing) {
                        Text("Goal · \(Fmt.compact(goal, app.displayCurrency))")
                            .font(Typo.mono(10, weight: .semibold))
                            .foregroundStyle(Color.lGain)
                            .padding(.horizontal, 4)
                    }
            }
            if let h = hovered {
                RuleMark(x: .value("Date", h.date))
                    .foregroundStyle(Color.lInk3.opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    .annotation(
                        position: .automatic,
                        alignment: .center,
                        spacing: 4,
                        overflowResolution: .init(x: .fit(to: .chart), y: .fit(to: .chart))
                    ) {
                        totalTooltip(for: h)
                    }
                PointMark(
                    x: .value("Date", h.date),
                    y: .value("Val", h.total)
                )
                .foregroundStyle(Color.lInk)
                .symbolSize(110)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { _ in
                AxisGridLine().foregroundStyle(Color.lLine)
                AxisValueLabel().font(Typo.mono(10)).foregroundStyle(Color.lInk3)
            }
        }
        .chartXAxis {
            AxisMarks { _ in
                AxisGridLine().foregroundStyle(Color.lLine.opacity(0.5))
                AxisValueLabel().font(Typo.mono(10)).foregroundStyle(Color.lInk3)
            }
        }
        .chartOverlay { proxy in
            GeometryReader { geo in
                Rectangle().fill(Color.clear).contentShape(Rectangle())
                    .onContinuousHover { phase in
                        switch phase {
                        case .active(let pt):
                            let origin = proxy.plotFrame.map { geo[$0].origin } ?? .zero
                            let x = pt.x - origin.x
                            if let d: Date = proxy.value(atX: x) {
                                hovered = nearest(to: d)
                            }
                        case .ended:
                            hovered = nil
                        }
                    }
            }
        }
    }

    private var forecastPanel: some View {
        let history = cachedSnapshotTotals.map { ($0.date, $0.total) }
        let goal = goalDisplay()
        let result = Forecast.compute(history: history,
                                      method: app.forecastMethod,
                                      horizonMonths: 24,
                                      goal: goal)
        return Panel {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Forecast")
                        .font(Typo.sans(14, weight: .semibold))
                        .foregroundStyle(Color.lInk)
                    if let cagr = result?.cagrPct {
                        Text("CAGR \(String(format: "%.1f", cagr))% / yr")
                            .font(Typo.mono(11))
                            .foregroundStyle(Color.lInk3)
                    } else if let m = result?.slopePerDay {
                        Text("Slope \(Fmt.compact(m * 30, app.displayCurrency))/mo")
                            .font(Typo.mono(11))
                            .foregroundStyle(Color.lInk3)
                    }
                    Spacer()
                    SegControl<ForecastMethod>(
                        options: ForecastMethod.allCases.map { ($0.label, $0) },
                        selection: Binding(
                            get: { app.forecastMethod },
                            set: { app.forecastMethod = $0 }
                        )
                    )
                }
                .padding(.horizontal, 18).padding(.top, 14).padding(.bottom, 10)
                Divider().overlay(Color.lLine)
                Group {
                    if let r = result {
                        forecastChart(r)
                    } else {
                        Text("Need at least 2 snapshots for projection.")
                            .font(Typo.serifItalic(12))
                            .foregroundStyle(Color.lInk3)
                            .padding(18)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func forecastChart(_ r: Forecast.Result) -> some View {
        Chart {
            // Confidence band on projection
            ForEach(r.projection) { p in
                AreaMark(x: .value("Date", p.date),
                         yStart: .value("Lower", p.lower),
                         yEnd: .value("Upper", p.upper))
                    .foregroundStyle(Color.lInk.opacity(0.10))
                    .interpolationMethod(.monotone)
            }
            // Historical actuals
            ForEach(Array(r.history.enumerated()), id: \.offset) { _, h in
                LineMark(x: .value("Date", h.date),
                         y: .value("Value", h.value))
                    .foregroundStyle(Color.lInk)
                    .lineStyle(StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))
                    .interpolationMethod(.monotone)
                PointMark(x: .value("Date", h.date),
                          y: .value("Value", h.value))
                    .foregroundStyle(Color.lInk)
                    .symbolSize(20)
            }
            // Projection line (dashed)
            ForEach(r.projection) { p in
                LineMark(x: .value("Date", p.date),
                         y: .value("Value", p.value))
                    .foregroundStyle(Color.lInk2)
                    .lineStyle(StrokeStyle(lineWidth: 1.4, lineCap: .round, dash: [4, 4]))
                    .interpolationMethod(.monotone)
            }
            // Goal rule
            if let goal = goalDisplay(), goal > 0 {
                RuleMark(y: .value("Goal", goal))
                    .foregroundStyle(Color.lGain.opacity(0.7))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    .annotation(position: .top, alignment: .trailing) {
                        Text("Goal · \(Fmt.compact(goal, app.displayCurrency))")
                            .font(Typo.mono(10))
                            .foregroundStyle(Color.lGain)
                    }
            }
            // ETA marker
            if let eta = r.etaForGoal {
                RuleMark(x: .value("ETA", eta))
                    .foregroundStyle(Color.lGain.opacity(0.6))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [2, 3]))
                    .annotation(position: .top, alignment: .leading) {
                        let f = DateFormatter(); f.dateFormat = "MMM yyyy"
                        return Text("ETA \(f.string(from: eta))")
                            .font(Typo.mono(10, weight: .semibold))
                            .foregroundStyle(Color.lGain)
                    }
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
        .frame(height: 260)
        .padding(18)
    }

    private func goalDisplay() -> Double? {
        guard app.netWorthGoal > 0 else { return nil }
        let rate = snapshots.first?.usdToInrRate ?? 1
        return CurrencyConverter.convert(
            nativeValue: app.netWorthGoal,
            from: app.netWorthGoalCurrency,
            to: app.displayCurrency,
            usdToInrRate: rate
        )
    }

    private func totalTooltip(for h: SnapshotTotal) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(h.label)
                .font(Typo.mono(10, weight: .semibold))
                .foregroundStyle(Color.lInk3)
            Text(Fmt.currency(h.total, app.displayCurrency))
                .font(Typo.mono(12, weight: .bold))
                .foregroundStyle(Color.lInk)
        }
        .padding(.horizontal, 9).padding(.vertical, 6)
        .background(Color.lPanel)
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.lLine, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .shadow(color: Color.black.opacity(0.25), radius: 6, y: 2)
    }

    private var multiSeriesChart: some View {
        let domain: [String] = cachedSeries.map(\.label)
        let range: [Color] = cachedSeries.map(\.color)
        return Chart {
            ForEach(cachedSeries) { line in
                ForEach(line.points) { p in
                    LineMark(
                        x: .value("Date", p.date),
                        y: .value("Val", p.value)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(by: .value("Series", line.label))
                    .lineStyle(StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))
                    PointMark(
                        x: .value("Date", p.date),
                        y: .value("Val", p.value)
                    )
                    .foregroundStyle(by: .value("Series", line.label))
                    .symbolSize(20)
                }
            }
            if let goal = goalDisplay() {
                RuleMark(y: .value("Goal", goal))
                    .foregroundStyle(Color.lGain.opacity(0.7))
                    .lineStyle(StrokeStyle(lineWidth: 1.4, dash: [5, 4]))
                    .annotation(position: .top, alignment: .trailing) {
                        Text("Goal · \(Fmt.compact(goal, app.displayCurrency))")
                            .font(Typo.mono(10, weight: .semibold))
                            .foregroundStyle(Color.lGain)
                            .padding(.horizontal, 4)
                    }
            }
            if let h = hovered {
                RuleMark(x: .value("Date", h.date))
                    .foregroundStyle(Color.lInk3.opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    .annotation(
                        position: .automatic,
                        alignment: .center,
                        spacing: 4,
                        overflowResolution: .init(x: .fit(to: .chart), y: .fit(to: .chart))
                    ) {
                        multiTooltip(at: h.date, label: h.label)
                    }
            }
        }
        .chartForegroundStyleScale(domain: domain, range: range)
        .chartLegend(.hidden)
        .chartYAxis {
            AxisMarks(position: .leading) { _ in
                AxisGridLine().foregroundStyle(Color.lLine)
                AxisValueLabel().font(Typo.mono(10)).foregroundStyle(Color.lInk3)
            }
        }
        .chartXAxis {
            AxisMarks { _ in
                AxisGridLine().foregroundStyle(Color.lLine.opacity(0.5))
                AxisValueLabel().font(Typo.mono(10)).foregroundStyle(Color.lInk3)
            }
        }
        .chartOverlay { proxy in
            GeometryReader { geo in
                Rectangle().fill(Color.clear).contentShape(Rectangle())
                    .onContinuousHover { phase in
                        switch phase {
                        case .active(let pt):
                            let origin = proxy.plotFrame.map { geo[$0].origin } ?? .zero
                            let x = pt.x - origin.x
                            if let d: Date = proxy.value(atX: x) {
                                hovered = nearest(to: d)
                            }
                        case .ended:
                            hovered = nil
                        }
                    }
            }
        }
    }

    private func multiTooltip(at date: Date, label: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(Typo.mono(10, weight: .semibold))
                .foregroundStyle(Color.lInk3)
            ForEach(seriesValuesAt(date: date), id: \.label) { entry in
                HStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(entry.color)
                        .frame(width: 7, height: 7)
                    Text(entry.label)
                        .font(Typo.sans(11))
                        .foregroundStyle(Color.lInk2)
                        .lineLimit(1)
                    Spacer(minLength: 10)
                    Text(Fmt.compact(entry.value, app.displayCurrency))
                        .font(Typo.mono(11, weight: .semibold))
                        .foregroundStyle(Color.lInk)
                }
            }
        }
        .frame(minWidth: 180, maxWidth: 280, alignment: .leading)
        .padding(.horizontal, 10).padding(.vertical, 8)
        .background(Color.lPanel)
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.lLine, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .shadow(color: Color.black.opacity(0.25), radius: 6, y: 2)
    }

    private struct SeriesEntry { let label: String; let value: Double; let color: Color }

    private func seriesValuesAt(date: Date) -> [SeriesEntry] {
        cachedSeries.compactMap { line in
            guard let p = line.points.first(where: { abs($0.date.timeIntervalSince(date)) < 1 }) else {
                return nil
            }
            return SeriesEntry(label: line.label, value: p.value, color: line.color)
        }
        .sorted { $0.value > $1.value }
    }

    private var legend: some View {
        let cols = [GridItem(.adaptive(minimum: 190, maximum: 260), spacing: 10, alignment: .leading)]
        return LazyVGrid(columns: cols, alignment: .leading, spacing: 8) {
            ForEach(cachedSeries) { line in
                HStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(line.color).frame(width: 8, height: 8)
                    Text(line.label)
                        .font(Typo.sans(12))
                        .foregroundStyle(Color.lInk2)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .layoutPriority(1)
                    Text(Fmt.compact(line.points.last?.value ?? 0, app.displayCurrency))
                        .font(Typo.mono(11, weight: .medium))
                        .foregroundStyle(Color.lInk)
                        .monospacedDigit()
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 10).padding(.vertical, 6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.lLine, lineWidth: 1)
                )
            }
        }
    }

    private func nearest(to date: Date) -> SnapshotTotal? {
        cachedSnapshotTotals.min(by: {
            abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date))
        })
    }

    // MARK: table

    private struct TrendRow: Identifiable {
        let id: UUID
        let label: String
        let date: Date
        let total: Double
        let hasPrev: Bool
        let diff: Double
        let pct: Double
    }

    private var trendRows: [TrendRow] {
        let chrono = Array(cachedSnapshotTotals.reversed())
        return chrono.enumerated().map { idx, r in
            let prev: SnapshotTotal? = chrono.dropFirst(idx + 1).first
            let diff = prev.map { r.total - $0.total } ?? 0
            let pct: Double = {
                guard let p = prev, p.total != 0 else { return 0 }
                return (r.total - p.total) / abs(p.total) * 100
            }()
            return TrendRow(id: r.id, label: r.label, date: r.date, total: r.total,
                            hasPrev: prev != nil, diff: diff, pct: pct)
        }
    }

    private var sortedTrendRows: [TrendRow] {
        sizer.sorted(trendRows, comparators: [
            "snap":  { $0.label.localizedCaseInsensitiveCompare($1.label) == .orderedAscending },
            "date":  { $0.date < $1.date },
            "val":   { $0.total < $1.total },
            "dAbs":  { $0.diff < $1.diff },
            "dPct":  { $0.pct < $1.pct },
        ])
    }

    private var tableSection: some View {
        VStack(spacing: 0) {
            PanelHead(title: "Snapshots", meta: "\(cachedSnapshotTotals.count) in range")
            ResizableHeader(sizer: sizer)
            let rows = sortedTrendRows
            ForEach(Array(rows.enumerated()), id: \.element.id) { idx, r in
                let diff = r.diff
                let pct = r.pct
                let hasPrev = r.hasPrev
                HStack(spacing: 0) {
                    ResizableCell(sizer: sizer, colID: "snap") {
                        Text(r.label)
                            .font(Typo.sans(12.5, weight: .medium))
                            .foregroundStyle(Color.lInk)
                            .lineLimit(1)
                    }
                    ResizableCell(sizer: sizer, colID: "date") {
                        Text(Fmt.date(r.date))
                            .font(Typo.mono(11))
                            .foregroundStyle(Color.lInk3)
                            .lineLimit(1)
                    }
                    ResizableCell(sizer: sizer, colID: "val") {
                        Text(Fmt.compact(r.total, app.displayCurrency))
                            .font(Typo.mono(12.5, weight: .semibold))
                            .lineLimit(1)
                    }
                    ResizableCell(sizer: sizer, colID: "dAbs") {
                        Text(hasPrev ? Fmt.signedDelta(diff, app.displayCurrency) : "—")
                            .font(Typo.mono(11, weight: .medium))
                            .foregroundStyle(hasPrev ? Palette.deltaColor(diff) : Color.lInk4)
                            .lineLimit(1)
                    }
                    ResizableCell(sizer: sizer, colID: "dPct") {
                        Text(hasPrev ? "\(pct >= 0 ? "+" : "−")\(String(format: "%.1f", abs(pct)))%" : "—")
                            .font(Typo.mono(11))
                            .foregroundStyle(hasPrev ? Palette.deltaColor(diff) : Color.lInk4)
                            .lineLimit(1)
                    }
                }
                .padding(.horizontal, 18).padding(.vertical, 10)
                .background(idx.isMultiple(of: 2) ? Color.clear : Color.lSunken.opacity(0.5))
            }
        }
    }

    // MARK: compute

    private var rangedSnapshots: [Snapshot] {
        let sorted = snapshots.sorted { $0.date < $1.date }
        guard let last = sorted.last else { return [] }
        let cutoff: Date?
        let cal = Calendar.current
        switch range {
        case .all: cutoff = nil
        case .y5:  cutoff = cal.date(byAdding: .year, value: -5, to: last.date)
        case .y2:  cutoff = cal.date(byAdding: .year, value: -2, to: last.date)
        case .y1:  cutoff = cal.date(byAdding: .year, value: -1, to: last.date)
        }
        if let cutoff { return sorted.filter { $0.date >= cutoff } }
        return sorted
    }

    private func passesFilters(_ v: AssetValue) -> Bool {
        guard let acc = v.account else { return false }
        for f in filters {
            switch f.key {
            case .category:
                if acc.assetType?.category.rawValue != f.matchValue { return false }
            case .person:
                if (acc.person?.name ?? "—") != f.matchValue { return false }
            case .country:
                if (acc.country?.name ?? "") != f.matchValue { return false }
            case .assetType:
                if (acc.assetType?.name ?? "—") != f.matchValue { return false }
            case .group:
                let g = acc.groupName.isEmpty ? "Ungrouped" : acc.groupName
                if g != f.matchValue { return false }
            }
        }
        return true
    }

    private func recompute() {
        let target = app.displayCurrency
        let inc = app.includeIlliquidInNetWorth
        let snaps = rangedSnapshots

        var totals: [SnapshotTotal] = []
        for s in snaps {
            let t = s.totalsValues
                .filter(passesFilters)
                .reduce(0.0) { $0 + CurrencyConverter.netDisplayValue(for: $1, in: target, includeIlliquid: inc) }
            totals.append(SnapshotTotal(snapshotID: s.id, date: s.date, label: s.label, total: t))
        }
        cachedSnapshotTotals = totals

        if seriesMode == .total {
            cachedSeries = [SeriesLine(
                label: "Total",
                color: Color.lInk,
                points: totals.map { SeriesPoint(date: $0.date, label: $0.label, value: $0.total) }
            )]
        } else {
            cachedSeries = computeMultiSeries(snaps: snaps, target: target)
        }

        cachedStartTotal = totals.first?.total ?? 0
        cachedCurrentTotal = totals.last?.total ?? 0
        cachedDeltaAbs = cachedCurrentTotal - cachedStartTotal
        cachedDeltaPct = cachedStartTotal == 0 ? 0 : (cachedCurrentTotal - cachedStartTotal) / abs(cachedStartTotal) * 100

        if totals.count >= 2 {
            let last = totals.last!
            let prev = totals[totals.count - 2]
            cachedQoQAbs = last.total - prev.total
            cachedQoQPct = prev.total == 0 ? 0 : (last.total - prev.total) / abs(prev.total) * 100
        } else {
            cachedQoQAbs = 0
            cachedQoQPct = 0
        }

        if let first = totals.first, let last = totals.last,
           first.total > 0, last.total > 0, first.date < last.date {
            let years = last.date.timeIntervalSince(first.date) / (365.25 * 24 * 3600)
            if years > 0 {
                cachedCAGR = (pow(last.total / first.total, 1.0 / years) - 1) * 100
            } else {
                cachedCAGR = 0
            }
        } else {
            cachedCAGR = 0
        }
    }

    private func computeMultiSeries(snaps: [Snapshot], target: Currency) -> [SeriesLine] {
        var byLabel: [String: (color: Color, points: [SeriesPoint])] = [:]
        let inc = app.includeIlliquidInNetWorth

        for s in snaps {
            var bucket: [String: Double] = [:]
            var colorByLabel: [String: Color] = [:]

            for v in s.totalsValues where passesFilters(v) {
                guard let acc = v.account else { continue }
                if !inc && (acc.assetType?.category.isIlliquid ?? false) { continue }
                let (label, color) = seriesKey(for: acc)
                bucket[label, default: 0] += CurrencyConverter.netDisplayValue(for: v, in: target, includeIlliquid: inc)
                colorByLabel[label] = color
            }

            for (label, value) in bucket {
                let col = colorByLabel[label] ?? Palette.fallback(for: label)
                if byLabel[label] == nil { byLabel[label] = (col, []) }
                byLabel[label]!.color = col
                byLabel[label]!.points.append(SeriesPoint(date: s.date, label: s.label, value: value))
            }
        }

        return byLabel.map { (label, pair) in
            SeriesLine(label: label, color: pair.color,
                       points: pair.points.sorted { $0.date < $1.date })
        }
        .sorted { ($0.points.last?.value ?? 0) > ($1.points.last?.value ?? 0) }
    }

    private func seriesKey(for acc: Account) -> (String, Color) {
        switch seriesMode {
        case .total:
            return ("Total", Color.lInk)
        case .person:
            let label = acc.person?.name ?? "—"
            let col = Color.fromHex(acc.person?.colorHex) ?? Palette.fallback(for: label)
            return (label, col)
        case .country:
            let c = acc.country
            let label = c.map { "\($0.flag) \($0.name)" } ?? "—"
            let col = Color.fromHex(c?.colorHex) ?? Palette.fallback(for: c?.code ?? label)
            return (label, col)
        case .assetType:
            let label = acc.assetType?.name ?? "—"
            let col: Color = acc.assetType.map { Palette.color(for: $0.category) } ?? Palette.fallback(for: label)
            return (label, col)
        case .category:
            let label = acc.assetType?.category.rawValue ?? "—"
            let col: Color = acc.assetType.map { Palette.color(for: $0.category) } ?? Palette.fallback(for: label)
            return (label, col)
        }
    }
}


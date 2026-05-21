import SwiftUI
import SwiftData
import Charts

struct DashboardView: View {
    @EnvironmentObject var app: AppState
    @Query(sort: \Snapshot.date, order: .reverse) private var snapshots: [Snapshot]
    @Query private var allAccounts: [Account]

    @State private var cachedPersonItems: [AllocItem] = []
    @State private var cachedCountryItems: [AllocItem] = []
    @State private var cachedTypeItems: [AllocItem] = []
    @State private var cachedCurTotal: Double = 0
    @State private var cachedPrevTotal: Double = 0
    @State private var cachedYaTotal: Double = 0
    @State private var cachedLiquid: Double = 0
    @State private var cachedInvested: Double = 0
    @State private var cachedRetirement: Double = 0
    @State private var cachedInsurance: Double = 0
    @State private var cachedDebt: Double = 0
    @State private var cachedPrevLiquid: Double = 0
    @State private var cachedPrevInvested: Double = 0
    @State private var cachedYaLiquid: Double = 0
    @State private var cachedYaInvested: Double = 0
    @State private var cachedYaRetirement: Double = 0
    @State private var cachedYaInsurance: Double = 0
    @State private var cachedYaDebt: Double = 0
    @State private var cachedPrevRetirement: Double = 0
    @State private var cachedPrevInsurance: Double = 0
    @State private var cachedPrevDebt: Double = 0
    @State private var cachedMovers: [MoverRow] = []
    @State private var cachedTrajectory: [TrajectoryPoint] = []
    @State private var cachedTargets: [AssetCategory: Double] = [:]
    @State private var showingTargets: Bool = false
    @State private var cachedLiabilities: [LiabilityRow] = []

    private struct LiabilityRow: Identifiable {
        let id: UUID
        let name: String
        let currency: Currency
        let currentDisplay: Double
        let currentNative: Double
        let prevDisplay: Double?
        let peakDisplay: Double
        let color: Color
        var qoqDelta: Double? { prevDisplay.map { currentDisplay - $0 } }
        var paydownPct: Double {
            guard peakDisplay > 0 else { return 0 }
            return max(0, min(100, (peakDisplay - currentDisplay) / peakDisplay * 100))
        }
    }

    private struct TrajectoryPoint: Identifiable {
        let id = UUID()
        let date: Date
        let val: Double
    }

    private var visibleWidgets: [DashboardWidget] {
        let hidden = app.dashboardWidgetsHidden
        return app.dashboardWidgetOrder.filter { w in
            if hidden.contains(w) { return false }
            // Auto-hide widgets with no data to avoid empty cards.
            switch w {
            case .goal:        return app.netWorthGoal > 0
            case .liabilities: return !cachedLiabilities.isEmpty
            case .receivables: return hasReceivables
            case .watchlist:   return !app.pinnedAccountIDs.isEmpty
            default:           return true
            }
        }
    }

    @ViewBuilder
    private func widgetView(_ w: DashboardWidget) -> some View {
        switch w {
        case .hero:        hero
        case .digest:      digestPanel
        case .goal:        goalProgressPanel
        case .liquidity:   liquidityPanel
        case .kpi:         kpiGrid
        case .composition: composition
        case .liabilities: liabilities
        case .receivables: receivablesPanel
        case .movers:      movers
        case .watchlist:   watchlistPanel
        }
    }

    var body: some View {
        Group {
            if snapshots.isEmpty {
                EditorialEmpty(
                    eyebrow: "Overview · Net Worth",
                    title: "A ledger",
                    titleItalic: "awaits its first entry.",
                    body: "No snapshots yet. Capture a quarterly snapshot to begin charting trajectory, allocation, and movers across the household.",
                    detail: "Snapshots are point-in-time totals. One per quarter keeps the trend honest.",
                    ctaLabel: "Create first snapshot",
                    cta: {
                        app.newSnapshotRequested = true
                        app.selectedScreen = .snapshots
                    },
                    secondaryLabel: "Set up accounts first",
                    secondary: { app.selectedScreen = .accounts },
                    illustration: "chart.bar.doc.horizontal"
                )
            } else {
                VStack(alignment: .leading, spacing: 28) {
                    ForEach(visibleWidgets, id: \.self) { w in
                        widgetView(w)
                    }
                }
            }
        }
        .onAppear { recompute() }
        .onChange(of: app.activeSnapshotID) { _, _ in recompute() }
        .onChange(of: app.displayCurrency) { _, _ in recompute() }
        .onChange(of: snapshots.count) { _, _ in recompute() }
        .onChange(of: snapshots.map { $0.isLocked }) { _, _ in recompute() }
        .onChange(of: snapshots.map { $0.usdToInrRate }) { _, _ in recompute() }
        .onChange(of: app.includeIlliquidInNetWorth) { _, _ in recompute() }
    }

    private func recompute() {
        let target = app.displayCurrency
        let cur = activeSnapshot
        let prev = prevSnapshot
        let ya = yearAgoSnapshot

        cachedCurTotal = total(cur, target: target)
        cachedPrevTotal = total(prev, target: target)
        cachedYaTotal = total(ya, target: target)

        cachedPersonItems = computePersonItems(cur, target: target)
        cachedCountryItems = computeCountryItems(cur, target: target)
        cachedTypeItems = computeTypeItems(cur, target: target)

        cachedLiquid = sumCats(cur, [.cash], target: target)
        cachedInvested = sumCats(cur, [.investment, .crypto], target: target)
        cachedRetirement = sumCats(cur, [.retirement], target: target)
        cachedInsurance = sumCats(cur, [.insurance], target: target)
        cachedDebt = sumCats(cur, [.debt], target: target)

        cachedPrevLiquid = sumCats(prev, [.cash], target: target)
        cachedPrevInvested = sumCats(prev, [.investment, .crypto], target: target)
        cachedPrevRetirement = sumCats(prev, [.retirement], target: target)
        cachedPrevInsurance = sumCats(prev, [.insurance], target: target)
        cachedPrevDebt = sumCats(prev, [.debt], target: target)

        cachedYaLiquid = sumCats(ya, [.cash], target: target)
        cachedYaInvested = sumCats(ya, [.investment, .crypto], target: target)
        cachedYaRetirement = sumCats(ya, [.retirement], target: target)
        cachedYaInsurance = sumCats(ya, [.insurance], target: target)
        cachedYaDebt = sumCats(ya, [.debt], target: target)

        cachedMovers = computeMovers(cur: cur, prev: prev, target: target)
        cachedTrajectory = sortedAsc.map { TrajectoryPoint(date: $0.date, val: total($0, target: target)) }
        cachedTargets = TargetAllocationStore.all()
        cachedLiabilities = computeLiabilities(cur: cur, prev: prev, target: target)
    }

    private func computeLiabilities(cur: Snapshot?, prev: Snapshot?, target: Currency) -> [LiabilityRow] {
        guard let cur else { return [] }
        let debts = cur.totalsValues.filter { $0.account?.assetType?.category == .debt }
        guard !debts.isEmpty else { return [] }

        var peak: [UUID: Double] = [:]
        for s in snapshots {
            for v in s.totalsValues where v.account?.assetType?.category == .debt {
                guard let id = v.account?.id else { continue }
                let mag = abs(CurrencyConverter.displayValue(for: v, in: target))
                peak[id] = max(peak[id] ?? 0, mag)
            }
        }
        var prevMap: [UUID: Double] = [:]
        if let prev {
            for v in prev.totalsValues where v.account?.assetType?.category == .debt {
                guard let id = v.account?.id else { continue }
                prevMap[id] = abs(CurrencyConverter.displayValue(for: v, in: target))
            }
        }

        return debts.compactMap { v -> LiabilityRow? in
            guard let acc = v.account else { return nil }
            let curDisp = abs(CurrencyConverter.displayValue(for: v, in: target))
            return LiabilityRow(
                id: acc.id,
                name: acc.name,
                currency: acc.nativeCurrency,
                currentDisplay: curDisp,
                currentNative: abs(v.nativeValue),
                prevDisplay: prevMap[acc.id],
                peakDisplay: peak[acc.id] ?? curDisp,
                color: Palette.color(for: .debt)
            )
        }
        .sorted { $0.currentDisplay > $1.currentDisplay }
    }

    private func total(_ s: Snapshot?, target: Currency) -> Double {
        guard let s else { return 0 }
        let inc = app.includeIlliquidInNetWorth
        return s.totalsValues.reduce(0) { $0 + CurrencyConverter.netDisplayValue(for: $1, in: target, includeIlliquid: inc) }
    }

    private func sumCats(_ s: Snapshot?, _ cats: [AssetCategory], target: Currency) -> Double {
        guard let s else { return 0 }
        return s.totalsValues
            .filter { v in cats.contains(where: { $0 == v.account?.assetType?.category }) }
            .reduce(0.0) { $0 + CurrencyConverter.displayValue(for: $1, in: target) }
    }

    private func computePersonItems(_ s: Snapshot?, target: Currency) -> [AllocItem] {
        guard let s else { return [] }
        let inc = app.includeIlliquidInNetWorth
        var buckets: [String: (Double, Color)] = [:]
        for v in s.totalsValues {
            guard let acc = v.account, let p = acc.person else { continue }
            let amt = CurrencyConverter.netDisplayValue(for: v, in: target, includeIlliquid: inc)
            let col = Color.fromHex(p.colorHex) ?? Palette.fallback(for: p.name)
            buckets[p.name, default: (0, col)].0 += amt
        }
        return buckets.map {
            AllocItem(label: $0.key, value: $0.value.0, color: $0.value.1,
                      groupKey: .person, matchValue: $0.key)
        }
        .sorted { $0.value > $1.value }
    }

    private func computeCountryItems(_ s: Snapshot?, target: Currency) -> [AllocItem] {
        guard let s else { return [] }
        let inc = app.includeIlliquidInNetWorth
        var buckets: [String: (Double, Color, String)] = [:]
        for v in s.totalsValues {
            guard let acc = v.account, let c = acc.country else { continue }
            let amt = CurrencyConverter.netDisplayValue(for: v, in: target, includeIlliquid: inc)
            let key = "\(c.flag) \(c.name)"
            let col = Color.fromHex(c.colorHex) ?? Palette.fallback(for: c.code)
            buckets[key, default: (0, col, c.name)].0 += amt
        }
        return buckets.map {
            AllocItem(label: $0.key, value: $0.value.0, color: $0.value.1,
                      groupKey: .country, matchValue: $0.value.2)
        }
        .sorted { $0.value > $1.value }
    }

    private func computeTypeItems(_ s: Snapshot?, target: Currency) -> [AllocItem] {
        guard let s else { return [] }
        let inc = app.includeIlliquidInNetWorth
        var buckets: [AssetCategory: Double] = [:]
        for v in s.totalsValues {
            guard let acc = v.account, let t = acc.assetType else { continue }
            if !inc && t.category.isIlliquid { continue }
            buckets[t.category, default: 0] += CurrencyConverter.netDisplayValue(for: v, in: target)
        }
        return buckets.map {
            AllocItem(label: $0.key.rawValue, value: $0.value, color: Palette.color(for: $0.key),
                      groupKey: .category, matchValue: $0.key.rawValue)
        }
    }

    private func computeMovers(cur: Snapshot?, prev: Snapshot?, target: Currency) -> [MoverRow] {
        guard let cur, let prev else { return [] }
        let inc = app.includeIlliquidInNetWorth
        var prevMap: [UUID: Double] = [:]
        for v in prev.totalsValues where v.account != nil {
            if !inc && CurrencyConverter.isIlliquid(v) { continue }
            prevMap[v.account!.id] = CurrencyConverter.netDisplayValue(for: v, in: target)
        }
        var list: [MoverRow] = []
        for v in cur.totalsValues {
            guard let acc = v.account else { continue }
            if !inc && CurrencyConverter.isIlliquid(v) { continue }
            let now = CurrencyConverter.netDisplayValue(for: v, in: target)
            let before = prevMap[acc.id] ?? 0
            let diff = now - before
            let p = before == 0 ? 0 : diff / abs(before) * 100
            list.append(MoverRow(account: acc, value: now, pct: p, up: diff >= 0))
        }
        return list.sorted { abs($0.pct) > abs($1.pct) }.prefix(6).map { $0 }
    }

    private func openBreakdown(_ item: AllocItem) {
        app.pendingBreakdownFilter = PendingFilter(
            key: item.groupKey, matchValue: item.matchValue, label: item.label
        )
        app.selectedScreen = .breakdown
    }

    // MARK: computed

    private var sortedAsc: [Snapshot] { snapshots.sorted { $0.date < $1.date } }

    private var activeSnapshot: Snapshot? {
        if let id = app.activeSnapshotID, let s = snapshots.first(where: { $0.id == id }) { return s }
        return snapshots.first
    }

    private var activeIdx: Int? {
        guard let a = activeSnapshot else { return nil }
        return sortedAsc.firstIndex { $0.id == a.id }
    }

    private var prevSnapshot: Snapshot? {
        guard let i = activeIdx, i > 0 else { return nil }
        return sortedAsc[i - 1]
    }

    private var yearAgoSnapshot: Snapshot? {
        guard let active = activeSnapshot else { return nil }
        let oneYearAgo = Calendar.current.date(
            byAdding: .year, value: -1, to: active.date)!
        return sortedAsc
            .filter { $0.id != active.id && $0.date <= active.date }
            .min(by: { abs($0.date.timeIntervalSince(oneYearAgo))
                     < abs($1.date.timeIntervalSince(oneYearAgo)) })
            .flatMap { s -> Snapshot? in
                abs(s.date.timeIntervalSince(oneYearAgo)) < 90 * 86400 ? s : nil
            }
    }

    private var curTotal: Double  { cachedCurTotal }
    private var prevTotal: Double { cachedPrevTotal }
    private var yaTotal: Double   { cachedYaTotal }

    private func pct(_ cur: Double, _ prev: Double) -> Double {
        guard prev != 0 else { return 0 }
        return (cur - prev) / abs(prev) * 100
    }

    // MARK: hero

    private var hero: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Eyebrow + compare picker on same row.
            HStack(spacing: 8) {
                Circle().fill(Color.lInk).frame(width: 5, height: 5)
                Text("NET WORTH · \(activeSnapshot?.label ?? "—")")
                    .font(Typo.eyebrow)
                    .tracking(1.5)
                    .foregroundStyle(Color.lInk3)
                Spacer(minLength: 0)
                compareSegment
            }
            .padding(.bottom, 14)

            // Oversized monospaced figure with inline delta chip.
            HStack(alignment: .firstTextBaseline, spacing: 14) {
                HStack(alignment: .top, spacing: 4) {
                    Text(app.displayCurrency.symbol)
                        .font(Typo.serifNum(56))
                        .foregroundStyle(Color.lInk3)
                        .padding(.top, 24)
                    Text(Fmt.groupedInt(curTotal,
                                        locale: app.displayCurrency == .INR
                                            ? .init(identifier: "en_IN")
                                            : .init(identifier: "en_US")))
                        .font(Typo.serifNum(96))
                        .foregroundStyle(Color.lInk)
                        .monospacedDigit()
                        .tracking(-1.5)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
                .stealthAmount()

                inlineDeltaChip
                    .stealthAmount()

                Spacer(minLength: 0)
            }
            .padding(.bottom, 16)

            // Embedded sparkline — thin, full-width.
            embeddedSparkline
                .frame(height: 56)
                .padding(.bottom, 14)

            if let s = activeSnapshot {
                Text(footnote(for: s))
                    .font(Typo.serifItalic(13))
                    .foregroundStyle(Color.lInk2)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(24)
        .background(Color.lPanel)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.lLine, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    @ViewBuilder
    private var compareSegment: some View {
        let opts: [(String, AppState.CompareMode)] =
            AppState.CompareMode.allCases.map { ($0.label, $0) }
        SegControl(
            options: opts,
            selection: Binding(
                get: { app.dashboardCompareMode },
                set: { app.dashboardCompareMode = $0 }
            )
        )
    }

    private var compareReferenceTotal: Double? {
        switch app.dashboardCompareMode {
        case .previous: return prevSnapshot != nil ? cachedPrevTotal : nil
        case .yearAgo:  return yearAgoSnapshot != nil ? cachedYaTotal : nil
        }
    }

    @ViewBuilder
    private var inlineDeltaChip: some View {
        if let ref = compareReferenceTotal {
            let delta = curTotal - ref
            let p = ref == 0 ? 0 : delta / abs(ref) * 100
            let up = delta >= 0
            HStack(spacing: 6) {
                Image(systemName: up ? "arrow.up.right" : "arrow.down.right")
                    .font(.system(size: 11, weight: .bold))
                Text("\(up ? "+" : "−")\(Fmt.compact(abs(delta), app.displayCurrency))")
                    .font(Typo.mono(13, weight: .semibold))
                    .monospacedDigit()
                Text("\(up ? "+" : "−")\(String(format: "%.1f", abs(p)))%")
                    .font(Typo.mono(11))
                    .foregroundStyle(.secondary)
                Text(app.dashboardCompareMode.shortLabel)
                    .font(Typo.eyebrow).tracking(1.0)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10).padding(.vertical, 6)
            .foregroundStyle(up ? Color.lGain : Color.lLoss)
            .background((up ? Color.lGain : Color.lLoss).opacity(0.10))
            .overlay(Capsule().stroke((up ? Color.lGain : Color.lLoss).opacity(0.35), lineWidth: 1))
            .clipShape(Capsule())
        } else {
            Text("No prior snapshot")
                .font(Typo.eyebrow).tracking(1.0)
                .foregroundStyle(Color.lInk3)
                .padding(.horizontal, 10).padding(.vertical, 6)
                .overlay(Capsule().stroke(Color.lLine, lineWidth: 1))
                .clipShape(Capsule())
        }
    }

    @ViewBuilder
    private var embeddedSparkline: some View {
        Chart(cachedTrajectory) { pt in
            AreaMark(x: .value("Date", pt.date), y: .value("Val", pt.val))
                .foregroundStyle(.linearGradient(
                    colors: [Color.lInk.opacity(0.18), Color.lInk.opacity(0.02)],
                    startPoint: .top, endPoint: .bottom))
                .interpolationMethod(.catmullRom)
            LineMark(x: .value("Date", pt.date), y: .value("Val", pt.val))
                .foregroundStyle(Color.lInk)
                .lineStyle(StrokeStyle(lineWidth: 1.4, lineCap: .round, lineJoin: .round))
                .interpolationMethod(.catmullRom)
            if let goal = goalDisplay() {
                RuleMark(y: .value("Goal", goal))
                    .foregroundStyle(Color.lGain.opacity(0.7))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
    }

    @ViewBuilder
    private var sparklinePanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Net worth trajectory")
                    .font(Typo.eyebrow)
                    .tracking(1.5)
                    .foregroundStyle(Color.lInk3)
                Spacer()
                if let first = sortedAsc.first, let last = sortedAsc.last {
                    HStack(spacing: 4) {
                        Text(first.label).font(Typo.mono(10))
                        Text("→").font(Typo.mono(10)).foregroundStyle(Color.lInk4)
                        Text(last.label).font(Typo.mono(10))
                    }
                    .foregroundStyle(Color.lInk3)
                }
            }
            Chart(cachedTrajectory) { pt in
                AreaMark(
                    x: .value("Date", pt.date),
                    y: .value("Val", pt.val)
                )
                .foregroundStyle(
                    .linearGradient(colors: [Color.lInk.opacity(0.18), Color.lInk.opacity(0.02)],
                                    startPoint: .top, endPoint: .bottom)
                )
                .interpolationMethod(.catmullRom)
                LineMark(
                    x: .value("Date", pt.date),
                    y: .value("Val", pt.val)
                )
                .foregroundStyle(Color.lInk)
                .lineStyle(StrokeStyle(lineWidth: 1.4, lineCap: .round, lineJoin: .round))
                .interpolationMethod(.catmullRom)
                if let goal = goalDisplay() {
                    RuleMark(y: .value("Goal", goal))
                        .foregroundStyle(Color.lGain.opacity(0.7))
                        .lineStyle(StrokeStyle(lineWidth: 1.2, dash: [4, 3]))
                        .annotation(position: .top, alignment: .trailing) {
                            Text("Goal · \(Fmt.compact(goal, app.displayCurrency))")
                                .font(Typo.mono(9, weight: .semibold))
                                .foregroundStyle(Color.lGain)
                                .padding(.horizontal, 4)
                        }
                }
            }
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .chartPlotStyle { $0.background(Color.lSunken.opacity(0.3)) }
        }
        .padding(14)
        .background(Color.lBg2)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.lLine, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    @ViewBuilder
    private var digestPanel: some View {
        let sentence = digestSentence
        if !sentence.isEmpty {
            Panel {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.lInk2)
                        .padding(.top, 1)
                    Text(sentence)
                        .font(Typo.serifItalic(15))
                        .foregroundStyle(Color.lInk)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
                .padding(16)
            }
        }
    }

    private var digestSentence: String {
        guard cachedCurTotal != 0 || cachedPrevTotal != 0 else { return "" }
        let delta = cachedCurTotal - cachedPrevTotal
        let pct = cachedPrevTotal == 0 ? 0 : delta / abs(cachedPrevTotal)
        let direction = delta >= 0 ? "grew" : "shrank"
        let absDelta = Fmt.compact(abs(delta), app.displayCurrency)
        let pctStr = String(format: "%.1f%%", abs(pct) * 100)

        let gainers = cachedMovers.filter { $0.up }.prefix(2).map { $0.account.name }
        let losers  = cachedMovers.filter { !$0.up }.prefix(2).map { $0.account.name }

        var parts: [String] = []
        parts.append("Net worth \(direction) \(absDelta) (\(pctStr)) since the previous snapshot.")
        if !gainers.isEmpty {
            let names = gainers.joined(separator: " and ")
            parts.append("Lifted by \(names).")
        }
        if !losers.isEmpty {
            let names = losers.joined(separator: " and ")
            parts.append("Dragged by \(names).")
        }
        if let goal = goalDisplay(), goal > 0 {
            let remain = goal - cachedCurTotal
            if remain > 0 {
                parts.append("\(Fmt.compact(remain, app.displayCurrency)) to reach goal.")
            } else {
                parts.append("Goal cleared by \(Fmt.compact(-remain, app.displayCurrency)).")
            }
        }
        return parts.joined(separator: " ")
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

    /// Builds (date, displayTotal) tuples for trend-fitting on every snapshot,
    /// converted to current display currency.
    private func historyForFit() -> [(Date, Double)] {
        let inc = app.includeIlliquidInNetWorth
        return snapshots
            .sorted { $0.date < $1.date }
            .map { s in
                let total = s.totalsValues.reduce(0.0) {
                    $0 + CurrencyConverter.netDisplayValue(for: $1,
                                                           in: app.displayCurrency,
                                                           includeIlliquid: inc)
                }
                return (s.date, total)
            }
    }

    @ViewBuilder
    private var goalProgressPanel: some View {
        let goal = goalDisplay() ?? 0
        let cur = cachedCurTotal
        let pct = goal > 0 ? min(1.0, max(0.0, cur / goal)) : 0
        let remaining = max(0, goal - cur)
        let cleared = cur >= goal
        let history = historyForFit()
        let forecast = Forecast.compute(history: history,
                                        method: app.forecastMethod,
                                        horizonMonths: 0,
                                        goal: goal)
        let trendETA = forecast?.etaForGoal
        let target = app.netWorthGoalDate

        Panel {
            VStack(alignment: .leading, spacing: 14) {
                PanelHead(title: "Goal",
                          meta: cleared ? "Cleared" : "\(Fmt.compact(remaining, app.displayCurrency)) to go")

                HStack(alignment: .firstTextBaseline) {
                    Text(Fmt.compact(cur, app.displayCurrency))
                        .font(Typo.serifNum(28))
                        .foregroundStyle(Color.lInk)
                        .stealthAmount()
                    Text("/ \(Fmt.compact(goal, app.displayCurrency))")
                        .font(Typo.mono(13))
                        .foregroundStyle(Color.lInk3)
                        .stealthAmount()
                    Spacer()
                    Text("\(String(format: "%.1f", pct * 100))%")
                        .font(Typo.mono(13, weight: .semibold))
                        .foregroundStyle(cleared ? Color.lGain : Color.lInk2)
                }
                .padding(.horizontal, 18)

                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.lSunken)
                        .frame(height: 8)
                    GeometryReader { geo in
                        RoundedRectangle(cornerRadius: 4)
                            .fill(LinearGradient(
                                colors: [Color.lGain, Color.lInk],
                                startPoint: .leading, endPoint: .trailing))
                            .frame(width: max(2, geo.size.width * pct), height: 8)
                    }
                    .frame(height: 8)
                }
                .padding(.horizontal, 18)

                HStack(alignment: .top, spacing: 18) {
                    goalStat(label: "Trend ETA",
                             value: trendETA.map(formatDateLabel) ?? "—",
                             sub: forecast.flatMap { f in
                                 f.cagrPct.map { "\(String(format: "%.1f", $0))% / yr (CAGR)" }
                                     ?? f.slopePerDay.map { "\(Fmt.compact($0 * 30, app.displayCurrency))/mo" }
                             } ?? "Need ≥ 2 snapshots")
                    if let target {
                        goalStat(label: "Target date",
                                 value: formatDateLabel(target),
                                 sub: pacingNote(eta: trendETA, target: target))
                    } else {
                        goalStat(label: "Target date",
                                 value: "—",
                                 sub: "Set in Settings to track pacing")
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 14)
            }
        }
    }

    @ViewBuilder
    private func goalStat(label: String, value: String, sub: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(Typo.eyebrow).tracking(1.2)
                .foregroundStyle(Color.lInk3)
            Text(value)
                .font(Typo.mono(13, weight: .semibold))
                .foregroundStyle(Color.lInk)
            Text(sub)
                .font(Typo.sans(11))
                .foregroundStyle(Color.lInk3)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var liquidityPanel: some View {
        if let r = LiquidityAnalysis.compute(snapshots: snapshots,
                                             displayCurrency: app.displayCurrency,
                                             includeIlliquid: app.includeIlliquidInNetWorth) {
            Panel {
                VStack(alignment: .leading, spacing: 0) {
                    PanelHead(title: "Liquidity",
                              meta: r.lookbackPairs > 0
                                  ? "\(r.lookbackPairs) snapshot transitions"
                                  : "needs ≥ 2 snapshots")
                    HStack(alignment: .top, spacing: 18) {
                        liquidityStat(label: "Cash on hand",
                                      value: Fmt.compact(r.liquidNow, app.displayCurrency),
                                      sub: "Sum of Cash-category accounts",
                                      tint: .lInk,
                                      blur: true)
                        liquidityStat(label: "Monthly net",
                                      value: r.monthlyChange == 0
                                          ? "—"
                                          : (r.monthlyChange > 0 ? "+" : "−")
                                              + Fmt.compact(abs(r.monthlyChange), app.displayCurrency),
                                      sub: r.monthlyChange >= 0
                                          ? "Cash growing — no burn"
                                          : "Avg monthly drop",
                                      tint: r.monthlyChange >= 0 ? .lGain : .lLoss,
                                      blur: true)
                        liquidityStat(label: "Runway",
                                      value: runwayLabel(r),
                                      sub: r.monthsRunway == nil
                                          ? "Burn = 0"
                                          : "At current burn rate",
                                      tint: runwayTint(r),
                                      blur: false)
                        Spacer(minLength: 0)
                    }
                    .padding(18)
                }
            }
        }
    }

    @ViewBuilder
    private func liquidityStat(label: String, value: String, sub: String,
                               tint: Color, blur: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(Typo.eyebrow).tracking(1.2)
                .foregroundStyle(Color.lInk3)
            Group {
                Text(value)
                    .font(Typo.serifNum(22))
                    .foregroundStyle(tint)
                    .monospacedDigit()
            }
            .modifier(StealthIfNeeded(blur: blur))
            Text(sub)
                .font(Typo.sans(11))
                .foregroundStyle(Color.lInk3)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(minWidth: 160, alignment: .leading)
    }

    private func runwayLabel(_ r: LiquidityAnalysis.Result) -> String {
        guard let m = r.monthsRunway else { return "∞" }
        if m >= 24 { return "\(Int(m / 12))y \(Int(m.truncatingRemainder(dividingBy: 12))) mo" }
        return "\(Int(m.rounded())) mo"
    }

    private func runwayTint(_ r: LiquidityAnalysis.Result) -> Color {
        guard let m = r.monthsRunway else { return .lGain }
        if m < 3 { return .lLoss }
        if m < 6 { return .lInk }
        return .lGain
    }

    private func formatDateLabel(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMM yyyy"
        return f.string(from: d)
    }

    private func pacingNote(eta: Date?, target: Date) -> String {
        guard let eta else { return "Trend not enough data" }
        let cal = Calendar.current
        let months = cal.dateComponents([.month], from: target, to: eta).month ?? 0
        if months <= 0 {
            return "On track — \(abs(months)) mo ahead of target"
        } else {
            return "Behind — \(months) mo past target"
        }
    }

    private func footnote(for s: Snapshot) -> String {
        let accCount = Set(s.values.compactMap { $0.account?.id }).count
        let countries = Set(s.values.compactMap { $0.account?.country?.name }).count
        let people = Set(s.values.compactMap { $0.account?.person?.name })
        let peopleStr = people.sorted().joined(separator: " & ")
        return "Across \(accCount) accounts in \(countries) \(countries == 1 ? "country" : "countries"), held by \(peopleStr). Last updated \(s.label) · exchange rate ₹\(String(format: "%.2f", s.usdToInrRate)) / $1."
    }

    // MARK: KPI grid

    /// Reference total per current compare mode. nil when no prior snapshot.
    private func kpiRef(prev: Double, ya: Double) -> Double? {
        switch app.dashboardCompareMode {
        case .previous: return prevSnapshot != nil ? prev : nil
        case .yearAgo:  return yearAgoSnapshot != nil ? ya : nil
        }
    }

    private func kpiDeltaText(cur: Double, ref: Double?) -> String? {
        guard let r = ref, r != 0 else { return nil }
        let d = (cur - r) / abs(r) * 100
        return "\(d >= 0 ? "+" : "−")\(String(format: "%.1f", abs(d)))% \(app.dashboardCompareMode.shortLabel)"
    }

    private var kpiGrid: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 14), count: 4),
            spacing: 14
        ) {
            let refLiquid    = kpiRef(prev: cachedPrevLiquid,    ya: cachedYaLiquid)
            let refInvested  = kpiRef(prev: cachedPrevInvested,  ya: cachedYaInvested)
            let refRetIns    = kpiRef(prev: cachedPrevRetirement + cachedPrevInsurance,
                                       ya: cachedYaRetirement + cachedYaInsurance)
            let refDebt      = kpiRef(prev: cachedPrevDebt,      ya: cachedYaDebt)

            KPICard(
                label: "Liquid",
                value: Fmt.compact(cachedLiquid, app.displayCurrency),
                sub: "Cash + deposits",
                deltaText: kpiDeltaText(cur: cachedLiquid, ref: refLiquid),
                deltaUp: cachedLiquid >= (refLiquid ?? cachedLiquid)
            )
            KPICard(
                label: "Invested",
                value: Fmt.compact(cachedInvested, app.displayCurrency),
                sub: "Equity + crypto",
                deltaText: kpiDeltaText(cur: cachedInvested, ref: refInvested),
                deltaUp: cachedInvested >= (refInvested ?? cachedInvested)
            )
            KPICard(
                label: "Retirement",
                value: Fmt.compact(cachedRetirement + cachedInsurance, app.displayCurrency),
                sub: "401k · IRA · NPS · HSA",
                deltaText: kpiDeltaText(cur: cachedRetirement + cachedInsurance, ref: refRetIns),
                deltaUp: (cachedRetirement + cachedInsurance) >= (refRetIns ?? (cachedRetirement + cachedInsurance))
            )
            KPICard(
                label: "Debt",
                value: Fmt.compact(abs(cachedDebt), app.displayCurrency),
                sub: "Loans · credit",
                valueColor: .lLoss,
                deltaText: kpiDeltaText(cur: cachedDebt, ref: refDebt),
                deltaUp: cachedDebt >= (refDebt ?? cachedDebt)
            )
        }
    }

    // MARK: Composition

    private var composition: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHead(title: "Composition", emphasis: "— where it lives",
                        rightLabel: (activeSnapshot?.label ?? "—") + " · " + app.displayCurrency.rawValue)
            HStack(alignment: .top, spacing: 14) {
                personPanel
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                countryPanel
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                typePanel
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var personPanel: some View {
        Panel {
            VStack(spacing: 0) {
                PanelHead(title: "By person", meta: "\(personItems.count) people")
                donutPanel(items: personItems, total: curTotal)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }

    private var countryPanel: some View {
        Panel {
            VStack(spacing: 0) {
                PanelHead(title: "By country", meta: "\(countryItems.count) \(countryItems.count == 1 ? "jurisdiction" : "jurisdictions")")
                VStack(alignment: .leading, spacing: 18) {
                    StackedHBar(items: countryItems.map {
                        StackedHBar.Item(label: $0.label, value: $0.value, color: $0.color)
                    })
                    VStack(spacing: 0) {
                        ForEach(Array(countryItems.enumerated()), id: \.offset) { _, c in
                            Button {
                                openBreakdown(c)
                            } label: {
                                AllocRow(
                                    color: c.color, label: c.label,
                                    value: Fmt.compact(c.value, app.displayCurrency),
                                    pct: curTotal == 0 ? 0 : c.value / curTotal * 100
                                )
                            }
                            .buttonStyle(.plain)
                            .pointerStyle(.link)
                            Divider().overlay(Color.lLine)
                        }
                    }
                }
                .padding(18)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }

    private var typePanel: some View {
        Panel {
            VStack(spacing: 0) {
                typePanelHead
                VStack(spacing: 0) {
                    ForEach(Array(typeItems.sorted { abs($0.value) > abs($1.value) }.enumerated()), id: \.offset) { _, t in
                        Button {
                            openBreakdown(t)
                        } label: {
                            AllocRow(
                                color: t.color, label: t.label,
                                value: Fmt.compact(abs(t.value), app.displayCurrency),
                                pct: curTotal == 0 ? 0 : abs(t.value) / curTotal * 100,
                                showBar: true,
                                valueColor: t.value < 0 ? .lLoss : .lInk,
                                targetPct: targetPct(for: t)
                            )
                        }
                        .buttonStyle(.plain)
                        .pointerStyle(.link)
                        Divider().overlay(Color.lLine)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .sheet(isPresented: $showingTargets) {
            TargetsEditorSheet(onSave: { recompute() })
        }
    }

    private var typePanelHead: some View {
        HStack {
            Text("By asset type")
                .font(Typo.sans(14, weight: .semibold))
                .foregroundStyle(Color.lInk)
            Spacer()
            Text(targetSummary)
                .font(Typo.sans(12))
                .foregroundStyle(Color.lInk3)
            GhostButton(action: { showingTargets = true }) {
                HStack(spacing: 4) {
                    Image(systemName: "target").font(.system(size: 10, weight: .semibold))
                    Text(cachedTargets.isEmpty ? "Set targets" : "Targets")
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .overlay(Rectangle().frame(height: 1).foregroundStyle(Color.lLine), alignment: .bottom)
    }

    private var targetSummary: String {
        if cachedTargets.isEmpty { return "\(typeItems.count) categories" }
        let sum = cachedTargets.values.reduce(0, +)
        if abs(sum - 100) < 0.05 { return "\(cachedTargets.count) set · balanced" }
        if sum < 100 { return "\(cachedTargets.count) set · \(String(format: "%.0f", 100 - sum))% unassigned" }
        return "\(cachedTargets.count) set · \(String(format: "%.0f", sum - 100))% over"
    }

    private func targetPct(for item: AllocItem) -> Double? {
        guard let cat = AssetCategory(rawValue: item.matchValue) else { return nil }
        return cachedTargets[cat]
    }

    /// Hit-test a point against the donut. Returns the AllocItem under the
    /// click, or nil if outside the ring. Used for tap-to-drilldown without
    /// the noisy hover updates that `.chartAngleSelection` produces on macOS.
    private func sectorAt(_ point: CGPoint, in size: CGSize, items: [AllocItem]) -> AllocItem? {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let dx = point.x - center.x
        let dy = point.y - center.y
        let r = sqrt(dx * dx + dy * dy)
        let outer = min(size.width, size.height) / 2
        let inner = outer * 0.66
        guard r >= inner && r <= outer else { return nil }

        // SwiftUI Charts SectorMark draws clockwise from 12 o'clock.
        var theta = atan2(dx, -dy)
        if theta < 0 { theta += 2 * .pi }

        let total = items.reduce(0.0) { $0 + abs($1.value) }
        guard total > 0 else { return nil }
        let target = theta / (2 * .pi) * total

        var cum = 0.0
        for it in items where abs(it.value) > 0 {
            cum += abs(it.value)
            if target <= cum { return it }
        }
        return items.last
    }

    @ViewBuilder
    private func donutPanel(items: [AllocItem], total: Double) -> some View {
        VStack(spacing: 14) {
            ZStack {
                Chart(items) { i in
                    SectorMark(
                        angle: .value("v", abs(i.value)),
                        innerRadius: .ratio(0.66),
                        angularInset: 1.5
                    )
                    .foregroundStyle(i.color)
                    .cornerRadius(2)
                }
                .frame(width: 180, height: 180)
                .chartOverlay { _ in
                    GeometryReader { geo in
                        Rectangle()
                            .fill(Color.clear)
                            .contentShape(Rectangle())
                            .onTapGesture { loc in
                                if let hit = sectorAt(loc, in: geo.size, items: items) {
                                    openBreakdown(hit)
                                }
                            }
                    }
                }
                VStack(spacing: 4) {
                    Text("TOTAL")
                        .font(Typo.sans(10, weight: .medium))
                        .tracking(1.4)
                        .foregroundStyle(Color.lInk3)
                    Text(Fmt.compact(total, app.displayCurrency))
                        .font(Typo.serifNum(26))
                        .foregroundStyle(Color.lInk)
                        .monospacedDigit()
                        .stealthAmount()
                }
            }
            .padding(.top, 14)
            VStack(spacing: 0) {
                ForEach(items) { i in
                    Button {
                        openBreakdown(i)
                    } label: {
                        AllocRow(
                            color: i.color, label: i.label,
                            value: Fmt.compact(i.value, app.displayCurrency),
                            pct: total == 0 ? 0 : i.value / total * 100
                        )
                    }
                    .buttonStyle(.plain)
                    .pointerStyle(.link)
                    Divider().overlay(Color.lLine)
                }
            }
        }
        .padding(18)
    }

    private struct AllocItem: Identifiable {
        let id = UUID()
        let label: String
        let value: Double
        let color: Color
        let groupKey: GroupKey
        let matchValue: String
    }

    private var personItems: [AllocItem] { cachedPersonItems }
    private var countryItems: [AllocItem] { cachedCountryItems }
    private var typeItems: [AllocItem] { cachedTypeItems }

    // MARK: Liabilities

    private var liabilities: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHead(title: "Liabilities", emphasis: "— what you owe",
                        rightLabel: Fmt.compact(totalLiabilities, app.displayCurrency))
            Panel {
                VStack(spacing: 0) {
                    PanelHead(title: "Debt accounts",
                              meta: "\(cachedLiabilities.count) \(cachedLiabilities.count == 1 ? "account" : "accounts") · total \(Fmt.compact(totalLiabilities, app.displayCurrency))")
                    VStack(spacing: 0) {
                        ForEach(Array(cachedLiabilities.enumerated()), id: \.element.id) { idx, row in
                            liabilityRow(row)
                                .padding(.horizontal, 18).padding(.vertical, 12)
                                .background(idx.isMultiple(of: 2) ? Color.clear : Color.lSunken.opacity(0.5))
                            if idx < cachedLiabilities.count - 1 {
                                Divider().overlay(Color.lLine)
                            }
                        }
                    }
                }
            }
        }
    }

    private var totalLiabilities: Double {
        cachedLiabilities.reduce(0) { $0 + $1.currentDisplay }
    }

    private func liabilityRow(_ row: LiabilityRow) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(row.color).frame(width: 10, height: 10)
                Text(row.name)
                    .font(Typo.sans(13, weight: .semibold))
                    .foregroundStyle(Color.lInk)
                    .lineLimit(1)
                Spacer(minLength: 8)
                if let d = row.qoqDelta {
                    let paidDown = d < 0
                    HStack(spacing: 4) {
                        Image(systemName: paidDown ? "arrow.down.right" : "arrow.up.right")
                            .font(.system(size: 9, weight: .bold))
                        Text(Fmt.compact(abs(d), app.displayCurrency))
                            .font(Typo.mono(11, weight: .semibold))
                        Text("QoQ")
                            .font(Typo.mono(10))
                            .opacity(0.7)
                    }
                    .foregroundStyle(paidDown ? Color.lGain : Color.lLoss)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background((paidDown ? Color.lGain : Color.lLoss).opacity(0.12))
                    .overlay(Capsule().stroke((paidDown ? Color.lGain : Color.lLoss).opacity(0.3), lineWidth: 1))
                    .clipShape(Capsule())
                }
                Text(Fmt.compact(row.currentDisplay, app.displayCurrency))
                    .font(Typo.sans(13, weight: .semibold))
                    .foregroundStyle(Color.lLoss)
                    .monospacedDigit()
            }
            HStack(spacing: 10) {
                Text("PAID \(String(format: "%.0f", row.paydownPct))%")
                    .font(Typo.eyebrow).tracking(1.2)
                    .foregroundStyle(Color.lInk3)
                    .frame(width: 70, alignment: .leading)
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Rectangle().fill(Color.lSunken)
                        Rectangle().fill(Color.lGain.opacity(0.55))
                            .frame(width: max(0, geo.size.width * CGFloat(row.paydownPct / 100)))
                    }
                }
                .frame(height: 6)
                .clipShape(RoundedRectangle(cornerRadius: 3))
                Text("peak \(Fmt.compact(row.peakDisplay, app.displayCurrency))")
                    .font(Typo.mono(10.5))
                    .foregroundStyle(Color.lInk3)
                    .frame(width: 120, alignment: .trailing)
            }
        }
    }

    // MARK: Movers

    private var movers: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHead(title: "Biggest movers", emphasis: "— this quarter",
                        rightLabel: prevSnapshot != nil ? "\(prevSnapshot!.label) → \(activeSnapshot?.label ?? "—")" : nil)
            Panel {
                VStack(spacing: 0) {
                    moversHeader
                    ForEach(Array(moversList.enumerated()), id: \.offset) { i, m in
                        moverRow(m)
                        if i < moversList.count - 1 {
                            Divider().overlay(Color.lLine)
                        }
                    }
                }
            }
        }
    }

    private var moversHeader: some View {
        HStack {
            Text("Account").frame(maxWidth: .infinity, alignment: .leading)
            Text("Owner").frame(width: 140, alignment: .leading)
            Text("Country").frame(width: 100, alignment: .leading)
            Text("Type").frame(width: 120, alignment: .leading)
            Text("Value").frame(width: 120, alignment: .trailing)
            Text("QoQ").frame(width: 80, alignment: .trailing)
        }
        .font(Typo.eyebrow)
        .tracking(1.2)
        .foregroundStyle(Color.lInk3)
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(Color.lSunken)
        .overlay(Rectangle().frame(height: 1).foregroundStyle(Color.lLine), alignment: .bottom)
    }

    private struct MoverRow: Identifiable {
        let id = UUID()
        let account: Account
        let value: Double
        let pct: Double
        let up: Bool
    }

    private var moversList: [MoverRow] { cachedMovers }

    private func moverRow(_ m: MoverRow) -> some View {
        let person = m.account.person
        let country = m.account.country
        let type = m.account.assetType
        return HStack {
            Text(m.account.name)
                .font(Typo.sans(12.5, weight: .medium))
                .foregroundStyle(Color.lInk)
                .frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: 6) {
                if let p = person {
                    Avatar(text: String(p.name.prefix(1)),
                           color: Color.fromHex(p.colorHex) ?? Palette.fallback(for: p.name),
                           size: 18)
                    Text(p.name).font(Typo.sans(12))
                }
            }
            .foregroundStyle(Color.lInk2)
            .frame(width: 140, alignment: .leading)
            Text(country?.flag ?? "")
                .font(.system(size: 14))
                .frame(width: 100, alignment: .leading)
            Text(type?.name ?? "")
                .font(Typo.sans(12))
                .foregroundStyle(Color.lInk2)
                .frame(width: 120, alignment: .leading)
            Text(Fmt.compact(m.value, app.displayCurrency))
                .font(Typo.mono(12, weight: .medium))
                .foregroundStyle(Color.lInk)
                .frame(width: 120, alignment: .trailing)
            Text("\(m.up ? "+" : "−")\(String(format: "%.1f", abs(m.pct)))%")
                .font(Typo.mono(12, weight: .medium))
                .foregroundStyle(m.up ? Color.lGain : Color.lLoss)
                .frame(width: 80, alignment: .trailing)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 11)
    }

    // MARK: - Pending receivables (outside net worth)

    private var hasReceivables: Bool {
        guard let cur = activeSnapshot else { return false }
        return cur.receivableValues.contains { $0.nativeValue != 0 }
            || cur.receivableValues.isEmpty == false
    }

    private var watchlistPanel: some View {
        let target = app.displayCurrency
        let pinned = app.pinnedAccountIDs
        let byID = Dictionary(uniqueKeysWithValues: allAccounts.map { ($0.id, $0) })
        let rows: [Account] = pinned.compactMap { byID[$0] }
        let activeSnap = activeSnapshot
        let prevSnap = prevSnapshot
        return Panel {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("WATCHLIST")
                            .font(Typo.eyebrow).tracking(1.5)
                            .foregroundStyle(Color.lInk3)
                        Text("Pinned accounts")
                            .font(Typo.serifNum(18))
                            .foregroundStyle(Color.lInk)
                    }
                    Spacer()
                    Text("\(rows.count) pinned")
                        .font(Typo.eyebrow).tracking(1.2)
                        .foregroundStyle(Color.lInk3)
                }
                .padding(.horizontal, 18).padding(.vertical, 14)
                .overlay(Rectangle().frame(height: 1).foregroundStyle(Color.lLine), alignment: .bottom)

                ForEach(Array(rows.enumerated()), id: \.element.id) { idx, a in
                    watchlistRow(a, target: target, activeSnap: activeSnap, prevSnap: prevSnap)
                    if idx < rows.count - 1 {
                        Divider().overlay(Color.lLine)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func watchlistRow(_ a: Account, target: Currency,
                              activeSnap: Snapshot?, prevSnap: Snapshot?) -> some View {
        let curNative = activeSnap?.values.first { $0.account?.id == a.id }?.nativeValue
        let prevNative = prevSnap?.values.first { $0.account?.id == a.id }?.nativeValue
        let curDisplay: Double? = {
            guard let v = curNative, let s = activeSnap else { return nil }
            return CurrencyConverter.convert(nativeValue: v, from: a.nativeCurrency, to: target,
                                             usdToInrRate: s.usdToInrRate)
        }()
        let prevDisplay: Double? = {
            guard let v = prevNative, let s = prevSnap else { return nil }
            return CurrencyConverter.convert(nativeValue: v, from: a.nativeCurrency, to: target,
                                             usdToInrRate: s.usdToInrRate)
        }()
        let diff: Double? = {
            guard let c = curDisplay, let p = prevDisplay else { return nil }
            return c - p
        }()
        Button {
            app.pendingFocusAccountID = a.id
            app.selectedScreen = .accounts
            app.touchRecent(.account, id: a.id, label: a.name)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(a.name)
                        .font(Typo.sans(13, weight: .medium))
                        .foregroundStyle(Color.lInk)
                        .lineLimit(1)
                    HStack(spacing: 6) {
                        if let p = a.person?.name { Text(p) }
                        if let cn = a.country?.code { Text(cn) }
                        if let t = a.assetType?.name { Text(t) }
                    }
                    .font(Typo.sans(11))
                    .foregroundStyle(Color.lInk3)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(curDisplay.map { Fmt.currency($0, target) } ?? "—")
                        .font(Typo.mono(13, weight: .semibold))
                        .foregroundStyle(Color.lInk)
                    if let d = diff {
                        Text(Fmt.signedDelta(d, target))
                            .font(Typo.mono(11))
                            .foregroundStyle(Palette.deltaColor(d))
                    } else {
                        Text("—")
                            .font(Typo.mono(11))
                            .foregroundStyle(Color.lInk4)
                    }
                }
                Button {
                    app.togglePinnedAccount(a.id)
                } label: {
                    Image(systemName: "star.slash")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.lInk3)
                        .padding(.leading, 8)
                }
                .buttonStyle(.plain)
                .pointerStyle(.link)
                .help("Unpin from watchlist")
            }
            .padding(.horizontal, 18).padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .pointerStyle(.link)
    }

    private var receivablesPanel: some View {
        let snap = activeSnapshot
        let target = app.displayCurrency
        let rows: [ReceivableValue] = snap.map { s in
            s.receivableValues.sorted { lhs, rhs in
                (lhs.receivable?.name ?? "").localizedCaseInsensitiveCompare(rhs.receivable?.name ?? "") == .orderedAscending
            }
        } ?? []
        let total = snap.map { CurrencyConverter.receivableDisplaySum($0, in: target) } ?? 0
        return Panel {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("OUTSIDE NET WORTH")
                            .font(Typo.eyebrow).tracking(1.5)
                            .foregroundStyle(Color.lInk3)
                        Text("Pending receivables")
                            .font(Typo.serifNum(18))
                            .foregroundStyle(Color.lInk)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 3) {
                        Text("TOTAL · NOT IN NET WORTH")
                            .font(Typo.eyebrow).tracking(1.2)
                            .foregroundStyle(Color.lInk3)
                        Text(Fmt.currency(total, target))
                            .font(Typo.mono(15, weight: .semibold))
                            .foregroundStyle(Color.lInk)
                    }
                }
                .padding(.horizontal, 18).padding(.vertical, 14)
                .overlay(Rectangle().frame(height: 1).foregroundStyle(Color.lLine), alignment: .bottom)

                ForEach(Array(rows.enumerated()), id: \.element.id) { idx, rv in
                    receivableRow(rv, idx: idx, target: target)
                    if idx < rows.count - 1 {
                        Divider().overlay(Color.lLine)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func receivableRow(_ rv: ReceivableValue, idx: Int, target: Currency) -> some View {
        let r = rv.receivable
        let ccy = r?.nativeCurrency ?? .USD
        let display = CurrencyConverter.displayValue(for: rv, in: target)
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(r?.name ?? "—")
                    .font(Typo.sans(13, weight: .medium))
                    .foregroundStyle(Color.lInk)
                if let debtor = r?.debtor, !debtor.isEmpty {
                    Text(debtor)
                        .font(Typo.sans(11))
                        .foregroundStyle(Color.lInk3)
                }
            }
            Spacer()
            Text(Fmt.currency(rv.nativeValue, ccy))
                .font(Typo.mono(12))
                .foregroundStyle(Color.lInk2)
                .frame(width: 130, alignment: .trailing)
            Text(Fmt.currency(display, target))
                .font(Typo.mono(13, weight: .semibold))
                .foregroundStyle(Color.lInk)
                .frame(width: 130, alignment: .trailing)
        }
        .padding(.horizontal, 18).padding(.vertical, 11)
        .background(idx.isMultiple(of: 2) ? Color.clear : Color.lSunken.opacity(0.5))
    }
}

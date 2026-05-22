import SwiftUI
import Charts

struct DashboardExportView: View {
    let snapshots: [Snapshot]
    let displayCurrency: Currency
    let activeSnapshotID: UUID?
    let appIconAssetName: String
    let generatedAt: Date

    private let sortedAsc: [Snapshot]
    private let active: Snapshot?
    private let prev: Snapshot?
    private let yearAgo: Snapshot?
    private let curTotal: Double
    private let prevTotal: Double
    private let yaTotal: Double
    private let trajectory: [Trajectory]
    private let personItems: [Item]
    private let countryItems: [Item]
    private let typeItems: [Item]
    private let movers: [Mover]
    private let liquid: Double
    private let invested: Double
    private let retirement: Double
    private let insurance: Double
    private let debt: Double
    private let prevLiquid: Double
    private let prevInvested: Double
    private let prevRetirement: Double
    private let prevInsurance: Double
    private let prevDebt: Double

    init(snapshots: [Snapshot], displayCurrency: Currency, activeSnapshotID: UUID?, appIconAssetName: String = "IconClassic", generatedAt: Date = Date()) {
        self.snapshots = snapshots
        self.displayCurrency = displayCurrency
        self.activeSnapshotID = activeSnapshotID
        self.appIconAssetName = appIconAssetName
        self.generatedAt = generatedAt

        let sorted = snapshots.sorted { $0.date < $1.date }
        self.sortedAsc = sorted

        let active: Snapshot? = {
            if let id = activeSnapshotID, let s = snapshots.first(where: { $0.id == id }) { return s }
            return sorted.last
        }()
        self.active = active

        let idx = active.flatMap { a in sorted.firstIndex { $0.id == a.id } }
        self.prev = (idx.map { $0 > 0 ? sorted[$0 - 1] : nil }) ?? nil
        self.yearAgo = {
            guard let a = active else { return nil }
            let oneYearAgo = Calendar.current.date(
                byAdding: .year, value: -1, to: a.date)!
            return sorted
                .filter { $0.id != a.id && $0.date <= a.date }
                .min(by: { abs($0.date.timeIntervalSince(oneYearAgo))
                         < abs($1.date.timeIntervalSince(oneYearAgo)) })
                .flatMap { s -> Snapshot? in
                    abs(s.date.timeIntervalSince(oneYearAgo)) < 90 * 86400 ? s : nil
                }
        }()

        let target = displayCurrency
        func valueIn(_ v: AssetValue, rate: Double) -> Double {
            guard let acc = v.account else { return 0 }
            return CurrencyConverter.convert(
                nativeValue: v.nativeValue,
                from: acc.nativeCurrency,
                to: target,
                usdToInrRate: rate
            )
        }
        func netValueIn(_ v: AssetValue, rate: Double) -> Double {
            guard let acc = v.account else { return 0 }
            let raw = CurrencyConverter.convert(
                nativeValue: v.nativeValue,
                from: acc.nativeCurrency,
                to: target,
                usdToInrRate: rate
            )
            let isDebt = acc.assetType?.category == .debt
            return isDebt ? -abs(raw) : raw
        }
        func total(_ s: Snapshot?) -> Double {
            guard let s else { return 0 }
            let rate = s.usdToInrRate
            return s.values.reduce(0) { $0 + netValueIn($1, rate: rate) }
        }
        func sumCats(_ s: Snapshot?, _ cats: [AssetCategory]) -> Double {
            guard let s else { return 0 }
            let rate = s.usdToInrRate
            return s.values
                .filter { v in cats.contains(where: { $0 == v.account?.assetType?.category }) }
                .reduce(0.0) { $0 + valueIn($1, rate: rate) }
        }

        self.curTotal = total(active)
        self.prevTotal = total(self.prev)
        self.yaTotal = total(self.yearAgo)
        self.liquid = sumCats(active, [.cash])
        self.invested = sumCats(active, [.investment, .crypto])
        self.retirement = sumCats(active, [.retirement])
        self.insurance = sumCats(active, [.insurance])
        self.debt = sumCats(active, [.debt])
        self.prevLiquid = sumCats(self.prev, [.cash])
        self.prevInvested = sumCats(self.prev, [.investment, .crypto])
        self.prevRetirement = sumCats(self.prev, [.retirement])
        self.prevInsurance = sumCats(self.prev, [.insurance])
        self.prevDebt = sumCats(self.prev, [.debt])

        self.trajectory = sorted.map { Trajectory(date: $0.date, val: total($0)) }

        // person/country/type
        var personBuckets: [String: (Double, Color)] = [:]
        var countryBuckets: [String: (Double, Color, String)] = [:]
        var typeBuckets: [AssetCategory: Double] = [:]
        let activeRate = active?.usdToInrRate ?? 0
        for v in active?.values ?? [] {
            guard let acc = v.account else { continue }
            let amt = netValueIn(v, rate: activeRate)
            if let p = acc.person {
                let col = Color.fromHex(p.colorHex) ?? Palette.fallback(for: p.name)
                personBuckets[p.name, default: (0, col)].0 += amt
            }
            if let c = acc.country {
                let key = "\(c.flag) \(c.name)"
                let col = Color.fromHex(c.colorHex) ?? Palette.fallback(for: c.code)
                countryBuckets[key, default: (0, col, c.name)].0 += amt
            }
            if let t = acc.assetType {
                typeBuckets[t.category, default: 0] += amt
            }
        }
        self.personItems = personBuckets
            .map { Item(label: $0.key, value: $0.value.0, color: $0.value.1) }
            .sorted { $0.value > $1.value }
        self.countryItems = countryBuckets
            .map { Item(label: $0.key, value: $0.value.0, color: $0.value.1) }
            .sorted { $0.value > $1.value }
        self.typeItems = typeBuckets
            .map { Item(label: $0.key.rawValue, value: $0.value, color: Palette.color(for: $0.key)) }
            .sorted { abs($0.value) > abs($1.value) }

        // movers
        var moverList: [Mover] = []
        if let cur = active, let p = self.prev {
            let curRate = cur.usdToInrRate
            let prevRate = p.usdToInrRate
            var prevMap: [UUID: Double] = [:]
            for v in p.values where v.account != nil {
                prevMap[v.account!.id] = netValueIn(v, rate: prevRate)
            }
            for v in cur.values {
                guard let acc = v.account else { continue }
                let now = netValueIn(v, rate: curRate)
                let before = prevMap[acc.id] ?? 0
                let diff = now - before
                let pct = before == 0 ? 0 : diff / abs(before) * 100
                moverList.append(Mover(
                    name: acc.name,
                    person: acc.person?.name ?? "—",
                    country: acc.country.map { "\($0.flag) \($0.code)" } ?? "—",
                    type: acc.assetType?.name ?? "—",
                    value: now,
                    pct: pct,
                    up: diff >= 0
                ))
            }
        }
        self.movers = moverList.sorted { abs($0.pct) > abs($1.pct) }.prefix(8).map { $0 }
    }

    struct Item: Identifiable {
        let id = UUID()
        let label: String
        let value: Double
        let color: Color
    }

    struct Mover: Identifiable {
        let id = UUID()
        let name: String
        let person: String
        let country: String
        let type: String
        let value: Double
        let pct: Double
        let up: Bool
    }

    struct Trajectory: Identifiable {
        let id = UUID()
        let date: Date
        let val: Double
    }

    private func pct(_ cur: Double, _ prev: Double) -> Double {
        guard prev != 0 else { return 0 }
        return (cur - prev) / abs(prev) * 100
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            reportHeader
            hero
            kpiGrid
            trajectoryPanel
            compositionPanels
            moversPanel
            footer
        }
        .padding(32)
        .frame(width: 1000, alignment: .topLeading)
        .background(Color.lBg)
    }

    private var reportHeader: some View {
        HStack(alignment: .firstTextBaseline) {
            HStack(spacing: 10) {
                Image(appIconAssetName)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 34, height: 34)
                    .clipShape(RoundedRectangle(cornerRadius: 7))
                    .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color.lLine, lineWidth: 0.5))
                VStack(alignment: .leading, spacing: 1) {
                    Text("Quiet Finance")
                        .font(Typo.serifNum(18))
                        .foregroundStyle(Color.lInk)
                    Text("NET WORTH REPORT")
                        .font(Typo.eyebrow).tracking(1.5)
                        .foregroundStyle(Color.lInk3)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 1) {
                Text("AS OF \(active?.label.uppercased() ?? "—")")
                    .font(Typo.eyebrow).tracking(1.3)
                    .foregroundStyle(Color.lInk3)
                Text("Generated \(Fmt.date(generatedAt))")
                    .font(Typo.mono(10))
                    .foregroundStyle(Color.lInk3)
            }
        }
        .padding(.bottom, 6)
        .overlay(Rectangle().frame(height: 1).foregroundStyle(Color.lLine), alignment: .bottom)
    }

    private var hero: some View {
        HStack(alignment: .top, spacing: 40) {
            VStack(alignment: .leading, spacing: 6) {
                Text("NET WORTH · \(active?.label ?? "—")")
                    .font(Typo.eyebrow).tracking(1.5)
                    .foregroundStyle(Color.lInk3)
                HStack(alignment: .top, spacing: 4) {
                    Text(displayCurrency.symbol)
                        .font(Typo.serifNum(44))
                        .foregroundStyle(Color.lInk3)
                        .padding(.top, 18)
                    Text(Fmt.groupedInt(curTotal, locale: displayCurrency == .INR ? .init(identifier: "en_IN") : .init(identifier: "en_US")))
                        .font(Typo.serifNum(80))
                        .foregroundStyle(Color.lInk)
                        .monospacedDigit()
                        .tracking(-1.5)
                }
                HStack(spacing: 10) {
                    if prev != nil {
                        HeroDelta(pct: pct(curTotal, prevTotal),
                                  suffix: "· \(Fmt.compact(curTotal - prevTotal, displayCurrency)) QoQ")
                    }
                    if yearAgo != nil {
                        HeroDelta(pct: pct(curTotal, yaTotal), suffix: "YoY")
                    }
                }
                if let s = active {
                    Text(footnote(for: s))
                        .font(Typo.serifItalic(12.5))
                        .foregroundStyle(Color.lInk2)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: 560, alignment: .leading)
                        .padding(.top, 10)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(24)
        .background(Color.lPanel)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.lLine, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func footnote(for s: Snapshot) -> String {
        let accCount = Set(s.values.compactMap { $0.account?.id }).count
        let countries = Set(s.values.compactMap { $0.account?.country?.name }).count
        let people = Set(s.values.compactMap { $0.account?.person?.name })
        let peopleStr = people.sorted().joined(separator: " & ")
        return "Across \(accCount) accounts in \(countries) \(countries == 1 ? "country" : "countries"), held by \(peopleStr). Exchange rate ₹\(String(format: "%.2f", s.usdToInrRate)) / $1."
    }

    private var kpiGrid: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4),
            spacing: 12
        ) {
            KPICard(label: "Liquid", value: Fmt.compact(liquid, displayCurrency),
                    sub: "Cash + deposits",
                    deltaText: deltaText(liquid, prevLiquid),
                    deltaUp: liquid >= prevLiquid)
            KPICard(label: "Invested", value: Fmt.compact(invested, displayCurrency),
                    sub: "Equity + crypto",
                    deltaText: deltaText(invested, prevInvested),
                    deltaUp: invested >= prevInvested)
            KPICard(label: "Retirement",
                    value: Fmt.compact(retirement + insurance, displayCurrency),
                    sub: "401k · IRA · NPS · HSA",
                    deltaText: deltaText(retirement + insurance, prevRetirement + prevInsurance),
                    deltaUp: (retirement + insurance) >= (prevRetirement + prevInsurance))
            KPICard(label: "Debt", value: Fmt.compact(abs(debt), displayCurrency),
                    sub: "Loans · credit",
                    valueColor: .lLoss,
                    deltaText: deltaText(debt, prevDebt),
                    deltaUp: debt >= prevDebt)
        }
    }

    private func deltaText(_ cur: Double, _ prev: Double) -> String? {
        guard prev != 0 else { return nil }
        let d = (cur - prev) / abs(prev) * 100
        return "\(d >= 0 ? "+" : "−")\(String(format: "%.1f", abs(d)))% QoQ"
    }

    private var trajectoryPanel: some View {
        Panel {
            VStack(alignment: .leading, spacing: 0) {
                PanelHead(title: "Net worth trajectory",
                          meta: "\(trajectory.count) snapshots")
                if trajectory.count >= 2 {
                    Chart(trajectory) { p in
                        AreaMark(x: .value("Date", p.date), y: .value("Val", p.val))
                            .interpolationMethod(.catmullRom)
                            .foregroundStyle(.linearGradient(
                                colors: [Color.lInk.opacity(0.18), Color.lInk.opacity(0.02)],
                                startPoint: .top, endPoint: .bottom
                            ))
                        LineMark(x: .value("Date", p.date), y: .value("Val", p.val))
                            .interpolationMethod(.catmullRom)
                            .foregroundStyle(Color.lInk)
                            .lineStyle(StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
                        PointMark(x: .value("Date", p.date), y: .value("Val", p.val))
                            .foregroundStyle(Color.lInk)
                            .symbolSize(24)
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading) { _ in
                            AxisGridLine().foregroundStyle(Color.lLine)
                            AxisValueLabel().font(Typo.mono(10)).foregroundStyle(Color.lInk3)
                        }
                    }
                    .chartXAxis {
                        AxisMarks { _ in
                            AxisValueLabel().font(Typo.mono(10)).foregroundStyle(Color.lInk3)
                        }
                    }
                    .frame(height: 220)
                    .padding(18)
                } else {
                    Text("Not enough history to chart.")
                        .font(Typo.serifItalic(13))
                        .foregroundStyle(Color.lInk3)
                        .padding(18)
                }
            }
        }
    }

    private var compositionPanels: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHead(title: "Composition", emphasis: "— where it lives",
                        rightLabel: (active?.label ?? "—") + " · " + displayCurrency.rawValue)
            HStack(alignment: .top, spacing: 12) {
                compPanel(title: "By person", items: personItems, showBar: false)
                compPanel(title: "By country", items: countryItems, showBar: false)
                compPanel(title: "By asset type", items: typeItems, showBar: true)
            }
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func compPanel(title: String, items: [Item], showBar: Bool) -> some View {
        Panel {
            VStack(spacing: 0) {
                PanelHead(title: title, meta: "\(items.count)")
                VStack(spacing: 0) {
                    ForEach(items) { i in
                        AllocRow(
                            color: i.color,
                            label: i.label,
                            value: Fmt.compact(abs(i.value), displayCurrency),
                            pct: curTotal == 0 ? 0 : abs(i.value) / curTotal * 100,
                            showBar: showBar,
                            valueColor: i.value < 0 ? .lLoss : .lInk
                        )
                        Divider().overlay(Color.lLine)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }

    private var moversPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHead(title: "Biggest movers", emphasis: "— this quarter",
                        rightLabel: prev.map { "\($0.label) → \(active?.label ?? "—")" })
            if movers.isEmpty {
                Panel {
                    Text("No previous snapshot for comparison.")
                        .font(Typo.serifItalic(13))
                        .foregroundStyle(Color.lInk3)
                        .padding(18)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                Panel {
                    VStack(spacing: 0) {
                        HStack {
                            Text("Account").frame(maxWidth: .infinity, alignment: .leading)
                            Text("Owner").frame(width: 140, alignment: .leading)
                            Text("Country").frame(width: 80, alignment: .leading)
                            Text("Type").frame(width: 120, alignment: .leading)
                            Text("Value").frame(width: 120, alignment: .trailing)
                            Text("QoQ").frame(width: 80, alignment: .trailing)
                        }
                        .font(Typo.eyebrow).tracking(1.2)
                        .foregroundStyle(Color.lInk3)
                        .padding(.horizontal, 18).padding(.vertical, 10)
                        .background(Color.lSunken)
                        .overlay(Rectangle().frame(height: 1).foregroundStyle(Color.lLine), alignment: .bottom)

                        ForEach(Array(movers.enumerated()), id: \.element.id) { i, m in
                            HStack {
                                Text(m.name).font(Typo.sans(12.5, weight: .medium))
                                    .foregroundStyle(Color.lInk)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Text(m.person).font(Typo.sans(12))
                                    .foregroundStyle(Color.lInk2)
                                    .frame(width: 140, alignment: .leading)
                                Text(m.country).font(Typo.sans(12))
                                    .foregroundStyle(Color.lInk2)
                                    .frame(width: 80, alignment: .leading)
                                Text(m.type).font(Typo.sans(12))
                                    .foregroundStyle(Color.lInk2)
                                    .frame(width: 120, alignment: .leading)
                                Text(Fmt.compact(m.value, displayCurrency))
                                    .font(Typo.mono(12, weight: .medium))
                                    .foregroundStyle(Color.lInk)
                                    .frame(width: 120, alignment: .trailing)
                                Text("\(m.up ? "+" : "−")\(String(format: "%.1f", abs(m.pct)))%")
                                    .font(Typo.mono(12, weight: .medium))
                                    .foregroundStyle(m.up ? Color.lGain : Color.lLoss)
                                    .frame(width: 80, alignment: .trailing)
                            }
                            .padding(.horizontal, 18)
                            .padding(.vertical, 10)
                            .background(i.isMultiple(of: 2) ? Color.clear : Color.lSunken.opacity(0.5))
                        }
                    }
                }
            }
        }
    }

    private var footer: some View {
        HStack {
            Text("Quiet Finance · offline wealth tracker")
                .font(Typo.eyebrow).tracking(1.2)
                .foregroundStyle(Color.lInk3)
            Spacer()
            Text("Currency: \(displayCurrency.rawValue)")
                .font(Typo.mono(10))
                .foregroundStyle(Color.lInk3)
        }
        .padding(.top, 8)
        .overlay(Rectangle().frame(height: 1).foregroundStyle(Color.lLine), alignment: .top)
    }
}

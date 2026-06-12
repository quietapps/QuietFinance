import SwiftUI

// MARK: - Dashboard value types
// Promoted out of DashboardView so extracted widget structs can share them.

struct AllocItem: Identifiable {
    let id = UUID()
    let label: String
    let value: Double
    let color: Color
    let groupKey: GroupKey
    let matchValue: String
}

struct MoverRow: Identifiable {
    let id = UUID()
    let account: Account
    let value: Double
    let pct: Double
    let up: Bool
}

struct LiabilityRow: Identifiable {
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

struct TrajectoryPoint: Identifiable {
    let id = UUID()
    let date: Date
    let val: Double
}

struct AnomalyFlag {
    let isGain: Bool
    let deltaPct: Double  // magnitude of current delta as % of previous
    let sigmas: Double    // how many σ above mean
}

/// Category subtotals for one snapshot. Filled in a single pass over values —
/// replaces fifteen separate filter+reduce sweeps.
struct CategoryTotals {
    var liquid: Double = 0
    var invested: Double = 0
    var retirement: Double = 0
    var insurance: Double = 0
    var debt: Double = 0
    static let zero = CategoryTotals()
}

/// Everything the dashboard renders, computed once per data change. Widgets
/// receive narrow slices of this bag so SwiftUI diffs per-widget.
struct DashboardStats {
    var active: Snapshot? = nil
    var prevSnap: Snapshot? = nil
    var curTotal: Double = 0
    var prevTotal: Double = 0
    var yaTotal: Double = 0
    var cur: CategoryTotals = .zero
    var prev: CategoryTotals = .zero
    var ya: CategoryTotals = .zero
    var personItems: [AllocItem] = []
    var countryItems: [AllocItem] = []
    var typeItems: [AllocItem] = []
    var movers: [MoverRow] = []
    var trajectory: [TrajectoryPoint] = []
    var fitHistory: [(Date, Double)] = []
    var targets: [AssetCategory: Double] = [:]
    var liabilities: [LiabilityRow] = []
    var anomaly: AnomalyFlag? = nil
    var liquidity: LiquidityAnalysis.Result? = nil
    var exposure: [CurrencyExposure.Slice] = []
    var debtPayoff: DebtPayoff.Result? = nil
    var netChange: NetChangeAnalysis.Result? = nil
    var hasPrev: Bool = false
    var hasYearAgo: Bool = false
    static let empty = DashboardStats()
}

// MARK: - Pure compute layer

enum DashboardCompute {

    /// Single entry point: resolves active/previous/year-ago snapshots, sorts
    /// once, and fills the whole stats bag.
    static func stats(snapshots: [Snapshot],
                      activeID: UUID?,
                      target: Currency,
                      includeIlliquid: Bool) -> DashboardStats {
        var out = DashboardStats()
        guard !snapshots.isEmpty else { return out }

        let asc = snapshots.sorted { $0.date < $1.date }
        let active: Snapshot? = {
            if let id = activeID, let s = asc.first(where: { $0.id == id }) { return s }
            return asc.last
        }()
        let activeIdx = active.flatMap { a in asc.firstIndex { $0.id == a.id } }
        let prev: Snapshot? = activeIdx.flatMap { $0 > 0 ? asc[$0 - 1] : nil }
        let ya = yearAgoSnapshot(in: asc, active: active)

        out.active = active
        out.prevSnap = prev
        out.hasPrev = prev != nil
        out.hasYearAgo = ya != nil

        out.curTotal = total(active, target: target, includeIlliquid: includeIlliquid)
        out.prevTotal = total(prev, target: target, includeIlliquid: includeIlliquid)
        out.yaTotal = total(ya, target: target, includeIlliquid: includeIlliquid)

        out.cur = categoryTotals(active, target: target)
        out.prev = categoryTotals(prev, target: target)
        out.ya = categoryTotals(ya, target: target)

        out.personItems = personItems(active, target: target, includeIlliquid: includeIlliquid)
        out.countryItems = countryItems(active, target: target, includeIlliquid: includeIlliquid)
        out.typeItems = typeItems(active, target: target, includeIlliquid: includeIlliquid)

        out.trajectory = asc.map {
            TrajectoryPoint(date: $0.date, val: total($0, target: target, includeIlliquid: includeIlliquid))
        }
        out.fitHistory = zip(asc, out.trajectory).map { ($0.date, $1.val) }
        out.movers = movers(cur: active, prev: prev, target: target, includeIlliquid: includeIlliquid)
        out.targets = TargetAllocationStore.all()
        out.liabilities = liabilities(cur: active, prev: prev, all: asc, target: target)
        out.anomaly = anomaly(trajectoryValues: out.trajectory.map(\.val))
        out.liquidity = LiquidityAnalysis.compute(snapshots: snapshots,
                                                  displayCurrency: target,
                                                  includeIlliquid: includeIlliquid)
        out.exposure = CurrencyExposure.compute(snapshot: active,
                                                displayCurrency: target,
                                                includeIlliquid: includeIlliquid)
        out.debtPayoff = DebtPayoff.compute(snapshots: snapshots, displayCurrency: target)
        out.netChange = NetChangeAnalysis.compute(snapshots: snapshots,
                                                  displayCurrency: target,
                                                  includeIlliquid: includeIlliquid)
        return out
    }

    static func yearAgoSnapshot(in asc: [Snapshot], active: Snapshot?) -> Snapshot? {
        guard let active,
              let oneYearAgo = Calendar.current.date(byAdding: .year, value: -1, to: active.date)
        else { return nil }
        return asc
            .filter { $0.id != active.id && $0.date <= active.date }
            .min(by: { abs($0.date.timeIntervalSince(oneYearAgo))
                     < abs($1.date.timeIntervalSince(oneYearAgo)) })
            .flatMap { s -> Snapshot? in
                abs(s.date.timeIntervalSince(oneYearAgo)) < 90 * 86400 ? s : nil
            }
    }

    static func total(_ s: Snapshot?, target: Currency, includeIlliquid: Bool) -> Double {
        guard let s else { return 0 }
        return s.totalsValues.reduce(0) {
            $0 + CurrencyConverter.netDisplayValue(for: $1, in: target, includeIlliquid: includeIlliquid)
        }
    }

    /// One pass over a snapshot's values producing every KPI bucket.
    /// Semantics match the old per-category sums exactly: gross display value
    /// (no debt sign flip, no illiquid filter), real estate excluded.
    static func categoryTotals(_ s: Snapshot?, target: Currency) -> CategoryTotals {
        guard let s else { return .zero }
        var t = CategoryTotals.zero
        for v in s.totalsValues {
            guard let cat = v.account?.assetType?.category else { continue }
            let amt = CurrencyConverter.displayValue(for: v, in: target)
            switch cat {
            case .cash:                 t.liquid += amt
            case .investment, .crypto:  t.invested += amt
            case .retirement:           t.retirement += amt
            case .insurance:            t.insurance += amt
            case .debt:                 t.debt += amt
            case .realEstate:           break
            }
        }
        return t
    }

    static func personItems(_ s: Snapshot?, target: Currency, includeIlliquid: Bool) -> [AllocItem] {
        guard let s else { return [] }
        var buckets: [String: (Double, Color)] = [:]
        for v in s.totalsValues {
            guard let acc = v.account, let p = acc.person else { continue }
            let amt = CurrencyConverter.netDisplayValue(for: v, in: target, includeIlliquid: includeIlliquid)
            let col = Color.fromHex(p.colorHex) ?? Palette.fallback(for: p.name)
            buckets[p.name, default: (0, col)].0 += amt
        }
        return buckets.map {
            AllocItem(label: $0.key, value: $0.value.0, color: $0.value.1,
                      groupKey: .person, matchValue: $0.key)
        }
        .sorted { $0.value > $1.value }
    }

    static func countryItems(_ s: Snapshot?, target: Currency, includeIlliquid: Bool) -> [AllocItem] {
        guard let s else { return [] }
        var buckets: [String: (Double, Color, String)] = [:]
        for v in s.totalsValues {
            guard let acc = v.account, let c = acc.country else { continue }
            let amt = CurrencyConverter.netDisplayValue(for: v, in: target, includeIlliquid: includeIlliquid)
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

    static func typeItems(_ s: Snapshot?, target: Currency, includeIlliquid: Bool) -> [AllocItem] {
        guard let s else { return [] }
        var buckets: [AssetCategory: Double] = [:]
        for v in s.totalsValues {
            guard let acc = v.account, let t = acc.assetType else { continue }
            if !includeIlliquid && t.category.isIlliquid { continue }
            buckets[t.category, default: 0] += CurrencyConverter.netDisplayValue(for: v, in: target)
        }
        return buckets.map {
            AllocItem(label: $0.key.rawValue, value: $0.value, color: Palette.color(for: $0.key),
                      groupKey: .category, matchValue: $0.key.rawValue)
        }
    }

    static func movers(cur: Snapshot?, prev: Snapshot?, target: Currency, includeIlliquid: Bool) -> [MoverRow] {
        guard let cur, let prev else { return [] }
        var prevMap: [UUID: Double] = [:]
        for v in prev.totalsValues {
            guard let acc = v.account else { continue }
            if !includeIlliquid && CurrencyConverter.isIlliquid(v) { continue }
            prevMap[acc.id] = CurrencyConverter.netDisplayValue(for: v, in: target)
        }
        var list: [MoverRow] = []
        for v in cur.totalsValues {
            guard let acc = v.account else { continue }
            if !includeIlliquid && CurrencyConverter.isIlliquid(v) { continue }
            let now = CurrencyConverter.netDisplayValue(for: v, in: target)
            let before = prevMap[acc.id] ?? 0
            let diff = now - before
            let p = before == 0 ? 0 : diff / abs(before) * 100
            list.append(MoverRow(account: acc, value: now, pct: p, up: diff >= 0))
        }
        return list.sorted { abs($0.pct) > abs($1.pct) }.prefix(6).map { $0 }
    }

    static func liabilities(cur: Snapshot?, prev: Snapshot?, all: [Snapshot], target: Currency) -> [LiabilityRow] {
        guard let cur else { return [] }
        let debts = cur.totalsValues.filter { $0.account?.assetType?.category == .debt }
        guard !debts.isEmpty else { return [] }

        var peak: [UUID: Double] = [:]
        for s in all {
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

    /// 2σ outlier detection over consecutive % deltas. Operates on the
    /// already-computed trajectory so it costs nothing extra.
    static func anomaly(trajectoryValues: [Double]) -> AnomalyFlag? {
        guard trajectoryValues.count >= 3 else { return nil }
        var deltas: [Double] = []
        for i in 1..<trajectoryValues.count {
            let prev = trajectoryValues[i - 1]
            let cur = trajectoryValues[i]
            guard prev != 0 else { continue }
            deltas.append((cur - prev) / abs(prev))
        }
        guard deltas.count >= 2 else { return nil }
        let mean = deltas.reduce(0, +) / Double(deltas.count)
        let variance = deltas.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Double(deltas.count)
        let stdev = variance.squareRoot()
        // Epsilon, not just > 0: with near-identical deltas, rounding noise can
        // leave a microscopic stdev that inflates sigma into a false anomaly.
        guard stdev > 1e-6, let lastDelta = deltas.last else { return nil }
        let sigmas = abs(lastDelta - mean) / stdev
        guard sigmas >= 2.0 else { return nil }
        return AnomalyFlag(isGain: lastDelta > mean, deltaPct: abs(lastDelta) * 100, sigmas: sigmas)
    }

    /// The one-sentence plain-language digest shown under the hero.
    static func digest(stats: DashboardStats, goal: Double?, currency: Currency) -> String {
        guard stats.curTotal != 0 || stats.prevTotal != 0 else { return "" }
        let delta = stats.curTotal - stats.prevTotal
        let pct = stats.prevTotal == 0 ? 0 : delta / abs(stats.prevTotal)
        let direction = delta >= 0 ? "grew" : "shrank"
        let absDelta = Fmt.compact(abs(delta), currency)
        let pctStr = String(format: "%.1f%%", abs(pct) * 100)

        let gainers = stats.movers.filter { $0.up }.prefix(2).map { $0.account.name }
        let losers  = stats.movers.filter { !$0.up }.prefix(2).map { $0.account.name }

        var parts: [String] = []
        parts.append("Net worth \(direction) \(absDelta) (\(pctStr)) since the previous snapshot.")
        if !gainers.isEmpty {
            parts.append("Lifted by \(gainers.joined(separator: " and ")).")
        }
        if !losers.isEmpty {
            parts.append("Dragged by \(losers.joined(separator: " and ")).")
        }
        if let goal, goal > 0 {
            let remain = goal - stats.curTotal
            if remain > 0 {
                parts.append("\(Fmt.compact(remain, currency)) to reach goal.")
            } else {
                parts.append("Goal cleared by \(Fmt.compact(-remain, currency)).")
            }
        }
        return parts.joined(separator: " ")
    }
}

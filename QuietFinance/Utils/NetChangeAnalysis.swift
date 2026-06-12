import Foundation

/// Per-month net-worth change from consecutive snapshot deltas. Snapshots
/// can't separate savings from market movement, so all copy must present this
/// as combined net change — never as a "savings rate".
enum NetChangeAnalysis {
    struct Result {
        let monthlyAvg: Double               // trailing-12mo per-month change
        let quarterlyAvg: Double             // monthlyAvg × 3
        let deltas: [(Date, Double)]         // per-transition raw change
        let transitions: Int
    }

    static func compute(snapshots: [Snapshot],
                        displayCurrency: Currency,
                        includeIlliquid: Bool) -> Result? {
        let asc = snapshots.sorted { $0.date < $1.date }
        guard asc.count >= 2 else { return nil }

        func total(_ s: Snapshot) -> Double {
            s.totalsValues.reduce(0) {
                $0 + CurrencyConverter.netDisplayValue(for: $1, in: displayCurrency,
                                                       includeIlliquid: includeIlliquid)
            }
        }

        var deltas: [(Date, Double)] = []
        var trailingChange = 0.0
        var trailingMonths = 0.0
        let cutoff = Calendar.current.date(byAdding: .year, value: -1, to: .now) ?? .distantPast

        for i in 1..<asc.count {
            let a = asc[i - 1], b = asc[i]
            let change = total(b) - total(a)
            deltas.append((b.date, change))
            let days = b.date.timeIntervalSince(a.date) / 86_400
            guard days > 0 else { continue }
            if b.date >= cutoff {
                trailingChange += change
                trailingMonths += days / 30.4375
            }
        }
        guard !deltas.isEmpty else { return nil }

        let monthly = trailingMonths > 0 ? trailingChange / trailingMonths : 0
        return Result(monthlyAvg: monthly,
                      quarterlyAvg: monthly * 3,
                      deltas: deltas,
                      transitions: deltas.count)
    }
}

import Foundation

/// Cash runway from snapshot deltas. Burn rate is the average monthly drop
/// in liquid (cash) total across the most recent N snapshots. Runway =
/// liquidNow / burnPerMonth. Positive cash flow means no runway concern,
/// represented by `monthsRunway = nil`.
enum LiquidityAnalysis {
    struct Result {
        let liquidNow: Double           // current cash subset, display ccy
        let monthlyChange: Double       // signed avg per-month change (positive = adding cash)
        let monthlyBurn: Double         // max(0, -monthlyChange)
        let monthsRunway: Double?       // nil if not burning
        let lookbackPairs: Int          // snapshot transitions used
    }

    /// Compute over up to last 6 snapshots in chronological order.
    static func compute(snapshots: [Snapshot],
                        displayCurrency: Currency,
                        includeIlliquid: Bool) -> Result? {
        let asc = snapshots.sorted { $0.date < $1.date }
        guard asc.count >= 1 else { return nil }

        func cashTotal(_ s: Snapshot) -> Double {
            s.totalsValues.reduce(0.0) { acc, v in
                guard let cat = v.account?.assetType?.category, cat == .cash else { return acc }
                return acc + CurrencyConverter.netDisplayValue(for: v,
                                                               in: displayCurrency,
                                                               includeIlliquid: includeIlliquid)
            }
        }

        let liquidNow = cashTotal(asc.last!)
        guard asc.count >= 2 else {
            return Result(liquidNow: liquidNow,
                          monthlyChange: 0,
                          monthlyBurn: 0,
                          monthsRunway: nil,
                          lookbackPairs: 0)
        }

        // Use at most last 6 snapshots → up to 5 transitions.
        let window = Array(asc.suffix(6))
        var totalChange = 0.0
        var totalMonths = 0.0
        for i in 1..<window.count {
            let a = window[i - 1]
            let b = window[i]
            let days = b.date.timeIntervalSince(a.date) / 86_400
            guard days > 0 else { continue }
            let months = days / 30.4375
            totalChange += cashTotal(b) - cashTotal(a)
            totalMonths += months
        }

        let monthlyChange = totalMonths > 0 ? totalChange / totalMonths : 0
        let burn = max(0, -monthlyChange)
        let runway: Double? = burn > 0 ? liquidNow / burn : nil
        return Result(liquidNow: liquidNow,
                      monthlyChange: monthlyChange,
                      monthlyBurn: burn,
                      monthsRunway: runway,
                      lookbackPairs: window.count - 1)
    }
}

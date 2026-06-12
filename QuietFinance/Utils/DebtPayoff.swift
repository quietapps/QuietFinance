import Foundation

/// Linear-trend projection of total debt to its zero crossing, plus the
/// "pay extra per month" what-if.
enum DebtPayoff {
    struct Result {
        let currentDebt: Double          // magnitude, display currency
        let monthlyPaydown: Double       // positive = shrinking
        let payoffDate: Date?            // nil when debt isn't shrinking
        let series: [(Date, Double)]     // debt magnitude per snapshot
    }

    /// Debt magnitude per snapshot (display currency), oldest first.
    static func debtSeries(snapshots: [Snapshot], displayCurrency: Currency) -> [(Date, Double)] {
        snapshots
            .sorted { $0.date < $1.date }
            .map { s in
                let debt = s.totalsValues
                    .filter { $0.account?.assetType?.category == .debt }
                    .reduce(0.0) { $0 + abs(CurrencyConverter.displayValue(for: $1, in: displayCurrency)) }
                return (s.date, debt)
            }
    }

    static func compute(snapshots: [Snapshot], displayCurrency: Currency) -> Result? {
        let series = debtSeries(snapshots: snapshots, displayCurrency: displayCurrency)
        guard let current = series.last?.1, current > 0 else { return nil }
        guard series.count >= 2,
              let fit = Forecast.compute(history: series, method: .linear,
                                         horizonMonths: 0, goal: nil),
              let slope = fit.slopePerDay
        else {
            return Result(currentDebt: current, monthlyPaydown: 0, payoffDate: nil, series: series)
        }

        let monthlyPaydown = -slope * 30.4375   // positive when debt shrinking
        let payoff: Date? = monthlyPaydown > 0
            ? payoffDate(balance: current, monthlyPaydown: monthlyPaydown)
            : nil
        return Result(currentDebt: current,
                      monthlyPaydown: monthlyPaydown,
                      payoffDate: payoff,
                      series: series)
    }

    /// Zero-crossing date at a given paydown rate. Used for both the trend
    /// estimate and the extra-payment slider.
    static func payoffDate(balance: Double, monthlyPaydown: Double) -> Date? {
        guard balance > 0, monthlyPaydown > 0 else { return nil }
        let months = balance / monthlyPaydown
        guard months.isFinite, months < 1200 else { return nil }  // >100y → effectively never
        return Calendar.current.date(byAdding: .day,
                                     value: Int(months * 30.4375),
                                     to: .now)
    }
}

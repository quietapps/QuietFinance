import Foundation

/// Restates nominal money values into the purchasing power of a single base
/// date, using a constant assumed annual inflation rate. Used by Trends and
/// Reports to show "real" net worth alongside the nominal trajectory.
///
/// Convention: the base date is the most recent point in the series, so the
/// current value is unchanged and history is scaled up into today's dollars.
/// A snapshot `years` before the base is multiplied by `(1 + rate)^years`,
/// i.e. older dollars are worth more in today's terms.
enum InflationAdjuster {
    /// Multiplier that converts a nominal value at `date` into `base`-date
    /// purchasing power. Returns 1 when the rate is non-positive or the date is
    /// at/after the base.
    static func realFactor(date: Date, base: Date, annualRatePct: Double) -> Double {
        guard annualRatePct > 0 else { return 1 }
        let years = base.timeIntervalSince(date) / (365.25 * 24 * 3600)
        guard years > 0 else { return 1 }
        let rate = annualRatePct / 100
        return pow(1 + rate, years)
    }

    /// Restate `value` (nominal, dated `date`) into `base`-date dollars.
    static func toReal(_ value: Double, date: Date, base: Date, annualRatePct: Double) -> Double {
        value * realFactor(date: date, base: base, annualRatePct: annualRatePct)
    }
}

import Foundation

/// VoiceOver summaries for charts that are otherwise purely visual.
/// Generalizes the proven pattern from TrendsView's chart summary.
enum ChartA11y {
    /// "12 snapshots from Mar 2023 to Jun 2026, start $1.2M, end $1.5M, change +25%."
    static func seriesSummary(points: [(Date, Double)], currency: Currency) -> String {
        guard let first = points.first, let last = points.last, points.count >= 2 else {
            return points.first.map { "One point: \(Fmt.compact($0.1, currency))." } ?? "No data."
        }
        let f = DateFormatter()
        f.dateFormat = "MMM yyyy"
        let changePct = first.1 != 0 ? (last.1 - first.1) / abs(first.1) * 100 : 0
        return "\(points.count) snapshots from \(f.string(from: first.0)) to \(f.string(from: last.0)). "
            + "Start \(Fmt.compact(first.1, currency)), end \(Fmt.compact(last.1, currency)), "
            + "change \(String(format: "%+.1f", changePct)) percent."
    }

    /// "Cash 42%, Investment 31%, Retirement 18%, and 2 more."
    static func allocationSummary(items: [(String, Double)], total: Double) -> String {
        guard total != 0, !items.isEmpty else { return "No allocation data." }
        let sorted = items.sorted { abs($0.1) > abs($1.1) }
        let top = sorted.prefix(3)
            .map { "\($0.0) \(String(format: "%.0f", abs($0.1) / abs(total) * 100)) percent" }
            .joined(separator: ", ")
        let rest = sorted.count - 3
        return rest > 0 ? "\(top), and \(rest) more." : "\(top)."
    }
}

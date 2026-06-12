import SwiftUI
import Combine

/// What-if sandbox: an in-memory mirror of a snapshot's values that the user
/// can tweak and compare against the baseline. Deliberately NOT a SwiftData
/// model — a persisted scenario flag would have to be filtered out of every
/// query, export, and backup forever, and one missed site silently corrupts
/// real data. In-memory cannot leak. Survives in-app navigation via
/// AppState.scenarioSession; discarded on quit.
final class ScenarioSession: ObservableObject {
    nonisolated let objectWillChange = ObservableObjectPublisher()

    struct Row: Identifiable {
        let id: UUID
        let accountID: UUID?            // nil = hypothetical item
        let name: String
        let personName: String
        let category: AssetCategory
        let currency: Currency
        let baselineNative: Double?     // nil for hypothetical
        var scenarioNative: Double
        var isHypothetical: Bool { accountID == nil }
    }

    let baselineLabel: String
    let baselineDate: Date
    /// Conversion captured at fork — the single multi-currency coupling point.
    private let convert: (Double, Currency, Currency) -> Double

    private(set) var rows: [Row] {
        willSet { objectWillChange.send() }
    }

    init(forkOf snapshot: Snapshot) {
        baselineLabel = snapshot.label
        baselineDate = snapshot.date
        convert = { value, from, to in
            CurrencyConverter.convert(nativeValue: value, from: from, to: to, in: snapshot) ?? 0
        }
        rows = snapshot.totalsValues
            .compactMap { v -> Row? in
                guard let acc = v.account else { return nil }
                return Row(id: v.id,
                           accountID: acc.id,
                           name: acc.name,
                           personName: acc.person?.name ?? "—",
                           category: acc.assetType?.category ?? .cash,
                           currency: acc.nativeCurrency,
                           baselineNative: v.nativeValue,
                           scenarioNative: v.nativeValue)
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    // MARK: mutation

    func setValue(_ value: Double, forRow id: UUID) {
        guard let idx = rows.firstIndex(where: { $0.id == id }) else { return }
        rows[idx].scenarioNative = value
    }

    func revertRow(_ id: UUID) {
        guard let idx = rows.firstIndex(where: { $0.id == id }) else { return }
        if let base = rows[idx].baselineNative {
            rows[idx].scenarioNative = base
        } else {
            rows.remove(at: idx)
        }
    }

    func addHypothetical(name: String, category: AssetCategory, currency: Currency, value: Double) {
        rows.append(Row(id: UUID(),
                        accountID: nil,
                        name: name,
                        personName: "Hypothetical",
                        category: category,
                        currency: currency,
                        baselineNative: nil,
                        scenarioNative: value))
    }

    func resetAll() {
        rows = rows.compactMap { row in
            guard let base = row.baselineNative else { return nil }
            var r = row
            r.scenarioNative = base
            return r
        }
    }

    var hasChanges: Bool {
        rows.contains { $0.isHypothetical || $0.scenarioNative != ($0.baselineNative ?? 0) }
    }

    // MARK: totals (debt sign-flip mirrors CurrencyConverter.netDisplayValue)

    private func net(_ value: Double, category: AssetCategory, currency: Currency, in display: Currency) -> Double {
        let converted = convert(value, currency, display)
        return category == .debt ? -abs(converted) : converted
    }

    func baselineTotal(in display: Currency) -> Double {
        rows.reduce(0) { acc, row in
            guard let base = row.baselineNative else { return acc }
            return acc + net(base, category: row.category, currency: row.currency, in: display)
        }
    }

    func scenarioTotal(in display: Currency) -> Double {
        rows.reduce(0) { acc, row in
            acc + net(row.scenarioNative, category: row.category, currency: row.currency, in: display)
        }
    }

    func displayDelta(forRow row: Row, in display: Currency) -> Double {
        let base = row.baselineNative.map { net($0, category: row.category, currency: row.currency, in: display) } ?? 0
        let scenario = net(row.scenarioNative, category: row.category, currency: row.currency, in: display)
        return scenario - base
    }

    /// Allocation by category, gross magnitudes (for the stacked bars).
    func allocation(scenario: Bool, in display: Currency) -> [(category: AssetCategory, value: Double)] {
        var buckets: [AssetCategory: Double] = [:]
        for row in rows {
            let value = scenario ? row.scenarioNative : (row.baselineNative ?? 0)
            guard value != 0 else { continue }
            buckets[row.category, default: 0] += abs(convert(value, row.currency, display))
        }
        return buckets.map { ($0.key, $0.value) }.sorted { $0.value > $1.value }
    }

    /// Goal ETA with the last history point replaced by the scenario total —
    /// "if the latest snapshot looked like this, when would the trend cross
    /// the goal?"
    func goalETA(history: [(Date, Double)], method: ForecastMethod,
                 goal: Double, in display: Currency, scenario: Bool) -> Date? {
        guard !history.isEmpty else { return nil }
        var h = history.sorted { $0.0 < $1.0 }
        let total = scenario ? scenarioTotal(in: display) : baselineTotal(in: display)
        h[h.count - 1] = (h[h.count - 1].0, total)
        return Forecast.compute(history: h, method: method, horizonMonths: 0, goal: goal)?.etaForGoal
    }
}

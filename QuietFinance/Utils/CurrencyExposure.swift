import Foundation

/// Net-worth share per native currency for the active snapshot. Sensitivity is
/// share-based — a k% move of currency c against the display currency changes
/// net worth by k% × share — so it needs no rate math at all.
enum CurrencyExposure {
    struct Slice: Identifiable {
        var id: String { currency.rawValue }
        let currency: Currency
        let displayValue: Double   // net, display currency
        let share: Double          // 0…1 of total magnitude
    }

    static func compute(snapshot: Snapshot?,
                        displayCurrency: Currency,
                        includeIlliquid: Bool) -> [Slice] {
        guard let snapshot else { return [] }
        var byCurrency: [Currency: Double] = [:]
        for v in snapshot.totalsValues {
            guard let acc = v.account else { continue }
            let amt = CurrencyConverter.netDisplayValue(for: v, in: displayCurrency,
                                                        includeIlliquid: includeIlliquid)
            byCurrency[acc.nativeCurrency, default: 0] += amt
        }
        let totalMagnitude = byCurrency.values.reduce(0) { $0 + abs($1) }
        guard totalMagnitude > 0 else { return [] }
        return byCurrency
            .map { Slice(currency: $0.key,
                         displayValue: $0.value,
                         share: abs($0.value) / totalMagnitude) }
            .sorted { abs($0.displayValue) > abs($1.displayValue) }
    }
}

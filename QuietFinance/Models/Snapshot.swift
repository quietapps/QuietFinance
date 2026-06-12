import Foundation
import SwiftData

@Model
final class Snapshot {
    @Attribute(.unique) var id: UUID
    var date: Date
    var label: String
    var usdToInrRate: Double
    var isLocked: Bool
    var lockedAt: Date?
    var notes: String
    var createdAt: Date
    /// Pre-computed totals filled when the snapshot is locked. Used for fast
    /// Dashboard / SnapshotListView rendering. Recomputed on lock; cleared on
    /// unlock or value edit (for active snapshot Dashboard recomputes anyway).
    var cachedTotalUSD: Double = 0
    var cachedTotalINR: Double = 0
    var cachedTotalsLiquid: Double = 0   // in USD
    var cachedTotalsInvested: Double = 0
    var cachedTotalsRetirement: Double = 0
    var cachedTotalsInsurance: Double = 0
    var cachedTotalsDebt: Double = 0
    var cacheValid: Bool = false
    /// JSON-encoded `[String: Double]` of currency code → units per 1 USD,
    /// frozen with the snapshot (lock immutability is "don't write this").
    /// Additive optional attribute for safe SwiftData auto-migration; the
    /// legacy `usdToInrRate` stays permanently mirrored from `["INR"]`.
    var ratesPerUSDData: Data? = nil

    @Relationship(deleteRule: .cascade, inverse: \AssetValue.snapshot)
    var values: [AssetValue] = []

    @Relationship(deleteRule: .cascade, inverse: \ReceivableValue.snapshot)
    var receivableValues: [ReceivableValue] = []

    init(date: Date, label: String, usdToInrRate: Double, notes: String = "") {
        self.id = UUID()
        self.date = date
        self.label = label
        self.usdToInrRate = usdToInrRate
        self.isLocked = false
        self.notes = notes
        self.createdAt = .now
        if usdToInrRate > 0 {
            self.ratesPerUSDData = try? JSONEncoder().encode(["INR": usdToInrRate])
        }
    }
}

extension Snapshot {
    /// Decoded multi-currency rate table. Setter mirrors INR into the legacy
    /// scalar so old code paths, CSV columns, and backups stay coherent.
    var ratesPerUSD: [String: Double] {
        get {
            guard let data = ratesPerUSDData,
                  let dict = try? JSONDecoder().decode([String: Double].self, from: data)
            else { return [:] }
            return dict
        }
        set {
            ratesPerUSDData = try? JSONEncoder().encode(newValue)
            if let inr = newValue["INR"], inr > 0 { usdToInrRate = inr }
        }
    }

    /// Units of `currency` per 1 USD at this snapshot. USD is always 1.
    /// Falls back to the legacy scalar for INR on un-migrated rows.
    func rate(for currency: Currency) -> Double? {
        if currency == .USD { return 1.0 }
        if let r = ratesPerUSD[currency.rawValue], r > 0 { return r }
        if currency == .INR, usdToInrRate > 0 { return usdToInrRate }
        return nil
    }

    func setRate(_ rate: Double, for currency: Currency) {
        guard currency != .USD else { return }
        var dict = ratesPerUSD
        dict[currency.rawValue] = rate
        ratesPerUSD = dict
    }

    /// Currencies used by this snapshot's account values and receivables,
    /// excluding USD (the base). Drives the rates editor and the lock gate.
    var currenciesInUse: [Currency] {
        var set = Set<Currency>()
        for v in values { if let c = v.account?.nativeCurrency { set.insert(c) } }
        for rv in receivableValues { if let c = rv.receivable?.nativeCurrency { set.insert(c) } }
        set.remove(.USD)
        return set.sorted { $0.rawValue < $1.rawValue }
    }

    /// True when every non-USD currency in use has a positive frozen rate —
    /// the lock precondition.
    var hasAllRequiredRates: Bool {
        currenciesInUse.allSatisfy { (rate(for: $0) ?? 0) > 0 }
    }
}

@Model
final class ExchangeRateHistory {
    @Attribute(.unique) var id: UUID
    var date: Date
    var usdToInr: Double
    var source: String

    init(date: Date, usdToInr: Double, source: String) {
        self.id = UUID()
        self.date = date
        self.usdToInr = usdToInr
        self.source = source
    }
}

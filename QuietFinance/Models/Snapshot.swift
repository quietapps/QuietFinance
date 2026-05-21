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

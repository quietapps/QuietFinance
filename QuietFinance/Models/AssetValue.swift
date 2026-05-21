import Foundation
import SwiftData

@Model
final class AssetValue {
    @Attribute(.unique) var id: UUID
    var snapshot: Snapshot?
    var account: Account?
    var nativeValue: Double
    var note: String

    init(snapshot: Snapshot, account: Account, nativeValue: Double, note: String = "") {
        self.id = UUID()
        self.snapshot = snapshot
        self.account = account
        self.nativeValue = nativeValue
        self.note = note
    }

    /// True when this AssetValue contributes to net-worth totals. Excludes
    /// values whose owning Person is flagged with `includeInNetWorth = false`
    /// (e.g. parents/partners tracked alongside but not part of own net worth).
    /// Per-row displays (snapshot editor rows, account rows) ignore this flag —
    /// only aggregators should filter on it.
    var includedInTotals: Bool {
        account?.person?.includeInNetWorth ?? true
    }
}

extension Snapshot {
    /// AssetValues that aggregate into net worth (filters out excluded persons).
    var totalsValues: [AssetValue] { values.filter(\.includedInTotals) }
}

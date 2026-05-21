import Foundation

/// Pre-computes per-snapshot totals once on lock so Dashboard, SnapshotListView,
/// and Reports avoid re-running the full reduce over `values` for every render.
/// Stored on the Snapshot itself; invalidated on edit / unlock.
enum SnapshotCache {
    /// Run on snapshot lock. Iterates totalsValues once, computes USD + INR
    /// totals plus per-category sums, persists to Snapshot fields.
    static func recompute(_ s: Snapshot, includeIlliquid: Bool = true) {
        let values = s.totalsValues
        var usdTotal = 0.0
        var inrTotal = 0.0
        var liquid = 0.0, invested = 0.0, retirement = 0.0, insurance = 0.0, debt = 0.0

        for v in values {
            // Skip illiquid only when the toggle would skip them — but the lock
            // cache is best stored as include-all. UI applies illiquid filter
            // on read by recomputing if user toggle changes.
            let usdVal = CurrencyConverter.netDisplayValue(for: v, in: .USD, includeIlliquid: includeIlliquid)
            let inrVal = CurrencyConverter.netDisplayValue(for: v, in: .INR, includeIlliquid: includeIlliquid)
            usdTotal += usdVal
            inrTotal += inrVal

            switch v.account?.assetType?.category {
            case .cash:        liquid += usdVal
            case .investment, .crypto: invested += usdVal
            case .retirement:  retirement += usdVal
            case .insurance:   insurance += usdVal
            case .debt:        debt += usdVal
            default: break
            }
        }

        s.cachedTotalUSD = usdTotal
        s.cachedTotalINR = inrTotal
        s.cachedTotalsLiquid = liquid
        s.cachedTotalsInvested = invested
        s.cachedTotalsRetirement = retirement
        s.cachedTotalsInsurance = insurance
        s.cachedTotalsDebt = debt
        s.cacheValid = true
    }

    static func invalidate(_ s: Snapshot) {
        s.cacheValid = false
    }

    /// Read total in display currency. Returns nil when cache invalid so the
    /// caller can fall back to the live reduce path.
    static func cachedTotal(_ s: Snapshot, in ccy: Currency) -> Double? {
        guard s.cacheValid else { return nil }
        return ccy == .USD ? s.cachedTotalUSD : s.cachedTotalINR
    }
}

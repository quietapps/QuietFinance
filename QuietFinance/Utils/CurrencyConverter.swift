import Foundation

enum CurrencyConverter {
    /// Convert using the rate table frozen on the snapshot. Never uses today's
    /// rate for historical values. Returns nil when the snapshot lacks a rate
    /// for either side of the pair (callers exclude the value and surface a
    /// warning badge).
    static func convert(nativeValue: Double,
                        from source: Currency,
                        to target: Currency,
                        in snapshot: Snapshot) -> Double? {
        guard source != target else { return nativeValue }
        guard let fromRate = snapshot.rate(for: source), fromRate > 0,
              let toRate = snapshot.rate(for: target), toRate > 0 else { return nil }
        // rates are units-per-USD: native / fromRate = USD, × toRate = target.
        return nativeValue / fromRate * toRate
    }

    /// Legacy scalar-rate conversion (USD↔INR only). Kept for call sites that
    /// predate per-snapshot rate tables; new code should pass the snapshot.
    static func convert(nativeValue: Double,
                        from source: Currency,
                        to target: Currency,
                        usdToInrRate: Double) -> Double {
        guard source != target else { return nativeValue }
        switch (source, target) {
        case (.USD, .INR): return nativeValue * usdToInrRate
        case (.INR, .USD): return nativeValue / usdToInrRate
        default:           return nativeValue
        }
    }

    static func displayValue(for assetValue: AssetValue, in target: Currency) -> Double {
        guard let acc = assetValue.account, let snap = assetValue.snapshot else { return 0 }
        return convert(nativeValue: assetValue.nativeValue,
                       from: acc.nativeCurrency,
                       to: target,
                       in: snap) ?? 0
    }

    /// Same as displayValue but flips the sign for `.debt` accounts so they
    /// subtract from net worth regardless of how the user entered the balance.
    static func netDisplayValue(for assetValue: AssetValue, in target: Currency) -> Double {
        let raw = displayValue(for: assetValue, in: target)
        let isDebt = assetValue.account?.assetType?.category == .debt
        let magnitude = abs(raw)
        return isDebt ? -magnitude : raw
    }

    /// True when the asset value belongs to an illiquid category (real estate, land, etc.).
    static func isIlliquid(_ assetValue: AssetValue) -> Bool {
        assetValue.account?.assetType?.category.isIlliquid ?? false
    }

    /// Net display value, optionally gating illiquid assets out of the total.
    static func netDisplayValue(for assetValue: AssetValue,
                                in target: Currency,
                                includeIlliquid: Bool) -> Double {
        if !includeIlliquid && isIlliquid(assetValue) { return 0 }
        return netDisplayValue(for: assetValue, in: target)
    }

    /// Display value (no debt sign flip), optionally gating illiquid assets to zero.
    static func displayValue(for assetValue: AssetValue,
                             in target: Currency,
                             includeIlliquid: Bool) -> Double {
        if !includeIlliquid && isIlliquid(assetValue) { return 0 }
        return displayValue(for: assetValue, in: target)
    }

    static func displayValue(for receivableValue: ReceivableValue, in target: Currency) -> Double {
        guard let r = receivableValue.receivable, let snap = receivableValue.snapshot else { return 0 }
        return convert(nativeValue: receivableValue.nativeValue,
                       from: r.nativeCurrency,
                       to: target,
                       in: snap) ?? 0
    }

    static func receivableDisplaySum(_ snapshot: Snapshot, in target: Currency) -> Double {
        snapshot.receivableValues.reduce(0.0) { sum, rv in
            sum + displayValue(for: rv, in: target)
        }
    }

    /// Number of values (account + receivable) in the snapshot that cannot be
    /// expressed in `target` because a rate is missing. Non-zero drives the
    /// "N values not converted" warning badge.
    static func unconvertibleCount(_ snapshot: Snapshot, in target: Currency) -> Int {
        var count = 0
        for v in snapshot.values {
            guard let acc = v.account else { continue }
            if convert(nativeValue: v.nativeValue, from: acc.nativeCurrency,
                       to: target, in: snapshot) == nil { count += 1 }
        }
        for rv in snapshot.receivableValues {
            guard let r = rv.receivable else { continue }
            if convert(nativeValue: rv.nativeValue, from: r.nativeCurrency,
                       to: target, in: snapshot) == nil { count += 1 }
        }
        return count
    }
}

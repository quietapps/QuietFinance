import Foundation

enum CurrencyConverter {
    /// Convert using the rate locked on the snapshot. Never use today's rate for historical values.
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
                       usdToInrRate: snap.usdToInrRate)
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
                       usdToInrRate: snap.usdToInrRate)
    }

    static func receivableDisplaySum(_ snapshot: Snapshot, in target: Currency) -> Double {
        snapshot.receivableValues.reduce(0.0) { sum, rv in
            sum + displayValue(for: rv, in: target)
        }
    }
}

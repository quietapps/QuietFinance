import Foundation

enum Fmt {
    static func currency(_ value: Double, _ ccy: Currency, fractionDigits: Int = 0) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = ccy.rawValue
        f.currencySymbol = ccy.symbol
        f.maximumFractionDigits = fractionDigits
        f.minimumFractionDigits = fractionDigits
        // INR uses Indian numbering grouping (1,23,45,678) via en_IN locale.
        if ccy == .INR { f.locale = Locale(identifier: "en_IN") }
        return f.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    static func percent(_ fraction: Double, fractionDigits: Int = 1) -> String {
        let f = NumberFormatter()
        f.numberStyle = .percent
        f.maximumFractionDigits = fractionDigits
        f.minimumFractionDigits = fractionDigits
        return f.string(from: NSNumber(value: fraction)) ?? "\(fraction)%"
    }

    static func label(value: Double, share: Double, ccy: Currency, mode: LabelMode) -> String {
        switch mode {
        case .dollar:  return currency(value, ccy)
        case .percent: return percent(share)
        case .both:    return "\(currency(value, ccy)) · \(percent(share))"
        }
    }

    static func date(_ d: Date, style: DateFormatter.Style = .medium) -> String {
        let f = DateFormatter()
        f.dateStyle = style
        return f.string(from: d)
    }

    static func signedDelta(_ value: Double, _ ccy: Currency) -> String {
        let sign = value >= 0 ? "+" : "−"
        return "\(sign)\(currency(abs(value), ccy))"
    }

    static func compact(_ value: Double, _ ccy: Currency) -> String {
        let abs = Swift.abs(value)
        let sign = value < 0 ? "−" : ""
        let sym = ccy.symbol
        if ccy == .INR {
            // Indian numbering: lakh (1e5), crore (1e7), arab (1e9 = 100Cr but we keep Cr)
            if abs >= 10_000_000 { return "\(sign)\(sym)\(String(format: "%.2fCr", abs / 10_000_000)) " .trimmingCharacters(in: .whitespaces) }
            if abs >= 100_000    { return "\(sign)\(sym)\(String(format: "%.2fL", abs / 100_000))" }
            if abs >= 1_000      { return "\(sign)\(sym)\(String(format: "%.1fK", abs / 1_000))" }
            return currency(value, ccy)
        }
        if abs >= 1_000_000_000 { return "\(sign)\(sym)\(String(format: "%.2fB", abs / 1_000_000_000))" }
        if abs >= 1_000_000     { return "\(sign)\(sym)\(String(format: "%.2fM", abs / 1_000_000))" }
        if abs >= 10_000        { return "\(sign)\(sym)\(String(format: "%.1fK", abs / 1_000))" }
        return currency(value, ccy)
    }

    static func groupedInt(_ value: Double, locale: Locale = .init(identifier: "en_US")) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.locale = locale
        f.maximumFractionDigits = 0
        return f.string(from: NSNumber(value: value)) ?? "\(Int(value))"
    }
}

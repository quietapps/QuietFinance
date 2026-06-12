import Foundation
import SwiftUI

/// Closed set matching frankfurter.app's supported currencies, so every case
/// is fetchable by construction. Adding cases is additive — stored raw values
/// ("USD"/"INR") decode unchanged.
enum Currency: String, Codable, CaseIterable, Identifiable {
    case USD, INR, EUR, GBP, JPY, AUD, CAD, CHF, CNY, HKD, SGD, KRW, NZD
    case SEK, NOK, DKK, PLN, CZK, HUF, RON, BGN, ISK, TRY, ILS, ZAR
    case MXN, BRL, MYR, THB, PHP, IDR

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .USD: return "$"
        case .INR: return "₹"
        case .EUR: return "€"
        case .GBP: return "£"
        case .JPY: return "¥"
        case .AUD: return "A$"
        case .CAD: return "C$"
        case .CHF: return "CHF "
        case .CNY: return "CN¥"
        case .HKD: return "HK$"
        case .SGD: return "S$"
        case .KRW: return "₩"
        case .NZD: return "NZ$"
        case .SEK, .NOK, .DKK, .ISK: return "kr "
        case .PLN: return "zł "
        case .CZK: return "Kč "
        case .HUF: return "Ft "
        case .RON: return "lei "
        case .BGN: return "лв "
        case .TRY: return "₺"
        case .ILS: return "₪"
        case .ZAR: return "R "
        case .MXN: return "MX$"
        case .BRL: return "R$"
        case .MYR: return "RM "
        case .THB: return "฿"
        case .PHP: return "₱"
        case .IDR: return "Rp "
        }
    }

    /// Localized long name, e.g. "Euro", "Indian Rupee".
    var displayName: String {
        Locale.current.localizedString(forCurrencyCode: rawValue) ?? rawValue
    }
}

enum AssetCategory: String, Codable, CaseIterable, Identifiable {
    case cash = "Cash"
    case investment = "Investment"
    case retirement = "Retirement"
    case crypto = "Crypto"
    case insurance = "Insurance"
    case realEstate = "Real Estate"
    case debt = "Debt"
    var id: String { rawValue }

    /// Long-term, illiquid assets (real estate, land, vehicles, collectibles).
    /// Net-worth inclusion gated by AppState.includeIlliquidInNetWorth.
    var isIlliquid: Bool { self == .realEstate }
}

enum LabelMode: String, Codable, CaseIterable, Identifiable {
    case dollar, percent, both
    var id: String { rawValue }
    var display: String {
        switch self { case .dollar: return "$"; case .percent: return "%"; case .both: return "Both" }
    }
}

enum ChartStyle: String, Codable, CaseIterable, Identifiable {
    case donut, bar
    var id: String { rawValue }
}

enum AppTheme: String, Codable, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }

    /// SwiftUI scheme to force via `.preferredColorScheme`. `nil` for `.system`
    /// so the app follows the OS. This is the authoritative driver of which
    /// light/dark token variant the dynamic colors resolve to — without it the
    /// dynamic NSColors fall back to `NSApp.effectiveAppearance` (the system
    /// scheme) on re-render, which flips content out from under a pinned theme.
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }
}

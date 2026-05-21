import Foundation

enum Currency: String, Codable, CaseIterable, Identifiable {
    case USD, INR
    var id: String { rawValue }
    var symbol: String { self == .USD ? "$" : "₹" }
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
}

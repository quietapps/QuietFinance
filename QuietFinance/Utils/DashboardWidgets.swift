import Foundation

/// Identifiable widgets that compose the Dashboard. User can toggle visibility
/// and reorder them. Persistence: comma-separated raw values in AppStorage.
enum DashboardWidget: String, CaseIterable, Identifiable, Codable {
    case hero
    case digest
    case goal
    case milestone
    case liquidity
    case kpi
    case netChange
    case currencyExposure
    case composition
    case allocationDrift
    case liabilities
    case debtPayoff
    case receivables
    case movers
    case watchlist

    var id: String { rawValue }

    var label: String {
        switch self {
        case .hero:             return "Hero · Net worth"
        case .digest:           return "Digest sentence"
        case .goal:             return "Goal progress"
        case .milestone:        return "Milestones"
        case .liquidity:        return "Liquidity"
        case .kpi:              return "KPI grid"
        case .netChange:        return "Net change rate"
        case .currencyExposure: return "Currency exposure"
        case .composition:      return "Composition (donuts)"
        case .allocationDrift:  return "Allocation drift"
        case .liabilities:      return "Liabilities"
        case .debtPayoff:       return "Debt payoff"
        case .receivables:      return "Receivables"
        case .movers:           return "Top movers"
        case .watchlist:        return "Watchlist (pinned)"
        }
    }

    var icon: String {
        switch self {
        case .hero:             return "house"
        case .digest:           return "text.alignleft"
        case .goal:             return "target"
        case .milestone:        return "flag.checkered"
        case .liquidity:        return "drop"
        case .kpi:              return "square.grid.2x2"
        case .netChange:        return "chart.line.flattrend.xyaxis"
        case .currencyExposure: return "dollarsign.arrow.circlepath"
        case .composition:      return "chart.pie"
        case .allocationDrift:  return "scalemass"
        case .liabilities:      return "minus.circle"
        case .debtPayoff:       return "creditcard.trianglebadge.exclamationmark"
        case .receivables:      return "hourglass"
        case .movers:           return "arrow.up.arrow.down"
        case .watchlist:        return "star"
        }
    }

    static var defaultOrder: [DashboardWidget] {
        [.hero, .digest, .goal, .milestone, .liquidity, .kpi, .netChange,
         .currencyExposure, .watchlist, .composition, .allocationDrift,
         .liabilities, .debtPayoff, .receivables, .movers]
    }
}

enum DashboardLayout {
    /// Decode a comma-separated AppStorage value into an ordered list with
    /// defaults filled in for any new widgets added since storage was written.
    static func decodeOrder(_ raw: String) -> [DashboardWidget] {
        var seen = Set<DashboardWidget>()
        var out: [DashboardWidget] = []
        for piece in raw.split(separator: ",") {
            if let w = DashboardWidget(rawValue: String(piece)), !seen.contains(w) {
                out.append(w); seen.insert(w)
            }
        }
        // Append any new widgets not yet stored, preserving definition order.
        for w in DashboardWidget.defaultOrder where !seen.contains(w) {
            out.append(w)
        }
        return out
    }

    static func encodeOrder(_ list: [DashboardWidget]) -> String {
        list.map(\.rawValue).joined(separator: ",")
    }

    static func decodeHidden(_ raw: String) -> Set<DashboardWidget> {
        Set(raw.split(separator: ",").compactMap { DashboardWidget(rawValue: String($0)) })
    }

    static func encodeHidden(_ set: Set<DashboardWidget>) -> String {
        set.map(\.rawValue).joined(separator: ",")
    }
}

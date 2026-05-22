import SwiftUI
import AppKit

/// User-selectable Dock icon variants. macOS doesn't support per-launch
/// alternate bundle icons without an app extension, so this swaps the
/// running app's icon via `NSApplication.applicationIconImage`. Choice is
/// persisted in `AppStorage` and re-applied on every launch.
enum AppIconChoice: String, CaseIterable, Identifiable {
    case classic       // Default — brand blue gradient, ascending snapshot bars
    case dusk          // Dusk ledger bars fade to quiet
    case quietFinance  // Gold L on dark squircle
    case vault         // Concentric gold rings on deep teal — snapshot timeline
    case strata        // Stacked allocation bars on cream paper

    var id: String { rawValue }

    var label: String {
        switch self {
        case .classic:      return "Classic"
        case .dusk:         return "Dusk"
        case .quietFinance: return "Quiet Finance"
        case .vault:        return "Vault"
        case .strata:       return "Strata"
        }
    }

    var subtitle: String {
        switch self {
        case .classic:      return "Snapshot bars on blue"
        case .dusk:         return "Ledger bars on dusk"
        case .quietFinance: return "Gold ledger on ink"
        case .vault:        return "Timeline arcs on ink"
        case .strata:       return "Allocation bars on slate"
        }
    }

    /// Asset catalog image name used for in-app preview AND for the
    /// runtime Dock icon.
    var assetName: String {
        switch self {
        case .dusk:         return "IconDusk"
        case .quietFinance: return "IconQuietFinance"
        case .classic:      return "IconClassic"
        case .vault:        return "IconVault"
        case .strata:       return "IconStrata"
        }
    }
}

enum AppIconSwitcher {
    /// Apply the chosen icon to the running app. Reverts to default bundle
    /// icon when called for `.dusk` (the bundle default) so the system
    /// supplies the higher-resolution rasters from Assets.
    @MainActor
    static func apply(_ choice: AppIconChoice) {
        if let image = NSImage(named: choice.assetName) {
            NSApp.applicationIconImage = image
        }
    }
}

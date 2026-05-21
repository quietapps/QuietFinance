import SwiftUI
import AppKit
import Combine

enum Screen: Hashable {
    case dashboard, breakdown, trends, snapshots, diff, reports, accounts, people, countries, assetTypes, receivables, settings
}

final class AppState: ObservableObject {
    @AppStorage("displayCurrency") var displayCurrencyRaw: String = Currency.USD.rawValue
    @AppStorage("labelMode")       var labelModeRaw: String = LabelMode.dollar.rawValue
    @AppStorage("theme")           var themeRaw: String = AppTheme.system.rawValue
    @AppStorage("includeIlliquidInNetWorth") var includeIlliquidInNetWorth: Bool = true
    @AppStorage("netWorthGoal") var netWorthGoal: Double = 0  // 0 = disabled
    @AppStorage("netWorthGoalCurrencyRaw") var netWorthGoalCurrencyRaw: String = Currency.USD.rawValue
    /// Target date as Unix timestamp. 0 = disabled (no date set).
    @AppStorage("netWorthGoalDate") var netWorthGoalDateTS: Double = 0
    @AppStorage("forecastMethod") var forecastMethodRaw: String = ForecastMethod.linear.rawValue
    @AppStorage("dashboardCompareMode") var dashboardCompareModeRaw: String = "previous"

    enum CompareMode: String, CaseIterable, Identifiable {
        case previous, yearAgo
        var id: String { rawValue }
        var label: String {
            switch self { case .previous: return "vs Previous"; case .yearAgo: return "vs Year ago" }
        }
        var shortLabel: String {
            switch self { case .previous: return "QoQ"; case .yearAgo: return "YoY" }
        }
    }
    var dashboardCompareMode: CompareMode {
        get { CompareMode(rawValue: dashboardCompareModeRaw) ?? .previous }
        set { dashboardCompareModeRaw = newValue.rawValue; objectWillChange.send() }
    }

    var netWorthGoalDate: Date? {
        get { netWorthGoalDateTS > 0 ? Date(timeIntervalSince1970: netWorthGoalDateTS) : nil }
        set {
            netWorthGoalDateTS = newValue?.timeIntervalSince1970 ?? 0
            objectWillChange.send()
        }
    }

    var forecastMethod: ForecastMethod {
        get { ForecastMethod(rawValue: forecastMethodRaw) ?? .linear }
        set { forecastMethodRaw = newValue.rawValue; objectWillChange.send() }
    }
    @AppStorage("compactMode") var compactMode: Bool = false
    @AppStorage("requireAppLock") var requireAppLock: Bool = true
    /// Minutes of in-app idle (no key/mouse) before the lock gate re-engages.
    /// 0 disables auto-lock. Only effective while `requireAppLock` is on.
    @AppStorage("autoLockIdleMinutes") var autoLockIdleMinutes: Int = 0
    @AppStorage("stealthMode") var stealthMode: Bool = false
    @AppStorage("sidebarWidth") var sidebarWidth: Double = 220
    @AppStorage("sidebarLastExpandedWidth") var sidebarLastExpandedWidth: Double = 220
    @AppStorage("iconOnlySidebar") var iconOnlySidebar: Bool = false
    @AppStorage("dashboardWidgetOrder") var dashboardWidgetOrderRaw: String = ""
    @AppStorage("dashboardWidgetsHidden") var dashboardWidgetsHiddenRaw: String = ""
    @AppStorage("menuBarEnabled") var menuBarEnabled: Bool = false
    /// Recent items stack: pipe-separated entries "kind|uuid|label". Newest first.
    @AppStorage("recentItems") var recentItemsRaw: String = ""

    /// Comma-separated UUIDs for accounts pinned to the dashboard watchlist.
    /// Order is preserved (insertion order = display order on dashboard).
    @AppStorage("pinnedAccountIDs") var pinnedAccountIDsRaw: String = ""

    var pinnedAccountIDs: [UUID] {
        pinnedAccountIDsRaw.split(separator: ",").compactMap { UUID(uuidString: String($0)) }
    }

    func isPinnedAccount(_ id: UUID) -> Bool {
        pinnedAccountIDs.contains(id)
    }

    func togglePinnedAccount(_ id: UUID) {
        var list = pinnedAccountIDs
        if let idx = list.firstIndex(of: id) {
            list.remove(at: idx)
        } else {
            list.append(id)
        }
        pinnedAccountIDsRaw = list.map(\.uuidString).joined(separator: ",")
        objectWillChange.send()
    }

    enum RecentKind: String { case account, snapshot, person, country }

    struct RecentItem: Identifiable, Equatable {
        let kind: RecentKind
        let entityID: UUID
        let label: String
        var id: String { "\(kind.rawValue)-\(entityID.uuidString)" }
        static func ==(a: RecentItem, b: RecentItem) -> Bool {
            a.kind == b.kind && a.entityID == b.entityID
        }
    }

    var recentItems: [RecentItem] {
        recentItemsRaw.split(separator: "\n").compactMap { line in
            let parts = line.split(separator: "|", maxSplits: 2, omittingEmptySubsequences: false).map(String.init)
            guard parts.count == 3,
                  let kind = RecentKind(rawValue: parts[0]),
                  let id = UUID(uuidString: parts[1]) else { return nil }
            return RecentItem(kind: kind, entityID: id, label: parts[2])
        }
    }

    func touchRecent(_ kind: RecentKind, id: UUID, label: String) {
        var list = recentItems
        list.removeAll { $0.kind == kind && $0.entityID == id }
        list.insert(RecentItem(kind: kind, entityID: id, label: label), at: 0)
        if list.count > 5 { list = Array(list.prefix(5)) }
        recentItemsRaw = list.map { "\($0.kind.rawValue)|\($0.entityID.uuidString)|\($0.label)" }
            .joined(separator: "\n")
        objectWillChange.send()
    }

    var dashboardWidgetOrder: [DashboardWidget] {
        get { DashboardLayout.decodeOrder(dashboardWidgetOrderRaw) }
        set { dashboardWidgetOrderRaw = DashboardLayout.encodeOrder(newValue); objectWillChange.send() }
    }

    var dashboardWidgetsHidden: Set<DashboardWidget> {
        get { DashboardLayout.decodeHidden(dashboardWidgetsHiddenRaw) }
        set { dashboardWidgetsHiddenRaw = DashboardLayout.encodeHidden(newValue); objectWillChange.send() }
    }
    @AppStorage("appIconChoice") var appIconChoiceRaw: String = AppIconChoice.dusk.rawValue

    var appIconChoice: AppIconChoice {
        get { AppIconChoice(rawValue: appIconChoiceRaw) ?? .dusk }
        set {
            appIconChoiceRaw = newValue.rawValue
            objectWillChange.send()
            AppIconSwitcher.apply(newValue)
        }
    }

    var netWorthGoalCurrency: Currency {
        get { Currency(rawValue: netWorthGoalCurrencyRaw) ?? .USD }
        set { netWorthGoalCurrencyRaw = newValue.rawValue; objectWillChange.send() }
    }

    @AppStorage("card.byPerson.style")   var byPersonStyleRaw: String = ChartStyle.donut.rawValue
    @AppStorage("card.byCountry.style")  var byCountryStyleRaw: String = ChartStyle.donut.rawValue
    @AppStorage("card.byCategory.style") var byCategoryStyleRaw: String = ChartStyle.donut.rawValue

    @Published var selectedScreen: Screen = .dashboard
    @Published var activeSnapshotID: UUID? = nil
    @Published var newSnapshotRequested: Bool = false
    @Published var pendingBreakdownFilter: PendingFilter? = nil
    @Published var globalSearchFocusTick: Int = 0
    @Published var commandPaletteOpen: Bool = false

    /// Set by GlobalSearchField to request that a manage view open the editor
    /// sheet for a specific entity ID after navigation. Each manage view
    /// observes its corresponding field, opens the sheet, and clears it.
    @Published var pendingFocusPersonID:    UUID? = nil
    @Published var pendingFocusAccountID:   UUID? = nil
    @Published var pendingFocusCountryID:   UUID? = nil
    @Published var pendingFocusAssetTypeID: UUID? = nil

    var displayCurrency: Currency {
        get { Currency(rawValue: displayCurrencyRaw) ?? .USD }
        set { displayCurrencyRaw = newValue.rawValue; objectWillChange.send() }
    }
    var labelMode: LabelMode {
        get { LabelMode(rawValue: labelModeRaw) ?? .dollar }
        set { labelModeRaw = newValue.rawValue; objectWillChange.send() }
    }
    var theme: AppTheme {
        get { AppTheme(rawValue: themeRaw) ?? .system }
        set {
            themeRaw = newValue.rawValue
            objectWillChange.send()
            applyAppearance()
        }
    }

    init() {}

    func applyAppearance() {
        // Theme switching is handled via `.preferredColorScheme` on the WindowGroup.
        // Setting NSApp.appearance directly conflicts with that and causes the
        // first toggle back to .system to appear stuck.
    }
    var byPersonStyle: ChartStyle {
        get { ChartStyle(rawValue: byPersonStyleRaw) ?? .donut }
        set { byPersonStyleRaw = newValue.rawValue; objectWillChange.send() }
    }
    var byCountryStyle: ChartStyle {
        get { ChartStyle(rawValue: byCountryStyleRaw) ?? .donut }
        set { byCountryStyleRaw = newValue.rawValue; objectWillChange.send() }
    }
    var byCategoryStyle: ChartStyle {
        get { ChartStyle(rawValue: byCategoryStyleRaw) ?? .donut }
        set { byCategoryStyleRaw = newValue.rawValue; objectWillChange.send() }
    }

    var preferredColorScheme: ColorScheme? {
        switch theme {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }
}

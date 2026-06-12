import SwiftUI
import SwiftData

/// Dashboard orchestrator: owns the queries, recomputes `DashboardStats` once
/// per data change, and hands narrow slices to the widget structs under
/// `Widgets/` so SwiftUI diffs per-widget instead of one giant body.
struct DashboardView: View {
    @EnvironmentObject var app: AppState
    @Query(sort: \Snapshot.date, order: .reverse) private var snapshots: [Snapshot]
    @Query private var allAccounts: [Account]
    @Query private var people: [Person]

    @State private var stats: DashboardStats = .empty

    /// All required onboarding steps done → checklist auto-hides.
    private var checklistComplete: Bool {
        !people.isEmpty && !allAccounts.isEmpty && !snapshots.isEmpty
    }

    private var visibleWidgets: [DashboardWidget] {
        let hidden = app.dashboardWidgetsHidden
        return app.dashboardWidgetOrder.filter { w in
            if hidden.contains(w) { return false }
            // Auto-hide widgets with no data to avoid empty cards.
            switch w {
            case .gettingStarted:   return !app.onboardingChecklistDismissed && !checklistComplete
            case .goal:             return app.netWorthGoal > 0
            case .milestone:        return snapshots.count >= 2
            case .netChange:        return stats.netChange != nil
            case .currencyExposure: return stats.exposure.count >= 2
            case .allocationDrift:  return !stats.targets.isEmpty
            case .liabilities:      return !stats.liabilities.isEmpty
            case .debtPayoff:       return stats.debtPayoff != nil
            case .receivables:      return hasReceivables
            case .watchlist:        return !app.pinnedAccountIDs.isEmpty
            default:                return true
            }
        }
    }

    @ViewBuilder
    private func widgetView(_ w: DashboardWidget) -> some View {
        switch w {
        case .gettingStarted:
            GettingStartedPanel()
        case .hero:
            DashboardHeroPanel(active: stats.active,
                               snapshots: Array(snapshots),
                               curTotal: stats.curTotal,
                               prevTotal: stats.prevTotal,
                               yaTotal: stats.yaTotal,
                               hasPrev: stats.hasPrev,
                               hasYearAgo: stats.hasYearAgo,
                               trajectory: stats.trajectory,
                               goal: goalDisplay(),
                               anomaly: stats.anomaly)
        case .digest:
            DashboardDigestPanel(sentence: DashboardCompute.digest(
                stats: stats, goal: goalDisplay(), currency: app.displayCurrency))
        case .goal:
            GoalProgressPanel(curTotal: stats.curTotal,
                              goal: goalDisplay() ?? 0,
                              history: stats.fitHistory)
        case .milestone:
            MilestonePanel(history: stats.fitHistory,
                           curTotal: stats.curTotal,
                           goal: goalDisplay())
        case .liquidity:
            LiquidityPanel(result: stats.liquidity)
        case .netChange:
            if let nc = stats.netChange {
                NetChangePanel(result: nc)
            }
        case .currencyExposure:
            CurrencyExposurePanel(slices: stats.exposure, curTotal: stats.curTotal)
        case .allocationDrift:
            AllocationDriftPanel(typeItems: stats.typeItems,
                                 targets: stats.targets,
                                 curTotal: stats.curTotal,
                                 onTargetsSaved: recompute)
        case .debtPayoff:
            if let dp = stats.debtPayoff {
                DebtPayoffPanel(result: dp)
            }
        case .kpi:
            KPIGridPanel(cur: stats.cur, prev: stats.prev, ya: stats.ya,
                         hasPrev: stats.hasPrev, hasYearAgo: stats.hasYearAgo)
        case .composition:
            CompositionSection(personItems: stats.personItems,
                               countryItems: stats.countryItems,
                               typeItems: stats.typeItems,
                               curTotal: stats.curTotal,
                               targets: stats.targets,
                               activeLabel: stats.active?.label ?? "—",
                               onOpen: openBreakdown,
                               onTargetsSaved: recompute)
        case .liabilities:
            LiabilitiesSection(rows: stats.liabilities)
        case .receivables:
            ReceivablesPanel(snapshot: stats.active)
        case .movers:
            MoversSection(rows: stats.movers,
                          fromLabel: stats.prevSnap?.label,
                          toLabel: stats.active?.label ?? "—")
        case .watchlist:
            WatchlistPanel(accounts: allAccounts,
                           activeSnap: stats.active,
                           prevSnap: stats.prevSnap)
        }
    }

    var body: some View {
        Group {
            if snapshots.isEmpty {
                // The widget loop is bypassed here, so the onboarding
                // checklist must render explicitly above the empty state.
                VStack(alignment: .leading, spacing: 28) {
                    if !app.onboardingChecklistDismissed && !checklistComplete {
                        GettingStartedPanel()
                    }
                    emptyState
                }
            } else {
                VStack(alignment: .leading, spacing: 28) {
                    ForEach(visibleWidgets, id: \.self) { w in
                        widgetView(w)
                    }
                }
            }
        }
        .onAppear { recompute() }
        .onChange(of: app.activeSnapshotID) { _, _ in recompute() }
        .onChange(of: app.displayCurrency) { _, _ in recompute() }
        .onChange(of: snapshotsFingerprint) { _, _ in recompute() }
        .onChange(of: app.includeIlliquidInNetWorth) { _, _ in recompute() }
    }

    private var emptyState: some View {
        EditorialEmpty(
            eyebrow: "Overview · Net Worth",
            title: "A ledger",
            titleItalic: "awaits its first entry.",
            body: "No snapshots yet. Capture a quarterly snapshot to begin charting trajectory, allocation, and movers across the household.",
            detail: "Snapshots are point-in-time totals. One per quarter keeps the trend honest.",
            ctaLabel: "Create first snapshot",
            cta: {
                app.newSnapshotRequested = true
                app.selectedScreen = .snapshots
            },
            secondaryLabel: "Set up accounts first",
            secondary: { app.selectedScreen = .accounts },
            illustration: "chart.bar.doc.horizontal"
        )
    }

    /// Cheap scalar capturing every input that should trigger a recompute —
    /// avoids the old pattern of allocating fresh arrays inside onChange.
    private var snapshotsFingerprint: Int {
        var h = Hasher()
        h.combine(snapshots.count)
        for s in snapshots {
            h.combine(s.isLocked)
            h.combine(s.ratesPerUSDData)
            h.combine(s.usdToInrRate)
        }
        return h.finalize()
    }

    private func recompute() {
        stats = DashboardCompute.stats(snapshots: Array(snapshots),
                                       activeID: app.activeSnapshotID,
                                       target: app.displayCurrency,
                                       includeIlliquid: app.includeIlliquidInNetWorth)
    }

    private func goalDisplay() -> Double? {
        guard app.netWorthGoal > 0 else { return nil }
        if let snap = snapshots.first,
           let v = CurrencyConverter.convert(nativeValue: app.netWorthGoal,
                                             from: app.netWorthGoalCurrency,
                                             to: app.displayCurrency,
                                             in: snap) {
            return v
        }
        // No snapshot or missing rate — usable only when no conversion needed.
        return app.netWorthGoalCurrency == app.displayCurrency ? app.netWorthGoal : nil
    }

    private func openBreakdown(_ item: AllocItem) {
        app.pendingBreakdownFilter = PendingFilter(
            key: item.groupKey, matchValue: item.matchValue, label: item.label
        )
        app.selectedScreen = .breakdown
    }

    private var hasReceivables: Bool {
        guard let cur = stats.active else { return false }
        return !cur.receivableValues.isEmpty
    }
}

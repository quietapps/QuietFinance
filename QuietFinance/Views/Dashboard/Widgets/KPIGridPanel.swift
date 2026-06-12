import SwiftUI

/// Four-up category KPI cards (liquid / invested / retirement / debt).
struct KPIGridPanel: View {
    @EnvironmentObject var app: AppState
    let cur: CategoryTotals
    let prev: CategoryTotals
    let ya: CategoryTotals
    let hasPrev: Bool
    let hasYearAgo: Bool

    var body: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 14), count: 4),
            spacing: 14
        ) {
            let refLiquid    = kpiRef(prev: prev.liquid,    ya: ya.liquid)
            let refInvested  = kpiRef(prev: prev.invested,  ya: ya.invested)
            let refRetIns    = kpiRef(prev: prev.retirement + prev.insurance,
                                       ya: ya.retirement + ya.insurance)
            let refDebt      = kpiRef(prev: prev.debt,      ya: ya.debt)

            KPICard(
                label: "Liquid",
                value: Fmt.compact(cur.liquid, app.displayCurrency),
                sub: "Cash + deposits",
                deltaText: kpiDeltaText(cur: cur.liquid, ref: refLiquid),
                deltaUp: cur.liquid >= (refLiquid ?? cur.liquid)
            )
            .copyable(value: String(format: "%.2f", cur.liquid))
            KPICard(
                label: "Invested",
                value: Fmt.compact(cur.invested, app.displayCurrency),
                sub: "Equity + crypto",
                deltaText: kpiDeltaText(cur: cur.invested, ref: refInvested),
                deltaUp: cur.invested >= (refInvested ?? cur.invested)
            )
            .copyable(value: String(format: "%.2f", cur.invested))
            KPICard(
                label: "Retirement",
                value: Fmt.compact(cur.retirement + cur.insurance, app.displayCurrency),
                sub: "401k · IRA · NPS · HSA",
                deltaText: kpiDeltaText(cur: cur.retirement + cur.insurance, ref: refRetIns),
                deltaUp: (cur.retirement + cur.insurance) >= (refRetIns ?? (cur.retirement + cur.insurance))
            )
            .copyable(value: String(format: "%.2f", cur.retirement + cur.insurance))
            KPICard(
                label: "Debt",
                value: Fmt.compact(abs(cur.debt), app.displayCurrency),
                sub: "Loans · credit",
                valueColor: .lLoss,
                deltaText: kpiDeltaText(cur: cur.debt, ref: refDebt),
                deltaUp: cur.debt >= (refDebt ?? cur.debt)
            )
            .copyable(value: String(format: "%.2f", abs(cur.debt)))
        }
    }

    /// Reference total per current compare mode. nil when no prior snapshot.
    private func kpiRef(prev p: Double, ya y: Double) -> Double? {
        switch app.dashboardCompareMode {
        case .previous: return hasPrev ? p : nil
        case .yearAgo:  return hasYearAgo ? y : nil
        }
    }

    private func kpiDeltaText(cur c: Double, ref: Double?) -> String? {
        guard let r = ref, r != 0 else { return nil }
        let d = (c - r) / abs(r) * 100
        return "\(d >= 0 ? "+" : "−")\(String(format: "%.1f", abs(d)))% \(app.dashboardCompareMode.shortLabel)"
    }
}

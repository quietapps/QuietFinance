import SwiftUI

/// Cash-on-hand, monthly net, and runway from snapshot deltas.
struct LiquidityPanel: View {
    @EnvironmentObject var app: AppState
    let result: LiquidityAnalysis.Result?

    var body: some View {
        if let r = result {
            Panel {
                VStack(alignment: .leading, spacing: 0) {
                    PanelHead(title: "Liquidity",
                              meta: r.lookbackPairs > 0
                                  ? "\(r.lookbackPairs) snapshot transitions"
                                  : "needs ≥ 2 snapshots")
                    HStack(alignment: .top, spacing: 18) {
                        liquidityStat(label: "Cash on hand",
                                      value: Fmt.compact(r.liquidNow, app.displayCurrency),
                                      sub: "Sum of Cash-category accounts",
                                      tint: .lInk,
                                      blur: true)
                        liquidityStat(label: "Monthly net",
                                      value: r.monthlyChange == 0
                                          ? "—"
                                          : (r.monthlyChange > 0 ? "+" : "−")
                                              + Fmt.compact(abs(r.monthlyChange), app.displayCurrency),
                                      sub: r.monthlyChange >= 0
                                          ? "Cash growing — no burn"
                                          : "Avg monthly drop",
                                      tint: r.monthlyChange >= 0 ? .lGain : .lLoss,
                                      blur: true)
                        liquidityStat(label: "Runway",
                                      value: runwayLabel(r),
                                      sub: r.monthsRunway == nil
                                          ? "Burn = 0"
                                          : "At current burn rate",
                                      tint: runwayTint(r),
                                      blur: false)
                        Spacer(minLength: 0)
                    }
                    .padding(18)
                }
            }
        }
    }

    @ViewBuilder
    private func liquidityStat(label: String, value: String, sub: String,
                               tint: Color, blur: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(Typo.eyebrow).tracking(1.2)
                .foregroundStyle(Color.lInk3)
            Group {
                Text(value)
                    .font(Typo.serifNum(22))
                    .foregroundStyle(tint)
                    .monospacedDigit()
            }
            .modifier(StealthIfNeeded(blur: blur))
            Text(sub)
                .font(Typo.sans(11))
                .foregroundStyle(Color.lInk3)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(minWidth: 160, alignment: .leading)
    }

    private func runwayLabel(_ r: LiquidityAnalysis.Result) -> String {
        guard let m = r.monthsRunway else { return "∞" }
        if m >= 24 { return "\(Int(m / 12))y \(Int(m.truncatingRemainder(dividingBy: 12))) mo" }
        return "\(Int(m.rounded())) mo"
    }

    private func runwayTint(_ r: LiquidityAnalysis.Result) -> Color {
        guard let m = r.monthsRunway else { return .lGain }
        if m < 3 { return .lLoss }
        if m < 6 { return .lInk }
        return .lGain
    }
}

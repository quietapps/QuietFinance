import SwiftUI

/// Average net change per month/quarter from snapshot deltas, with a delta
/// sparkline. Copy is deliberately honest: snapshots can't separate savings
/// from market movement.
struct NetChangePanel: View {
    @EnvironmentObject var app: AppState
    let result: NetChangeAnalysis.Result

    var body: some View {
        Panel {
            VStack(alignment: .leading, spacing: 0) {
                PanelHead(title: "Net change rate",
                          meta: "\(result.transitions) snapshot transitions")
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .top, spacing: 22) {
                        stat("PER MONTH",
                             signed(result.monthlyAvg),
                             tint: result.monthlyAvg >= 0 ? .lGain : .lLoss)
                        stat("PER QUARTER",
                             signed(result.quarterlyAvg),
                             tint: result.quarterlyAvg >= 0 ? .lGain : .lLoss)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("PER-SNAPSHOT CHANGE")
                                .font(Typo.eyebrow).tracking(1.2)
                                .foregroundStyle(Color.lInk3)
                            Sparkline(values: result.deltas.map(\.1),
                                      stroke: result.monthlyAvg >= 0 ? Color.lGain : Color.lLoss,
                                      fill: (result.monthlyAvg >= 0 ? Color.lGain : Color.lLoss).opacity(0.08))
                                .frame(width: 160, height: 24)
                        }
                        Spacer(minLength: 0)
                    }
                    Text("Trailing 12 months. Savings and market movement combined — snapshots can’t separate the two.")
                        .font(Typo.serifItalic(11.5))
                        .foregroundStyle(Color.lInk3)
                }
                .padding(18)
            }
        }
    }

    private func signed(_ v: Double) -> String {
        "\(v >= 0 ? "+" : "−")\(Fmt.compact(abs(v), app.displayCurrency))"
    }

    @ViewBuilder
    private func stat(_ label: String, _ value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(Typo.eyebrow).tracking(1.2)
                .foregroundStyle(Color.lInk3)
            Text(value)
                .font(Typo.serifNum(20))
                .foregroundStyle(tint)
                .monospacedDigit()
                .stealthAmount()
        }
    }
}

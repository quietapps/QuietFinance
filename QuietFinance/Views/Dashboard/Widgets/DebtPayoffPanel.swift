import SwiftUI

/// Trend-based debt payoff ETA with a live "pay extra per month" what-if.
/// The slider value is deliberately ephemeral — persisting a currency amount
/// is ambiguous across display-currency switches.
struct DebtPayoffPanel: View {
    @EnvironmentObject var app: AppState
    let result: DebtPayoff.Result

    @State private var extraMonthly: Double = 0

    private var sliderCap: Double {
        max(1000, result.monthlyPaydown * 4, result.currentDebt / 24)
    }

    var body: some View {
        Panel {
            VStack(alignment: .leading, spacing: 0) {
                PanelHead(title: "Debt payoff",
                          meta: "\(Fmt.compact(result.currentDebt, app.displayCurrency)) outstanding")
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .top, spacing: 22) {
                        stat("PAYOFF ETA",
                             result.payoffDate.map(formatDateLabel) ?? "—",
                             sub: result.payoffDate == nil
                                 ? "debt isn’t shrinking on trend"
                                 : "at current paydown pace",
                             tint: result.payoffDate == nil ? .lLoss : .lInk)
                        stat("MONTHLY PAYDOWN",
                             result.monthlyPaydown > 0
                                 ? Fmt.compact(result.monthlyPaydown, app.displayCurrency)
                                 : "—",
                             sub: "trend across snapshots",
                             tint: result.monthlyPaydown > 0 ? .lGain : .lLoss)
                        if extraMonthly > 0, let accelerated = acceleratedDate {
                            stat("WITH EXTRA",
                                 formatDateLabel(accelerated),
                                 sub: monthsSavedText(accelerated),
                                 tint: .lGain)
                        }
                        Spacer(minLength: 0)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("PAY EXTRA / MONTH")
                                .font(Typo.eyebrow).tracking(1.2)
                                .foregroundStyle(Color.lInk3)
                            Spacer()
                            Text(Fmt.compact(extraMonthly, app.displayCurrency))
                                .font(Typo.mono(12, weight: .semibold))
                                .foregroundStyle(extraMonthly > 0 ? Color.lGain : Color.lInk3)
                                .stealthAmount()
                        }
                        Slider(value: $extraMonthly, in: 0...sliderCap)
                            .controlSize(.small)
                    }
                }
                .padding(18)
            }
        }
    }

    private var acceleratedDate: Date? {
        DebtPayoff.payoffDate(balance: result.currentDebt,
                              monthlyPaydown: max(0, result.monthlyPaydown) + extraMonthly)
    }

    private func monthsSavedText(_ accelerated: Date) -> String {
        guard let base = result.payoffDate else { return "vs never on current trend" }
        let months = Calendar.current.dateComponents([.month], from: accelerated, to: base).month ?? 0
        return months > 0 ? "\(months) mo sooner" : "same as trend"
    }

    @ViewBuilder
    private func stat(_ label: String, _ value: String, sub: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(Typo.eyebrow).tracking(1.2)
                .foregroundStyle(Color.lInk3)
            Text(value)
                .font(Typo.mono(13, weight: .semibold))
                .foregroundStyle(tint)
            Text(sub)
                .font(Typo.sans(11))
                .foregroundStyle(Color.lInk3)
        }
    }

    private func formatDateLabel(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMM yyyy"
        return f.string(from: d)
    }
}

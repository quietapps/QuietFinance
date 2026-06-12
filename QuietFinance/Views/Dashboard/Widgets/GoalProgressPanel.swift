import SwiftUI

/// Goal progress bar with trend ETA, target-date pacing, and monthly-needed.
struct GoalProgressPanel: View {
    @EnvironmentObject var app: AppState
    let curTotal: Double
    let goal: Double
    let history: [(Date, Double)]

    var body: some View {
        let pct = goal > 0 ? min(1.0, max(0.0, curTotal / goal)) : 0
        let remaining = max(0, goal - curTotal)
        let cleared = curTotal >= goal
        let forecast = Forecast.compute(history: history,
                                        method: app.forecastMethod,
                                        horizonMonths: 0,
                                        goal: goal)
        let trendETA = forecast?.etaForGoal
        let target = app.netWorthGoalDate

        Panel {
            VStack(alignment: .leading, spacing: 14) {
                PanelHead(title: "Goal",
                          meta: cleared ? "Cleared" : "\(Fmt.compact(remaining, app.displayCurrency)) to go")

                HStack(alignment: .firstTextBaseline) {
                    Text(Fmt.compact(curTotal, app.displayCurrency))
                        .font(Typo.serifNum(28))
                        .foregroundStyle(Color.lInk)
                        .stealthAmount()
                    Text("/ \(Fmt.compact(goal, app.displayCurrency))")
                        .font(Typo.mono(13))
                        .foregroundStyle(Color.lInk3)
                        .stealthAmount()
                    Spacer()
                    Text("\(String(format: "%.1f", pct * 100))%")
                        .font(Typo.mono(13, weight: .semibold))
                        .foregroundStyle(cleared ? Color.lGain : Color.lInk2)
                }
                .padding(.horizontal, 18)

                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.lSunken)
                        .frame(height: 8)
                    GeometryReader { geo in
                        RoundedRectangle(cornerRadius: 4)
                            .fill(LinearGradient(
                                colors: [Color.lGain, Color.lInk],
                                startPoint: .leading, endPoint: .trailing))
                            .frame(width: max(2, geo.size.width * pct), height: 8)
                    }
                    .frame(height: 8)
                }
                .padding(.horizontal, 18)

                HStack(alignment: .top, spacing: 18) {
                    goalStat(label: "Trend ETA",
                             value: trendETA.map(formatDateLabel) ?? "—",
                             sub: forecast.flatMap { f in
                                 f.cagrPct.map { "\(String(format: "%.1f", $0))% / yr (CAGR)" }
                                     ?? f.slopePerDay.map { "\(Fmt.compact($0 * 30, app.displayCurrency))/mo" }
                             } ?? "Need ≥ 2 snapshots")
                    if let target {
                        goalStat(label: "Target date",
                                 value: formatDateLabel(target),
                                 sub: pacingNote(eta: trendETA, target: target))
                        goalStat(label: "Monthly needed",
                                 value: monthlySavingsNeeded(goal: goal, cur: curTotal, by: target).map {
                                     Fmt.compact($0, app.displayCurrency)
                                 } ?? "—",
                                 sub: cleared ? "Goal reached" : "to hit target by deadline")
                    } else {
                        goalStat(label: "Target date",
                                 value: "—",
                                 sub: "Set in Settings to track pacing")
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 14)
            }
        }
    }

    @ViewBuilder
    private func goalStat(label: String, value: String, sub: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(Typo.eyebrow).tracking(1.2)
                .foregroundStyle(Color.lInk3)
            Text(value)
                .font(Typo.mono(13, weight: .semibold))
                .foregroundStyle(Color.lInk)
            Text(sub)
                .font(Typo.sans(11))
                .foregroundStyle(Color.lInk3)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func formatDateLabel(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMM yyyy"
        return f.string(from: d)
    }

    private func monthlySavingsNeeded(goal: Double, cur: Double, by target: Date) -> Double? {
        guard cur < goal else { return nil }
        let months = Calendar.current.dateComponents([.month], from: Date(), to: target).month ?? 0
        guard months > 0 else { return nil }
        return (goal - cur) / Double(months)
    }

    private func pacingNote(eta: Date?, target: Date) -> String {
        guard let eta else { return "Trend not enough data" }
        let cal = Calendar.current
        let months = cal.dateComponents([.month], from: target, to: eta).month ?? 0
        if months <= 0 {
            return "On track — \(abs(months)) mo ahead of target"
        } else {
            return "Behind — \(months) mo past target"
        }
    }
}

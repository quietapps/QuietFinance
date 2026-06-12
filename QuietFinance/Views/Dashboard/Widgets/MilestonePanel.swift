import SwiftUI

/// On-track/behind status vs goal plus progress to the next round-number
/// milestone. Unlike the goal widget, this shows even without a goal set —
/// the milestone ladder needs none.
struct MilestonePanel: View {
    @EnvironmentObject var app: AppState
    let history: [(Date, Double)]
    let curTotal: Double
    let goal: Double?

    var body: some View {
        if let status = Milestones.compute(history: history,
                                           method: app.forecastMethod,
                                           goal: goal,
                                           goalDate: app.netWorthGoalDate) {
            Panel {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        PanelHead(title: "Milestones",
                                  meta: "next: \(Fmt.compact(status.nextMilestone, app.displayCurrency))")
                            .overlay(alignment: .trailing) { paceBadge(status) }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(Fmt.compact(curTotal, app.displayCurrency))
                                .font(Typo.serifNum(24))
                                .foregroundStyle(Color.lInk)
                                .stealthAmount()
                            Text("→ \(Fmt.compact(status.nextMilestone, app.displayCurrency))")
                                .font(Typo.mono(13))
                                .foregroundStyle(Color.lInk3)
                            Spacer()
                            Text("\(String(format: "%.0f", status.progressToNext * 100))%")
                                .font(Typo.mono(12, weight: .semibold))
                                .foregroundStyle(Color.lInk2)
                        }
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.lSunken)
                                .frame(height: 8)
                            GeometryReader { geo in
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(LinearGradient(colors: [Color.lGain, Color.lInk],
                                                         startPoint: .leading, endPoint: .trailing))
                                    .frame(width: max(2, geo.size.width * status.progressToNext), height: 8)
                            }
                            .frame(height: 8)
                        }
                    }
                    .padding(.horizontal, 18)

                    HStack(alignment: .top, spacing: 22) {
                        stat("NEXT MILESTONE",
                             status.nextMilestoneETA.map(formatDateLabel) ?? "—",
                             sub: "crossing \(Fmt.compact(status.nextMilestone, app.displayCurrency)) on trend")
                        if status.goal != nil {
                            stat("GOAL ETA",
                                 status.goalETA.map(formatDateLabel) ?? "—",
                                 sub: paceText(status))
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 14)
                }
            }
        }
    }

    @ViewBuilder
    private func paceBadge(_ status: Milestones.Status) -> some View {
        if let off = status.monthsOffPace {
            let onTrack = off <= 0
            Pill(text: onTrack ? "On track" : "Behind ~\(off) mo", emphasis: onTrack)
        }
    }

    private func paceText(_ status: Milestones.Status) -> String {
        guard let off = status.monthsOffPace else {
            return status.goalTargetDate == nil ? "no target date set" : "trend not enough data"
        }
        return off <= 0 ? "\(abs(off)) mo ahead of target" : "\(off) mo past target"
    }

    @ViewBuilder
    private func stat(_ label: String, _ value: String, sub: String) -> some View {
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
        }
    }

    private func formatDateLabel(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMM yyyy"
        return f.string(from: d)
    }
}

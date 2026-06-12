import SwiftUI
import SwiftData

/// First-run checklist on the dashboard. Steps are derived live from store
/// state — never persisted — so progress can't go stale. Only the dismissal
/// flag is stored.
struct GettingStartedPanel: View {
    @EnvironmentObject var app: AppState
    @Query private var people: [Person]
    @Query private var accounts: [Account]
    @Query private var snapshots: [Snapshot]

    private struct Step: Identifiable {
        let id: Int
        let title: String
        let subtitle: String
        let done: Bool
        let optional: Bool
        let actionLabel: String
        let action: () -> Void
    }

    private var steps: [Step] {
        [
            Step(id: 1, title: "Add a person",
                 subtitle: "Who owns the accounts — you, a partner, the household.",
                 done: !people.isEmpty, optional: false,
                 actionLabel: "Add person") { app.selectedScreen = .people },
            Step(id: 2, title: "Add an account",
                 subtitle: "An asset or liability: checking, brokerage, loan…",
                 done: !accounts.isEmpty, optional: false,
                 actionLabel: "Add account") {
                     app.newAccountRequested = true
                     app.selectedScreen = .accounts
                 },
            Step(id: 3, title: "Capture your first snapshot",
                 subtitle: "Today's balances, frozen in time. One per quarter keeps the trend honest.",
                 done: !snapshots.isEmpty, optional: false,
                 actionLabel: "New snapshot") {
                     app.newSnapshotRequested = true
                     app.selectedScreen = .snapshots
                 },
            Step(id: 4, title: "Set a net worth goal",
                 subtitle: "Optional — unlocks pacing, ETA, and milestone tracking.",
                 done: app.netWorthGoal > 0, optional: true,
                 actionLabel: "Open Settings") { app.selectedScreen = .settings },
        ]
    }

    private var requiredDone: Int { steps.filter { !$0.optional && $0.done }.count }
    private var requiredTotal: Int { steps.filter { !$0.optional }.count }
    var allRequiredDone: Bool { requiredDone == requiredTotal }

    var body: some View {
        Panel {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("GETTING STARTED")
                            .font(Typo.eyebrow).tracking(1.5)
                            .foregroundStyle(Color.lInk3)
                        Text("\(requiredDone) of \(requiredTotal) done")
                            .font(Typo.serifNum(18))
                            .foregroundStyle(Color.lInk)
                    }
                    Spacer()
                    IconButton(systemName: "xmark") {
                        app.onboardingChecklistDismissed = true
                    }
                    .help("Hide this checklist")
                }
                .padding(.horizontal, 18).padding(.vertical, 14)
                .overlay(Rectangle().frame(height: 1).foregroundStyle(Color.lLine), alignment: .bottom)

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Rectangle().fill(Color.lSunken)
                        Rectangle().fill(Color.lGain.opacity(0.6))
                            .frame(width: geo.size.width * CGFloat(requiredDone) / CGFloat(max(1, requiredTotal)))
                    }
                }
                .frame(height: 3)

                VStack(spacing: 0) {
                    ForEach(steps) { step in
                        stepRow(step)
                        if step.id != steps.last?.id {
                            Divider().overlay(Color.lLine)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func stepRow(_ step: Step) -> some View {
        HStack(spacing: 12) {
            Image(systemName: step.done ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 16))
                .foregroundStyle(step.done ? Color.lGain : Color.lInk4)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(step.title)
                        .font(Typo.sans(13, weight: .medium))
                        .foregroundStyle(step.done ? Color.lInk3 : Color.lInk)
                        .strikethrough(step.done, color: Color.lInk4)
                    if step.optional {
                        Text("OPTIONAL")
                            .font(Typo.eyebrow).tracking(1.0)
                            .foregroundStyle(Color.lInk4)
                    }
                }
                Text(step.subtitle)
                    .font(Typo.sans(11))
                    .foregroundStyle(Color.lInk3)
            }
            Spacer(minLength: 8)
            if !step.done {
                GhostButton(action: step.action) {
                    Text(step.actionLabel)
                }
            }
        }
        .padding(.horizontal, 18).padding(.vertical, 12)
    }
}

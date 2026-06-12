import SwiftUI
import SwiftData

/// First-run welcome: choose between starting with an empty ledger or
/// exploring with demo data. Replaces the old silent demo-data seed.
struct WelcomeSheet: View {
    @EnvironmentObject var app: AppState
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                Text("QUIET FINANCE · WELCOME")
                    .font(Typo.eyebrow).tracking(1.5)
                    .foregroundStyle(Color.lInk3)
                HStack(spacing: 8) {
                    Text("A ledger,")
                        .font(Typo.serifNum(34))
                        .foregroundStyle(Color.lInk)
                    Text("kept quietly.")
                        .font(Typo.serifItalic(34))
                        .foregroundStyle(Color.lInk3)
                }
                Text("Track net worth through dated snapshots of every account — local, private, no cloud. Capture one snapshot a quarter; the charts take care of the rest.")
                    .font(Typo.sans(13))
                    .foregroundStyle(Color.lInk2)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 32).padding(.top, 30).padding(.bottom, 22)

            Divider().overlay(Color.lLine)

            VStack(alignment: .leading, spacing: 14) {
                choiceRow(
                    icon: "square.and.pencil",
                    title: "Start fresh",
                    subtitle: "Empty ledger. A short checklist on the dashboard walks you through your first person, account, and snapshot.",
                    primary: true
                ) {
                    app.welcomeChoiceRaw = "fresh"
                    finish()
                }
                choiceRow(
                    icon: "sparkles",
                    title: "Explore with demo data",
                    subtitle: "A sample household with accounts and two snapshots, so every screen has something to show. Reset anytime in Settings.",
                    primary: false
                ) {
                    SeedData.seedDemo(context: context)
                    app.welcomeChoiceRaw = "demo"
                    finish()
                }
            }
            .padding(.horizontal, 32).padding(.vertical, 22)

            Divider().overlay(Color.lLine)
            HStack {
                Text("100% local · nothing leaves this Mac")
                    .font(Typo.serifItalic(11.5))
                    .foregroundStyle(Color.lInk3)
                Spacer()
                Button("Skip for now") {
                    app.welcomeChoiceRaw = "fresh"
                    finish()
                }
                .buttonStyle(.plain)
                .font(Typo.sans(12))
                .foregroundStyle(Color.lInk3)
                .pointerStyle(.link)
                .keyboardShortcut(.cancelAction)
            }
            .padding(.horizontal, 32).padding(.vertical, 14)
        }
        .background(Color.lBg)
        .frame(width: 560)
    }

    private func finish() {
        app.welcomeCompleted = true
        dismiss()
    }

    @ViewBuilder
    private func choiceRow(icon: String, title: String, subtitle: String,
                           primary: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(primary ? Color.lPanel : Color.lInk2)
                    .frame(width: 40, height: 40)
                    .background(primary ? Color.lInk : Color.lSunken)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(Typo.sans(14, weight: .semibold))
                        .foregroundStyle(Color.lInk)
                    Text(subtitle)
                        .font(Typo.sans(12))
                        .foregroundStyle(Color.lInk3)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.lInk4)
                    .padding(.top, 12)
            }
            .padding(14)
            .background(Color.lPanel)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.lLine, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .contentShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .pointerStyle(.link)
    }
}

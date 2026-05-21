import SwiftUI

/// Overlay that blocks the UI until `gate.authenticate` succeeds. Auto-prompts
/// once on appear; user can retry via button if they cancel.
struct LockScreen: View {
    @ObservedObject var gate: AppLockGate
    @EnvironmentObject var app: AppState
    @State private var didAutoPrompt = false

    var body: some View {
        ZStack {
            Color.lBg.ignoresSafeArea()

            VStack(spacing: 18) {
                Image(app.appIconChoice.assetName)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 120, height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 26))
                    .overlay(RoundedRectangle(cornerRadius: 26).stroke(Color.lLine, lineWidth: 1))
                    .shadow(color: .black.opacity(0.25), radius: 18, y: 6)

                VStack(spacing: 6) {
                    Text("Quiet Finance is locked")
                        .font(Typo.serifNum(28))
                        .foregroundStyle(Color.lInk)
                    Text("Authenticate with Touch ID or your password to continue.")
                        .font(Typo.serifItalic(13))
                        .foregroundStyle(Color.lInk3)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 360)
                }

                PrimaryButton(action: { Task { await prompt() } }) {
                    HStack(spacing: 6) {
                        Image(systemName: "touchid").font(.system(size: 11, weight: .bold))
                        Text("Unlock")
                    }
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(40)
        }
        .onAppear {
            guard !didAutoPrompt else { return }
            didAutoPrompt = true
            Task { await prompt() }
        }
    }

    private func prompt() async {
        await gate.authenticate(reason: "Unlock Quiet Finance to view your finances.")
    }
}

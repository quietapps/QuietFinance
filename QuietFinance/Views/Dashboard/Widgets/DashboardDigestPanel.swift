import SwiftUI

/// One-sentence plain-language summary of the latest period.
struct DashboardDigestPanel: View {
    let sentence: String

    var body: some View {
        if !sentence.isEmpty {
            Panel {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.lInk2)
                        .padding(.top, 1)
                    Text(sentence)
                        .font(Typo.serifItalic(15))
                        .foregroundStyle(Color.lInk)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
                .padding(16)
            }
        }
    }
}

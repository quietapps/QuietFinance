import SwiftUI
import AppKit

// Renders a shareable net-worth card and copies it to the clipboard as PNG.
// Design: white card, brand blue accent, clean tabular numerics.

enum SnapshotShareCard {

    @MainActor
    static func copyToClipboard(
        snapshot: Snapshot,
        prevTotal: Double?,
        displayCurrency: Currency,
        includeIlliquid: Bool
    ) {
        let current = snapshot.totalsValues.reduce(0.0) { sum, v in
            sum + CurrencyConverter.netDisplayValue(for: v, in: displayCurrency, includeIlliquid: includeIlliquid)
        }
        let delta = prevTotal.map { current - $0 }

        let card = ShareCardView(
            label: snapshot.label,
            date: snapshot.date,
            total: current,
            delta: delta,
            currency: displayCurrency
        )
        .environment(\.colorScheme, .light)

        let renderer = ImageRenderer(content: card)
        renderer.scale = 2.0
        renderer.proposedSize = ProposedViewSize(width: 600, height: nil)

        guard let cgImage = renderer.cgImage else { return }
        let nsImage = NSImage(cgImage: cgImage, size: .zero)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects([nsImage])
    }
}

// MARK: - Card view

private struct ShareCardView: View {
    let label: String
    let date: Date
    let total: Double
    let delta: Double?
    let currency: Currency

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header strip
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("NET WORTH")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .tracking(1.6)
                        .foregroundStyle(.white.opacity(0.7))
                    Text(label)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                }
                Spacer()
                Text("quiet finance")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.55))
            }
            .padding(.horizontal, 28).padding(.vertical, 20)
            .background(Color(red: 0.102, green: 0.455, blue: 0.769))

            // Body
            VStack(alignment: .leading, spacing: 18) {
                // Main figure
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(currency.symbol)
                        .font(.system(size: 28, weight: .light, design: .rounded))
                        .foregroundStyle(Color(red: 0.4, green: 0.4, blue: 0.45))
                        .padding(.top, 12)
                    Text(formattedTotal)
                        .font(.system(size: 64, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(red: 0.1, green: 0.11, blue: 0.14))
                        .monospacedDigit()
                        .tracking(-1)
                }

                // Delta pill
                if let delta {
                    let up = delta >= 0
                    HStack(spacing: 6) {
                        Image(systemName: up ? "arrow.up.right" : "arrow.down.right")
                            .font(.system(size: 11, weight: .bold))
                        Text("\(up ? "+" : "−")\(currency.symbol)\(formattedAbs(delta))")
                            .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        Text("vs previous snapshot")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    .foregroundStyle(up ? Color(red: 0.08, green: 0.45, blue: 0.22) : Color(red: 0.65, green: 0.1, blue: 0.1))
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background((up ? Color(red: 0.89, green: 0.97, blue: 0.93) : Color(red: 0.99, green: 0.9, blue: 0.89)))
                    .clipShape(Capsule())
                }

                // Footer
                HStack {
                    Text(formattedDate)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Color(red: 0.55, green: 0.56, blue: 0.6))
                    Spacer()
                    Text("app.quiet.finance")
                        .font(.system(size: 11))
                        .foregroundStyle(Color(red: 0.7, green: 0.71, blue: 0.75))
                }
            }
            .padding(.horizontal, 28).padding(.top, 24).padding(.bottom, 28)
            .background(.white)
        }
        .clipShape(RoundedRectangle(cornerRadius: 0))
        .shadow(color: .black.opacity(0.12), radius: 20, y: 8)
    }

    private var formattedTotal: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        formatter.maximumFractionDigits = 0
        formatter.locale = currency == .INR ? Locale(identifier: "en_IN") : Locale(identifier: "en_US")
        return formatter.string(from: NSNumber(value: total)) ?? "\(Int(total))"
    }

    private func formattedAbs(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: abs(value))) ?? "\(Int(abs(value)))"
    }

    private var formattedDate: String {
        let f = DateFormatter()
        f.dateFormat = "MMMM d, yyyy"
        return f.string(from: date).uppercased()
    }
}

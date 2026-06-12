import SwiftUI

/// Debt accounts with QoQ paydown chips and progress-to-peak bars.
struct LiabilitiesSection: View {
    @EnvironmentObject var app: AppState
    let rows: [LiabilityRow]

    private var totalLiabilities: Double {
        rows.reduce(0) { $0 + $1.currentDisplay }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHead(title: "Liabilities", emphasis: "— what you owe",
                        rightLabel: Fmt.compact(totalLiabilities, app.displayCurrency))
            Panel {
                VStack(spacing: 0) {
                    PanelHead(title: "Debt accounts",
                              meta: "\(rows.count) \(rows.count == 1 ? "account" : "accounts") · total \(Fmt.compact(totalLiabilities, app.displayCurrency))")
                    VStack(spacing: 0) {
                        ForEach(Array(rows.enumerated()), id: \.element.id) { idx, row in
                            liabilityRow(row)
                                .padding(.horizontal, 18).padding(.vertical, 12)
                                .background(idx.isMultiple(of: 2) ? Color.clear : Color.lSunken.opacity(0.5))
                            if idx < rows.count - 1 {
                                Divider().overlay(Color.lLine)
                            }
                        }
                    }
                }
            }
        }
    }

    private func liabilityRow(_ row: LiabilityRow) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(row.color).frame(width: 10, height: 10)
                Text(row.name)
                    .font(Typo.sans(13, weight: .semibold))
                    .foregroundStyle(Color.lInk)
                    .lineLimit(1)
                Spacer(minLength: 8)
                if let d = row.qoqDelta {
                    let paidDown = d < 0
                    HStack(spacing: 4) {
                        Image(systemName: paidDown ? "arrow.down.right" : "arrow.up.right")
                            .font(.system(size: 9, weight: .bold))
                        Text(Fmt.compact(abs(d), app.displayCurrency))
                            .font(Typo.mono(11, weight: .semibold))
                        Text("QoQ")
                            .font(Typo.mono(10))
                            .opacity(0.7)
                    }
                    .foregroundStyle(paidDown ? Color.lGain : Color.lLoss)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background((paidDown ? Color.lGain : Color.lLoss).opacity(0.12))
                    .overlay(Capsule().stroke((paidDown ? Color.lGain : Color.lLoss).opacity(0.3), lineWidth: 1))
                    .clipShape(Capsule())
                }
                Text(Fmt.compact(row.currentDisplay, app.displayCurrency))
                    .font(Typo.sans(13, weight: .semibold))
                    .foregroundStyle(Color.lLoss)
                    .monospacedDigit()
            }
            HStack(spacing: 10) {
                Text("PAID \(String(format: "%.0f", row.paydownPct))%")
                    .font(Typo.eyebrow).tracking(1.2)
                    .foregroundStyle(Color.lInk3)
                    .frame(width: 70, alignment: .leading)
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Rectangle().fill(Color.lSunken)
                        Rectangle().fill(Color.lGain.opacity(0.55))
                            .frame(width: max(0, geo.size.width * CGFloat(row.paydownPct / 100)))
                    }
                }
                .frame(height: 6)
                .clipShape(RoundedRectangle(cornerRadius: 3))
                Text("peak \(Fmt.compact(row.peakDisplay, app.displayCurrency))")
                    .font(Typo.mono(10.5))
                    .foregroundStyle(Color.lInk3)
                    .frame(width: 120, alignment: .trailing)
            }
        }
    }
}

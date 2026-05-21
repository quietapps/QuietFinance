import SwiftUI

struct TreemapTile: Identifiable {
    let id: UUID
    let label: String
    let value: Double
    let color: Color
    let accountID: UUID?
    let nativeValue: Double?
    let nativeCurrency: Currency?
    let isDebt: Bool
    var children: [TreemapTile] = []

    init(id: UUID = UUID(),
         label: String,
         value: Double,
         color: Color,
         accountID: UUID? = nil,
         nativeValue: Double? = nil,
         nativeCurrency: Currency? = nil,
         isDebt: Bool = false,
         children: [TreemapTile] = []) {
        self.id = id
        self.label = label
        self.value = value
        self.color = color
        self.accountID = accountID
        self.nativeValue = nativeValue
        self.nativeCurrency = nativeCurrency
        self.isDebt = isDebt
        self.children = children
    }
}

struct StackedBarsView: View {
    let groups: [TreemapTile]
    let currency: Currency
    let total: Double
    var onTap: (TreemapTile) -> Void
    var onHover: (TreemapTile?) -> Void

    @State private var hoverSegmentID: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(groups) { g in
                groupRow(g)
            }
        }
    }

    @ViewBuilder
    private func groupRow(_ g: TreemapTile) -> some View {
        let groupTotal = g.value
        let pct = total > 0 ? groupTotal / total * 100 : 0
        let signedLabel = g.isDebt ? "−\(Fmt.compact(groupTotal, currency))" : Fmt.compact(groupTotal, currency)
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Button { onTap(g) } label: {
                    HStack(spacing: 8) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(g.color)
                            .frame(width: 10, height: 10)
                            .overlay(
                                g.isDebt
                                ? RoundedRectangle(cornerRadius: 3).stroke(Color.lLoss, lineWidth: 1.2)
                                : nil
                            )
                        Text(g.label)
                            .font(Typo.sans(12.5, weight: .semibold))
                            .foregroundStyle(Color.lInk)
                            .lineLimit(1)
                        if g.isDebt {
                            Text("DEBT")
                                .font(Typo.eyebrow).tracking(1.1)
                                .foregroundStyle(Color.lLoss)
                                .padding(.horizontal, 5).padding(.vertical, 1)
                                .overlay(Capsule().stroke(Color.lLoss.opacity(0.5), lineWidth: 1))
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .pointerStyle(.link)
                .help("Click to filter by \(g.label)")

                Spacer(minLength: 8)

                Text("\(g.children.count) accounts")
                    .font(Typo.mono(10.5))
                    .foregroundStyle(Color.lInk3)
                Text(signedLabel)
                    .font(Typo.mono(12, weight: .semibold))
                    .foregroundStyle(g.isDebt ? Color.lLoss : Color.lInk)
                Text(String(format: "%.1f%%", pct))
                    .font(Typo.mono(11))
                    .foregroundStyle(Color.lInk3)
                    .frame(width: 46, alignment: .trailing)
            }

            bar(for: g)
        }
    }

    @ViewBuilder
    private func bar(for g: TreemapTile) -> some View {
        let segments = g.children.isEmpty
            ? [g]
            : g.children.sorted { $0.value > $1.value }
        let groupTotal = max(g.value, 0.0001)

        GeometryReader { geo in
            let barWidth = geo.size.width
            HStack(spacing: 1) {
                ForEach(Array(segments.enumerated()), id: \.element.id) { idx, seg in
                    let frac = max(seg.value, 0) / groupTotal
                    let w = max(barWidth * frac - 1, 1)
                    segmentView(seg: seg, idx: idx, width: w, barWidth: barWidth)
                }
            }
        }
        .frame(height: 26)
        .clipShape(RoundedRectangle(cornerRadius: 5))
        .overlay(
            RoundedRectangle(cornerRadius: 5)
                .stroke(Color.lLine, lineWidth: 1)
        )
    }

    @ViewBuilder
    private func segmentView(seg: TreemapTile, idx: Int, width: CGFloat, barWidth: CGFloat) -> some View {
        let shade = shadeFactor(idx: idx)
        let isHovered = hoverSegmentID == seg.id
        let labelWidth: CGFloat = width
        let showLabel = labelWidth >= 42
        Rectangle()
            .fill(seg.color.opacity(seg.isDebt ? shade * 0.6 : shade))
            .frame(width: width)
            .overlay(
                Group {
                    if seg.isDebt {
                        DiagonalStripes(spacing: 5, lineWidth: 1, color: Color.black.opacity(0.22))
                    }
                }
            )
            .overlay(
                Group {
                    if showLabel {
                        Text(compactLabel(seg: seg, width: labelWidth))
                            .font(Typo.mono(10, weight: .semibold))
                            .foregroundStyle(legibleInk(on: seg.color.opacity(shade)))
                            .lineLimit(1)
                            .padding(.horizontal, 4)
                    }
                }
            )
            .overlay(
                Rectangle()
                    .stroke(Color.lInk.opacity(isHovered ? 0.5 : 0), lineWidth: 1.5)
            )
            .contentShape(Rectangle())
            .onTapGesture { onTap(seg) }
            .pointerStyle(.link)
            .onHover { inside in
                if inside {
                    hoverSegmentID = seg.id
                    onHover(seg)
                } else if hoverSegmentID == seg.id {
                    hoverSegmentID = nil
                    onHover(nil)
                }
            }
            .help(tooltip(seg: seg, barTotal: barWidth))
    }

    private func shadeFactor(idx: Int) -> Double {
        let steps: [Double] = [1.0, 0.82, 0.66, 0.52, 0.42, 0.34]
        return steps[idx % steps.count]
    }

    private func legibleInk(on _: Color) -> Color {
        Color.black.opacity(0.78)
    }

    private func compactLabel(seg: TreemapTile, width: CGFloat) -> String {
        let sign = seg.isDebt ? "−" : ""
        let amt = "\(sign)\(Fmt.compact(seg.value, currency))"
        if width >= 120 {
            return "\(seg.label) · \(amt)"
        } else if width >= 72 {
            return amt
        } else {
            return seg.label.prefix(3).uppercased() + ""
        }
    }

    private func tooltip(seg: TreemapTile, barTotal: CGFloat) -> String {
        let pct = total > 0 ? seg.value / total * 100 : 0
        let sign = seg.isDebt ? "−" : ""
        return "\(seg.label) · \(sign)\(Fmt.compact(seg.value, currency)) · \(String(format: "%.1f%%", pct))\(seg.isDebt ? " (debt)" : "")"
    }
}

private struct DiagonalStripes: View {
    var spacing: CGFloat = 6
    var lineWidth: CGFloat = 1
    var color: Color = .black.opacity(0.2)

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            Path { p in
                var x: CGFloat = -h
                while x < w + h {
                    p.move(to: CGPoint(x: x, y: h))
                    p.addLine(to: CGPoint(x: x + h, y: 0))
                    x += spacing
                }
            }
            .stroke(color, lineWidth: lineWidth)
        }
        .clipped()
        .allowsHitTesting(false)
    }
}

import SwiftUI

/// Sankey-style flow diagram between two snapshots.
/// Left column: per-account values at snapshot A.
/// Right column: per-account values at snapshot B.
/// Ribbon: same-account flow A→B, color-coded by direction.
/// Synthetic "NEW" source feeds added accounts; "GONE" sink absorbs dropped.
struct SnapshotSankeyView: View {
    let flows: [SankeyFlow]
    let labelA: String
    let labelB: String

    @State private var hoverID: AnyHashable?

    private let barWidth: CGFloat = 14
    private let nodeGap: CGFloat = 4
    private let topPad: CGFloat = 28
    private let bottomPad: CGFloat = 18
    private let sidePad: CGFloat = 96

    var body: some View {
        GeometryReader { geo in
            let layout = computeLayout(size: geo.size)
            ZStack {
                Canvas { ctx, _ in
                    drawRibbons(ctx: ctx, layout: layout)
                    drawNodes(ctx: ctx, layout: layout)
                }
                labelOverlays(layout: layout, size: geo.size)
            }
        }
        .frame(minHeight: max(280, CGFloat(flows.count) * 22))
    }

    // MARK: - Layout

    private struct NodeRect {
        let id: AnyHashable
        let isSource: Bool
        let rect: CGRect
        let value: Double
        let label: String
        let isPseudo: Bool
    }

    private struct Layout {
        var leftNodes: [NodeRect] = []
        var rightNodes: [NodeRect] = []
        var ribbons: [Ribbon] = []
        var leftTotal: Double = 0
        var rightTotal: Double = 0
    }

    private struct Ribbon {
        let leftID: AnyHashable
        let rightID: AnyHashable
        let leftY: CGFloat
        let leftH: CGFloat
        let rightY: CGFloat
        let rightH: CGFloat
        let kind: Kind

        enum Kind { case grew, shrank, flat, added, dropped }
    }

    private func computeLayout(size: CGSize) -> Layout {
        var l = Layout()
        guard size.height > 0, size.width > 0, !flows.isEmpty else { return l }

        // Aggregate node values for each side, including pseudo nodes.
        // Persisting & dropped contribute to leftTotal (their A value).
        // Persisting & added contribute to rightTotal (their B value).
        // To keep heights matched on both sides for visual balance, we set the
        // *displayed* total = max(leftSum, rightSum) and pad the lighter side
        // with a pseudo "balance" segment that draws no ribbon.
        var leftSum: Double = 0
        var rightSum: Double = 0
        for f in flows {
            leftSum  += max(f.valA, 0)
            rightSum += max(f.valB, 0)
        }
        let displayTotal = max(leftSum, rightSum, 1)
        l.leftTotal = leftSum
        l.rightTotal = rightSum

        // Sort: persisting by combined size desc, then dropped, then added.
        let persisting = flows.filter { $0.status == .same }
            .sorted { ($0.valA + $0.valB) > ($1.valA + $1.valB) }
        let dropped = flows.filter { $0.status == .dropped }
            .sorted { $0.valA > $1.valA }
        let added = flows.filter { $0.status == .added }
            .sorted { $0.valB > $1.valB }

        // Left side ordering: persisting (top) -> dropped -> pseudo balance (if leftSum < rightSum)
        // Right side ordering: persisting (top) -> added -> pseudo balance (if rightSum < leftSum)

        let usableH = size.height - topPad - bottomPad
        let leftSideCount = persisting.count + dropped.count + (leftSum < rightSum ? 1 : 0)
        let rightSideCount = persisting.count + added.count + (rightSum < leftSum ? 1 : 0)
        let leftGapTotal  = CGFloat(max(leftSideCount  - 1, 0)) * nodeGap
        let rightGapTotal = CGFloat(max(rightSideCount - 1, 0)) * nodeGap
        let leftAvailH  = max(usableH - leftGapTotal,  0)
        let rightAvailH = max(usableH - rightGapTotal, 0)
        let scaleLeft  = leftAvailH  / displayTotal
        let scaleRight = rightAvailH / displayTotal

        let leftX  = sidePad - barWidth
        let rightX = size.width - sidePad

        // Build left nodes.
        var leftMap: [AnyHashable: NodeRect] = [:]
        var y = topPad
        for f in persisting {
            let h = max(CGFloat(f.valA) * scaleLeft, f.valA > 0 ? 1.0 : 0)
            let rect = CGRect(x: leftX, y: y, width: barWidth, height: h)
            let n = NodeRect(id: f.id, isSource: true, rect: rect,
                             value: f.valA, label: f.name, isPseudo: false)
            l.leftNodes.append(n); leftMap[f.id] = n
            y += h + nodeGap
        }
        for f in dropped {
            let h = max(CGFloat(f.valA) * scaleLeft, 1.0)
            let rect = CGRect(x: leftX, y: y, width: barWidth, height: h)
            let n = NodeRect(id: f.id, isSource: true, rect: rect,
                             value: f.valA, label: f.name, isPseudo: false)
            l.leftNodes.append(n); leftMap[f.id] = n
            y += h + nodeGap
        }
        if leftSum < rightSum {
            let h = CGFloat(rightSum - leftSum) * scaleLeft
            let rect = CGRect(x: leftX, y: y, width: barWidth, height: h)
            l.leftNodes.append(NodeRect(id: "__pad_left__", isSource: true,
                                         rect: rect, value: rightSum - leftSum,
                                         label: "", isPseudo: true))
        }

        // Build right nodes.
        var rightMap: [AnyHashable: NodeRect] = [:]
        y = topPad
        for f in persisting {
            let h = max(CGFloat(f.valB) * scaleRight, f.valB > 0 ? 1.0 : 0)
            let rect = CGRect(x: rightX, y: y, width: barWidth, height: h)
            let n = NodeRect(id: f.id, isSource: false, rect: rect,
                             value: f.valB, label: f.name, isPseudo: false)
            l.rightNodes.append(n); rightMap[f.id] = n
            y += h + nodeGap
        }
        for f in added {
            let h = max(CGFloat(f.valB) * scaleRight, 1.0)
            let rect = CGRect(x: rightX, y: y, width: barWidth, height: h)
            let n = NodeRect(id: f.id, isSource: false, rect: rect,
                             value: f.valB, label: f.name, isPseudo: false)
            l.rightNodes.append(n); rightMap[f.id] = n
            y += h + nodeGap
        }
        if rightSum < leftSum {
            let h = CGFloat(leftSum - rightSum) * scaleRight
            let rect = CGRect(x: rightX, y: y, width: barWidth, height: h)
            l.rightNodes.append(NodeRect(id: "__pad_right__", isSource: false,
                                          rect: rect, value: leftSum - rightSum,
                                          label: "", isPseudo: true))
        }

        // Ribbons.
        for f in persisting {
            guard let lN = leftMap[f.id], let rN = rightMap[f.id] else { continue }
            let kind: Ribbon.Kind = {
                if f.valB > f.valA { return .grew }
                if f.valB < f.valA { return .shrank }
                return .flat
            }()
            l.ribbons.append(Ribbon(
                leftID: f.id, rightID: f.id,
                leftY: lN.rect.minY, leftH: lN.rect.height,
                rightY: rN.rect.minY, rightH: rN.rect.height,
                kind: kind
            ))
        }
        // Added: draw small ribbon from pad-left base to right node, only if pad exists.
        if let padLeft = l.leftNodes.first(where: { $0.id == "__pad_left__" as AnyHashable }) {
            var cursor = padLeft.rect.minY
            for f in added {
                guard let rN = rightMap[f.id] else { continue }
                let portionH = (CGFloat(f.valB) / CGFloat(rightSum - leftSum)) * padLeft.rect.height
                l.ribbons.append(Ribbon(
                    leftID: "__pad_left__", rightID: f.id,
                    leftY: cursor, leftH: portionH,
                    rightY: rN.rect.minY, rightH: rN.rect.height,
                    kind: .added
                ))
                cursor += portionH
            }
        }
        // Dropped: draw to pad-right.
        if let padRight = l.rightNodes.first(where: { $0.id == "__pad_right__" as AnyHashable }) {
            var cursor = padRight.rect.minY
            for f in dropped {
                guard let lN = leftMap[f.id] else { continue }
                let portionH = (CGFloat(f.valA) / CGFloat(leftSum - rightSum)) * padRight.rect.height
                l.ribbons.append(Ribbon(
                    leftID: f.id, rightID: "__pad_right__",
                    leftY: lN.rect.minY, leftH: lN.rect.height,
                    rightY: cursor, rightH: portionH,
                    kind: .dropped
                ))
                cursor += portionH
            }
        }

        return l
    }

    // MARK: - Drawing

    private func drawRibbons(ctx: GraphicsContext, layout: Layout) {
        for r in layout.ribbons {
            let leftNode  = layout.leftNodes.first(where: { $0.id == r.leftID })
            let rightNode = layout.rightNodes.first(where: { $0.id == r.rightID })
            guard let ln = leftNode, let rn = rightNode else { continue }
            let x0 = ln.rect.maxX
            let x1 = rn.rect.minX
            let topL = r.leftY
            let botL = r.leftY + r.leftH
            let topR = r.rightY
            let botR = r.rightY + r.rightH
            let cx0 = x0 + (x1 - x0) * 0.5
            let cx1 = x0 + (x1 - x0) * 0.5

            var path = Path()
            path.move(to: CGPoint(x: x0, y: topL))
            path.addCurve(to: CGPoint(x: x1, y: topR),
                          control1: CGPoint(x: cx0, y: topL),
                          control2: CGPoint(x: cx1, y: topR))
            path.addLine(to: CGPoint(x: x1, y: botR))
            path.addCurve(to: CGPoint(x: x0, y: botL),
                          control1: CGPoint(x: cx1, y: botR),
                          control2: CGPoint(x: cx0, y: botL))
            path.closeSubpath()

            let dim = (hoverID != nil) && hoverID != r.leftID && hoverID != r.rightID
            let alpha: Double = dim ? 0.10 : 0.50
            let color = ribbonColor(r.kind).opacity(alpha)
            ctx.fill(path, with: .color(color))
        }
    }

    private func drawNodes(ctx: GraphicsContext, layout: Layout) {
        for n in layout.leftNodes + layout.rightNodes {
            if n.isPseudo {
                ctx.fill(Path(n.rect), with: .color(Color.lInk3.opacity(0.15)))
            } else {
                ctx.fill(Path(n.rect), with: .color(Color.lInk.opacity(0.85)))
            }
        }
    }

    private func ribbonColor(_ kind: Ribbon.Kind) -> Color {
        switch kind {
        case .grew:    return .lGain
        case .shrank:  return .lLoss
        case .flat:    return .lInk3
        case .added:   return .lGain
        case .dropped: return .lLoss
        }
    }

    // MARK: - Labels

    @ViewBuilder
    private func labelOverlays(layout: Layout, size: CGSize) -> some View {
        ZStack(alignment: .topLeading) {
            // Column headers.
            HStack {
                Text(labelA.uppercased())
                    .font(Typo.eyebrow).tracking(1.2)
                    .foregroundStyle(Color.lInk3)
                    .position(x: sidePad - barWidth / 2, y: 12)
                Spacer()
            }
            HStack {
                Spacer()
                Text(labelB.uppercased())
                    .font(Typo.eyebrow).tracking(1.2)
                    .foregroundStyle(Color.lInk3)
                    .position(x: size.width - sidePad + barWidth / 2, y: 12)
            }

            // Per-node labels.
            ForEach(Array(layout.leftNodes.enumerated()), id: \.offset) { _, n in
                if !n.isPseudo, n.rect.height >= 10 {
                    Text(n.label)
                        .font(Typo.sans(10.5, weight: .medium))
                        .foregroundStyle(Color.lInk2)
                        .lineLimit(1)
                        .frame(width: sidePad - barWidth - 8, alignment: .trailing)
                        .position(x: (sidePad - barWidth - 8) / 2,
                                  y: n.rect.midY)
                }
            }
            ForEach(Array(layout.rightNodes.enumerated()), id: \.offset) { _, n in
                if !n.isPseudo, n.rect.height >= 10 {
                    Text(n.label)
                        .font(Typo.sans(10.5, weight: .medium))
                        .foregroundStyle(Color.lInk2)
                        .lineLimit(1)
                        .frame(width: sidePad - barWidth - 8, alignment: .leading)
                        .position(x: size.width - (sidePad - barWidth - 8) / 2,
                                  y: n.rect.midY)
                }
            }
        }
    }
}

struct SankeyFlow: Identifiable, Equatable {
    let id: UUID
    let name: String
    let valA: Double
    let valB: Double
    let status: Status

    enum Status: Equatable { case same, added, dropped }
}

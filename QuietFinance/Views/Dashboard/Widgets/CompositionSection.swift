import SwiftUI
import Charts

/// Three-panel composition row: by person (donut), by country (stacked bar),
/// by asset type (target-aware rows).
struct CompositionSection: View {
    @EnvironmentObject var app: AppState
    let personItems: [AllocItem]
    let countryItems: [AllocItem]
    let typeItems: [AllocItem]
    let curTotal: Double
    let targets: [AssetCategory: Double]
    let activeLabel: String
    let onOpen: (AllocItem) -> Void
    let onTargetsSaved: () -> Void

    @State private var showingTargets: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHead(title: "Composition", emphasis: "— where it lives",
                        rightLabel: activeLabel + " · " + app.displayCurrency.rawValue)
            HStack(alignment: .top, spacing: 14) {
                personPanel
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                countryPanel
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                typePanel
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var personPanel: some View {
        Panel {
            VStack(spacing: 0) {
                PanelHead(title: "By person", meta: "\(personItems.count) people")
                donutPanel(items: personItems, total: curTotal)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }

    private var countryPanel: some View {
        Panel {
            VStack(spacing: 0) {
                PanelHead(title: "By country", meta: "\(countryItems.count) \(countryItems.count == 1 ? "jurisdiction" : "jurisdictions")")
                VStack(alignment: .leading, spacing: 18) {
                    StackedHBar(items: countryItems.map {
                        StackedHBar.Item(label: $0.label, value: $0.value, color: $0.color)
                    })
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Allocation by country")
                    .accessibilityValue(ChartA11y.allocationSummary(
                        items: countryItems.map { ($0.label, $0.value) }, total: curTotal))
                    VStack(spacing: 0) {
                        ForEach(Array(countryItems.enumerated()), id: \.offset) { _, c in
                            Button {
                                onOpen(c)
                            } label: {
                                AllocRow(
                                    color: c.color, label: c.label,
                                    value: Fmt.compact(c.value, app.displayCurrency),
                                    pct: curTotal == 0 ? 0 : c.value / curTotal * 100
                                )
                            }
                            .buttonStyle(.plain)
                            .pointerStyle(.link)
                            Divider().overlay(Color.lLine)
                        }
                    }
                }
                .padding(18)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }

    private var typePanel: some View {
        Panel {
            VStack(spacing: 0) {
                typePanelHead
                VStack(spacing: 0) {
                    ForEach(Array(typeItems.sorted { abs($0.value) > abs($1.value) }.enumerated()), id: \.offset) { _, t in
                        Button {
                            onOpen(t)
                        } label: {
                            AllocRow(
                                color: t.color, label: t.label,
                                value: Fmt.compact(abs(t.value), app.displayCurrency),
                                pct: curTotal == 0 ? 0 : abs(t.value) / curTotal * 100,
                                showBar: true,
                                valueColor: t.value < 0 ? .lLoss : .lInk,
                                targetPct: targetPct(for: t)
                            )
                        }
                        .buttonStyle(.plain)
                        .pointerStyle(.link)
                        Divider().overlay(Color.lLine)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .sheet(isPresented: $showingTargets) {
            TargetsEditorSheet(onSave: { onTargetsSaved() })
        }
    }

    private var typePanelHead: some View {
        HStack {
            Text("By asset type")
                .font(Typo.sans(14, weight: .semibold))
                .foregroundStyle(Color.lInk)
            Spacer()
            Text(targetSummary)
                .font(Typo.sans(12))
                .foregroundStyle(Color.lInk3)
            GhostButton(action: { showingTargets = true }) {
                HStack(spacing: 4) {
                    Image(systemName: "target").font(.system(size: 10, weight: .semibold))
                    Text(targets.isEmpty ? "Set targets" : "Targets")
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .overlay(Rectangle().frame(height: 1).foregroundStyle(Color.lLine), alignment: .bottom)
    }

    private var targetSummary: String {
        if targets.isEmpty { return "\(typeItems.count) categories" }
        let sum = targets.values.reduce(0, +)
        if abs(sum - 100) < 0.05 { return "\(targets.count) set · balanced" }
        if sum < 100 { return "\(targets.count) set · \(String(format: "%.0f", 100 - sum))% unassigned" }
        return "\(targets.count) set · \(String(format: "%.0f", sum - 100))% over"
    }

    private func targetPct(for item: AllocItem) -> Double? {
        guard let cat = AssetCategory(rawValue: item.matchValue) else { return nil }
        return targets[cat]
    }

    /// Hit-test a point against the donut. Returns the AllocItem under the
    /// click, or nil if outside the ring. Used for tap-to-drilldown without
    /// the noisy hover updates that `.chartAngleSelection` produces on macOS.
    private func sectorAt(_ point: CGPoint, in size: CGSize, items: [AllocItem]) -> AllocItem? {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let dx = point.x - center.x
        let dy = point.y - center.y
        let r = sqrt(dx * dx + dy * dy)
        let outer = min(size.width, size.height) / 2
        let inner = outer * 0.66
        guard r >= inner && r <= outer else { return nil }

        // SwiftUI Charts SectorMark draws clockwise from 12 o'clock.
        var theta = atan2(dx, -dy)
        if theta < 0 { theta += 2 * .pi }

        let total = items.reduce(0.0) { $0 + abs($1.value) }
        guard total > 0 else { return nil }
        let target = theta / (2 * .pi) * total

        var cum = 0.0
        for it in items where abs(it.value) > 0 {
            cum += abs(it.value)
            if target <= cum { return it }
        }
        return items.last
    }

    @ViewBuilder
    private func donutPanel(items: [AllocItem], total: Double) -> some View {
        VStack(spacing: 14) {
            ZStack {
                Chart(items) { i in
                    SectorMark(
                        angle: .value("v", abs(i.value)),
                        innerRadius: .ratio(0.66),
                        angularInset: 1.5
                    )
                    .foregroundStyle(i.color)
                    .cornerRadius(2)
                }
                .frame(width: 180, height: 180)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Allocation donut")
                .accessibilityValue(ChartA11y.allocationSummary(
                    items: items.map { ($0.label, $0.value) }, total: total))
                .chartOverlay { _ in
                    GeometryReader { geo in
                        Rectangle()
                            .fill(Color.clear)
                            .contentShape(Rectangle())
                            .onTapGesture { loc in
                                if let hit = sectorAt(loc, in: geo.size, items: items) {
                                    onOpen(hit)
                                }
                            }
                    }
                }
                VStack(spacing: 4) {
                    Text("TOTAL")
                        .font(Typo.sans(10, weight: .medium))
                        .tracking(1.4)
                        .foregroundStyle(Color.lInk3)
                    Text(Fmt.compact(total, app.displayCurrency))
                        .font(Typo.serifNum(26))
                        .foregroundStyle(Color.lInk)
                        .monospacedDigit()
                        .stealthAmount()
                }
            }
            .padding(.top, 14)
            VStack(spacing: 0) {
                ForEach(items) { i in
                    Button {
                        onOpen(i)
                    } label: {
                        AllocRow(
                            color: i.color, label: i.label,
                            value: Fmt.compact(i.value, app.displayCurrency),
                            pct: total == 0 ? 0 : i.value / total * 100
                        )
                    }
                    .buttonStyle(.plain)
                    .pointerStyle(.link)
                    Divider().overlay(Color.lLine)
                }
            }
        }
        .padding(18)
    }
}

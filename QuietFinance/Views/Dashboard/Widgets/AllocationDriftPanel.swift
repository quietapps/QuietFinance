import SwiftUI

/// Actual vs target allocation per category, drift in both percent and
/// display currency, with a single largest-pair rebalance hint. Reuses the
/// existing TargetAllocationStore + TargetsEditorSheet.
struct AllocationDriftPanel: View {
    @EnvironmentObject var app: AppState
    let typeItems: [AllocItem]
    let targets: [AssetCategory: Double]
    let curTotal: Double
    let onTargetsSaved: () -> Void

    @State private var showingTargets = false

    private struct DriftRow: Identifiable {
        let id: String
        let category: AssetCategory
        let actualPct: Double
        let targetPct: Double
        var driftPct: Double { actualPct - targetPct }
    }

    private var rows: [DriftRow] {
        guard curTotal != 0 else { return [] }
        let actualByCategory: [AssetCategory: Double] = typeItems.reduce(into: [:]) { acc, item in
            if let cat = AssetCategory(rawValue: item.matchValue) {
                acc[cat, default: 0] += abs(item.value)
            }
        }
        return targets
            .map { cat, target in
                DriftRow(id: cat.rawValue,
                         category: cat,
                         actualPct: (actualByCategory[cat] ?? 0) / abs(curTotal) * 100,
                         targetPct: target)
            }
            .sorted { abs($0.driftPct) > abs($1.driftPct) }
    }

    var body: some View {
        let rows = self.rows
        if !rows.isEmpty {
            Panel {
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Text("Allocation drift")
                            .font(Typo.sans(14, weight: .semibold))
                            .foregroundStyle(Color.lInk)
                        Spacer()
                        GhostButton(action: { showingTargets = true }) {
                            HStack(spacing: 4) {
                                Image(systemName: "target").font(.system(size: 10, weight: .semibold))
                                Text("Edit targets")
                            }
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .overlay(Rectangle().frame(height: 1).foregroundStyle(Color.lLine), alignment: .bottom)

                    VStack(spacing: 0) {
                        ForEach(rows) { row in
                            driftRow(row)
                            Divider().overlay(Color.lLine)
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 8)

                    if let hint = rebalanceHint(rows) {
                        Text(hint)
                            .font(Typo.serifItalic(12))
                            .foregroundStyle(Color.lInk2)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, 18)
                            .padding(.bottom, 14)
                            .stealthAmount()
                    }
                }
            }
            .sheet(isPresented: $showingTargets) {
                TargetsEditorSheet(onSave: { onTargetsSaved() })
            }
        }
    }

    @ViewBuilder
    private func driftRow(_ row: DriftRow) -> some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Palette.color(for: row.category))
                .frame(width: 10, height: 10)
            Text(row.category.rawValue)
                .font(Typo.sans(12.5, weight: .medium))
                .foregroundStyle(Color.lInk)
            Spacer()
            Text("\(String(format: "%.1f", row.actualPct))% of \(String(format: "%.0f", row.targetPct))%")
                .font(Typo.mono(11.5))
                .foregroundStyle(Color.lInk2)
            let drift = row.driftPct
            Text("\(drift >= 0 ? "+" : "−")\(String(format: "%.1f", abs(drift)))%")
                .font(Typo.mono(11.5, weight: .semibold))
                .foregroundStyle(abs(drift) < 2 ? Color.lInk3 : (drift > 0 ? Color.lGain : Color.lLoss))
                .frame(width: 60, alignment: .trailing)
        }
        .padding(.vertical, 9)
    }

    /// "Move ~$12k from Cash → Investment to match targets."
    private func rebalanceHint(_ rows: [DriftRow]) -> String? {
        guard let over = rows.filter({ $0.driftPct > 1 }).max(by: { $0.driftPct < $1.driftPct }),
              let under = rows.filter({ $0.driftPct < -1 }).min(by: { $0.driftPct < $1.driftPct })
        else { return nil }
        let amount = min(abs(over.driftPct), abs(under.driftPct)) / 100 * abs(curTotal)
        guard amount > 0 else { return nil }
        return "Move ~\(Fmt.compact(amount, app.displayCurrency)) from \(over.category.rawValue) → \(under.category.rawValue) to match targets."
    }
}

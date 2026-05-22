import SwiftUI

struct YearInReviewSheet: View {
    let snapshots: [Snapshot]
    let displayCurrency: Currency
    let includeIlliquid: Bool

    @Environment(\.dismiss) private var dismiss

    private struct ReviewData {
        let period: String
        let totalChange: Double
        let totalChangePct: Double
        let bestSnapshot: (label: String, total: Double)?
        let worstDropSnapshot: (label: String, delta: Double)?
        let bestGainSnapshot: (label: String, delta: Double)?
        let biggestMoverAccount: (name: String, delta: Double, currency: Currency)?
        let snapshotCount: Int
    }

    private var review: ReviewData? {
        let cutoff = Calendar.current.date(byAdding: .year, value: -1, to: Date()) ?? Date()
        let period = snapshots
            .filter { $0.date >= cutoff }
            .sorted { $0.date < $1.date }
        guard period.count >= 2 else { return nil }

        func tot(_ s: Snapshot) -> Double {
            s.totalsValues.reduce(0) {
                $0 + CurrencyConverter.netDisplayValue(for: $1, in: displayCurrency, includeIlliquid: includeIlliquid)
            }
        }

        let totals: [(Snapshot, Double)] = period.map { ($0, tot($0)) }
        let firstTotal = totals.first!.1
        let lastTotal  = totals.last!.1
        let totalChange = lastTotal - firstTotal
        let totalChangePct = firstTotal != 0 ? totalChange / abs(firstTotal) * 100 : 0

        // Best snapshot (highest total)
        let best = totals.max { $0.1 < $1.1 }.map { ($0.0.label, $0.1) }

        // QoQ deltas
        var deltas: [(label: String, delta: Double)] = []
        for i in 1..<totals.count {
            let d = totals[i].1 - totals[i - 1].1
            deltas.append((totals[i].0.label, d))
        }
        let bestGain  = deltas.max  { $0.delta < $1.delta }
        let worstDrop = deltas.min  { $0.delta < $1.delta }.flatMap { $0.delta < 0 ? $0 : nil }

        // Biggest mover account (largest absolute change first vs last snapshot)
        var accountMovers: [(name: String, delta: Double, currency: Currency)] = []
        let firstSnap = period.first!
        let lastSnap  = period.last!
        for v in lastSnap.totalsValues {
            guard let acc = v.account else { continue }
            if let prev = firstSnap.values.first(where: { $0.account?.id == acc.id }) {
                let delta = CurrencyConverter.displayValue(for: v, in: displayCurrency)
                          - CurrencyConverter.displayValue(for: prev, in: displayCurrency)
                accountMovers.append((acc.name, delta, acc.nativeCurrency))
            }
        }
        let biggestMover = accountMovers.max { abs($0.delta) < abs($1.delta) }

        let f = DateFormatter(); f.dateFormat = "MMM yyyy"
        let periodStr = "\(f.string(from: period.first!.date)) – \(f.string(from: period.last!.date))"

        return ReviewData(
            period: periodStr,
            totalChange: totalChange,
            totalChangePct: totalChangePct,
            bestSnapshot: best,
            worstDropSnapshot: worstDrop,
            bestGainSnapshot: bestGain,
            biggestMoverAccount: biggestMover,
            snapshotCount: period.count
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("YEAR IN REVIEW")
                        .font(Typo.eyebrow).tracking(1.5)
                        .foregroundStyle(Color.lInk3)
                    Text("Trailing 12 months")
                        .font(Typo.serifNum(22))
                        .foregroundStyle(Color.lInk)
                }
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.lInk3)
                }
                .buttonStyle(.plain)
                .pointerStyle(.link)
            }
            .padding(.horizontal, 28).padding(.top, 24).padding(.bottom, 20)
            .overlay(Rectangle().frame(height: 1).foregroundStyle(Color.lLine), alignment: .bottom)

            if let r = review {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        // Period + snapshot count
                        HStack(spacing: 4) {
                            Text(r.period)
                                .font(Typo.mono(11, weight: .medium))
                                .foregroundStyle(Color.lInk2)
                            Text("·")
                                .foregroundStyle(Color.lInk4)
                            Text("\(r.snapshotCount) snapshots")
                                .font(Typo.mono(11))
                                .foregroundStyle(Color.lInk3)
                        }
                        .padding(.top, 4)

                        // Year total change — headline stat
                        Panel {
                            VStack(alignment: .leading, spacing: 0) {
                                PanelHead(title: "Net change", meta: r.period)
                                HStack(alignment: .firstTextBaseline, spacing: 10) {
                                    let up = r.totalChange >= 0
                                    Text("\(up ? "+" : "−")\(Fmt.compact(abs(r.totalChange), displayCurrency))")
                                        .font(Typo.serifNum(40))
                                        .foregroundStyle(up ? Color.lGain : Color.lLoss)
                                        .stealthAmount()
                                    Text(String(format: "%+.1f%%", r.totalChangePct))
                                        .font(Typo.mono(16, weight: .semibold))
                                        .foregroundStyle((up ? Color.lGain : Color.lLoss).opacity(0.8))
                                }
                                .padding(.horizontal, 18).padding(.bottom, 18).padding(.top, 10)
                            }
                        }

                        // 2-column grid of stats
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                            if let best = r.bestSnapshot {
                                statCard(
                                    icon: "crown",
                                    label: "Highest net worth",
                                    value: Fmt.compact(best.total, displayCurrency),
                                    sub: best.label,
                                    color: .lGain
                                )
                            }
                            if let gain = r.bestGainSnapshot {
                                statCard(
                                    icon: "arrow.up.right",
                                    label: "Best quarter",
                                    value: "+\(Fmt.compact(gain.delta, displayCurrency))",
                                    sub: gain.label,
                                    color: .lGain
                                )
                            }
                            if let drop = r.worstDropSnapshot {
                                statCard(
                                    icon: "arrow.down.right",
                                    label: "Worst quarter",
                                    value: "−\(Fmt.compact(abs(drop.delta), displayCurrency))",
                                    sub: drop.label,
                                    color: .lLoss
                                )
                            }
                            if let mover = r.biggestMoverAccount {
                                let up = mover.delta >= 0
                                statCard(
                                    icon: "bolt",
                                    label: "Biggest mover",
                                    value: "\(up ? "+" : "−")\(Fmt.compact(abs(mover.delta), displayCurrency))",
                                    sub: mover.name,
                                    color: up ? .lGain : .lLoss
                                )
                            }
                        }
                    }
                    .padding(28)
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "calendar.badge.exclamationmark")
                        .font(.system(size: 32))
                        .foregroundStyle(Color.lInk3)
                    Text("Need at least 2 snapshots in the trailing 12 months.")
                        .font(Typo.serifItalic(14))
                        .foregroundStyle(Color.lInk3)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(40)
            }
        }
        .background(Color.lBg)
        .frame(minWidth: 520, minHeight: 480)
    }

    @ViewBuilder
    private func statCard(icon: String, label: String, value: String, sub: String, color: Color) -> some View {
        Panel {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: icon)
                        .font(.system(size: 11))
                        .foregroundStyle(color)
                    Text(label.uppercased())
                        .font(Typo.eyebrow).tracking(1.2)
                        .foregroundStyle(Color.lInk3)
                }
                Text(value)
                    .font(Typo.serifNum(22))
                    .foregroundStyle(color)
                    .stealthAmount()
                Text(sub)
                    .font(Typo.mono(11))
                    .foregroundStyle(Color.lInk3)
            }
            .padding(16)
        }
    }
}

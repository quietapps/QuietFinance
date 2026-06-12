import SwiftUI
import Charts

/// Oversized net-worth figure with compare picker, delta chip, sparkline,
/// anomaly banner, and the Year-in-Review entry point.
struct DashboardHeroPanel: View {
    @EnvironmentObject var app: AppState
    let active: Snapshot?
    let snapshots: [Snapshot]
    let curTotal: Double
    let prevTotal: Double
    let yaTotal: Double
    let hasPrev: Bool
    let hasYearAgo: Bool
    let trajectory: [TrajectoryPoint]
    let goal: Double?
    let anomaly: AnomalyFlag?

    @State private var showingYearInReview: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Eyebrow + compare picker on same row.
            HStack(spacing: 8) {
                Circle().fill(Color.lInk).frame(width: 5, height: 5)
                Text("NET WORTH · \(active?.label ?? "—")")
                    .font(Typo.eyebrow)
                    .tracking(1.5)
                    .foregroundStyle(Color.lInk3)
                Spacer(minLength: 0)
                compareSegment
            }
            .padding(.bottom, 14)

            // Oversized monospaced figure with inline delta chip.
            HStack(alignment: .firstTextBaseline, spacing: 14) {
                HStack(alignment: .top, spacing: 4) {
                    Text(app.displayCurrency.symbol)
                        .font(Typo.serifNum(56))
                        .foregroundStyle(Color.lInk3)
                        .padding(.top, 24)
                    Text(Fmt.groupedInt(curTotal,
                                        locale: app.displayCurrency == .INR
                                            ? .init(identifier: "en_IN")
                                            : .init(identifier: "en_US")))
                        .font(Typo.serifNum(96))
                        .foregroundStyle(Color.lInk)
                        .monospacedDigit()
                        .tracking(-1.5)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
                .stealthAmount()

                inlineDeltaChip
                    .stealthAmount()

                Spacer(minLength: 0)
            }
            .padding(.bottom, 16)

            // Embedded sparkline — thin, full-width.
            embeddedSparkline
                .frame(height: 56)
                .padding(.bottom, 14)

            if let s = active {
                Text(footnote(for: s))
                    .font(Typo.serifItalic(13))
                    .foregroundStyle(Color.lInk2)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let flag = anomaly {
                anomalyBanner(flag)
            }

            if let s = active {
                let missing = CurrencyConverter.unconvertibleCount(s, in: app.displayCurrency)
                if missing > 0 {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 10, weight: .semibold))
                        Text("\(missing) \(missing == 1 ? "value" : "values") not converted — missing exchange rate. Open the snapshot to fix.")
                            .font(Typo.sans(11))
                    }
                    .foregroundStyle(Color.lLoss)
                    .padding(.top, 8)
                }
            }

            HStack {
                Spacer()
                Button {
                    showingYearInReview = true
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "calendar.badge.clock")
                            .font(.system(size: 10))
                        Text("Year in review")
                            .font(Typo.sans(11))
                    }
                    .foregroundStyle(Color.lInk3)
                }
                .buttonStyle(.plain)
                .pointerStyle(.link)
                .disabled(snapshots.count < 2)
                .opacity(snapshots.count < 2 ? 0.4 : 1)
            }
        }
        .padding(24)
        .background(Color.lPanel)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.lLine, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .sheet(isPresented: $showingYearInReview) {
            YearInReviewSheet(snapshots: snapshots,
                              displayCurrency: app.displayCurrency,
                              includeIlliquid: app.includeIlliquidInNetWorth)
        }
    }

    @ViewBuilder
    private func anomalyBanner(_ flag: AnomalyFlag) -> some View {
        HStack(spacing: 10) {
            Image(systemName: flag.isGain ? "arrow.up.right.circle.fill" : "arrow.down.right.circle.fill")
                .font(.system(size: 14))
                .foregroundStyle(flag.isGain ? Color.lGain : Color.lLoss)
            VStack(alignment: .leading, spacing: 1) {
                Text(flag.isGain ? "Unusual gain this period" : "Unusual drop this period")
                    .font(Typo.sans(12, weight: .semibold))
                    .foregroundStyle(Color.lInk)
                Text(String(format: "%.1f%% change — %.1fσ from your historical average. Worth a second look.", flag.deltaPct, flag.sigmas))
                    .font(Typo.sans(11))
                    .foregroundStyle(Color.lInk3)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background((flag.isGain ? Color.lGainSoft : Color.lLossSoft).opacity(0.35))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(
            (flag.isGain ? Color.lGain : Color.lLoss).opacity(0.25), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding(.top, 8)
    }

    @ViewBuilder
    private var compareSegment: some View {
        let opts: [(String, AppState.CompareMode)] =
            AppState.CompareMode.allCases.map { ($0.label, $0) }
        SegControl(
            options: opts,
            selection: Binding(
                get: { app.dashboardCompareMode },
                set: { app.dashboardCompareMode = $0 }
            )
        )
    }

    private var compareReferenceTotal: Double? {
        switch app.dashboardCompareMode {
        case .previous: return hasPrev ? prevTotal : nil
        case .yearAgo:  return hasYearAgo ? yaTotal : nil
        }
    }

    @ViewBuilder
    private var inlineDeltaChip: some View {
        if let ref = compareReferenceTotal {
            let delta = curTotal - ref
            let p = ref == 0 ? 0 : delta / abs(ref) * 100
            let up = delta >= 0
            HStack(spacing: 6) {
                Image(systemName: up ? "arrow.up.right" : "arrow.down.right")
                    .font(.system(size: 11, weight: .bold))
                Text("\(up ? "+" : "−")\(Fmt.compact(abs(delta), app.displayCurrency))")
                    .font(Typo.mono(13, weight: .semibold))
                    .monospacedDigit()
                Text("\(up ? "+" : "−")\(String(format: "%.1f", abs(p)))%")
                    .font(Typo.mono(11))
                    .foregroundStyle(.secondary)
                Text(app.dashboardCompareMode.shortLabel)
                    .font(Typo.eyebrow).tracking(1.0)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10).padding(.vertical, 6)
            .foregroundStyle(up ? Color.lGain : Color.lLoss)
            .background((up ? Color.lGain : Color.lLoss).opacity(0.10))
            .overlay(Capsule().stroke((up ? Color.lGain : Color.lLoss).opacity(0.35), lineWidth: 1))
            .clipShape(Capsule())
        } else {
            Text("No prior snapshot")
                .font(Typo.eyebrow).tracking(1.0)
                .foregroundStyle(Color.lInk3)
                .padding(.horizontal, 10).padding(.vertical, 6)
                .overlay(Capsule().stroke(Color.lLine, lineWidth: 1))
                .clipShape(Capsule())
        }
    }

    @ViewBuilder
    private var embeddedSparkline: some View {
        let chartColor = app.useModernDesign ? Color.lAccent : Color.lInk
        Chart(trajectory) { pt in
            AreaMark(x: .value("Date", pt.date), y: .value("Val", pt.val))
                .foregroundStyle(.linearGradient(
                    colors: [chartColor.opacity(0.18), chartColor.opacity(0.02)],
                    startPoint: .top, endPoint: .bottom))
                .interpolationMethod(.catmullRom)
            LineMark(x: .value("Date", pt.date), y: .value("Val", pt.val))
                .foregroundStyle(chartColor)
                .lineStyle(StrokeStyle(lineWidth: 1.4, lineCap: .round, lineJoin: .round))
                .interpolationMethod(.catmullRom)
            if let goal {
                RuleMark(y: .value("Goal", goal))
                    .foregroundStyle(Color.lGain.opacity(0.7))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
    }

    private func footnote(for s: Snapshot) -> String {
        let accCount = Set(s.values.compactMap { $0.account?.id }).count
        let countries = Set(s.values.compactMap { $0.account?.country?.name }).count
        let people = Set(s.values.compactMap { $0.account?.person?.name })
        let peopleStr = people.sorted().joined(separator: " & ")
        var note = "Across \(accCount) accounts in \(countries) \(countries == 1 ? "country" : "countries"), held by \(peopleStr). Last updated \(s.label)"
        let used = s.currenciesInUse
        if !used.isEmpty {
            let rates = used
                .compactMap { c in s.rate(for: c).map { "\(c.rawValue) \(String(format: "%.2f", $0))" } }
                .joined(separator: " · ")
            if !rates.isEmpty { note += " · rates per $1: \(rates)" }
        }
        return note + "."
    }
}

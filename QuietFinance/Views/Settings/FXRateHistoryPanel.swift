import SwiftUI
import Charts

struct FXRateHistoryPanel: View {
    let snapshots: [Snapshot]
    @State private var hovered: RatePoint?

    struct RatePoint: Identifiable, Equatable {
        let id = UUID()
        let date: Date
        let label: String
        let rate: Double
    }

    private var series: [RatePoint] {
        snapshots.sorted { $0.date < $1.date }.map {
            RatePoint(date: $0.date, label: $0.label, rate: $0.usdToInrRate)
        }
    }

    var body: some View {
        Panel {
            VStack(spacing: 0) {
                PanelHead(title: "USD → INR", meta: meta)
                content
            }
        }
    }

    private var meta: String {
        guard !series.isEmpty else { return "no snapshots" }
        return "\(series.count) \(series.count == 1 ? "point" : "points")"
    }

    @ViewBuilder
    private var content: some View {
        if series.isEmpty {
            Text("Add a snapshot to begin charting exchange rate history.")
                .font(Typo.serifItalic(13))
                .foregroundStyle(Color.lInk3)
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else if series.count == 1, let only = series.first {
            singlePointView(only)
        } else {
            VStack(alignment: .leading, spacing: 14) {
                stats
                chart
                footnote
            }
            .padding(18)
        }
    }

    private func singlePointView(_ p: RatePoint) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("₹")
                    .font(Typo.serifNum(20))
                    .foregroundStyle(Color.lInk3)
                Text(String(format: "%.4f", p.rate))
                    .font(Typo.serifNum(32))
                    .foregroundStyle(Color.lInk)
                    .monospacedDigit()
                Text("/ $1")
                    .font(Typo.sans(12))
                    .foregroundStyle(Color.lInk3)
            }
            Text("One snapshot on file · \(p.label). Add another to see trend.")
                .font(Typo.serifItalic(12))
                .foregroundStyle(Color.lInk3)
        }
        .padding(18)
    }

    private var stats: some View {
        let rates = series.map { $0.rate }
        let cur = series.last!.rate
        let first = series.first!.rate
        let hi = rates.max()!
        let lo = rates.min()!
        let avg = rates.reduce(0, +) / Double(rates.count)
        let drift = first == 0 ? 0 : (cur - first) / first * 100
        return HStack(alignment: .top, spacing: 18) {
            stat("CURRENT", String(format: "₹%.4f", cur), emphasize: true)
            stat("RANGE", String(format: "%.2f – %.2f", lo, hi))
            stat("AVG", String(format: "₹%.4f", avg))
            stat("DRIFT", String(format: "%@%.2f%%",
                                 drift >= 0 ? "+" : "−", abs(drift)),
                 tint: drift >= 0 ? .lGain : .lLoss)
        }
    }

    private func stat(_ label: String, _ value: String, emphasize: Bool = false, tint: Color = .lInk) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(Typo.eyebrow).tracking(1.2)
                .foregroundStyle(Color.lInk3)
            Text(value)
                .font(emphasize ? Typo.serifNum(18) : Typo.mono(13, weight: .semibold))
                .foregroundStyle(tint)
                .monospacedDigit()
        }
    }

    private var chart: some View {
        Chart {
            ForEach(series) { p in
                AreaMark(
                    x: .value("Date", p.date),
                    y: .value("Rate", p.rate)
                )
                .foregroundStyle(
                    .linearGradient(colors: [Color.lInk.opacity(0.18), Color.lInk.opacity(0.02)],
                                    startPoint: .top, endPoint: .bottom)
                )
                .interpolationMethod(.monotone)
                LineMark(
                    x: .value("Date", p.date),
                    y: .value("Rate", p.rate)
                )
                .foregroundStyle(Color.lInk)
                .lineStyle(StrokeStyle(lineWidth: 1.4, lineCap: .round, lineJoin: .round))
                .interpolationMethod(.monotone)
            }
            if let h = hovered {
                RuleMark(x: .value("Date", h.date))
                    .foregroundStyle(Color.lInk3.opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    .annotation(
                        position: .automatic,
                        alignment: .center,
                        spacing: 4,
                        overflowResolution: .init(x: .fit(to: .chart), y: .fit(to: .chart))
                    ) { tooltip(for: h) }
                PointMark(
                    x: .value("Date", h.date),
                    y: .value("Rate", h.rate)
                )
                .foregroundStyle(Color.lInk)
                .symbolSize(90)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { _ in
                AxisGridLine().foregroundStyle(Color.lLine.opacity(0.5))
                AxisValueLabel()
                    .font(Typo.mono(10))
                    .foregroundStyle(Color.lInk3)
            }
        }
        .chartXAxis {
            AxisMarks { _ in
                AxisGridLine().foregroundStyle(Color.lLine.opacity(0.3))
                AxisValueLabel(format: .dateTime.month(.abbreviated).year(.twoDigits))
                    .font(Typo.mono(10))
                    .foregroundStyle(Color.lInk3)
            }
        }
        .chartOverlay { proxy in
            GeometryReader { geo in
                Rectangle().fill(Color.clear).contentShape(Rectangle())
                    .onContinuousHover { phase in
                        switch phase {
                        case .active(let loc):
                            guard let plotFrame = proxy.plotFrame else { hovered = nil; return }
                            let origin = geo[plotFrame].origin
                            let x = loc.x - origin.x
                            guard let date: Date = proxy.value(atX: x) else { hovered = nil; return }
                            hovered = nearest(to: date)
                        case .ended:
                            hovered = nil
                        }
                    }
            }
        }
        .frame(height: 140)
    }

    private func nearest(to date: Date) -> RatePoint? {
        series.min(by: {
            abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date))
        })
    }

    private func tooltip(for p: RatePoint) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(p.label)
                .font(Typo.eyebrow).tracking(1.2)
                .foregroundStyle(Color.lInk3)
            Text(String(format: "₹%.4f", p.rate))
                .font(Typo.mono(12, weight: .semibold))
                .foregroundStyle(Color.lInk)
                .monospacedDigit()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color.lPanel)
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.lLine, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .shadow(color: .black.opacity(0.08), radius: 6, y: 2)
    }

    private var footnote: some View {
        Text("Rates frozen at snapshot time. Edit a snapshot to correct its rate.")
            .font(Typo.serifItalic(11))
            .foregroundStyle(Color.lInk3)
    }
}

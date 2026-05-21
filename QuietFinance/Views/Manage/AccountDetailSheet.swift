import SwiftUI
import SwiftData
import Charts

struct AccountDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var app: AppState
    @Query(sort: \Snapshot.date, order: .forward) private var snapshots: [Snapshot]
    let account: Account

    private var seriesColor: Color {
        if let cat = account.assetType?.category { return Palette.color(for: cat) }
        return Color.lInk
    }
    @State private var editing: Account?

    private struct Point: Identifiable {
        let id = UUID()
        let date: Date
        let label: String
        let native: Double
        let display: Double
        let snapshotID: UUID
    }

    private var ccy: Currency { app.displayCurrency }
    private var native: Currency { account.nativeCurrency }

    private var series: [Point] {
        snapshots.compactMap { s -> Point? in
            guard let v = s.values.first(where: { $0.account?.id == account.id }) else { return nil }
            let display = CurrencyConverter.convert(
                nativeValue: v.nativeValue,
                from: account.nativeCurrency,
                to: ccy,
                usdToInrRate: s.usdToInrRate
            )
            return Point(date: s.date, label: s.label, native: v.nativeValue, display: display, snapshotID: s.id)
        }
    }

    private var first: Point? { series.first }
    private var last: Point? { series.last }
    private var lifetimeDelta: Double? {
        guard let f = first, let l = last else { return nil }
        return l.display - f.display
    }
    private var lifetimePct: Double {
        guard let f = first, let l = last, f.display != 0 else { return 0 }
        return (l.display - f.display) / abs(f.display)
    }
    private var cagr: Double {
        guard let f = first, let l = last, f.display > 0, l.display > 0 else { return 0 }
        let years = max(1.0/12.0, l.date.timeIntervalSince(f.date) / (365.25 * 86400))
        return pow(l.display / f.display, 1.0 / years) - 1.0
    }
    private var qoqDelta: Double? {
        guard series.count >= 2 else { return nil }
        return series[series.count - 1].display - series[series.count - 2].display
    }
    private var peak: Point? { series.max(by: { $0.display < $1.display }) }
    private var trough: Point? { series.min(by: { $0.display < $1.display }) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    summaryStats
                    chartPanel
                    metaPanel
                    historyPanel
                }
                .padding(20)
            }
            Divider().overlay(Color.lLine)
            footer
        }
        .background(Color.lBg)
        .frame(minWidth: 920, minHeight: 680)
        .sheet(item: $editing) { _ in
            AccountEditorSheet(existing: account)
        }
        .overlay(alignment: .topLeading) {
            Button("") { dismiss() }
                .keyboardShortcut(.cancelAction)
                .hidden()
                .frame(width: 0, height: 0)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("ACCOUNT · DETAIL")
                    .font(Typo.eyebrow).tracking(1.5)
                    .foregroundStyle(Color.lInk3)
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Circle().fill(account.assetType.map { Palette.color(for: $0.category) } ?? .lInk3)
                        .frame(width: 9, height: 9)
                    Text(account.name)
                        .font(Typo.serifNum(28))
                        .foregroundStyle(Color.lInk)
                    if !account.isActive {
                        Pill(text: "ARCHIVED", emphasis: false)
                    }
                    if AccountAnalysis.isStale(account) {
                        Text("STALE · \(AccountAnalysis.unchangedStreak(account)) snapshots unchanged")
                            .font(Typo.eyebrow).tracking(1.2)
                            .foregroundStyle(Color.lLoss)
                            .padding(.horizontal, 7).padding(.vertical, 3)
                            .overlay(Capsule().stroke(Color.lLoss.opacity(0.5), lineWidth: 1))
                    }
                }
                Text(metaLine)
                    .font(Typo.mono(11))
                    .foregroundStyle(Color.lInk3)
            }
            Spacer()
            HStack(spacing: 6) {
                GhostButton(action: { editing = account }) {
                    HStack(spacing: 5) {
                        Image(systemName: "pencil").font(.system(size: 10, weight: .bold))
                        Text("Edit")
                    }
                }
                GhostButton(action: { dismiss() }) { Text("Close") }
            }
        }
        .padding(20)
        .overlay(Rectangle().frame(height: 1).foregroundStyle(Color.lLine), alignment: .bottom)
    }

    private var metaLine: String {
        var parts: [String] = []
        if let p = account.person?.name { parts.append("👤 \(p)") }
        if let c = account.country { parts.append("\(c.flag) \(c.name)") }
        if let t = account.assetType { parts.append("📊 \(t.name) · \(t.category.rawValue)") }
        parts.append("💰 native \(native.rawValue)")
        if !account.institution.isEmpty { parts.append("📍 \(account.institution)") }
        if !account.groupName.isEmpty { parts.append("📁 \(account.groupName)") }
        return parts.joined(separator: " · ")
    }

    // MARK: - Summary stats

    private var summaryStats: some View {
        HStack(alignment: .top, spacing: 14) {
            stat("CURRENT",
                 last.map { Fmt.currency($0.display, ccy) } ?? "—",
                 last.map { Fmt.compact($0.native, native) } ?? "—",
                 emphasize: true)
            stat("LIFETIME Δ",
                 lifetimeDelta.map { Fmt.signedDelta($0, ccy) } ?? "—",
                 lifetimeDelta == nil ? "" : Fmt.percent(lifetimePct, fractionDigits: 2),
                 tint: (lifetimeDelta ?? 0) >= 0 ? .lGain : .lLoss)
            stat("CAGR",
                 cagr == 0 ? "—" : Fmt.percent(cagr, fractionDigits: 2),
                 series.count >= 2 ? "\(series.count) pts" : "",
                 tint: cagr >= 0 ? .lGain : .lLoss)
            stat("QoQ",
                 qoqDelta.map { Fmt.signedDelta($0, ccy) } ?? "—",
                 "",
                 tint: (qoqDelta ?? 0) >= 0 ? .lGain : .lLoss)
            stat("PEAK",
                 peak.map { Fmt.compact($0.display, ccy) } ?? "—",
                 peak?.label ?? "")
            stat("TROUGH",
                 trough.map { Fmt.compact($0.display, ccy) } ?? "—",
                 trough?.label ?? "")
        }
    }

    private func stat(_ eyebrow: String, _ primary: String, _ secondary: String, tint: Color = .lInk, emphasize: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(eyebrow)
                .font(Typo.eyebrow).tracking(1.2).foregroundStyle(Color.lInk3)
            Text(primary)
                .font(emphasize ? Typo.serifNum(22) : Typo.serifNum(16))
                .foregroundStyle(tint)
                .monospacedDigit()
            if !secondary.isEmpty {
                Text(secondary)
                    .font(Typo.mono(10))
                    .foregroundStyle(Color.lInk3)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.lLine, lineWidth: 1))
    }

    // MARK: - Chart

    private var chartPanel: some View {
        Panel {
            VStack(spacing: 0) {
                PanelHead(title: "Trajectory", meta: series.count >= 2 ? "\(series.count) snapshots" : "")
                Group {
                    if series.count >= 2 {
                        Chart {
                            ForEach(series) { p in
                                AreaMark(x: .value("Date", p.date), y: .value("Value", p.display))
                                    .foregroundStyle(.linearGradient(colors: [seriesColor.opacity(0.25), seriesColor.opacity(0.02)],
                                                                     startPoint: .top, endPoint: .bottom))
                                    .interpolationMethod(.monotone)
                                LineMark(x: .value("Date", p.date), y: .value("Value", p.display))
                                    .foregroundStyle(seriesColor)
                                    .lineStyle(StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
                                    .interpolationMethod(.monotone)
                                PointMark(x: .value("Date", p.date), y: .value("Value", p.display))
                                    .foregroundStyle(seriesColor)
                                    .symbolSize(28)
                            }
                        }
                        .chartYAxis {
                            AxisMarks(position: .leading) { _ in
                                AxisGridLine().foregroundStyle(Color.lLine.opacity(0.4))
                                AxisValueLabel().font(Typo.mono(10)).foregroundStyle(Color.lInk3)
                            }
                        }
                        .chartXAxis {
                            AxisMarks { _ in
                                AxisGridLine().foregroundStyle(Color.lLine.opacity(0.3))
                                AxisValueLabel(format: .dateTime.month(.abbreviated).year(.twoDigits))
                                    .font(Typo.mono(10)).foregroundStyle(Color.lInk3)
                            }
                        }
                        .frame(height: 180)
                        .padding(18)
                    } else {
                        Text("Need at least 2 snapshots with this account to chart.")
                            .font(Typo.serifItalic(12))
                            .foregroundStyle(Color.lInk3)
                            .padding(18)
                    }
                }
            }
        }
    }

    // MARK: - Meta

    private var metaPanel: some View {
        Panel {
            VStack(spacing: 0) {
                PanelHead(title: "Details")
                VStack(alignment: .leading, spacing: 0) {
                    metaRow("Owner", account.person?.name ?? "—")
                    Divider().overlay(Color.lLine)
                    metaRow("Country", account.country.map { "\($0.flag) \($0.name)" } ?? "—")
                    Divider().overlay(Color.lLine)
                    metaRow("Asset type", account.assetType.map { "\($0.name) · \($0.category.rawValue)" } ?? "—")
                    Divider().overlay(Color.lLine)
                    metaRow("Native currency", native.rawValue)
                    Divider().overlay(Color.lLine)
                    metaRow("Institution", account.institution.isEmpty ? "—" : account.institution)
                    Divider().overlay(Color.lLine)
                    metaRow("Group", account.groupName.isEmpty ? "—" : account.groupName)
                    Divider().overlay(Color.lLine)
                    metaRow("Status", account.isActive ? "Active" : "Archived")
                    if !account.notes.isEmpty {
                        Divider().overlay(Color.lLine)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("NOTES").font(Typo.eyebrow).tracking(1.2).foregroundStyle(Color.lInk3)
                            Text(account.notes).font(Typo.sans(12)).foregroundStyle(Color.lInk2)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 18).padding(.vertical, 10)
                    }
                }
            }
        }
    }

    private func metaRow(_ k: String, _ v: String) -> some View {
        HStack {
            Text(k).font(Typo.sans(12, weight: .medium)).foregroundStyle(Color.lInk2)
            Spacer()
            Text(v).font(Typo.mono(12)).foregroundStyle(Color.lInk)
        }
        .padding(.horizontal, 18).padding(.vertical, 10)
    }

    // MARK: - History

    private var historyPanel: some View {
        Panel {
            VStack(spacing: 0) {
                PanelHead(title: "History", meta: "\(series.count) entries")
                if series.isEmpty {
                    Text("No snapshot data for this account yet.")
                        .font(Typo.serifItalic(12))
                        .foregroundStyle(Color.lInk3)
                        .padding(18)
                } else {
                    VStack(spacing: 0) {
                        HStack {
                            Text("SNAPSHOT").frame(maxWidth: .infinity, alignment: .leading)
                            Text("DATE").frame(width: 100, alignment: .leading)
                            Text("NATIVE (\(native.rawValue))").frame(width: 140, alignment: .trailing)
                            Text("\(ccy.rawValue) DISPLAY").frame(width: 130, alignment: .trailing)
                            Text("Δ vs PREV").frame(width: 130, alignment: .trailing)
                            Text("Δ%").frame(width: 70, alignment: .trailing)
                        }
                        .font(Typo.eyebrow).tracking(1.2).foregroundStyle(Color.lInk3)
                        .padding(.horizontal, 18).padding(.vertical, 10)
                        .background(Color.lSunken)
                        ForEach(Array(series.reversed().enumerated()), id: \.element.id) { idx, p in
                            let prevIdx = series.firstIndex(where: { $0.id == p.id }).map { $0 - 1 } ?? -1
                            let prev: Point? = (prevIdx >= 0 && prevIdx < series.count) ? series[prevIdx] : nil
                            let delta = prev.map { p.display - $0.display }
                            let pct: Double = {
                                guard let prev, prev.display != 0, let d = delta else { return 0 }
                                return d / abs(prev.display)
                            }()
                            HStack {
                                Text(p.label).font(Typo.sans(12, weight: .medium)).foregroundStyle(Color.lInk)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Text(Fmt.date(p.date)).font(Typo.mono(11)).foregroundStyle(Color.lInk3)
                                    .frame(width: 100, alignment: .leading)
                                Text(Fmt.currency(p.native, native)).font(Typo.mono(12)).foregroundStyle(Color.lInk2)
                                    .frame(width: 140, alignment: .trailing)
                                Text(Fmt.currency(p.display, ccy)).font(Typo.mono(12, weight: .semibold)).foregroundStyle(Color.lInk)
                                    .frame(width: 130, alignment: .trailing)
                                Group {
                                    if let delta {
                                        Text(Fmt.signedDelta(delta, ccy))
                                            .foregroundStyle(delta >= 0 ? Color.lGain : Color.lLoss)
                                    } else {
                                        Text("—").foregroundStyle(Color.lInk3)
                                    }
                                }
                                .font(Typo.mono(11))
                                .frame(width: 130, alignment: .trailing)
                                Text(prev == nil ? "—" : Fmt.percent(pct, fractionDigits: 1))
                                    .font(Typo.mono(11))
                                    .foregroundStyle(Color.lInk3)
                                    .frame(width: 70, alignment: .trailing)
                            }
                            .padding(.horizontal, 18).padding(.vertical, 8)
                            .background(idx.isMultiple(of: 2) ? Color.clear : Color.lSunken.opacity(0.5))
                        }
                    }
                }
            }
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Spacer()
            GhostButton(action: { dismiss() }) { Text("Done") }
        }
        .padding(.horizontal, 20).padding(.vertical, 14)
    }
}

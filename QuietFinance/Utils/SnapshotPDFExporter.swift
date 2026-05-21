import SwiftUI
import AppKit
import UniformTypeIdentifiers

enum SnapshotPDFExporter {
    enum Result {
        case exported(String)
        case cancelled
        case failed(String)
    }

    @MainActor
    static func export(
        snapshot: Snapshot,
        previousSnapshot: Snapshot?,
        displayCurrency: Currency,
        includeIlliquid: Bool,
        theme: AppTheme
    ) -> Result {
        let scheme = resolveScheme(theme)
        let appearance: NSAppearance = (scheme == .dark)
            ? (NSAppearance(named: .darkAqua) ?? NSApp.effectiveAppearance)
            : (NSAppearance(named: .aqua) ?? NSApp.effectiveAppearance)

        let view = SnapshotPDFView(
            snapshot: snapshot,
            previous: previousSnapshot,
            displayCurrency: displayCurrency,
            includeIlliquid: includeIlliquid
        )
        .environment(\.colorScheme, scheme)

        let renderer = ImageRenderer(content: view)
        renderer.proposedSize = ProposedViewSize(width: 1000, height: nil)

        let panel = NSSavePanel()
        panel.title = "Export Snapshot PDF"
        panel.nameFieldStringValue = "QuietFinance-snapshot-\(safe(snapshot.label))-\(datestamp()).pdf"
        panel.allowedContentTypes = [.pdf]
        guard panel.runModal() == .OK, let dest = panel.url else { return .cancelled }

        var renderFailed = false
        appearance.performAsCurrentDrawingAppearance {
            renderer.render { size, context in
                var box = CGRect(origin: .zero, size: size)
                guard let consumer = CGDataConsumer(url: dest as CFURL),
                      let pdf = CGContext(consumer: consumer, mediaBox: &box, nil) else {
                    renderFailed = true
                    return
                }
                pdf.beginPDFPage(nil)
                context(pdf)
                pdf.endPDFPage()
                pdf.closePDF()
            }
        }
        if renderFailed { return .failed("PDF setup failed.") }
        return .exported("Exported \(dest.lastPathComponent).")
    }

    private static func resolveScheme(_ theme: AppTheme) -> ColorScheme {
        switch theme {
        case .light: return .light
        case .dark:  return .dark
        case .system:
            let eff = NSApp.effectiveAppearance
            let isDark = eff.bestMatch(from: [.darkAqua, .vibrantDark]) != nil
            return isDark ? .dark : .light
        }
    }

    private static func datestamp() -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }

    private static func safe(_ s: String) -> String {
        s.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: " ", with: "_")
    }
}

// MARK: - Render view

struct SnapshotPDFView: View {
    let snapshot: Snapshot
    let previous: Snapshot?
    let displayCurrency: Currency
    let includeIlliquid: Bool

    private var ccy: Currency { displayCurrency }

    private func total(_ s: Snapshot) -> Double {
        s.values.reduce(0) { $0 + CurrencyConverter.netDisplayValue(for: $1, in: ccy, includeIlliquid: includeIlliquid) }
    }

    private func categoryBuckets(_ s: Snapshot) -> [(String, Double)] {
        var out: [String: Double] = [:]
        for v in s.values {
            guard let cat = v.account?.assetType?.category else { continue }
            if !includeIlliquid && cat.isIlliquid { continue }
            let dv = CurrencyConverter.netDisplayValue(for: v, in: ccy, includeIlliquid: includeIlliquid)
            out[cat.rawValue, default: 0] += dv
        }
        return AssetCategory.allCases.compactMap { c in
            out[c.rawValue].map { (c.rawValue, $0) }
        }
    }

    private struct Row: Identifiable {
        let id = UUID()
        let person: String
        let account: String
        let category: String
        let native: Double
        let nativeCurrency: Currency
        let display: Double
        let prevDisplay: Double?
    }

    private var rows: [Row] {
        let prev = previous?.values.reduce(into: [UUID: Double]()) { dict, v in
            guard let acc = v.account else { return }
            dict[acc.id] = CurrencyConverter.netDisplayValue(for: v, in: ccy, includeIlliquid: includeIlliquid)
        } ?? [:]
        return snapshot.values.compactMap { v -> Row? in
            guard let acc = v.account else { return nil }
            if !includeIlliquid && (acc.assetType?.category.isIlliquid ?? false) { return nil }
            let display = CurrencyConverter.netDisplayValue(for: v, in: ccy, includeIlliquid: includeIlliquid)
            return Row(
                person: acc.person?.name ?? "—",
                account: acc.name,
                category: acc.assetType?.category.rawValue ?? "—",
                native: v.nativeValue,
                nativeCurrency: acc.nativeCurrency,
                display: display,
                prevDisplay: prev[acc.id]
            )
        }
        .sorted { lhs, rhs in
            if lhs.nativeCurrency != rhs.nativeCurrency { return lhs.nativeCurrency.rawValue < rhs.nativeCurrency.rawValue }
            if lhs.person != rhs.person { return lhs.person.localizedCaseInsensitiveCompare(rhs.person) == .orderedAscending }
            return lhs.account.localizedCaseInsensitiveCompare(rhs.account) == .orderedAscending
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            header
            cards
            categoryTable
            accountsTable
            if !snapshot.receivableValues.isEmpty {
                receivablesTable
            }
            footer
        }
        .padding(36)
        .frame(width: 1000, alignment: .topLeading)
        .background(Color.lBg)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("QUIET FINANCE · SNAPSHOT")
                .font(Typo.eyebrow).tracking(1.5)
                .foregroundStyle(Color.lInk3)
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(snapshot.label).font(Typo.serifNum(36)).foregroundStyle(Color.lInk)
                Text("— \(Fmt.date(snapshot.date))")
                    .font(Typo.serifItalic(20)).foregroundStyle(Color.lInk3)
            }
            Text("Display currency \(ccy.rawValue) · USD→INR \(String(format: "%.4f", snapshot.usdToInrRate)) · \(snapshot.isLocked ? "🔒 locked" : "✎ draft")")
                .font(Typo.mono(11)).foregroundStyle(Color.lInk3)
        }
    }

    private var cards: some View {
        let t = total(snapshot)
        let prevT = previous.map(total)
        let delta = prevT.map { t - $0 }
        let pct = (prevT ?? 0) == 0 ? 0 : (delta ?? 0) / abs(prevT ?? 1)
        return HStack(spacing: 14) {
            card(eyebrow: "NET WORTH", primary: Fmt.compact(t, ccy),
                 secondary: "\(snapshot.values.count) positions")
            if let prevT, let delta {
                card(eyebrow: "FROM \(previous?.label ?? "PREV")", primary: Fmt.compact(prevT, ccy),
                     secondary: "")
                card(eyebrow: "Δ", primary: Fmt.signedDelta(delta, ccy),
                     secondary: Fmt.percent(pct, fractionDigits: 2),
                     tint: delta >= 0 ? .lGain : .lLoss)
            }
        }
    }

    private func card(eyebrow: String, primary: String, secondary: String, tint: Color = .lInk) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(eyebrow)
                .font(Typo.eyebrow).tracking(1.2).foregroundStyle(Color.lInk3)
            Text(primary)
                .font(Typo.serifNum(24)).foregroundStyle(tint).monospacedDigit()
            if !secondary.isEmpty {
                Text(secondary).font(Typo.mono(11)).foregroundStyle(Color.lInk3)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.lLine, lineWidth: 1))
    }

    private var categoryTable: some View {
        let buckets = categoryBuckets(snapshot)
        let total = max(0.0001, buckets.reduce(0) { $0 + $1.1 })
        return VStack(alignment: .leading, spacing: 6) {
            Text("BY CATEGORY")
                .font(Typo.eyebrow).tracking(1.2).foregroundStyle(Color.lInk3)
            ForEach(buckets, id: \.0) { entry in
                let cat = entry.0
                let v = entry.1
                HStack {
                    HStack(spacing: 6) {
                        Circle().fill(Palette.color(for: AssetCategory(rawValue: cat) ?? .cash))
                            .frame(width: 7, height: 7)
                        Text(cat).font(Typo.sans(12, weight: .medium))
                    }
                    .frame(width: 160, alignment: .leading)
                    Text(Fmt.compact(v, ccy)).font(Typo.mono(12, weight: .semibold))
                        .frame(width: 120, alignment: .trailing)
                    Text(Fmt.percent(v / total, fractionDigits: 1))
                        .font(Typo.mono(11)).foregroundStyle(Color.lInk3)
                        .frame(width: 70, alignment: .trailing)
                    GeometryReader { geo in
                        Rectangle()
                            .fill(Palette.color(for: AssetCategory(rawValue: cat) ?? .cash))
                            .frame(width: max(0, geo.size.width * (v / total)))
                    }
                    .frame(height: 6)
                    .clipShape(RoundedRectangle(cornerRadius: 2))
                }
                .padding(.vertical, 3)
            }
        }
    }

    private var accountsTable: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("ACCOUNTS")
                .font(Typo.eyebrow).tracking(1.2).foregroundStyle(Color.lInk3)
            HStack {
                Text("ACCOUNT").frame(maxWidth: .infinity, alignment: .leading)
                Text("PERSON").frame(width: 90, alignment: .leading)
                Text("CAT").frame(width: 80, alignment: .leading)
                Text("NATIVE").frame(width: 130, alignment: .trailing)
                Text("DISPLAY").frame(width: 110, alignment: .trailing)
                Text("Δ vs prev").frame(width: 110, alignment: .trailing)
            }
            .font(Typo.eyebrow).tracking(1.0).foregroundStyle(Color.lInk3)
            ForEach(rows) { r in
                let delta = r.prevDisplay.map { r.display - $0 }
                HStack {
                    Text(r.account).font(Typo.sans(12, weight: .medium))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(r.person).font(Typo.sans(11)).foregroundStyle(Color.lInk2)
                        .frame(width: 90, alignment: .leading)
                    Text(r.category).font(Typo.mono(10)).foregroundStyle(Color.lInk3)
                        .frame(width: 80, alignment: .leading)
                    Text("\(Fmt.compact(r.native, r.nativeCurrency))")
                        .font(Typo.mono(11)).foregroundStyle(Color.lInk2)
                        .frame(width: 130, alignment: .trailing)
                    Text(Fmt.compact(r.display, ccy))
                        .font(Typo.mono(12, weight: .semibold))
                        .frame(width: 110, alignment: .trailing)
                    Group {
                        if let delta {
                            Text(Fmt.signedDelta(delta, ccy))
                                .foregroundStyle(delta >= 0 ? Color.lGain : Color.lLoss)
                        } else {
                            Text("—").foregroundStyle(Color.lInk3)
                        }
                    }
                    .font(Typo.mono(11))
                    .frame(width: 110, alignment: .trailing)
                }
                .padding(.vertical, 3)
                Divider().overlay(Color.lLine.opacity(0.5))
            }
        }
    }

    private var receivablesTable: some View {
        let total = CurrencyConverter.receivableDisplaySum(snapshot, in: ccy)
        let rows = snapshot.receivableValues.sorted {
            ($0.receivable?.name ?? "").localizedCaseInsensitiveCompare($1.receivable?.name ?? "") == .orderedAscending
        }
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("PENDING RECEIVABLES · NOT IN NET WORTH")
                    .font(Typo.eyebrow).tracking(1.2).foregroundStyle(Color.lInk3)
                Spacer()
                Text("Total \(Fmt.compact(total, ccy))")
                    .font(Typo.mono(11, weight: .semibold))
                    .foregroundStyle(Color.lInk2)
            }
            HStack {
                Text("RECEIVABLE").frame(maxWidth: .infinity, alignment: .leading)
                Text("DEBTOR").frame(width: 140, alignment: .leading)
                Text("NATIVE").frame(width: 130, alignment: .trailing)
                Text("DISPLAY").frame(width: 110, alignment: .trailing)
            }
            .font(Typo.eyebrow).tracking(1.0).foregroundStyle(Color.lInk3)
            ForEach(rows, id: \.id) { rv in
                let r = rv.receivable
                let display = CurrencyConverter.displayValue(for: rv, in: ccy)
                HStack {
                    Text(r?.name ?? "—").font(Typo.sans(12, weight: .medium))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(r?.debtor.isEmpty == false ? r!.debtor : "—")
                        .font(Typo.sans(11)).foregroundStyle(Color.lInk2)
                        .frame(width: 140, alignment: .leading)
                    Text(Fmt.compact(rv.nativeValue, r?.nativeCurrency ?? .USD))
                        .font(Typo.mono(11)).foregroundStyle(Color.lInk2)
                        .frame(width: 130, alignment: .trailing)
                    Text(Fmt.compact(display, ccy))
                        .font(Typo.mono(12, weight: .semibold))
                        .frame(width: 110, alignment: .trailing)
                }
                .padding(.vertical, 3)
                Divider().overlay(Color.lLine.opacity(0.5))
            }
        }
    }

    private var footer: some View {
        Text("Generated \(Fmt.date(.now)) · Quiet Finance v\(AppInfo.versionString)")
            .font(Typo.mono(10)).foregroundStyle(Color.lInk4)
    }
}

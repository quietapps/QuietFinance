import SwiftUI
import AppKit
import UniformTypeIdentifiers

enum DashboardPDFExporter {
    enum Result {
        case exported(String)
        case cancelled
        case failed(String)
    }

    @MainActor
    static func export(
        snapshots: [Snapshot],
        displayCurrency: Currency,
        activeSnapshotID: UUID?,
        theme: AppTheme,
        appIconAssetName: String = "IconClassic"
    ) -> Result {
        let scheme = resolveScheme(theme)
        let appearance: NSAppearance = (scheme == .dark)
            ? (NSAppearance(named: .darkAqua) ?? NSApp.effectiveAppearance)
            : (NSAppearance(named: .aqua) ?? NSApp.effectiveAppearance)

        let view = DashboardExportView(
            snapshots: snapshots,
            displayCurrency: displayCurrency,
            activeSnapshotID: activeSnapshotID,
            appIconAssetName: appIconAssetName,
            generatedAt: Date()
        )
        .environment(\.colorScheme, scheme)

        let renderer = ImageRenderer(content: view)
        renderer.proposedSize = ProposedViewSize(width: 1000, height: nil)

        let panel = NSSavePanel()
        panel.title = "Export Dashboard PDF"
        panel.nameFieldStringValue = "QuietFinance-dashboard-\(datestamp()).pdf"
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
}

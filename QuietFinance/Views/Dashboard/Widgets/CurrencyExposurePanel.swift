import SwiftUI

/// Net-worth share per native currency with a share-based FX sensitivity line.
struct CurrencyExposurePanel: View {
    @EnvironmentObject var app: AppState
    let slices: [CurrencyExposure.Slice]
    let curTotal: Double

    var body: some View {
        Panel {
            VStack(alignment: .leading, spacing: 0) {
                PanelHead(title: "Currency exposure",
                          meta: "\(slices.count) currencies")
                VStack(alignment: .leading, spacing: 16) {
                    StackedHBar(items: slices.map {
                        StackedHBar.Item(label: $0.currency.rawValue,
                                         value: abs($0.displayValue),
                                         color: Palette.fallback(for: $0.currency.rawValue))
                    })
                    VStack(spacing: 0) {
                        ForEach(slices) { slice in
                            AllocRow(
                                color: Palette.fallback(for: slice.currency.rawValue),
                                label: "\(slice.currency.rawValue) — \(slice.currency.displayName)",
                                value: Fmt.compact(slice.displayValue, app.displayCurrency),
                                pct: slice.share * 100
                            )
                            Divider().overlay(Color.lLine)
                        }
                    }
                    if let sensitivity = sensitivityLine {
                        Text(sensitivity)
                            .font(Typo.serifItalic(12))
                            .foregroundStyle(Color.lInk2)
                            .fixedSize(horizontal: false, vertical: true)
                            .stealthAmount()
                    }
                }
                .padding(18)
            }
        }
    }

    /// "If INR weakens 10% vs USD, net worth changes −$32k (−4.1%)."
    private var sensitivityLine: String? {
        guard let biggest = slices.first(where: { $0.currency != app.displayCurrency }) else { return nil }
        let impact = abs(biggest.displayValue) * 0.10
        let pct = curTotal != 0 ? impact / abs(curTotal) * 100 : 0
        return "If \(biggest.currency.rawValue) weakens 10% vs \(app.displayCurrency.rawValue), net worth changes −\(Fmt.compact(impact, app.displayCurrency)) (−\(String(format: "%.1f", pct))%)."
    }
}

import SwiftUI

/// Pending receivables tracked outside net worth.
struct ReceivablesPanel: View {
    @EnvironmentObject var app: AppState
    let snapshot: Snapshot?

    var body: some View {
        let target = app.displayCurrency
        let rows: [ReceivableValue] = snapshot.map { s in
            s.receivableValues.sorted { lhs, rhs in
                (lhs.receivable?.name ?? "").localizedCaseInsensitiveCompare(rhs.receivable?.name ?? "") == .orderedAscending
            }
        } ?? []
        let total = snapshot.map { CurrencyConverter.receivableDisplaySum($0, in: target) } ?? 0
        Panel {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("OUTSIDE NET WORTH")
                            .font(Typo.eyebrow).tracking(1.5)
                            .foregroundStyle(Color.lInk3)
                        Text("Pending receivables")
                            .font(Typo.serifNum(18))
                            .foregroundStyle(Color.lInk)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 3) {
                        Text("TOTAL · NOT IN NET WORTH")
                            .font(Typo.eyebrow).tracking(1.2)
                            .foregroundStyle(Color.lInk3)
                        Text(Fmt.currency(total, target))
                            .font(Typo.mono(15, weight: .semibold))
                            .foregroundStyle(Color.lInk)
                    }
                }
                .padding(.horizontal, 18).padding(.vertical, 14)
                .overlay(Rectangle().frame(height: 1).foregroundStyle(Color.lLine), alignment: .bottom)

                ForEach(Array(rows.enumerated()), id: \.element.id) { idx, rv in
                    receivableRow(rv, idx: idx, target: target)
                    if idx < rows.count - 1 {
                        Divider().overlay(Color.lLine)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func receivableRow(_ rv: ReceivableValue, idx: Int, target: Currency) -> some View {
        let r = rv.receivable
        let ccy = r?.nativeCurrency ?? .USD
        let display = CurrencyConverter.displayValue(for: rv, in: target)
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(r?.name ?? "—")
                    .font(Typo.sans(13, weight: .medium))
                    .foregroundStyle(Color.lInk)
                if let debtor = r?.debtor, !debtor.isEmpty {
                    Text(debtor)
                        .font(Typo.sans(11))
                        .foregroundStyle(Color.lInk3)
                }
            }
            Spacer()
            Text(Fmt.currency(rv.nativeValue, ccy))
                .font(Typo.mono(12))
                .foregroundStyle(Color.lInk2)
                .frame(width: 130, alignment: .trailing)
            Text(Fmt.currency(display, target))
                .font(Typo.mono(13, weight: .semibold))
                .foregroundStyle(Color.lInk)
                .frame(width: 130, alignment: .trailing)
        }
        .padding(.horizontal, 18).padding(.vertical, 11)
        .background(idx.isMultiple(of: 2) ? Color.clear : Color.lSunken.opacity(0.5))
    }
}

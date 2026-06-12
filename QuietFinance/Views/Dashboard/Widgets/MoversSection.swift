import SwiftUI

/// Biggest account movers between the previous and active snapshots.
struct MoversSection: View {
    @EnvironmentObject var app: AppState
    let rows: [MoverRow]
    let fromLabel: String?
    let toLabel: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHead(title: "Biggest movers", emphasis: "— this quarter",
                        rightLabel: fromLabel.map { "\($0) → \(toLabel)" })
            Panel {
                VStack(spacing: 0) {
                    moversHeader
                    ForEach(Array(rows.enumerated()), id: \.offset) { i, m in
                        moverRow(m)
                        if i < rows.count - 1 {
                            Divider().overlay(Color.lLine)
                        }
                    }
                }
            }
        }
    }

    private var moversHeader: some View {
        HStack {
            Text("Account").frame(maxWidth: .infinity, alignment: .leading)
            Text("Owner").frame(width: 140, alignment: .leading)
            Text("Country").frame(width: 100, alignment: .leading)
            Text("Type").frame(width: 120, alignment: .leading)
            Text("Value").frame(width: 120, alignment: .trailing)
            Text("QoQ").frame(width: 80, alignment: .trailing)
        }
        .font(Typo.eyebrow)
        .tracking(1.2)
        .foregroundStyle(Color.lInk3)
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(Color.lSunken)
        .overlay(Rectangle().frame(height: 1).foregroundStyle(Color.lLine), alignment: .bottom)
    }

    private func moverRow(_ m: MoverRow) -> some View {
        let person = m.account.person
        let country = m.account.country
        let type = m.account.assetType
        return HStack {
            Text(m.account.name)
                .font(Typo.sans(12.5, weight: .medium))
                .foregroundStyle(Color.lInk)
                .frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: 6) {
                if let p = person {
                    Avatar(text: String(p.name.prefix(1)),
                           color: Color.fromHex(p.colorHex) ?? Palette.fallback(for: p.name),
                           size: 18)
                    Text(p.name).font(Typo.sans(12))
                }
            }
            .foregroundStyle(Color.lInk2)
            .frame(width: 140, alignment: .leading)
            Text(country?.flag ?? "")
                .font(.system(size: 14))
                .frame(width: 100, alignment: .leading)
            Text(type?.name ?? "")
                .font(Typo.sans(12))
                .foregroundStyle(Color.lInk2)
                .frame(width: 120, alignment: .leading)
            Text(Fmt.compact(m.value, app.displayCurrency))
                .font(Typo.mono(12, weight: .medium))
                .foregroundStyle(Color.lInk)
                .frame(width: 120, alignment: .trailing)
            Text("\(m.up ? "+" : "−")\(String(format: "%.1f", abs(m.pct)))%")
                .font(Typo.mono(12, weight: .medium))
                .foregroundStyle(m.up ? Color.lGain : Color.lLoss)
                .frame(width: 80, alignment: .trailing)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 11)
    }
}

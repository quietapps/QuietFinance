import SwiftUI

/// Compact menu-based currency selector. SegControl can't host 31 options, so
/// display-currency surfaces use this instead. Currencies already in use by
/// accounts are listed first.
struct CurrencyPicker: View {
    @Binding var selection: Currency
    var inUse: [Currency] = []
    var help: String = "Display currency"

    private var prioritized: [Currency] {
        inUse.filter { $0 != selection }.sorted { $0.rawValue < $1.rawValue }
    }

    private var rest: [Currency] {
        Currency.allCases.filter { !inUse.contains($0) }
    }

    var body: some View {
        Menu {
            if !prioritized.isEmpty || inUse.contains(selection) {
                Section("In use") {
                    ForEach(inUse.sorted { $0.rawValue < $1.rawValue }) { c in
                        currencyButton(c)
                    }
                }
            }
            Section(inUse.isEmpty ? "Currencies" : "All currencies") {
                ForEach(rest) { c in
                    currencyButton(c)
                }
            }
        } label: {
            HStack(spacing: 5) {
                Text(selection.rawValue)
                    .font(Typo.mono(11, weight: .semibold))
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .bold))
            }
            .foregroundStyle(Color.lInk)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .overlay(Capsule().stroke(Color.lLine, lineWidth: 1))
            .contentShape(Capsule())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help(help)
        .accessibilityLabel("\(help): \(selection.displayName)")
    }

    private func currencyButton(_ c: Currency) -> some View {
        Button {
            selection = c
        } label: {
            if c == selection {
                Label("\(c.rawValue) — \(c.displayName)", systemImage: "checkmark")
            } else {
                Text("\(c.rawValue) — \(c.displayName)")
            }
        }
    }
}

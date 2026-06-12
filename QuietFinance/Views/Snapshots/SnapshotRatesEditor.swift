import SwiftUI
import SwiftData

/// Per-currency exchange-rate rows for a snapshot form or editor. One row per
/// non-USD currency in use, each editable (units per 1 USD) with a single
/// "Fetch all" action that pulls every pair in one frankfurter request.
/// Read-only rendering when the snapshot is locked.
struct RatesEditor: View {
    let currencies: [Currency]
    @Binding var rates: [String: Double]
    var date: Date? = nil
    var readOnly: Bool = false
    var onRatesFetched: () -> Void = {}

    @Environment(\.modelContext) private var context
    @State private var isFetching = false
    @State private var fetchError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if currencies.isEmpty {
                Text("All accounts are in USD — no exchange rates needed.")
                    .font(Typo.serifItalic(12))
                    .foregroundStyle(Color.lInk3)
            } else {
                HStack {
                    Text("RATES PER 1 USD")
                        .font(Typo.eyebrow).tracking(1.2)
                        .foregroundStyle(Color.lInk3)
                    Spacer()
                    if !readOnly {
                        Button {
                            Task { await fetchAll() }
                        } label: {
                            HStack(spacing: 4) {
                                if isFetching {
                                    ProgressView().controlSize(.small)
                                } else {
                                    Image(systemName: "arrow.down.circle")
                                        .font(.system(size: 11))
                                }
                                Text("Fetch all")
                                    .font(Typo.sans(11, weight: .medium))
                            }
                            .foregroundStyle(Color.lInk2)
                        }
                        .disabled(isFetching)
                        .buttonStyle(.plain)
                        .pointerStyle(.link)
                        .help(date.map { "Fetch rates for \(Fmt.date($0)) from frankfurter.app" }
                              ?? "Fetch latest rates from frankfurter.app")
                    }
                }
                ForEach(currencies) { c in
                    rateRow(c)
                }
                if let err = fetchError {
                    Text(err)
                        .font(Typo.sans(11))
                        .foregroundStyle(Color.lLoss)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    @ViewBuilder
    private func rateRow(_ c: Currency) -> some View {
        let value = rates[c.rawValue] ?? 0
        HStack(spacing: 8) {
            Text("USD → \(c.rawValue)")
                .font(Typo.mono(11, weight: .medium))
                .foregroundStyle(Color.lInk2)
                .frame(width: 90, alignment: .leading)
            if readOnly {
                Text(value > 0 ? String(format: "%.4f", value) : "—")
                    .font(Typo.mono(12, weight: .semibold))
                    .foregroundStyle(value > 0 ? Color.lInk : Color.lLoss)
            } else {
                TextField("", value: Binding(
                    get: { rates[c.rawValue] ?? 0 },
                    set: { rates[c.rawValue] = $0 }
                ), format: .number)
                .textFieldStyle(.roundedBorder)
                .font(Typo.mono(12))
                .frame(width: 100)
                if value <= 0 {
                    Text("required")
                        .font(Typo.mono(10, weight: .medium))
                        .foregroundStyle(Color.lLoss)
                }
            }
            Spacer(minLength: 0)
        }
    }

    @MainActor
    private func fetchAll() async {
        isFetching = true
        defer { isFetching = false }
        do {
            let fetched = try await FXService.fetchRates(for: currencies, on: date)
            for (code, rate) in fetched where rate > 0 {
                rates[code] = rate
                // Audit trail of every successful fetch, one row per pair.
                context.insert(ExchangeRateHistory(date: date ?? .now,
                                                   usdToInr: rate,
                                                   source: "frankfurter.app",
                                                   currencyCode: code))
            }
            try? context.save()
            let missing = currencies.map(\.rawValue).filter { (rates[$0] ?? 0) <= 0 }
            fetchError = missing.isEmpty
                ? nil
                : "No rate returned for \(missing.joined(separator: ", ")) — enter manually."
            onRatesFetched()
        } catch {
            fetchError = "Fetch failed: \(error.localizedDescription). Enter rates manually."
        }
    }
}

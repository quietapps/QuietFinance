import SwiftUI
import SwiftData

struct NewSnapshotSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \Snapshot.date, order: .reverse) private var snapshots: [Snapshot]
    @Query private var accounts: [Account]
    @Query(sort: \Receivable.name) private var receivables: [Receivable]

    @State private var date: Date = Calendar.current.startOfDay(for: Date())
    @State private var rates: [String: Double] = [:]
    @State private var copyPrevious: Bool = true
    @State private var notes: String = ""
    @State private var errorMessage: String?
    @State private var rateFetchedAt: Date?
    @State private var showUnsavedConfirm = false
    @State private var initialSnapshot: FormSnapshot = FormSnapshot()
    var onCreated: (Snapshot) -> Void = { _ in }

    private let minGapDays = 7

    private struct FormSnapshot: Equatable {
        var date: Date = Date()
        var rates: [String: Double] = [:]
        var copyPrevious: Bool = true
        var notes: String = ""
    }

    private var currentSnapshot: FormSnapshot {
        FormSnapshot(date: date, rates: rates, copyPrevious: copyPrevious, notes: notes)
    }

    /// Non-USD currencies the new snapshot will need rates for, derived from
    /// active accounts and active receivables.
    private var requiredCurrencies: [Currency] {
        var set = Set<Currency>()
        for a in accounts where a.isActive { set.insert(a.nativeCurrency) }
        for r in receivables where r.isActive && r.startDate <= Calendar.current.startOfDay(for: date) {
            set.insert(r.nativeCurrency)
        }
        set.remove(.USD)
        return set.sorted { $0.rawValue < $1.rawValue }
    }

    private var hasChanges: Bool { currentSnapshot != initialSnapshot }

    private func attemptCancel() {
        if hasChanges { showUnsavedConfirm = true } else { dismiss() }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            VStack(alignment: .leading, spacing: 18) {
                grid
                notesField
                noticeBox
                if let err = errorMessage {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(Color.lLoss)
                        Text(err).font(Typo.sans(12)).foregroundStyle(Color.lLoss)
                    }
                    .padding(12)
                    .background(Color.lLossSoft.opacity(0.4))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.lLoss.opacity(0.3), lineWidth: 1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            .padding(24)

            Divider().overlay(Color.lLine)

            HStack {
                Spacer()
                GhostButton(action: { attemptCancel() }) { Text("Cancel") }
                PrimaryButton(action: create) {
                    HStack(spacing: 5) {
                        Image(systemName: "plus").font(.system(size: 10, weight: .bold))
                        Text("Create Snapshot")
                    }
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            Button("") { create() }
                .keyboardShortcut("s", modifiers: .command)
                .hidden()
                .frame(width: 0, height: 0)
            Button("") { attemptCancel() }
                .keyboardShortcut(.cancelAction)
                .hidden()
                .frame(width: 0, height: 0)
        }
        .background(Color.lBg)
        .frame(minWidth: 580)
        .onAppear {
            // Prefill each required currency from the previous snapshot's
            // frozen table (legacy INR scalar covered by rate(for:)).
            if let prev = snapshots.first {
                for c in requiredCurrencies {
                    if let r = prev.rate(for: c), r > 0 { rates[c.rawValue] = r }
                }
            }
            initialSnapshot = currentSnapshot
        }
        .confirmationDialog("Save changes before closing?", isPresented: $showUnsavedConfirm) {
            Button("Save") { create() }
                .keyboardShortcut(.defaultAction)
            Button("Discard", role: .destructive) { dismiss() }
            Button("Cancel", role: .cancel) {}
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("NEW SNAPSHOT")
                .font(Typo.eyebrow).tracking(1.5).foregroundStyle(Color.lInk3)
            Text("Record this quarter").font(Typo.serifNum(26))
                .foregroundStyle(Color.lInk)
            Text("Values become locked after save · edit freely until then")
                .font(Typo.serifItalic(13))
                .foregroundStyle(Color.lInk3)
        }
        .padding(.horizontal, 24).padding(.top, 22).padding(.bottom, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(Rectangle().frame(height: 1).foregroundStyle(Color.lLine), alignment: .bottom)
    }

    private var grid: some View {
        LazyVGrid(
            columns: [GridItem(.flexible(), spacing: 18), GridItem(.flexible(), spacing: 18)],
            alignment: .leading,
            spacing: 14
        ) {
            field(label: "Snapshot date") {
                DatePicker("", selection: $date, in: ...Date(), displayedComponents: .date)
                    .labelsHidden()
                    .datePickerStyle(.field)
            }

            field(label: "Exchange rates") {
                RatesEditor(currencies: requiredCurrencies,
                            rates: $rates,
                            date: date,
                            onRatesFetched: { rateFetchedAt = Date() })
            }

            Toggle(isOn: $copyPrevious) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Copy previous values")
                        .font(Typo.sans(12, weight: .medium))
                        .foregroundStyle(Color.lInk)
                    Text("Prefill active accounts from last snapshot")
                        .font(Typo.sans(11))
                        .foregroundStyle(Color.lInk3)
                }
            }
            .toggleStyle(.switch)

            if let fetched = rateFetchedAt {
                VStack(alignment: .leading, spacing: 2) {
                    Text("LIVE RATE").font(Typo.eyebrow).tracking(1.2)
                        .foregroundStyle(Color.lInk3)
                    Text("Fetched \(Fmt.date(fetched))")
                        .font(Typo.mono(11))
                        .foregroundStyle(Color.lInk2)
                }
            }
        }
    }

    @ViewBuilder
    private func field<V: View>(label: String, @ViewBuilder content: () -> V) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label.uppercased())
                .font(Typo.eyebrow).tracking(1.2).foregroundStyle(Color.lInk3)
            content()
        }
    }

    private var notesField: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("NOTES")
                .font(Typo.eyebrow).tracking(1.2).foregroundStyle(Color.lInk3)
            TextField("Optional — context for this snapshot", text: $notes, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .font(Typo.sans(12))
                .lineLimit(2...4)
        }
    }

    private var noticeBox: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "info.circle.fill")
                .foregroundStyle(Color.lInk3)
            VStack(alignment: .leading, spacing: 3) {
                Text("Heads up")
                    .font(Typo.sans(12, weight: .semibold))
                    .foregroundStyle(Color.lInk)
                Text("Exchange rates are immutable once locked. The rates set here are used for every balance entered in this snapshot.")
                    .font(Typo.sans(12))
                    .foregroundStyle(Color.lInk2)
                    .lineSpacing(2)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(Color.lSunken)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.lLine, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func create() {
        let cal = Calendar.current
        let chosen = cal.startOfDay(for: date)
        if chosen > cal.startOfDay(for: Date()) {
            errorMessage = "Future snapshots not allowed."
            return
        }
        for s in snapshots {
            let existing = cal.startOfDay(for: s.date)
            let days = abs(cal.dateComponents([.day], from: existing, to: chosen).day ?? 0)
            if days < minGapDays {
                errorMessage = "Must be at least \(minGapDays) days from existing snapshot (\(Fmt.date(existing)))."
                return
            }
        }
        let missing = requiredCurrencies.filter { (rates[$0.rawValue] ?? 0) <= 0 }
        if !missing.isEmpty {
            errorMessage = "Missing rate for \(missing.map(\.rawValue).joined(separator: ", ")). Fetch or enter manually."
            return
        }

        let snap = Snapshot(date: chosen, label: Fmt.date(chosen),
                            usdToInrRate: rates["INR"] ?? 0, notes: notes)
        let positiveRates = rates.filter { $0.value > 0 }
        if !positiveRates.isEmpty { snap.ratesPerUSD = positiveRates }
        context.insert(snap)

        let previous = snapshots.first
        let activeAccounts = accounts.filter { $0.isActive }
        for acc in activeAccounts {
            let prefill: Double
            if copyPrevious, let prev = previous,
               let prevValue = prev.values.first(where: { $0.account?.id == acc.id }) {
                prefill = prevValue.nativeValue
            } else {
                prefill = 0
            }
            let av = AssetValue(snapshot: snap, account: acc, nativeValue: prefill)
            context.insert(av)
        }

        let activeReceivables = receivables.filter { $0.isActive && $0.startDate <= chosen }
        for r in activeReceivables {
            let prefill: Double
            if copyPrevious, let prev = previous,
               let prevValue = prev.receivableValues.first(where: { $0.receivable?.id == r.id }) {
                prefill = prevValue.nativeValue
            } else {
                prefill = 0
            }
            let rv = ReceivableValue(snapshot: snap, receivable: r, nativeValue: prefill)
            context.insert(rv)
        }

        do {
            try context.save()
            onCreated(snap)
            dismiss()
        } catch {
            errorMessage = "Save failed: \(error.localizedDescription)"
        }
    }
}

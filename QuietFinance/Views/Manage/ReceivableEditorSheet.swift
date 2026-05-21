import SwiftUI
import SwiftData

struct ReceivableEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    let existing: Receivable?

    @AppStorage("displayCurrency") private var displayCurrencyRaw: String = Currency.USD.rawValue

    @State private var name: String = ""
    @State private var debtor: String = ""
    @State private var nativeCurrency: Currency = .USD
    @State private var notes: String = ""
    @State private var isActive: Bool = true
    @State private var startDate: Date = .now
    @State private var errorMessage: String?
    @State private var showUnsavedConfirm = false
    @State private var initialSnapshot: FormSnapshot = FormSnapshot()

    private struct FormSnapshot: Equatable {
        var name: String = ""
        var debtor: String = ""
        var nativeCurrency: Currency = .USD
        var notes: String = ""
        var isActive: Bool = true
        var startDate: Date = .now
    }

    private var currentSnapshot: FormSnapshot {
        FormSnapshot(name: name, debtor: debtor, nativeCurrency: nativeCurrency,
                     notes: notes, isActive: isActive, startDate: startDate)
    }

    private var hasChanges: Bool { currentSnapshot != initialSnapshot }

    private func attemptCancel() {
        if hasChanges { showUnsavedConfirm = true } else { dismiss() }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(existing == nil ? "New Receivable" : "Edit Receivable")
                .font(Typo.serifNum(24))

            Form {
                TextField("Name", text: $name)
                TextField("Debtor (who owes)", text: $debtor)
                Picker("Native Currency", selection: $nativeCurrency) {
                    ForEach(Currency.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                DatePicker("Start date", selection: $startDate, displayedComponents: .date)
                TextField("Notes (optional)", text: $notes)
                Toggle("Active", isOn: $isActive)
            }
            .formStyle(.grouped)

            if let err = errorMessage {
                Text(err).foregroundStyle(Color.lLoss).font(Typo.sans(12))
            }

            Text("Receivables track money owed to you that hasn't been received. Their value does not contribute to net worth or any total. Each snapshot from the start date forward lets you update the value as partial / full receipt happens.")
                .font(Typo.sans(11))
                .foregroundStyle(Color.lInk3)
                .lineSpacing(2)

            HStack {
                Spacer()
                Button("Cancel") { attemptCancel() }
                    .keyboardShortcut(.cancelAction)
                    .pointerStyle(.link)
                Button { save() } label: { Label("Save", systemImage: "checkmark") }
                    .keyboardShortcut(.defaultAction)
                    .pointerStyle(.link)
            }
            Button("") { save() }
                .keyboardShortcut("s", modifiers: .command)
                .hidden()
                .frame(width: 0, height: 0)
        }
        .padding(24)
        .frame(minWidth: 480)
        .onAppear(perform: prefill)
        .confirmationDialog("Save changes before closing?", isPresented: $showUnsavedConfirm) {
            Button("Save") { save() }
                .keyboardShortcut(.defaultAction)
            Button("Discard", role: .destructive) { dismiss() }
            Button("Cancel", role: .cancel) {}
        }
    }

    private func prefill() {
        if let r = existing {
            name = r.name
            debtor = r.debtor
            nativeCurrency = r.nativeCurrency
            notes = r.notes
            isActive = r.isActive
            startDate = r.startDate == .distantPast ? r.createdAt : r.startDate
        } else if let c = Currency(rawValue: displayCurrencyRaw) {
            nativeCurrency = c
        }
        initialSnapshot = currentSnapshot
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { errorMessage = "Name required."; return }
        if let r = existing {
            r.name = trimmed
            r.debtor = debtor
            r.nativeCurrency = nativeCurrency
            r.notes = notes
            r.isActive = isActive
            r.startDate = startDate
        } else {
            let r = Receivable(name: trimmed,
                               debtor: debtor,
                               nativeCurrency: nativeCurrency,
                               notes: notes,
                               isActive: isActive,
                               startDate: startDate)
            context.insert(r)
        }
        do { try context.save(); dismiss() }
        catch { errorMessage = "Save failed: \(error.localizedDescription)" }
    }
}

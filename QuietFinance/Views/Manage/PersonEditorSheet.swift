import SwiftUI
import SwiftData

struct PersonEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \Person.name) private var allPeople: [Person]
    let existing: Person?
    @State private var name: String = ""
    @State private var color: Color = .blue
    @State private var includeInNetWorth: Bool = true
    @State private var errorMessage: String?
    @State private var showUnsavedConfirm = false
    @State private var initialName: String = ""
    @State private var initialColorHex: String = ""
    @State private var initialInclude: Bool = true

    private var hasChanges: Bool {
        name != initialName
            || (color.toHex() ?? "") != initialColorHex
            || includeInNetWorth != initialInclude
    }

    private func attemptCancel() {
        if hasChanges { showUnsavedConfirm = true } else { dismiss() }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(existing == nil ? "New Person" : "Edit Person").font(Typo.serifNum(24))
            Form {
                TextField("Name", text: $name)
                ColorPicker("Chart color", selection: $color, supportsOpacity: false)
                Toggle("Include in net worth", isOn: $includeInNetWorth)
            }
            .formStyle(.grouped)
            Text(includeInNetWorth
                 ? "Accounts contribute to totals, KPIs, breakdowns and forecasts."
                 : "Accounts are tracked but excluded from totals — useful for parents / partners whose finances live alongside yours.")
                .font(Typo.sans(11))
                .foregroundStyle(Color.lInk3)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)

            if let err = errorMessage {
                Text(err).foregroundStyle(Color.lLoss).font(Typo.sans(12))
            }

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
        .frame(minWidth: 400)
        .onAppear {
            name = existing?.name ?? ""
            includeInNetWorth = existing?.includeInNetWorth ?? true
            if let hex = existing?.colorHex, let c = Color.fromHex(hex) {
                color = c
            } else {
                let taken = allPeople.filter { $0.id != existing?.id }.compactMap { $0.colorHex }
                color = Palette.unusedFallback(taken: taken)
            }
            initialName = name
            initialColorHex = color.toHex() ?? ""
            initialInclude = includeInNetWorth
        }
        .confirmationDialog("Save changes before closing?", isPresented: $showUnsavedConfirm) {
            Button("Save") { save() }
                .keyboardShortcut(.defaultAction)
            Button("Discard", role: .destructive) { dismiss() }
            Button("Cancel", role: .cancel) {}
        }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { errorMessage = "Name required."; return }
        let hex = color.toHex()
        if let p = existing {
            p.name = trimmed
            p.colorHex = hex
            p.includeInNetWorth = includeInNetWorth
        } else {
            let p = Person(name: trimmed)
            p.colorHex = hex
            p.includeInNetWorth = includeInNetWorth
            context.insert(p)
        }
        do { try context.save(); dismiss() }
        catch { errorMessage = "Save failed: \(error.localizedDescription)" }
    }
}

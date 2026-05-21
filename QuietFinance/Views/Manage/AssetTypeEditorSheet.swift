import SwiftUI
import SwiftData

struct AssetTypeEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    let existing: AssetType?

    @State private var name: String = ""
    @State private var category: AssetCategory = .cash
    @State private var errorMessage: String?
    @State private var showUnsavedConfirm = false
    @State private var initialName: String = ""
    @State private var initialCategory: AssetCategory = .cash

    private var hasChanges: Bool { name != initialName || category != initialCategory }

    private func attemptCancel() {
        if hasChanges { showUnsavedConfirm = true } else { dismiss() }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(existing == nil ? "New Asset Type" : "Edit Asset Type").font(Typo.serifNum(24))
            Form {
                TextField("Name", text: $name)
                Picker("Category", selection: $category) {
                    ForEach(AssetCategory.allCases) { Text($0.rawValue).tag($0) }
                }
            }
            .formStyle(.grouped)

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
        .frame(minWidth: 420)
        .onAppear {
            if let t = existing { name = t.name; category = t.category }
            initialName = name
            initialCategory = category
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
        if let t = existing {
            t.name = trimmed; t.category = category
        } else {
            context.insert(AssetType(name: trimmed, category: category))
        }
        do { try context.save(); dismiss() }
        catch { errorMessage = "Save failed: \(error.localizedDescription)" }
    }
}

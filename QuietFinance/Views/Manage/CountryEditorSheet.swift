import SwiftUI
import SwiftData
import AppKit

struct CountryEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \Country.code) private var allCountries: [Country]
    let existing: Country?

    @AppStorage("displayCurrency") private var displayCurrencyRaw: String = Currency.USD.rawValue

    @State private var code: String = ""
    @State private var name: String = ""
    @State private var flag: String = ""
    @State private var defaultCurrency: Currency = .USD
    @State private var color: Color = .blue
    @State private var errorMessage: String?
    @State private var showingFlagPicker: Bool = false
    @State private var showUnsavedConfirm = false
    @State private var initialSnapshot: FormSnapshot = FormSnapshot()

    private struct FormSnapshot: Equatable {
        var code: String = ""
        var name: String = ""
        var flag: String = ""
        var defaultCurrency: Currency = .USD
        var colorHex: String = ""
    }

    private var currentSnapshot: FormSnapshot {
        FormSnapshot(code: code, name: name, flag: flag,
                     defaultCurrency: defaultCurrency, colorHex: color.toHex() ?? "")
    }

    private var hasChanges: Bool { currentSnapshot != initialSnapshot }

    private func attemptCancel() {
        if hasChanges { showUnsavedConfirm = true } else { dismiss() }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(existing == nil ? "New Country" : "Edit Country").font(Typo.serifNum(24))
            Form {
                TextField("Code (US, IN)", text: $code).textCase(.uppercase)
                TextField("Name", text: $name)
                HStack(spacing: 8) {
                    TextField("Flag emoji", text: $flag)
                    if !flag.isEmpty {
                        Text(flag).font(.system(size: 22))
                    }
                    Button {
                        showingFlagPicker = true
                    } label: {
                        Label("Pick country…", systemImage: "flag.fill")
                    }
                    .pointerStyle(.link)
                    .help("Searchable list of all country flags")
                }
                Picker("Default Currency", selection: $defaultCurrency) {
                    ForEach(Currency.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                ColorPicker("Chart color", selection: $color, supportsOpacity: false)
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
        .frame(minWidth: 480)
        .onAppear {
            prefill()
            initialSnapshot = currentSnapshot
        }
        .sheet(isPresented: $showingFlagPicker) {
            FlagPickerSheet(flag: $flag, code: $code)
        }
        .confirmationDialog("Save changes before closing?", isPresented: $showUnsavedConfirm) {
            Button("Save") { save() }
                .keyboardShortcut(.defaultAction)
            Button("Discard", role: .destructive) { dismiss() }
            Button("Cancel", role: .cancel) {}
        }
    }

    private func prefill() {
        guard let c = existing else {
            let taken = allCountries.compactMap { $0.colorHex }
            color = Palette.unusedFallback(taken: taken)
            if let cur = Currency(rawValue: displayCurrencyRaw) { defaultCurrency = cur }
            return
        }
        code = c.code; name = c.name; flag = c.flag; defaultCurrency = c.defaultCurrency
        if let hex = c.colorHex, let col = Color.fromHex(hex) {
            color = col
        } else {
            let taken = allCountries.filter { $0.id != c.id }.compactMap { $0.colorHex }
            color = Palette.unusedFallback(taken: taken)
        }
    }

    private func save() {
        let trimCode = code.uppercased().trimmingCharacters(in: .whitespaces)
        let trimName = name.trimmingCharacters(in: .whitespaces)
        guard !trimCode.isEmpty, !trimName.isEmpty else { errorMessage = "Code and name required."; return }
        let hex = color.toHex()
        if let c = existing {
            c.code = trimCode; c.name = trimName; c.flag = flag; c.defaultCurrency = defaultCurrency
            c.colorHex = hex
        } else {
            let c = Country(code: trimCode, name: trimName, flag: flag, defaultCurrency: defaultCurrency)
            c.colorHex = hex
            context.insert(c)
        }
        do { try context.save(); dismiss() }
        catch { errorMessage = "Save failed: \(error.localizedDescription)" }
    }
}

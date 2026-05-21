import SwiftUI
import SwiftData

struct AccountEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \Person.name) private var people: [Person]
    @Query(sort: \Country.code) private var countries: [Country]
    @Query(sort: \AssetType.name) private var assetTypes: [AssetType]
    @Query(sort: \Account.name) private var allAccounts: [Account]

    let existing: Account?

    @State private var name: String = ""
    @State private var personID: UUID?
    @State private var countryID: UUID?
    @State private var assetTypeID: UUID?
    @State private var nativeCurrency: Currency = .USD
    @State private var institution: String = ""
    @State private var notes: String = ""
    @State private var isActive: Bool = true
    @State private var costBasis: Double = 0
    @State private var errorMessage: String?
    @State private var savedToast: String?
    @State private var showUnsavedConfirm = false
    @State private var initialSnapshot: FormSnapshot = FormSnapshot()

    private struct FormSnapshot: Equatable {
        var name: String = ""
        var personID: UUID?
        var countryID: UUID?
        var assetTypeID: UUID?
        var nativeCurrency: Currency = .USD
        var institution: String = ""
        var notes: String = ""
        var isActive: Bool = true
        var costBasis: Double = 0
    }

    @AppStorage("acct.lastPersonID")    private var lastPersonIDStr: String = ""
    @AppStorage("acct.lastCountryID")   private var lastCountryIDStr: String = ""
    @AppStorage("acct.lastAssetTypeID") private var lastAssetTypeIDStr: String = ""
    @AppStorage("acct.lastCurrency")    private var lastCurrencyRaw: String = ""
    @AppStorage("acct.lastInstitution") private var lastInstitution: String = ""
    @AppStorage("displayCurrency")      private var displayCurrencyRaw: String = Currency.USD.rawValue

    private var currentSnapshot: FormSnapshot {
        FormSnapshot(name: name, personID: personID, countryID: countryID,
                 assetTypeID: assetTypeID, nativeCurrency: nativeCurrency,
                 institution: institution, notes: notes, isActive: isActive,
                 costBasis: costBasis)
    }

    private var hasChanges: Bool { currentSnapshot != initialSnapshot }

    private func attemptCancel() {
        if hasChanges { showUnsavedConfirm = true } else { dismiss() }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(existing == nil ? "New Account" : "Edit Account").font(Typo.serifNum(24))

            Form {
                TextField("Name", text: $name)

                if let warn = duplicateWarning {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(Color.lLoss)
                            .font(.system(size: 10))
                        Text(warn)
                            .font(Typo.sans(11))
                            .foregroundStyle(Color.lLoss)
                    }
                }

                Picker("Person", selection: $personID) {
                    Text("—").tag(UUID?.none)
                    ForEach(people) { Text($0.name).tag(UUID?.some($0.id)) }
                }
                Picker("Country", selection: $countryID) {
                    Text("—").tag(UUID?.none)
                    ForEach(countries) { Text("\($0.flag) \($0.name)").tag(UUID?.some($0.id)) }
                }
                .onChange(of: countryID) { _, new in
                    if existing == nil, let c = countries.first(where: { $0.id == new }) {
                        nativeCurrency = c.defaultCurrency
                    }
                }
                Picker("Asset Type", selection: $assetTypeID) {
                    Text("—").tag(UUID?.none)
                    ForEach(assetTypes) { Text("\($0.name) (\($0.category.rawValue))").tag(UUID?.some($0.id)) }
                }

                Picker("Native Currency", selection: $nativeCurrency) {
                    ForEach(Currency.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)

                TextField("Institution (optional)", text: $institution)
                TextField("Notes (optional)", text: $notes)

                LabeledContent("Cost basis (optional)") {
                    HStack(spacing: 6) {
                        TextField("0", value: $costBasis, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 140)
                        Text(nativeCurrency.rawValue)
                            .font(Typo.mono(11))
                            .foregroundStyle(Color.lInk3)
                    }
                }

                Toggle("Active", isOn: $isActive)
            }
            .formStyle(.grouped)

            if let err = errorMessage {
                Text(err).foregroundStyle(Color.lLoss).font(Typo.sans(12))
            }

            HStack {
                if let toast = savedToast {
                    HStack(spacing: 5) {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.lGain)
                            .font(.system(size: 11))
                        Text(toast).font(Typo.sans(11)).foregroundStyle(Color.lInk2)
                    }
                    .transition(.opacity)
                }
                Spacer()
                Button("Cancel") { attemptCancel() }
                    .keyboardShortcut(.cancelAction)
                    .pointerStyle(.link)
                if existing == nil {
                    Button { save(continueAdding: true) } label: {
                        Label("Save & Add Next", systemImage: "plus.circle")
                    }
                    .keyboardShortcut("s", modifiers: [.command, .shift])
                    .pointerStyle(.link)
                }
                Button { save(continueAdding: false) } label: {
                    Label(existing == nil ? "Save & Close" : "Save", systemImage: "checkmark")
                }
                .keyboardShortcut(.defaultAction)
                .pointerStyle(.link)
            }
            Button("") { save(continueAdding: false) }
                .keyboardShortcut("s", modifiers: .command)
                .hidden()
                .frame(width: 0, height: 0)
        }
        .padding(24)
        .frame(minWidth: 560)
        .onAppear {
            prefill()
            initialSnapshot = currentSnapshot
        }
        .animation(.easeInOut(duration: 0.2), value: savedToast)
        .confirmationDialog("Save changes before closing?", isPresented: $showUnsavedConfirm) {
            Button("Save") { save(continueAdding: false) }
                .keyboardShortcut(.defaultAction)
            Button("Discard", role: .destructive) { dismiss() }
            Button("Cancel", role: .cancel) {}
        }
    }

    private var duplicateWarning: String? {
        let trimmed = name.trimmingCharacters(in: .whitespaces).lowercased()
        guard trimmed.count >= 2 else { return nil }
        let dups = allAccounts.filter {
            $0.id != existing?.id
                && $0.name.lowercased() == trimmed
                && $0.person?.id == personID
                && $0.country?.id == countryID
        }
        guard !dups.isEmpty else { return nil }
        let owner = dups.first?.person?.name ?? "no person"
        let country = dups.first?.country?.code ?? "no country"
        return "Same name + person (\(owner)) + country (\(country)) already exists."
    }

    private func prefill() {
        if let a = existing {
            name = a.name
            personID = a.person?.id
            countryID = a.country?.id
            assetTypeID = a.assetType?.id
            nativeCurrency = a.nativeCurrency
            institution = a.institution
            notes = a.notes
            isActive = a.isActive
            costBasis = a.costBasis
            return
        }
        // New account: prefill from last-saved.
        if personID == nil, let id = UUID(uuidString: lastPersonIDStr),
           people.contains(where: { $0.id == id }) { personID = id }
        if countryID == nil, let id = UUID(uuidString: lastCountryIDStr),
           countries.contains(where: { $0.id == id }) { countryID = id }
        if assetTypeID == nil, let id = UUID(uuidString: lastAssetTypeIDStr),
           assetTypes.contains(where: { $0.id == id }) { assetTypeID = id }
        if let c = Currency(rawValue: lastCurrencyRaw) {
            nativeCurrency = c
        } else if let c = Currency(rawValue: displayCurrencyRaw) {
            nativeCurrency = c
        }
        // Country default currency (set by .onChange) only fires if user picks
        // country *after* sheet open. If a country is prefilled from last-saved,
        // honor its defaultCurrency over the display currency fallback.
        if lastCurrencyRaw.isEmpty,
           let id = countryID,
           let c = countries.first(where: { $0.id == id }) {
            nativeCurrency = c.defaultCurrency
        }
        if institution.isEmpty { institution = lastInstitution }
    }

    private func save(continueAdding: Bool = false) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { errorMessage = "Name required."; return }
        guard let p = people.first(where: { $0.id == personID }) else { errorMessage = "Pick person."; return }
        guard let c = countries.first(where: { $0.id == countryID }) else { errorMessage = "Pick country."; return }
        guard let t = assetTypes.first(where: { $0.id == assetTypeID }) else { errorMessage = "Pick asset type."; return }

        let hardDup = allAccounts.contains {
            $0.id != existing?.id
                && $0.name.lowercased() == trimmed.lowercased()
                && $0.person?.id == p.id
        }
        if hardDup {
            errorMessage = "\(p.name) already owns an account named “\(trimmed)”."
            return
        }

        if let a = existing {
            a.name = trimmed
            a.person = p
            a.country = c
            a.assetType = t
            a.nativeCurrency = nativeCurrency
            a.institution = institution
            a.notes = notes
            a.isActive = isActive
            a.costBasis = max(0, costBasis)
        } else {
            let a = Account(name: trimmed, person: p, country: c, assetType: t,
                            nativeCurrency: nativeCurrency, institution: institution,
                            notes: notes, isActive: isActive)
            a.costBasis = max(0, costBasis)
            a.sortIndex = (allAccounts.map(\.sortIndex).max() ?? 0) + 1
            context.insert(a)
        }

        do {
            try context.save()
            errorMessage = nil
            // Remember last selections for next "Save & Add Next" / next sheet open.
            lastPersonIDStr    = p.id.uuidString
            lastCountryIDStr   = c.id.uuidString
            lastAssetTypeIDStr = t.id.uuidString
            lastCurrencyRaw    = nativeCurrency.rawValue
            lastInstitution    = institution

            if continueAdding {
                savedToast = "Added “\(trimmed)”. Continue adding…"
                // Reset name + notes; keep person/country/type/ccy/inst.
                name = ""
                notes = ""
                initialSnapshot = currentSnapshot
                Task {
                    try? await Task.sleep(nanoseconds: 1_800_000_000)
                    await MainActor.run { savedToast = nil }
                }
            } else {
                dismiss()
            }
        }
        catch { errorMessage = "Save failed: \(error.localizedDescription)" }
    }
}

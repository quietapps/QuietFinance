import SwiftUI
import SwiftData

struct BulkEditAccountsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \Person.name) private var people: [Person]
    @Query(sort: \Country.code) private var countries: [Country]
    @Query(sort: \AssetType.name) private var assetTypes: [AssetType]
    @Query private var allAccounts: [Account]

    let accountIDs: Set<UUID>
    var onComplete: () -> Void = {}

    @State private var applyPerson = false
    @State private var applyCountry = false
    @State private var applyAssetType = false
    @State private var applyActive = false
    @State private var applyGroup = false

    @State private var personID: UUID?
    @State private var countryID: UUID?
    @State private var assetTypeID: UUID?
    @State private var isActive: Bool = true
    @State private var groupName: String = ""

    @State private var errorMessage: String?

    private var targets: [Account] {
        allAccounts.filter { accountIDs.contains($0.id) }
    }

    private var anyApplied: Bool {
        applyPerson || applyCountry || applyAssetType || applyActive || applyGroup
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Bulk Edit Accounts").font(Typo.serifNum(24))
            Text("\(targets.count) selected. Toggle a field to apply its new value to all.")
                .font(Typo.sans(12)).foregroundStyle(Color.lInk2)

            Form {
                row(toggle: $applyPerson, label: "Person") {
                    Picker("", selection: $personID) {
                        Text("—").tag(UUID?.none)
                        ForEach(people) { Text($0.name).tag(UUID?.some($0.id)) }
                    }.labelsHidden().disabled(!applyPerson)
                }
                row(toggle: $applyCountry, label: "Country") {
                    Picker("", selection: $countryID) {
                        Text("—").tag(UUID?.none)
                        ForEach(countries) { Text("\($0.flag) \($0.name)").tag(UUID?.some($0.id)) }
                    }.labelsHidden().disabled(!applyCountry)
                }
                row(toggle: $applyAssetType, label: "Asset Type") {
                    Picker("", selection: $assetTypeID) {
                        Text("—").tag(UUID?.none)
                        ForEach(assetTypes) { Text("\($0.name) (\($0.category.rawValue))").tag(UUID?.some($0.id)) }
                    }.labelsHidden().disabled(!applyAssetType)
                }
                row(toggle: $applyActive, label: "Status") {
                    Picker("", selection: $isActive) {
                        Text("Active").tag(true)
                        Text("Retired").tag(false)
                    }.pickerStyle(.segmented).labelsHidden().disabled(!applyActive)
                }
                row(toggle: $applyGroup, label: "Group") {
                    TextField("Group name (empty to clear)", text: $groupName)
                        .disabled(!applyGroup)
                }
            }
            .formStyle(.grouped)

            if let err = errorMessage {
                Text(err).foregroundStyle(Color.lLoss).font(Typo.sans(12))
            }

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Apply to \(targets.count)") { apply() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!anyApplied || targets.isEmpty)
            }
        }
        .padding(24)
        .frame(minWidth: 560)
    }

    @ViewBuilder
    private func row<Content: View>(toggle: Binding<Bool>, label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack {
            Toggle(isOn: toggle) { Text(label) }
            Spacer()
            content().frame(maxWidth: 280)
        }
    }

    private func apply() {
        let p = applyPerson ? people.first(where: { $0.id == personID }) : nil
        let c = applyCountry ? countries.first(where: { $0.id == countryID }) : nil
        let t = applyAssetType ? assetTypes.first(where: { $0.id == assetTypeID }) : nil

        if applyPerson && p == nil { errorMessage = "Pick a person."; return }
        if applyCountry && c == nil { errorMessage = "Pick a country."; return }
        if applyAssetType && t == nil { errorMessage = "Pick an asset type."; return }

        for a in targets {
            if let p { a.person = p }
            if let c { a.country = c }
            if let t { a.assetType = t }
            if applyActive { a.isActive = isActive }
            if applyGroup { a.groupName = groupName.trimmingCharacters(in: .whitespaces) }
        }

        do {
            try context.save()
            onComplete()
            dismiss()
        } catch {
            context.rollback()
            errorMessage = "Save failed: \(error.localizedDescription)"
        }
    }
}

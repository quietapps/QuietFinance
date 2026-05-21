import SwiftUI
import SwiftData

struct CountriesView: View {
    @EnvironmentObject var app: AppState
    @Environment(\.modelContext) private var context
    @Query(sort: \Country.code) private var countries: [Country]
    @State private var confirmDelete: Country?
    @State private var addingNew: Bool = false
    @State private var newCode: String = ""
    @State private var newName: String = ""
    @State private var newFlag: String = "🌐"
    @State private var newCurrency: Currency = .USD
    @State private var newColor: Color = .blue
    /// Drives the FlagPickerSheet. When non-nil, picker is open. Identifies
    /// either the existing Country being edited (`Existing(country)`) or the
    /// in-progress add row (`AddRow`).
    @State private var flagTarget: FlagPickerTarget?
    @FocusState private var focusedNewName: Bool
    @AppStorage("displayCurrency") private var displayCurrencyRaw: String = Currency.USD.rawValue

    private enum FlagPickerTarget: Identifiable {
        case existing(Country)
        case addRow
        var id: String {
            switch self {
            case .existing(let c): return c.id.uuidString
            case .addRow:          return "addRow"
            }
        }
    }

    @StateObject private var sizer = ColumnSizer(tableID: "countries", specs: [
        ColumnSpec(id: "color",    title: "Color",    minWidth: 60,  defaultWidth: 70,  resizable: false, sortable: false),
        ColumnSpec(id: "flag",     title: "Flag",     minWidth: 50,  defaultWidth: 60,  resizable: false, sortable: false),
        ColumnSpec(id: "code",     title: "Code",     minWidth: 60,  defaultWidth: 80),
        ColumnSpec(id: "name",     title: "Name",     minWidth: 140, defaultWidth: 280, flex: true),
        ColumnSpec(id: "ccy",      title: "Ccy",      minWidth: 70,  defaultWidth: 110),
        ColumnSpec(id: "accounts", title: "Accounts", minWidth: 80,  defaultWidth: 100, alignment: .trailing),
        ColumnSpec(id: "actions",  title: "",         minWidth: 60,  defaultWidth: 60,  alignment: .trailing, resizable: false, sortable: false),
    ])

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            header
            if countries.isEmpty {
                EditorialEmpty(
                    eyebrow: "Breakdown · Countries",
                    title: "No jurisdictions",
                    titleItalic: "on file.",
                    body: "Countries carry a flag, a default currency, and pin each account to a tax home. Add at least one before creating accounts.",
                    detail: "Click 'New Country' to add a row. Edit any field directly in the grid.",
                    illustration: "globe"
                )
            }
            tablePanel
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .sheet(item: $flagTarget) { target in
            switch target {
            case .existing(let c):
                FlagPickerSheet(
                    flag: Binding(get: { c.flag }, set: { c.flag = $0; try? context.save() }),
                    code: Binding(get: { c.code }, set: { c.code = $0; try? context.save() })
                )
            case .addRow:
                FlagPickerSheet(flag: $newFlag, code: $newCode)
            }
        }
        .confirmationDialog("Delete \(confirmDelete?.name ?? "")?",
                            isPresented: Binding(get: { confirmDelete != nil }, set: { if !$0 { confirmDelete = nil } }),
                            titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                if let c = confirmDelete { context.delete(c); try? context.save() }
                confirmDelete = nil
            }
            .keyboardShortcut(.defaultAction)
            Button("Cancel", role: .cancel) { confirmDelete = nil }
        } message: {
            Text("Country, all \(confirmDelete?.accounts.count ?? 0) accounts in this country, and their historical values will be deleted. Cannot be undone.")
        }
        .onAppear { consumePendingFocus() }
        .onChange(of: app.pendingFocusCountryID) { _, _ in consumePendingFocus() }
    }

    private func consumePendingFocus() {
        app.pendingFocusCountryID = nil
    }

    private func seedNewColor() {
        let taken = countries.compactMap { $0.colorHex }
        newColor = Palette.unusedFallback(taken: taken)
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("BREAKDOWN")
                    .font(Typo.eyebrow).tracking(1.5).foregroundStyle(Color.lInk3)
                HStack(spacing: 8) {
                    Text("Countries").font(Typo.serifNum(32))
                    Text("— \(countries.count)").font(Typo.serifItalic(28))
                        .foregroundStyle(Color.lInk3)
                }
                .foregroundStyle(Color.lInk)
            }
            Spacer()
            PrimaryButton(action: {
                addingNew = true
                seedNewColor()
                newCode = ""
                newName = ""
                newFlag = "🌐"
                newCurrency = Currency(rawValue: displayCurrencyRaw) ?? .USD
                DispatchQueue.main.async { focusedNewName = true }
            }) {
                HStack(spacing: 5) {
                    Image(systemName: "plus").font(.system(size: 10, weight: .bold))
                    Text("New Country")
                }
            }
        }
    }

    private var sortedRows: [Country] {
        sizer.sorted(countries, comparators: [
            "code":     { $0.code < $1.code },
            "name":     { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending },
            "ccy":      { $0.defaultCurrency.rawValue < $1.defaultCurrency.rawValue },
            "accounts": { $0.accounts.count < $1.accounts.count },
        ])
    }

    private var tablePanel: some View {
        Panel {
            VStack(spacing: 0) {
                PanelHead(title: "Jurisdictions",
                          meta: "Edit inline · click flag to pick")
                ResizableHeader(sizer: sizer)
                ScrollView(.vertical) {
                    LazyVStack(spacing: 0) {
                        let sortedCountries = sortedRows
                        ForEach(Array(sortedCountries.enumerated()), id: \.element.id) { idx, c in
                            row(c, idx: idx)
                            if idx < sortedCountries.count - 1 || addingNew {
                                Divider().overlay(Color.lLine)
                            }
                        }
                        if addingNew {
                            addRow
                        }
                    }
                }
            }
        }
        .frame(maxHeight: .infinity)
    }

    private var addRow: some View {
        HStack(spacing: 0) {
            ResizableCell(sizer: sizer, colID: "color") {
                HStack {
                    ColorSwatchButton(current: newColor, onPick: { newColor = $0 }, size: 16)
                    Spacer(minLength: 0)
                }
            }
            ResizableCell(sizer: sizer, colID: "flag") {
                Button {
                    flagTarget = .addRow
                } label: {
                    Text(newFlag).font(.system(size: 16))
                        .frame(width: 30, height: 22)
                        .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.lLine, lineWidth: 1))
                }
                .buttonStyle(.plain).pointerStyle(.link)
            }
            ResizableCell(sizer: sizer, colID: "code") {
                TextField("US", text: $newCode)
                    .textFieldStyle(.plain)
                    .font(Typo.mono(12, weight: .semibold))
                    .foregroundStyle(Color.lInk)
                    .onChange(of: newCode) { _, v in
                        let upper = v.uppercased()
                        if upper != newCode { newCode = String(upper.prefix(3)) }
                    }
            }
            ResizableCell(sizer: sizer, colID: "name") {
                TextField("Country name", text: $newName)
                    .textFieldStyle(.plain)
                    .font(Typo.sans(13, weight: .medium))
                    .foregroundStyle(Color.lInk)
                    .focused($focusedNewName)
                    .onSubmit { commitNew() }
            }
            ResizableCell(sizer: sizer, colID: "ccy") {
                Picker("", selection: $newCurrency) {
                    ForEach(Currency.allCases) { Text($0.rawValue).tag($0) }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .controlSize(.small)
            }
            ResizableCell(sizer: sizer, colID: "accounts") {
                Text("—").font(Typo.mono(11)).foregroundStyle(Color.lInk4)
            }
            ResizableCell(sizer: sizer, colID: "actions") {
                HStack(spacing: 6) {
                    Button { cancelNew() } label: {
                        Image(systemName: "xmark.circle")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.lInk3)
                    }
                    .buttonStyle(.plain).pointerStyle(.link).help("Cancel")
                    Button { commitNew() } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(canCommit ? Color.lGain : Color.lInk4)
                    }
                    .buttonStyle(.plain).pointerStyle(.link)
                    .disabled(!canCommit)
                    .keyboardShortcut(.defaultAction)
                }
            }
        }
        .padding(.horizontal, 18).padding(.vertical, 10)
        .background(Color.lSunken.opacity(0.4))
    }

    private var canCommit: Bool {
        let n = newName.trimmingCharacters(in: .whitespaces)
        let c = newCode.trimmingCharacters(in: .whitespaces)
        return !n.isEmpty && !c.isEmpty
    }

    private func cancelNew() {
        addingNew = false
        focusedNewName = false
    }

    private func commitNew() {
        guard canCommit else { return }
        let code = newCode.trimmingCharacters(in: .whitespaces).uppercased()
        let name = newName.trimmingCharacters(in: .whitespaces)
        // Reject duplicate code.
        if countries.contains(where: { $0.code == code }) { return }
        let c = Country(code: code, name: name, flag: newFlag, defaultCurrency: newCurrency)
        c.colorHex = newColor.toHex()
        context.insert(c)
        try? context.save()
        addingNew = false
        focusedNewName = false
    }

    private func row(_ c: Country, idx: Int) -> some View {
        HStack(spacing: 0) {
            ResizableCell(sizer: sizer, colID: "color") {
                HStack {
                    ColorSwatchButton(
                        current: Color.fromHex(c.colorHex) ?? Palette.fallback(for: c.code),
                        onPick: { col in
                            c.colorHex = col.toHex()
                            try? context.save()
                        },
                        size: 16
                    )
                    Spacer(minLength: 0)
                }
            }
            ResizableCell(sizer: sizer, colID: "flag") {
                Button {
                    flagTarget = .existing(c)
                } label: {
                    Text(c.flag).font(.system(size: 16))
                        .frame(width: 30, height: 22)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain).pointerStyle(.link)
                .help("Pick flag")
            }
            ResizableCell(sizer: sizer, colID: "code") {
                TextField("Code", text: Binding(
                    get: { c.code },
                    set: { newVal in
                        let upper = String(newVal.uppercased().prefix(3))
                        if upper != c.code, !upper.isEmpty,
                           !countries.contains(where: { $0.id != c.id && $0.code == upper }) {
                            c.code = upper
                            try? context.save()
                        }
                    }
                ))
                .textFieldStyle(.plain)
                .font(Typo.mono(12, weight: .semibold))
                .foregroundStyle(Color.lInk)
            }
            ResizableCell(sizer: sizer, colID: "name") {
                TextField("Name", text: Binding(
                    get: { c.name },
                    set: { c.name = $0; try? context.save() }
                ))
                .textFieldStyle(.plain)
                .font(Typo.sans(13, weight: .medium))
                .foregroundStyle(Color.lInk)
                .lineLimit(1)
            }
            ResizableCell(sizer: sizer, colID: "ccy") {
                Picker("", selection: Binding(
                    get: { c.defaultCurrency },
                    set: { c.defaultCurrency = $0; try? context.save() }
                )) {
                    ForEach(Currency.allCases) { Text($0.rawValue).tag($0) }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .controlSize(.small)
            }
            ResizableCell(sizer: sizer, colID: "accounts") {
                Text("\(c.accounts.count)")
                    .font(Typo.mono(12))
                    .foregroundStyle(Color.lInk2)
            }
            ResizableCell(sizer: sizer, colID: "actions") {
                Button { confirmDelete = c } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.lInk3)
                }
                .buttonStyle(.plain).pointerStyle(.link)
                .help("Delete country and all its accounts")
            }
        }
        .padding(.horizontal, 18).padding(.vertical, 10)
        .background(idx.isMultiple(of: 2) ? Color.clear : Color.lSunken.opacity(0.5))
    }
}

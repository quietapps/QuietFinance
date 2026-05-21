import SwiftUI
import SwiftData

struct PeopleView: View {
    @EnvironmentObject var app: AppState
    @Environment(\.modelContext) private var context
    @Query(sort: \Person.name) private var people: [Person]
    @State private var confirmDelete: Person?
    @State private var newName: String = ""
    @State private var newColor: Color = .blue
    @State private var newInclude: Bool = true
    @State private var showInactive: Bool = true
    @State private var addingNew: Bool = false
    @FocusState private var focusedNewRow: Bool
    @StateObject private var sizer = ColumnSizer(tableID: "people", specs: [
        ColumnSpec(id: "color",    title: "Color",    minWidth: 60,  defaultWidth: 70,  resizable: false, sortable: false),
        ColumnSpec(id: "name",     title: "Name",     minWidth: 160, defaultWidth: 280, flex: true),
        ColumnSpec(id: "include",  title: "In NW",    minWidth: 70,  defaultWidth: 80,  resizable: false),
        ColumnSpec(id: "active",   title: "Active",   minWidth: 70,  defaultWidth: 80,  resizable: false),
        ColumnSpec(id: "accounts", title: "Accounts", minWidth: 80,  defaultWidth: 100, alignment: .trailing),
        ColumnSpec(id: "actions",  title: "",         minWidth: 60,  defaultWidth: 60,  alignment: .trailing, resizable: false, sortable: false),
    ])

    private var visible: [Person] {
        let base = showInactive ? people : people.filter(\.isActive)
        return sizer.sorted(base, comparators: [
            "name":     { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending },
            "include":  { ($0.includeInNetWorth ? 0 : 1) < ($1.includeInNetWorth ? 0 : 1) },
            "active":   { ($0.isActive ? 0 : 1) < ($1.isActive ? 0 : 1) },
            "accounts": { $0.accounts.count < $1.accounts.count },
        ])
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            header
            if people.isEmpty {
                EditorialEmpty(
                    eyebrow: "Breakdown · People",
                    title: "No household",
                    titleItalic: "members yet.",
                    body: "Wealth is usually held by someone. Add the people whose accounts you track — they become filters across every view.",
                    detail: "Type a name in the row at the bottom to add. Toggle 'In NW' off for parents / partners whose accounts you track but don't include in your own net worth.",
                    illustration: "person.2"
                )
            }
            tablePanel
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .confirmationDialog("Delete \(confirmDelete?.name ?? "")?",
                            isPresented: Binding(get: { confirmDelete != nil }, set: { if !$0 { confirmDelete = nil } }),
                            titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                if let p = confirmDelete { context.delete(p); try? context.save() }
                confirmDelete = nil
            }
            .keyboardShortcut(.defaultAction)
            Button("Cancel", role: .cancel) { confirmDelete = nil }
        } message: {
            Text("Person, all \(confirmDelete?.accounts.count ?? 0) accounts, and all historical snapshot values will be deleted. Cannot be undone.")
        }
        .onAppear {
            seedNewColor()
            consumePendingFocus()
        }
        .onChange(of: app.pendingFocusPersonID) { _, _ in consumePendingFocus() }
    }

    private func consumePendingFocus() {
        app.pendingFocusPersonID = nil
    }

    private func seedNewColor() {
        let taken = people.compactMap { $0.colorHex }
        newColor = Palette.unusedFallback(taken: taken)
    }

    private var header: some View {
        HStack(alignment: .lastTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text("BREAKDOWN")
                    .font(Typo.eyebrow).tracking(1.5).foregroundStyle(Color.lInk3)
                HStack(spacing: 8) {
                    Text("People").font(Typo.serifNum(32))
                    Text("— \(visible.count) of \(people.count)")
                        .font(Typo.serifItalic(28))
                        .foregroundStyle(Color.lInk3)
                }
                .foregroundStyle(Color.lInk)
            }
            Spacer()
            Toggle("Show inactive", isOn: $showInactive)
                .toggleStyle(.switch)
                .controlSize(.small)
                .font(Typo.sans(11))
                .foregroundStyle(Color.lInk3)
            PrimaryButton(action: {
                addingNew = true
                seedNewColor()
                DispatchQueue.main.async { focusedNewRow = true }
            }) {
                HStack(spacing: 5) {
                    Image(systemName: "plus").font(.system(size: 10, weight: .bold))
                    Text("New Person")
                }
            }
        }
    }

    private var tablePanel: some View {
        Panel {
            VStack(spacing: 0) {
                PanelHead(title: "Household members",
                          meta: "Edit inline · toggle In NW to exclude from totals")
                ResizableHeader(sizer: sizer)
                ScrollView(.vertical) {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(visible.enumerated()), id: \.element.id) { idx, p in
                            row(p, idx: idx)
                            if idx < visible.count - 1 || addingNew {
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
            ResizableCell(sizer: sizer, colID: "name") {
                TextField("Add new person…", text: $newName)
                    .textFieldStyle(.plain)
                    .font(Typo.sans(13, weight: .medium))
                    .foregroundStyle(Color.lInk)
                    .focused($focusedNewRow)
                    .onSubmit { commitNew() }
            }
            ResizableCell(sizer: sizer, colID: "include") {
                Toggle("", isOn: $newInclude)
                    .toggleStyle(.switch)
                    .labelsHidden()
                    .controlSize(.small)
            }
            ResizableCell(sizer: sizer, colID: "active") {
                Text("—").font(Typo.mono(11)).foregroundStyle(Color.lInk4)
            }
            ResizableCell(sizer: sizer, colID: "accounts") {
                Text("—").font(Typo.mono(11)).foregroundStyle(Color.lInk4)
            }
            ResizableCell(sizer: sizer, colID: "actions") {
                HStack(spacing: 6) {
                    Button {
                        cancelNew()
                    } label: {
                        Image(systemName: "xmark.circle")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.lInk3)
                    }
                    .buttonStyle(.plain)
                    .pointerStyle(.link)
                    .help("Cancel")
                    Button {
                        commitNew()
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(newName.trimmingCharacters(in: .whitespaces).isEmpty
                                             ? Color.lInk4 : Color.lGain)
                    }
                    .buttonStyle(.plain)
                    .pointerStyle(.link)
                    .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
                    .keyboardShortcut(.defaultAction)
                }
            }
        }
        .padding(.horizontal, 18).padding(.vertical, 10)
        .background(Color.lSunken.opacity(0.4))
    }

    private func cancelNew() {
        newName = ""
        newInclude = true
        addingNew = false
        focusedNewRow = false
    }

    private func commitNew() {
        let trimmed = newName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let p = Person(name: trimmed)
        p.colorHex = newColor.toHex()
        p.includeInNetWorth = newInclude
        p.isActive = true
        context.insert(p)
        try? context.save()
        newName = ""
        newInclude = true
        addingNew = false
        focusedNewRow = false
        seedNewColor()
    }

    private func row(_ p: Person, idx: Int) -> some View {
        HStack(spacing: 0) {
            ResizableCell(sizer: sizer, colID: "color") {
                HStack {
                    ColorSwatchButton(
                        current: Color.fromHex(p.colorHex) ?? Palette.fallback(for: p.name),
                        onPick: { c in
                            p.colorHex = c.toHex()
                            try? context.save()
                        },
                        size: 16
                    )
                    Spacer(minLength: 0)
                }
            }
            ResizableCell(sizer: sizer, colID: "name") {
                TextField("Name", text: Binding(
                    get: { p.name },
                    set: { newVal in
                        p.name = newVal
                        try? context.save()
                    }
                ))
                .textFieldStyle(.plain)
                .font(Typo.sans(13, weight: .medium))
                .foregroundStyle(Color.lInk)
                .lineLimit(1)
            }
            ResizableCell(sizer: sizer, colID: "include") {
                Toggle("", isOn: Binding(
                    get: { p.includeInNetWorth },
                    set: { newOn in
                        p.includeInNetWorth = newOn
                        try? context.save()
                    }
                ))
                .toggleStyle(.switch)
                .labelsHidden()
                .controlSize(.small)
                .help(p.includeInNetWorth
                      ? "Counted in net worth and aggregations."
                      : "Excluded from net worth — accounts tracked but not aggregated.")
            }
            ResizableCell(sizer: sizer, colID: "active") {
                Toggle("", isOn: Binding(
                    get: { p.isActive },
                    set: { newOn in
                        p.isActive = newOn
                        try? context.save()
                    }
                ))
                .toggleStyle(.switch)
                .labelsHidden()
                .controlSize(.small)
                .help(p.isActive
                      ? "Active — shown by default."
                      : "Archived — hidden when 'Show inactive' is off.")
            }
            ResizableCell(sizer: sizer, colID: "accounts") {
                Text("\(p.accounts.count)")
                    .font(Typo.mono(12))
                    .foregroundStyle(Color.lInk2)
            }
            ResizableCell(sizer: sizer, colID: "actions") {
                Button { confirmDelete = p } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.lInk3)
                }
                .buttonStyle(.plain)
                .pointerStyle(.link)
                .help("Delete person and all their accounts")
            }
        }
        .padding(.horizontal, 18).padding(.vertical, 10)
        .background(idx.isMultiple(of: 2) ? Color.clear : Color.lSunken.opacity(0.5))
        .opacity(p.isActive ? (p.includeInNetWorth ? 1.0 : 0.78) : 0.55)
    }
}

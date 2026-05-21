import SwiftUI
import SwiftData

struct AssetTypesView: View {
    @EnvironmentObject var app: AppState
    @Environment(\.modelContext) private var context
    @Query(sort: \AssetType.name) private var types: [AssetType]
    @State private var editing: AssetType?
    @State private var creatingNew: Bool = false
    @State private var confirmDelete: AssetType?
    @State private var colorTick: Int = 0
    @StateObject private var sizer = ColumnSizer(tableID: "assetTypes", specs: [
        ColumnSpec(id: "color",    title: "Color",    minWidth: 60,  defaultWidth: 80,  resizable: false, sortable: false),
        ColumnSpec(id: "name",     title: "Name",     minWidth: 140, defaultWidth: 280, flex: true),
        ColumnSpec(id: "category", title: "Category", minWidth: 110, defaultWidth: 160),
        ColumnSpec(id: "accounts", title: "Accounts", minWidth: 80,  defaultWidth: 110, alignment: .trailing),
        ColumnSpec(id: "actions",  title: "",         minWidth: 160, defaultWidth: 160, alignment: .trailing, resizable: false, sortable: false),
    ])

    private var sortedTypes: [AssetType] {
        sizer.sorted(types, comparators: [
            "name":     { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending },
            "category": { $0.category.rawValue < $1.category.rawValue },
            "accounts": { $0.accounts.count < $1.accounts.count },
        ])
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            header
            if types.isEmpty {
                EditorialEmpty(
                    eyebrow: "Breakdown · Asset Types",
                    title: "No taxonomy",
                    titleItalic: "defined.",
                    body: "Asset types classify what each account holds — cash, equities, real estate, crypto, debt. They drive every category breakdown in the app.",
                    detail: "Each type belongs to a category: Cash · Investment · Retirement · Insurance · Crypto · Debt · Other.",
                    ctaLabel: "New Type",
                    cta: { creatingNew = true },
                    illustration: "square.stack.3d.up"
                )
            } else {
                tablePanel
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .sheet(item: $editing) { AssetTypeEditorSheet(existing: $0) }
        .sheet(isPresented: $creatingNew) { AssetTypeEditorSheet(existing: nil) }
        .confirmationDialog("Delete \(confirmDelete?.name ?? "")?",
                            isPresented: Binding(get: { confirmDelete != nil }, set: { if !$0 { confirmDelete = nil } }),
                            titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                if let t = confirmDelete { context.delete(t); try? context.save() }
                confirmDelete = nil
            }
            .keyboardShortcut(.defaultAction)
            Button("Cancel", role: .cancel) { confirmDelete = nil }
        } message: {
            Text("Asset type, all \(confirmDelete?.accounts.count ?? 0) accounts using it, and their historical values will be deleted. Cannot be undone.")
        }
        .onAppear { consumePendingFocus() }
        .onChange(of: app.pendingFocusAssetTypeID) { _, _ in consumePendingFocus() }
    }

    private func consumePendingFocus() {
        guard let id = app.pendingFocusAssetTypeID,
              let t = types.first(where: { $0.id == id }) else { return }
        editing = t
        app.pendingFocusAssetTypeID = nil
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("BREAKDOWN")
                    .font(Typo.eyebrow).tracking(1.5).foregroundStyle(Color.lInk3)
                HStack(spacing: 8) {
                    Text("Asset Types").font(Typo.serifNum(32))
                    Text("— \(types.count)").font(Typo.serifItalic(28))
                        .foregroundStyle(Color.lInk3)
                }
                .foregroundStyle(Color.lInk)
            }
            Spacer()
            PrimaryButton(action: { creatingNew = true }) {
                HStack(spacing: 5) {
                    Image(systemName: "plus").font(.system(size: 10, weight: .bold))
                    Text("New Type")
                }
            }
        }
    }

    private var tablePanel: some View {
        Panel {
            VStack(spacing: 0) {
                PanelHead(title: "Asset taxonomy", meta: "\(types.count) total")
                ResizableHeader(sizer: sizer)
                ScrollView(.vertical) {
                    LazyVStack(spacing: 0) {
                        let rows = sortedTypes
                        ForEach(Array(rows.enumerated()), id: \.element.id) { idx, t in
                            row(t, idx: idx)
                            if idx < rows.count - 1 {
                                Divider().overlay(Color.lLine)
                            }
                        }
                    }
                }
            }
        }
        .frame(maxHeight: .infinity)
    }

    private func row(_ t: AssetType, idx: Int) -> some View {
        HStack(spacing: 0) {
            ResizableCell(sizer: sizer, colID: "color") {
                HStack {
                    ColorSwatchButton(
                        current: Palette.color(for: t.category),
                        onPick: { c in
                            CategoryColorStore.setHex(c.toHex(), for: t.category)
                            colorTick &+= 1
                        }
                    )
                    .id("swatch-\(t.id)-\(colorTick)")
                    Spacer(minLength: 0)
                }
            }
            ResizableCell(sizer: sizer, colID: "name") {
                Text(t.name)
                    .font(Typo.sans(13, weight: .medium))
                    .foregroundStyle(Color.lInk)
                    .lineLimit(1)
            }
            ResizableCell(sizer: sizer, colID: "category") {
                Text(t.category.rawValue)
                    .font(Typo.sans(12))
                    .foregroundStyle(Color.lInk2)
                    .lineLimit(1)
            }
            ResizableCell(sizer: sizer, colID: "accounts") {
                Text("\(t.accounts.count)")
                    .font(Typo.mono(12))
                    .foregroundStyle(Color.lInk2)
            }
            ResizableCell(sizer: sizer, colID: "actions") {
                HStack(spacing: 6) {
                    GhostButton(action: { editing = t }) { Text("Edit") }
                    GhostButton(action: { confirmDelete = t }) {
                        Image(systemName: "trash").font(.system(size: 10, weight: .bold))
                    }
                }
            }
        }
        .padding(.horizontal, 18).padding(.vertical, 10)
        .background(idx.isMultiple(of: 2) ? Color.clear : Color.lSunken.opacity(0.5))
        .rowClickable { editing = t }
    }
}

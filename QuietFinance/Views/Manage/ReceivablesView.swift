import SwiftUI
import SwiftData

struct ReceivablesView: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject var app: AppState
    @Query(sort: \Receivable.name) private var receivables: [Receivable]
    @Query(sort: \Snapshot.date, order: .reverse) private var snapshots: [Snapshot]
    @State private var editing: Receivable?
    @State private var creatingNew: Bool = false
    @State private var confirmDelete: Receivable?
    @State private var showInactive: Bool = false

    @StateObject private var sizer = ColumnSizer(tableID: "receivables", specs: [
        ColumnSpec(id: "name",     title: "Name",     minWidth: 140, defaultWidth: 240, flex: true),
        ColumnSpec(id: "debtor",   title: "Debtor",   minWidth: 100, defaultWidth: 180),
        ColumnSpec(id: "ccy",      title: "Ccy",      minWidth: 50,  defaultWidth: 60,  alignment: .center),
        ColumnSpec(id: "latest",   title: "Latest",   minWidth: 100, defaultWidth: 140, alignment: .trailing),
        ColumnSpec(id: "status",   title: "Status",   minWidth: 70,  defaultWidth: 90,  alignment: .leading),
        ColumnSpec(id: "actions",  title: "",         minWidth: 160, defaultWidth: 160, alignment: .trailing, resizable: false, sortable: false),
    ])

    private var visible: [Receivable] {
        let base = showInactive ? receivables : receivables.filter { $0.isActive }
        return sizer.sorted(base, comparators: [
            "name":   { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending },
            "debtor": { $0.debtor.localizedCaseInsensitiveCompare($1.debtor) == .orderedAscending },
            "ccy":    { $0.nativeCurrency.rawValue < $1.nativeCurrency.rawValue },
            "latest": { (latestValue(for: $0) ?? -.infinity) < (latestValue(for: $1) ?? -.infinity) },
            "status": { ($0.isActive ? 0 : 1) < ($1.isActive ? 0 : 1) },
        ])
    }

    private func latestValue(for r: Receivable) -> Double? {
        guard let snap = snapshots.first else { return nil }
        return snap.receivableValues.first { $0.receivable?.id == r.id }?.nativeValue
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            header
            if receivables.isEmpty {
                EditorialEmpty(
                    eyebrow: "Outside Net Worth",
                    title: "No pending",
                    titleItalic: "receivables yet.",
                    body: "Track money you're owed but haven't received — loans to friends, unpaid invoices, expected reimbursements. Values stay outside net worth and can be updated each snapshot as partial or full receipt happens.",
                    detail: "Set the value to zero once received. The record stays for history.",
                    ctaLabel: "New Receivable",
                    cta: { creatingNew = true },
                    illustration: "hourglass"
                )
            } else {
                tablePanel
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .sheet(item: $editing) { ReceivableEditorSheet(existing: $0) }
        .sheet(isPresented: $creatingNew) { ReceivableEditorSheet(existing: nil) }
        .confirmationDialog("Delete \(confirmDelete?.name ?? "")?",
                            isPresented: Binding(get: { confirmDelete != nil }, set: { if !$0 { confirmDelete = nil } }),
                            titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                if let r = confirmDelete { context.delete(r); try? context.save() }
                confirmDelete = nil
            }
            .keyboardShortcut(.defaultAction)
            Button("Cancel", role: .cancel) { confirmDelete = nil }
        } message: {
            Text("Receivable and all \(confirmDelete?.values.count ?? 0) historical values will be deleted. Cannot be undone.")
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("OUTSIDE NET WORTH")
                    .font(Typo.eyebrow).tracking(1.5).foregroundStyle(Color.lInk3)
                HStack(spacing: 8) {
                    Text("Receivables").font(Typo.serifNum(32))
                    Text("— \(visible.count)").font(Typo.serifItalic(28))
                        .foregroundStyle(Color.lInk3)
                }
                .foregroundStyle(Color.lInk)
            }
            Spacer()
            Toggle("Show inactive", isOn: $showInactive)
                .toggleStyle(.switch)
                .font(Typo.sans(11))
            PrimaryButton(action: { creatingNew = true }) {
                HStack(spacing: 5) {
                    Image(systemName: "plus").font(.system(size: 10, weight: .bold))
                    Text("New Receivable")
                }
            }
        }
    }

    private var tablePanel: some View {
        Panel {
            VStack(spacing: 0) {
                PanelHead(title: "Pending receivables", meta: "\(visible.count) shown")
                ResizableHeader(sizer: sizer)
                ScrollView(.vertical) {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(visible.enumerated()), id: \.element.id) { idx, r in
                            row(r, idx: idx)
                            if idx < visible.count - 1 {
                                Divider().overlay(Color.lLine)
                            }
                        }
                    }
                }
            }
        }
        .frame(maxHeight: .infinity)
    }

    private func row(_ r: Receivable, idx: Int) -> some View {
        let latest = latestValue(for: r)
        return HStack(spacing: 0) {
            ResizableCell(sizer: sizer, colID: "name") {
                Text(r.name)
                    .font(Typo.sans(13, weight: .medium))
                    .foregroundStyle(Color.lInk)
                    .lineLimit(1)
            }
            ResizableCell(sizer: sizer, colID: "debtor") {
                Text(r.debtor.isEmpty ? "—" : r.debtor)
                    .font(Typo.sans(12))
                    .foregroundStyle(Color.lInk2)
                    .lineLimit(1)
            }
            ResizableCell(sizer: sizer, colID: "ccy") {
                Text(r.nativeCurrency.rawValue)
                    .font(Typo.mono(11, weight: .medium))
                    .foregroundStyle(Color.lInk3)
            }
            ResizableCell(sizer: sizer, colID: "latest") {
                if let latest {
                    Text(Fmt.currency(latest, r.nativeCurrency))
                        .font(Typo.mono(12, weight: .semibold))
                        .foregroundStyle(Color.lInk)
                } else {
                    Text("—")
                        .font(Typo.mono(12))
                        .foregroundStyle(Color.lInk3)
                }
            }
            ResizableCell(sizer: sizer, colID: "status") {
                Pill(text: r.isActive ? "active" : "archived", emphasis: r.isActive)
            }
            ResizableCell(sizer: sizer, colID: "actions") {
                HStack(spacing: 6) {
                    GhostButton(action: { editing = r }) { Text("Edit") }
                    GhostButton(action: { confirmDelete = r }) {
                        Image(systemName: "trash").font(.system(size: 10, weight: .bold))
                    }
                }
            }
        }
        .padding(.horizontal, 18).padding(.vertical, 10)
        .background(idx.isMultiple(of: 2) ? Color.clear : Color.lSunken.opacity(0.5))
        .rowClickable { editing = r }
    }
}

import SwiftUI
import SwiftData

struct SnapshotListView: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var undo: UndoStash
    @Environment(\.modelContext) private var context
    @Query(sort: \Snapshot.date, order: .reverse) private var snapshots: [Snapshot]
    @Query private var allAccounts: [Account]
    @Query private var allReceivables: [Receivable]
    @State private var editing: Snapshot?
    @State private var showingNew = false
    @State private var confirmDelete: Snapshot?
    @State private var confirmUnlock: Snapshot?
    @AppStorage("pinnedSnapshotIDs") private var pinnedRaw: String = ""
    @StateObject private var sizer = ColumnSizer(tableID: "snapshots", specs: [
        ColumnSpec(id: "snap",    title: "Snapshot", minWidth: 140, defaultWidth: 260, flex: true),
        ColumnSpec(id: "date",    title: "Date",     minWidth: 110, defaultWidth: 150),
        ColumnSpec(id: "fx",      title: "FX",       minWidth: 80,  defaultWidth: 120, alignment: .trailing),
        ColumnSpec(id: "total",   title: "Total",    minWidth: 100, defaultWidth: 150, alignment: .trailing),
        ColumnSpec(id: "status",  title: "Status",   minWidth: 130, defaultWidth: 170),
        ColumnSpec(id: "actions", title: "",         minWidth: 90,  defaultWidth: 90,  alignment: .trailing, resizable: false, sortable: false),
    ])

    private var sortedSnapshots: [Snapshot] {
        sizer.sorted(snapshots, comparators: [
            "snap":   { $0.label.localizedCaseInsensitiveCompare($1.label) == .orderedAscending },
            "date":   { $0.date < $1.date },
            "fx":     { $0.usdToInrRate < $1.usdToInrRate },
            "total":  { totalFor($0) < totalFor($1) },
            "status": { ($0.isLocked ? 0 : 1) < ($1.isLocked ? 0 : 1) },
        ])
    }

    private func totalFor(_ s: Snapshot) -> Double {
        // Use pre-computed cache if available (snapshot is locked + cache populated),
        // unless the user has illiquid toggle off — cache is always include-all.
        if app.includeIlliquidInNetWorth, let cached = SnapshotCache.cachedTotal(s, in: app.displayCurrency) {
            return cached
        }
        let inc = app.includeIlliquidInNetWorth
        return s.totalsValues.reduce(0) { $0 + CurrencyConverter.netDisplayValue(for: $1, in: app.displayCurrency, includeIlliquid: inc) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("OVERVIEW · HISTORICAL")
                        .font(Typo.eyebrow).tracking(1.5).foregroundStyle(Color.lInk3)
                    HStack(spacing: 8) {
                        Text("Snapshots").font(Typo.serifNum(32))
                        Text("— \(snapshots.count) quarters").font(Typo.serifItalic(28))
                            .foregroundStyle(Color.lInk3)
                    }
                    .foregroundStyle(Color.lInk)
                }
                Spacer()
                PrimaryButton(action: { showingNew = true }) {
                    HStack(spacing: 5) {
                        Image(systemName: "plus").font(.system(size: 10, weight: .bold))
                        Text("New Snapshot")
                    }
                }
            }

            if snapshots.isEmpty {
                EditorialEmpty(
                    eyebrow: "Overview · Historical",
                    title: "No quarters",
                    titleItalic: "on the record.",
                    body: "Each snapshot freezes balances and FX at one moment. Four per year is plenty — the series grows with you.",
                    detail: "Snapshots lock when complete; unlock any time to amend.",
                    ctaLabel: "New snapshot",
                    cta: { showingNew = true },
                    illustration: "calendar.badge.plus"
                )
            } else {
                pinnedTabsStrip
                Panel {
                    VStack(spacing: 0) {
                        ResizableHeader(sizer: sizer)
                        let rows = sortedSnapshots
                        ForEach(Array(rows.enumerated()), id: \.element.id) { idx, s in
                            row(idx: idx, s: s)
                            if idx < rows.count - 1 {
                                Divider().overlay(Color.lLine)
                            }
                        }
                    }
                }
            }
        }
        .sheet(item: $editing) { SnapshotEditorView(snapshot: $0) }
        .sheet(isPresented: $showingNew) {
            NewSnapshotSheet { created in editing = created }
        }
        .onChange(of: app.newSnapshotRequested) { _, requested in
            if requested {
                app.newSnapshotRequested = false
                showingNew = true
            }
        }
        .onAppear {
            if app.newSnapshotRequested {
                app.newSnapshotRequested = false
                showingNew = true
            }
        }
        .onChange(of: editing?.id) { _, id in
            if let s = editing, let id { app.touchRecent(.snapshot, id: id, label: s.label) }
        }
        .confirmationDialog("Delete \(confirmDelete?.label ?? "")?",
                            isPresented: Binding(get: { confirmDelete != nil }, set: { if !$0 { confirmDelete = nil } }),
                            titleVisibility: .visible) {
            Button("Delete Snapshot", role: .destructive) {
                if let s = confirmDelete {
                    let cap = undo.capture(snapshot: s)
                    if app.activeSnapshotID == s.id { app.activeSnapshotID = nil }
                    context.delete(s)
                    try? context.save()
                    undo.stash(.snapshot(cap))
                }
                confirmDelete = nil
            }
            .keyboardShortcut(.defaultAction)
            Button("Cancel", role: .cancel) { confirmDelete = nil }
        } message: {
            Text("All \(confirmDelete?.values.count ?? 0) asset values recorded in this snapshot will also be deleted.")
        }
        .confirmationDialog("Unlock \(confirmUnlock?.label ?? "")?",
                            isPresented: Binding(get: { confirmUnlock != nil }, set: { if !$0 { confirmUnlock = nil } }),
                            titleVisibility: .visible) {
            Button("Unlock", role: .destructive) {
                if let s = confirmUnlock {
                    s.isLocked = false
                    s.lockedAt = nil
                    try? context.save()
                }
                confirmUnlock = nil
            }
            .keyboardShortcut(.defaultAction)
            Button("Cancel", role: .cancel) { confirmUnlock = nil }
        } message: {
            Text("Values and exchange rate become editable again. Re-lock after amending.")
        }
    }

    private func row(idx: Int, s: Snapshot) -> some View {
        HStack(spacing: 0) {
            ResizableCell(sizer: sizer, colID: "snap") {
                HStack(spacing: 10) {
                    if app.activeSnapshotID == s.id {
                        Circle().fill(Color.lInk).frame(width: 6, height: 6)
                    }
                    Text(s.label)
                        .font(Typo.sans(13, weight: .semibold))
                        .foregroundStyle(Color.lInk)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                }
            }
            ResizableCell(sizer: sizer, colID: "date") {
                Text(Fmt.date(s.date))
                    .font(Typo.mono(11))
                    .foregroundStyle(Color.lInk3)
            }
            ResizableCell(sizer: sizer, colID: "fx") {
                Text("₹\(String(format: "%.2f", s.usdToInrRate))")
                    .font(Typo.mono(12))
                    .foregroundStyle(Color.lInk2)
            }
            ResizableCell(sizer: sizer, colID: "total") {
                Text(Fmt.compact(totalFor(s), app.displayCurrency))
                    .font(Typo.mono(12.5, weight: .semibold))
                    .foregroundStyle(Color.lInk)
                    .stealthAmount()
            }
            ResizableCell(sizer: sizer, colID: "status") {
                HStack(spacing: 6) {
                    Pill(text: s.isLocked ? "🔒 locked" : "✎ draft",
                         emphasis: !s.isLocked)
                    completenessChip(for: s)
                    Spacer(minLength: 0)
                }
            }
            ResizableCell(sizer: sizer, colID: "actions") {
                HStack(spacing: 6) {
                    GhostButton(action: { editing = s }) { Text("Open") }
                    Menu {
                        if s.isLocked {
                            Button("Unlock…") { confirmUnlock = s }
                        }
                        Button("Set active") { app.activeSnapshotID = s.id }
                        Button(pinnedIDs.contains(s.id) ? "Unpin tab" : "Pin as tab") {
                            togglePin(s)
                        }
                        Button("Export PDF…") { exportSnapshotPDF(s) }
                        Button("Delete…", role: .destructive) { confirmDelete = s }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Color.lInk2)
                            .frame(width: 24, height: 24)
                            .overlay(Circle().stroke(Color.lLine, lineWidth: 1))
                    }
                    .menuStyle(.borderlessButton)
                    .menuIndicator(.hidden)
                    .fixedSize()
                    .pointerStyle(.link)
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(idx.isMultiple(of: 2) ? Color.clear : Color.lSunken.opacity(0.5))
        .rowClickable { editing = s }
    }

    @ViewBuilder
    private func completenessChip(for s: Snapshot) -> some View {
        let r = SnapshotCompleteness.evaluate(snapshot: s, accounts: allAccounts, receivables: allReceivables)
        if r.totalRows == 0 {
            EmptyView()
        } else if r.isComplete {
            HStack(spacing: 3) {
                Image(systemName: "checkmark.circle.fill").font(.system(size: 9))
                Text("Complete").font(Typo.mono(10, weight: .medium))
            }
            .foregroundStyle(Color.lGain)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .overlay(Capsule().stroke(Color.lGain.opacity(0.5), lineWidth: 1))
            .clipShape(Capsule())
            .help("All \(r.totalRows) active accounts + receivables have non-zero values.")
        } else {
            HStack(spacing: 3) {
                Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 9))
                Text("\(r.filledRows)/\(r.totalRows)").font(Typo.mono(10, weight: .semibold))
            }
            .foregroundStyle(Color.lLoss)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .overlay(Capsule().stroke(Color.lLoss.opacity(0.5), lineWidth: 1))
            .clipShape(Capsule())
            .help("\(r.missingCount) row(s) missing values. Open snapshot to review.")
        }
    }

    private var pinnedIDs: [UUID] {
        pinnedRaw.split(separator: ",")
            .compactMap { UUID(uuidString: String($0)) }
    }

    private var pinnedSnapshots: [Snapshot] {
        let ids = pinnedIDs
        guard !ids.isEmpty else { return [] }
        return ids.compactMap { id in snapshots.first(where: { $0.id == id }) }
    }

    private func togglePin(_ s: Snapshot) {
        var ids = pinnedIDs
        if let i = ids.firstIndex(of: s.id) {
            ids.remove(at: i)
        } else {
            ids.append(s.id)
            // Cap to 6 most recent pins.
            if ids.count > 6 { ids.removeFirst(ids.count - 6) }
        }
        pinnedRaw = ids.map { $0.uuidString }.joined(separator: ",")
    }

    @ViewBuilder
    private var pinnedTabsStrip: some View {
        let pins = pinnedSnapshots
        if !pins.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(pins) { s in
                        pinnedTab(s)
                    }
                    Spacer(minLength: 4)
                }
                .padding(.horizontal, 2)
                .padding(.vertical, 2)
            }
        }
    }

    @ViewBuilder
    private func pinnedTab(_ s: Snapshot) -> some View {
        let isActive = app.activeSnapshotID == s.id
        Button {
            app.activeSnapshotID = s.id
            editing = s
        } label: {
            HStack(spacing: 8) {
                Image(systemName: s.isLocked ? "lock.fill" : "pencil")
                    .font(.system(size: 9))
                    .foregroundStyle(isActive ? Color.lInk : Color.lInk3)
                VStack(alignment: .leading, spacing: 1) {
                    Text(s.label)
                        .font(Typo.sans(12, weight: .semibold))
                        .foregroundStyle(Color.lInk)
                        .lineLimit(1)
                    Text(Fmt.date(s.date))
                        .font(Typo.mono(9.5))
                        .foregroundStyle(Color.lInk3)
                }
                Button {
                    togglePin(s)
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(Color.lInk3)
                        .frame(width: 14, height: 14)
                }
                .buttonStyle(.plain)
                .pointerStyle(.link)
                .help("Unpin")
            }
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(isActive ? Color.lPanel : Color.lSunken.opacity(0.6))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isActive ? Color.lInk : Color.lLine, lineWidth: isActive ? 1.5 : 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .pointerStyle(.link)
    }

    @MainActor
    private func exportSnapshotPDF(_ s: Snapshot) {
        let prior = snapshots.first { $0.date < s.date && $0.id != s.id }
        _ = SnapshotPDFExporter.export(
            snapshot: s,
            previousSnapshot: prior,
            displayCurrency: app.displayCurrency,
            includeIlliquid: app.includeIlliquidInNetWorth,
            theme: app.theme
        )
    }
}

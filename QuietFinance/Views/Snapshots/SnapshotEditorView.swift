import SwiftUI
import SwiftData

struct SnapshotEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @EnvironmentObject var app: AppState
    @EnvironmentObject var undo: UndoStash
    @Query(sort: \Snapshot.date, order: .reverse) private var allSnapshots: [Snapshot]
    @Query(sort: \Receivable.name) private var allReceivables: [Receivable]
    @Query(sort: \Account.name) private var allAccounts: [Account]
    let snapshot: Snapshot
    @State private var confirmingLock = false
    @State private var confirmingUnlock = false
    @State private var confirmingDelete = false
    @State private var isFetchingRate = false
    @State private var fetchError: String?
    @State private var showSavedToast = false
    @State private var saveError: String?
    @State private var sanityWarning: SanityWarning?

    private struct SanityWarning: Identifiable {
        let id = UUID()
        let dropPct: Double
        let prevTotal: Double
        let newTotal: Double
        let dismissAfter: Bool
    }

    private var previousSnapshot: Snapshot? {
        allSnapshots.first { $0.date < snapshot.date && $0.id != snapshot.id }
    }

    private func previousValue(for account: Account?) -> Double? {
        guard let account, let prev = previousSnapshot else { return nil }
        return prev.values.first { $0.account?.id == account.id }?.nativeValue
    }

    private var liveTotalDisplay: Double {
        let inc = app.includeIlliquidInNetWorth
        return snapshot.totalsValues.reduce(0.0) { sum, v in
            sum + CurrencyConverter.netDisplayValue(for: v, in: app.displayCurrency, includeIlliquid: inc)
        }
    }

    private var previousTotalDisplay: Double? {
        guard let prev = previousSnapshot else { return nil }
        let inc = app.includeIlliquidInNetWorth
        return prev.totalsValues.reduce(0.0) { sum, v in
            sum + CurrencyConverter.netDisplayValue(for: v, in: app.displayCurrency, includeIlliquid: inc)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    valuesPanel
                    if !applicableReceivables.isEmpty {
                        receivablesPanel
                    }
                    notesPanel

                    if let err = saveError {
                        errorBanner(err)
                    }
                }
                .padding(24)
            }

            Divider().overlay(Color.lLine)
            footer
        }
        .background(Color.lBg)
        .frame(minWidth: 980, minHeight: 680)
        .overlay(alignment: .topLeading) {
            VStack(spacing: 0) {
                Button("") {
                    if !snapshot.isLocked { saveDraft(dismissAfter: false) }
                }
                .keyboardShortcut("s", modifiers: .command)
                .hidden()
                .frame(width: 0, height: 0)
                Button("") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                    .hidden()
                    .frame(width: 0, height: 0)
            }
        }
        .confirmationDialog(
            "Net worth dropped sharply — confirm save?",
            isPresented: Binding(
                get: { sanityWarning != nil },
                set: { if !$0 { sanityWarning = nil } }
            ),
            titleVisibility: .visible,
            presenting: sanityWarning
        ) { warn in
            Button("Save anyway", role: .destructive) {
                let after = warn.dismissAfter
                sanityWarning = nil
                commitSave(dismissAfter: after)
            }
            .keyboardShortcut(.defaultAction)
            Button("Review values", role: .cancel) {
                sanityWarning = nil
            }
        } message: { warn in
            Text("Total \(Fmt.compact(warn.prevTotal, app.displayCurrency)) → \(Fmt.compact(warn.newTotal, app.displayCurrency)) (−\(String(format: "%.1f%%", warn.dropPct * 100))). Likely a missed entry. Cancel to review, or save anyway if intentional.")
        }
        .onAppear {
            context.autosaveEnabled = false
            backfillAccountValues()
            backfillReceivableValues()
        }
        .onDisappear {
            try? context.save()
            context.autosaveEnabled = true
        }
        .overlay(alignment: .top) {
            if showSavedToast {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.lGain)
                    Text("Draft saved")
                        .font(Typo.sans(12.5, weight: .semibold))
                        .foregroundStyle(Color.lInk)
                }
                .padding(.horizontal, 14).padding(.vertical, 9)
                .background(Color.lPanel)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.lLine, lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .shadow(color: .black.opacity(0.15), radius: 10, y: 4)
                .padding(.top, 14)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: showSavedToast)
        .confirmationDialog("Lock \(snapshot.label)?",
                            isPresented: $confirmingLock,
                            titleVisibility: .visible) {
            Button("Lock Snapshot", role: .destructive) {
                guard snapshot.usdToInrRate > 0 else {
                    saveError = "Exchange rate must be positive before locking."
                    return
                }
                snapshot.isLocked = true
                snapshot.lockedAt = .now
                SnapshotCache.recompute(snapshot)
                try? context.save()
                _ = BackupService.backupOnLock(label: snapshot.label)
            }
            .keyboardShortcut(.defaultAction)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Values become read-only. Exchange rate frozen at \(String(format: "%.2f", snapshot.usdToInrRate)).")
        }
        .confirmationDialog("Unlock \(snapshot.label)?",
                            isPresented: $confirmingUnlock,
                            titleVisibility: .visible) {
            Button("Unlock", role: .destructive) {
                snapshot.isLocked = false
                snapshot.lockedAt = nil
                SnapshotCache.invalidate(snapshot)
                try? context.save()
                backfillAccountValues()
                backfillReceivableValues()
            }
            .keyboardShortcut(.defaultAction)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Values and exchange rate become editable again. Missing accounts/receivables will be backfilled with 0. Re-lock when done.")
        }
        .confirmationDialog("Delete \(snapshot.label)?",
                            isPresented: $confirmingDelete,
                            titleVisibility: .visible) {
            Button("Delete Snapshot", role: .destructive) {
                let cap = undo.capture(snapshot: snapshot)
                if app.activeSnapshotID == snapshot.id { app.activeSnapshotID = nil }
                context.delete(snapshot)
                try? context.save()
                undo.stash(.snapshot(cap))
                dismiss()
            }
            .keyboardShortcut(.defaultAction)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Removes this snapshot and all \(snapshot.values.count) account values.")
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("SNAPSHOT · \(Fmt.date(snapshot.date).uppercased())")
                        .font(Typo.eyebrow).tracking(1.5)
                        .foregroundStyle(Color.lInk3)
                    HStack(spacing: 10) {
                        Text(snapshot.label)
                            .font(Typo.serifNum(26))
                            .foregroundStyle(Color.lInk)
                        Pill(text: snapshot.isLocked ? "🔒 locked" : "✎ draft",
                             emphasis: !snapshot.isLocked)
                        completenessBadge
                    }
                    Text(snapshot.isLocked
                         ? "Locked \(snapshot.lockedAt.map { Fmt.date($0) } ?? "") · values frozen"
                         : "Draft · edit freely until locked")
                        .font(Typo.serifItalic(13))
                        .foregroundStyle(Color.lInk3)
                }
                Spacer()
                rateBlock
            }
            if let err = fetchError {
                Text(err)
                    .font(Typo.sans(11))
                    .foregroundStyle(Color.lLoss)
            }
        }
        .padding(.horizontal, 24).padding(.top, 22).padding(.bottom, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(Rectangle().frame(height: 1).foregroundStyle(Color.lLine), alignment: .bottom)
    }

    private var completeness: SnapshotCompleteness.Result {
        SnapshotCompleteness.evaluate(snapshot: snapshot,
                                      accounts: allAccounts,
                                      receivables: allReceivables)
    }

    @ViewBuilder
    private var completenessBadge: some View {
        let r = completeness
        if r.totalRows > 0 {
            if r.isComplete {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill").font(.system(size: 10))
                    Text("Complete").font(Typo.mono(11, weight: .semibold))
                }
                .foregroundStyle(Color.lGain)
                .padding(.horizontal, 8).padding(.vertical, 3)
                .overlay(Capsule().stroke(Color.lGain.opacity(0.5), lineWidth: 1))
                .clipShape(Capsule())
                .help("All \(r.totalRows) rows have non-zero values.")
            } else {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 10))
                    Text("\(r.filledRows)/\(r.totalRows) filled · \(r.missingCount) missing")
                        .font(Typo.mono(11, weight: .semibold))
                }
                .foregroundStyle(Color.lLoss)
                .padding(.horizontal, 8).padding(.vertical, 3)
                .overlay(Capsule().stroke(Color.lLoss.opacity(0.5), lineWidth: 1))
                .clipShape(Capsule())
                .help("Rows with zero value are highlighted red below.")
            }
        }
    }

    private var rateBlock: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text("USD → INR")
                .font(Typo.eyebrow).tracking(1.2)
                .foregroundStyle(Color.lInk3)
            if snapshot.isLocked {
                Text(String(format: "₹%.4f", snapshot.usdToInrRate))
                    .font(Typo.mono(14, weight: .semibold))
                    .foregroundStyle(Color.lInk)
            } else {
                HStack(spacing: 6) {
                    TextField("", value: Binding(
                        get: { snapshot.usdToInrRate },
                        set: { snapshot.usdToInrRate = $0 }
                    ), format: .number)
                    .textFieldStyle(.roundedBorder)
                    .font(Typo.mono(13))
                    .frame(width: 90)
                    Button {
                        Task { await fetchLiveRate() }
                    } label: {
                        if isFetchingRate {
                            ProgressView().controlSize(.small)
                        } else {
                            Image(systemName: "arrow.down.circle")
                                .foregroundStyle(Color.lInk2)
                        }
                    }
                    .disabled(isFetchingRate)
                    .buttonStyle(.plain)
                    .pointerStyle(.link)
                    .help("Fetch USD→INR for \(Fmt.date(snapshot.date)) from frankfurter.app")
                }
                if snapshot.usdToInrRate <= 0 {
                    Text("Rate must be > 0")
                        .font(Typo.mono(10, weight: .medium))
                        .foregroundStyle(Color.lLoss)
                }
            }
        }
    }

    // MARK: - Values panel

    private var sortedValues: [AssetValue] {
        snapshot.values.sorted { lhs, rhs in
            let la = lhs.account?.name ?? ""
            let ra = rhs.account?.name ?? ""
            let acmp = la.localizedCaseInsensitiveCompare(ra)
            if acmp != .orderedSame { return acmp == .orderedAscending }
            return lhs.id.uuidString < rhs.id.uuidString
        }
    }

    private var valuesPanel: some View {
        Panel {
            VStack(spacing: 0) {
                PanelHead(title: "Account values", meta: "\(sortedValues.count) rows")
                rowHeader
                let values = sortedValues
                ForEach(Array(values.enumerated()), id: \.element.id) { idx, v in
                    row(v, idx: idx)
                    if idx < values.count - 1 {
                        Divider().overlay(Color.lLine)
                    }
                }
                Divider().overlay(Color.lLine)
                totalsRow
            }
        }
        .animation(.none, value: snapshot.values.count)
        .transaction { $0.animation = nil }
    }

    private var rowHeader: some View {
        HStack {
            Text("Account").frame(maxWidth: .infinity, alignment: .leading)
            Text("Person").frame(width: 110, alignment: .leading)
            Text("Prev").frame(width: 130, alignment: .trailing)
            Text("Δ").frame(width: 130, alignment: .trailing)
            Text("Native value").frame(width: 210, alignment: .trailing)
        }
        .font(Typo.eyebrow).tracking(1.2).foregroundStyle(Color.lInk3)
        .padding(.horizontal, 18).padding(.vertical, 10)
        .background(Color.lSunken)
        .overlay(Rectangle().frame(height: 1).foregroundStyle(Color.lLine), alignment: .bottom)
    }

    @ViewBuilder
    private func row(_ v: AssetValue, idx: Int) -> some View {
        let ccy = v.account?.nativeCurrency ?? .USD
        let prev = previousValue(for: v.account)
        let diff = prev.map { v.nativeValue - $0 }
        let isMissing = (v.account?.isActive ?? false) && abs(v.nativeValue) <= 0.0001
        HStack {
            HStack(spacing: 6) {
                if isMissing {
                    Circle().fill(Color.lLoss).frame(width: 6, height: 6)
                        .help("Missing value — active account but zero recorded.")
                }
                Text(v.account?.name ?? "—")
                    .font(Typo.sans(13, weight: .medium))
                    .foregroundStyle(Color.lInk)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(v.account?.person?.name ?? "—")
                .font(Typo.sans(12))
                .foregroundStyle(Color.lInk2)
                .frame(width: 110, alignment: .leading)

            Group {
                if let prev {
                    Text(Fmt.currency(prev, ccy))
                        .foregroundStyle(Color.lInk3)
                } else {
                    Text("—").foregroundStyle(Color.lInk3)
                }
            }
            .font(Typo.mono(12))
            .frame(width: 130, alignment: .trailing)

            Group {
                if let diff {
                    Text(Fmt.signedDelta(diff, ccy))
                        .foregroundStyle(diff == 0 ? Color.lInk3 : (diff > 0 ? Color.lGain : Color.lLoss))
                } else {
                    Text("—").foregroundStyle(Color.lInk3)
                }
            }
            .font(Typo.mono(12, weight: .medium))
            .frame(width: 130, alignment: .trailing)

            if snapshot.isLocked {
                HStack(spacing: 6) {
                    Text(Fmt.currency(v.nativeValue, ccy))
                        .font(Typo.mono(13, weight: .semibold))
                        .foregroundStyle(Color.lInk)
                    Text(ccy.rawValue)
                        .font(Typo.mono(10, weight: .medium))
                        .foregroundStyle(Color.lInk3)
                        .frame(width: 30, alignment: .leading)
                }
                .frame(width: 210, alignment: .trailing)
            } else {
                HStack(spacing: 6) {
                    TextField("", value: Binding(
                        get: { v.nativeValue },
                        set: { v.nativeValue = $0 }
                    ), format: .number)
                    .textFieldStyle(.roundedBorder)
                    .multilineTextAlignment(.trailing)
                    .font(Typo.mono(13))
                    .frame(width: 170)
                    Text(ccy.rawValue)
                        .font(Typo.mono(10, weight: .medium))
                        .foregroundStyle(Color.lInk3)
                        .frame(width: 30, alignment: .leading)
                }
                .frame(width: 210, alignment: .trailing)
            }
        }
        .padding(.horizontal, 18).padding(.vertical, 10)
        .background(
            isMissing
                ? Color.lLoss.opacity(0.06)
                : (idx.isMultiple(of: 2) ? Color.clear : Color.lSunken.opacity(0.5))
        )
        .overlay(alignment: .leading) {
            if isMissing {
                Rectangle().fill(Color.lLoss).frame(width: 2)
            }
        }
    }

    private var totalsRow: some View {
        let prevTotal = previousTotalDisplay
        let total = liveTotalDisplay
        let diff = prevTotal.map { total - $0 }
        let ccy = app.displayCurrency
        return HStack {
            Text("TOTAL (\(ccy.rawValue))")
                .font(Typo.eyebrow).tracking(1.2)
                .foregroundStyle(Color.lInk)
                .frame(maxWidth: .infinity, alignment: .leading)

            Group {
                if let prevTotal {
                    Text(Fmt.currency(prevTotal, ccy))
                        .foregroundStyle(Color.lInk3)
                } else {
                    Text("—").foregroundStyle(Color.lInk3)
                }
            }
            .font(Typo.mono(12))
            .frame(width: 130, alignment: .trailing)

            Group {
                if let diff {
                    Text(Fmt.signedDelta(diff, ccy))
                        .foregroundStyle(diff == 0 ? Color.lInk3 : (diff > 0 ? Color.lGain : Color.lLoss))
                } else {
                    Text("—").foregroundStyle(Color.lInk3)
                }
            }
            .font(Typo.mono(12, weight: .semibold))
            .frame(width: 130, alignment: .trailing)

            HStack(spacing: 6) {
                Text(Fmt.currency(total, ccy))
                    .font(Typo.mono(14, weight: .bold))
                    .foregroundStyle(Color.lInk)
                Text(ccy.rawValue)
                    .font(Typo.mono(10, weight: .medium))
                    .foregroundStyle(Color.lInk3)
                    .frame(width: 30, alignment: .leading)
            }
            .frame(width: 210, alignment: .trailing)
        }
        .padding(.horizontal, 18).padding(.vertical, 12)
        .background(Color.lSunken)
    }

    // MARK: - Receivables panel

    private var applicableReceivables: [Receivable] {
        allReceivables.filter { r in
            r.isActive && r.startDate <= snapshot.date
        }
    }

    /// Insert zero-value AssetValue rows for every active account that has no
    /// row in this snapshot. Lets user fill in forgotten accounts in past
    /// (unlocked) snapshots. Locked snapshots are skipped to honor immutability;
    /// missing-count chip in header signals need to unlock.
    private func backfillAccountValues() {
        guard !snapshot.isLocked else { return }
        let existingIDs = Set(snapshot.values.compactMap { $0.account?.id })
        var inserted = false
        for a in allAccounts where a.isActive && !existingIDs.contains(a.id) {
            let av = AssetValue(snapshot: snapshot, account: a, nativeValue: 0)
            context.insert(av)
            inserted = true
        }
        if inserted { try? context.save() }
    }

    private func backfillReceivableValues() {
        guard !snapshot.isLocked else { return }
        let existingIDs = Set(snapshot.receivableValues.compactMap { $0.receivable?.id })
        var inserted = false
        for r in applicableReceivables where !existingIDs.contains(r.id) {
            let rv = ReceivableValue(snapshot: snapshot, receivable: r, nativeValue: 0)
            context.insert(rv)
            inserted = true
        }
        if inserted { try? context.save() }
    }

    private var sortedReceivableValues: [ReceivableValue] {
        snapshot.receivableValues.sorted { lhs, rhs in
            let ln = lhs.receivable?.name ?? ""
            let rn = rhs.receivable?.name ?? ""
            let cmp = ln.localizedCaseInsensitiveCompare(rn)
            if cmp != .orderedSame { return cmp == .orderedAscending }
            return lhs.id.uuidString < rhs.id.uuidString
        }
    }

    private func previousReceivableValue(for receivable: Receivable?) -> Double? {
        guard let receivable, let prev = previousSnapshot else { return nil }
        return prev.receivableValues.first { $0.receivable?.id == receivable.id }?.nativeValue
    }

    private var receivablesPanel: some View {
        Panel {
            VStack(spacing: 0) {
                PanelHead(title: "Pending receivables · outside net worth",
                          meta: "\(sortedReceivableValues.count) rows")
                receivableHeader
                let rows = sortedReceivableValues
                ForEach(Array(rows.enumerated()), id: \.element.id) { idx, rv in
                    receivableRow(rv, idx: idx)
                    if idx < rows.count - 1 {
                        Divider().overlay(Color.lLine)
                    }
                }
            }
        }
        .transaction { $0.animation = nil }
    }

    private var receivableHeader: some View {
        HStack {
            Text("Receivable").frame(maxWidth: .infinity, alignment: .leading)
            Text("Debtor").frame(width: 140, alignment: .leading)
            Text("Prev").frame(width: 130, alignment: .trailing)
            Text("Δ").frame(width: 130, alignment: .trailing)
            Text("Native value").frame(width: 210, alignment: .trailing)
        }
        .font(Typo.eyebrow).tracking(1.2).foregroundStyle(Color.lInk3)
        .padding(.horizontal, 18).padding(.vertical, 10)
        .background(Color.lSunken)
        .overlay(Rectangle().frame(height: 1).foregroundStyle(Color.lLine), alignment: .bottom)
    }

    @ViewBuilder
    private func receivableRow(_ rv: ReceivableValue, idx: Int) -> some View {
        let ccy = rv.receivable?.nativeCurrency ?? .USD
        let prev = previousReceivableValue(for: rv.receivable)
        let diff = prev.map { rv.nativeValue - $0 }
        let r = rv.receivable
        let applicable = (r?.isActive ?? false) && (r?.startDate ?? .distantPast) <= snapshot.date
        let isMissing = applicable && abs(rv.nativeValue) <= 0.0001
        HStack {
            HStack(spacing: 6) {
                if isMissing {
                    Circle().fill(Color.lLoss).frame(width: 6, height: 6)
                        .help("Missing value — applicable receivable but zero recorded.")
                }
                Text(rv.receivable?.name ?? "—")
                    .font(Typo.sans(13, weight: .medium))
                    .foregroundStyle(Color.lInk)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(rv.receivable?.debtor.isEmpty == false ? rv.receivable!.debtor : "—")
                .font(Typo.sans(12))
                .foregroundStyle(Color.lInk2)
                .frame(width: 140, alignment: .leading)

            Group {
                if let prev {
                    Text(Fmt.currency(prev, ccy))
                        .foregroundStyle(Color.lInk3)
                } else {
                    Text("—").foregroundStyle(Color.lInk3)
                }
            }
            .font(Typo.mono(12))
            .frame(width: 130, alignment: .trailing)

            Group {
                if let diff {
                    Text(Fmt.signedDelta(diff, ccy))
                        .foregroundStyle(diff == 0 ? Color.lInk3 : (diff > 0 ? Color.lGain : Color.lLoss))
                } else {
                    Text("—").foregroundStyle(Color.lInk3)
                }
            }
            .font(Typo.mono(12, weight: .medium))
            .frame(width: 130, alignment: .trailing)

            if snapshot.isLocked {
                HStack(spacing: 6) {
                    Text(Fmt.currency(rv.nativeValue, ccy))
                        .font(Typo.mono(13, weight: .semibold))
                        .foregroundStyle(Color.lInk)
                    Text(ccy.rawValue)
                        .font(Typo.mono(10, weight: .medium))
                        .foregroundStyle(Color.lInk3)
                        .frame(width: 30, alignment: .leading)
                }
                .frame(width: 210, alignment: .trailing)
            } else {
                HStack(spacing: 6) {
                    TextField("", value: Binding(
                        get: { rv.nativeValue },
                        set: { rv.nativeValue = $0 }
                    ), format: .number)
                    .textFieldStyle(.roundedBorder)
                    .multilineTextAlignment(.trailing)
                    .font(Typo.mono(13))
                    .frame(width: 170)
                    Text(ccy.rawValue)
                        .font(Typo.mono(10, weight: .medium))
                        .foregroundStyle(Color.lInk3)
                        .frame(width: 30, alignment: .leading)
                }
                .frame(width: 210, alignment: .trailing)
            }
        }
        .padding(.horizontal, 18).padding(.vertical, 10)
        .background(
            isMissing
                ? Color.lLoss.opacity(0.06)
                : (idx.isMultiple(of: 2) ? Color.clear : Color.lSunken.opacity(0.5))
        )
        .overlay(alignment: .leading) {
            if isMissing {
                Rectangle().fill(Color.lLoss).frame(width: 2)
            }
        }
    }

    // MARK: - Footer / misc

    private var footer: some View {
        HStack(spacing: 10) {
            GhostButton(action: { confirmingDelete = true }) {
                HStack(spacing: 5) {
                    Image(systemName: "trash").font(.system(size: 10, weight: .bold))
                    Text("Delete")
                }
            }
            Spacer()
            GhostButton(action: { dismiss() }) { Text("Close") }
            if snapshot.isLocked {
                PrimaryButton(action: { confirmingUnlock = true }) {
                    HStack(spacing: 5) {
                        Image(systemName: "lock.open.fill").font(.system(size: 10, weight: .bold))
                        Text("Unlock Snapshot")
                    }
                }
                .help("Unlock to amend values, then re-lock when done.")
            } else {
                GhostButton(action: { saveDraft(dismissAfter: false) }) {
                    HStack(spacing: 5) {
                        Image(systemName: "square.and.arrow.down").font(.system(size: 10, weight: .bold))
                        Text("Save Draft")
                    }
                }
                GhostButton(action: { saveDraft(dismissAfter: true) }) {
                    HStack(spacing: 5) {
                        Image(systemName: "square.and.arrow.down.on.square").font(.system(size: 10, weight: .bold))
                        Text("Save & Close")
                    }
                }
                PrimaryButton(action: { confirmingLock = true }) {
                    HStack(spacing: 5) {
                        Image(systemName: "lock.fill").font(.system(size: 10, weight: .bold))
                        Text("Lock Snapshot")
                    }
                }
                .disabled(snapshot.usdToInrRate <= 0)
                .opacity(snapshot.usdToInrRate <= 0 ? 0.5 : 1)
                .help(snapshot.usdToInrRate <= 0 ? "Set a positive USD→INR rate first" : "Freeze this snapshot")
            }
        }
        .padding(.horizontal, 24).padding(.vertical, 16)
    }

    private var notesPanel: some View {
        Panel {
            VStack(alignment: .leading, spacing: 0) {
                PanelHead(title: "Notes", meta: snapshot.isLocked ? "read-only" : "editable")
                if snapshot.isLocked {
                    Group {
                        if snapshot.notes.isEmpty {
                            Text("No notes recorded.")
                                .font(Typo.serifItalic(12.5))
                                .foregroundStyle(Color.lInk3)
                        } else {
                            Text(snapshot.notes)
                                .font(Typo.serifItalic(13))
                                .foregroundStyle(Color.lInk2)
                                .fixedSize(horizontal: false, vertical: true)
                                .textSelection(.enabled)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                } else {
                    TextField(
                        "Context, notable events, assumptions…",
                        text: Binding(
                            get: { snapshot.notes },
                            set: { snapshot.notes = $0 }
                        ),
                        axis: .vertical
                    )
                    .textFieldStyle(.plain)
                    .font(Typo.sans(12.5))
                    .foregroundStyle(Color.lInk)
                    .lineLimit(3...10)
                    .padding(14)
                    .background(Color.lSunken.opacity(0.5))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.lLine, lineWidth: 1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .padding(16)
                }
            }
        }
    }

    private func errorBanner(_ err: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Color.lLoss)
            Text(err).font(Typo.sans(12)).foregroundStyle(Color.lLoss)
        }
        .padding(12)
        .background(Color.lLossSoft.opacity(0.4))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.lLoss.opacity(0.3), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func saveDraft(dismissAfter: Bool = false) {
        guard snapshot.usdToInrRate > 0 else {
            saveError = "Exchange rate must be positive before saving."
            return
        }
        // Sanity check: net worth dropped >50% vs previous snapshot.
        if let prev = previousTotalDisplay, prev > 0 {
            let now = liveTotalDisplay
            let dropPct = (prev - now) / prev
            if dropPct > 0.5 {
                sanityWarning = SanityWarning(
                    dropPct: dropPct,
                    prevTotal: prev,
                    newTotal: now,
                    dismissAfter: dismissAfter
                )
                return
            }
        }
        commitSave(dismissAfter: dismissAfter)
    }

    private func commitSave(dismissAfter: Bool) {
        do {
            try context.save()
            saveError = nil
            withAnimation { showSavedToast = true }
            Task {
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                await MainActor.run {
                    withAnimation { showSavedToast = false }
                    if dismissAfter { dismiss() }
                }
            }
        } catch {
            saveError = "Save failed: \(error.localizedDescription)"
        }
    }

    @MainActor
    private func fetchLiveRate() async {
        guard !snapshot.isLocked else { return }
        isFetchingRate = true
        defer { isFetchingRate = false }
        do {
            let r = try await FXService.fetchUSDtoINR(on: snapshot.date)
            snapshot.usdToInrRate = r
            try? context.save()
            fetchError = nil
        } catch {
            fetchError = "Fetch failed: \(error.localizedDescription)"
        }
    }
}

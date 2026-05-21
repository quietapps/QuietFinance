import SwiftUI
import SwiftData

struct MergeAccountsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query private var accounts: [Account]

    let candidateIDs: [UUID]
    var onComplete: () -> Void = {}

    @State private var targetID: UUID?
    @State private var errorMessage: String?
    @State private var confirming = false

    private var candidates: [Account] {
        candidateIDs.compactMap { id in accounts.first(where: { $0.id == id }) }
    }
    private var target: Account? { candidates.first(where: { $0.id == targetID }) }
    private var source: Account? { candidates.first(where: { $0.id != targetID }) }

    private var currencyMismatch: Bool {
        guard let s = source, let t = target else { return false }
        return s.nativeCurrency != t.nativeCurrency
    }

    private var snapshotOverlap: Int {
        guard let s = source, let t = target else { return 0 }
        let targetSnapshotIDs = Set(t.values.compactMap { $0.snapshot?.id })
        return s.values.compactMap { $0.snapshot?.id }.filter { targetSnapshotIDs.contains($0) }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Merge Accounts").font(Typo.serifNum(24))
            Text("Combine two accounts into one. Source is deleted; its history moves to target.")
                .font(Typo.sans(12)).foregroundStyle(Color.lInk2)

            if candidates.count != 2 {
                Text("Select exactly two accounts to merge.")
                    .foregroundStyle(Color.lLoss)
                    .font(Typo.sans(12))
            } else {
                Form {
                    Picker("Keep (target)", selection: $targetID) {
                        Text("—").tag(UUID?.none)
                        ForEach(candidates) { Text(label(for: $0)).tag(UUID?.some($0.id)) }
                    }
                    if let s = source, let t = target {
                        LabeledContent("Source (deleted)") {
                            Text(label(for: s)).font(Typo.sans(12)).foregroundStyle(Color.lInk2)
                        }
                        LabeledContent("Target keeps") {
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(t.name).font(Typo.sans(12, weight: .medium))
                                Text("Person: \(t.person?.name ?? "—") · Country: \(t.country?.code ?? "—")")
                                    .font(Typo.sans(11)).foregroundStyle(Color.lInk3)
                            }
                        }
                        LabeledContent("Snapshots moved") {
                            Text("\(s.values.count) values · \(snapshotOverlap) overlap (will sum)")
                                .font(Typo.mono(11)).foregroundStyle(Color.lInk2)
                        }
                        LabeledContent("Cost basis") {
                            Text("\(Fmt.currency(t.costBasis, t.nativeCurrency)) + \(Fmt.currency(s.costBasis, s.nativeCurrency)) → \(Fmt.currency(t.costBasis + s.costBasis, t.nativeCurrency))")
                                .font(Typo.mono(11)).foregroundStyle(Color.lInk2)
                        }
                    }
                }
                .formStyle(.grouped)

                if currencyMismatch {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(Color.lLoss).font(.system(size: 11))
                        Text("Currency mismatch (\(source?.nativeCurrency.rawValue ?? "?") vs \(target?.nativeCurrency.rawValue ?? "?")). Merge blocked.")
                            .font(Typo.sans(11)).foregroundStyle(Color.lLoss)
                    }
                }
            }

            if let err = errorMessage {
                Text(err).foregroundStyle(Color.lLoss).font(Typo.sans(12))
            }

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Merge…") { confirming = true }
                    .keyboardShortcut(.defaultAction)
                    .disabled(target == nil || source == nil || currencyMismatch)
            }
        }
        .padding(24)
        .frame(minWidth: 560)
        .onAppear {
            if targetID == nil { targetID = candidateIDs.first }
        }
        .confirmationDialog("Merge \(source?.name ?? "") into \(target?.name ?? "")?",
                            isPresented: $confirming, titleVisibility: .visible) {
            Button("Merge permanently", role: .destructive) { performMerge() }
                .keyboardShortcut(.defaultAction)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Source account will be deleted. \(source?.values.count ?? 0) historical values move to target. This cannot be undone.")
        }
    }

    private func label(for a: Account) -> String {
        let owner = a.person?.name ?? "—"
        return "\(a.name) · \(owner) · \(a.nativeCurrency.rawValue) · \(a.values.count) values"
    }

    private func performMerge() {
        guard let source, let target else { return }
        guard source.nativeCurrency == target.nativeCurrency else {
            errorMessage = "Currency mismatch — cannot merge."
            return
        }

        var targetBySnapshot: [UUID: AssetValue] = [:]
        for v in target.values {
            if let sid = v.snapshot?.id { targetBySnapshot[sid] = v }
        }

        let sourceValues = source.values
        for v in sourceValues {
            guard let snap = v.snapshot else {
                context.delete(v)
                continue
            }
            if let existing = targetBySnapshot[snap.id] {
                existing.nativeValue += v.nativeValue
                if !v.note.isEmpty {
                    existing.note = existing.note.isEmpty ? v.note : (existing.note + "\n" + v.note)
                }
                context.delete(v)
            } else {
                v.account = target
                targetBySnapshot[snap.id] = v
            }
        }

        target.costBasis += source.costBasis
        if !source.notes.isEmpty {
            target.notes = target.notes.isEmpty ? source.notes : (target.notes + "\n— merged from \(source.name) —\n" + source.notes)
        }

        context.delete(source)

        do {
            try context.save()
            onComplete()
            dismiss()
        } catch {
            context.rollback()
            errorMessage = "Merge failed: \(error.localizedDescription)"
        }
    }
}

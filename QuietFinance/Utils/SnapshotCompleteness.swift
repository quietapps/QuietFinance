import Foundation

/// Evaluates whether a snapshot has values recorded for every active account
/// and every applicable receivable. "Filled" means `nativeValue > 0`.
/// Used by SnapshotListView badges and SnapshotEditorView highlights.
enum SnapshotCompleteness {
    struct Result {
        let filledAccounts: Int
        let totalAccounts: Int
        let filledReceivables: Int
        let totalReceivables: Int
        let missingAccountIDs: Set<UUID>
        let missingReceivableIDs: Set<UUID>

        var totalRows: Int { totalAccounts + totalReceivables }
        var filledRows: Int { filledAccounts + filledReceivables }
        var missingCount: Int { totalRows - filledRows }
        var pct: Double { totalRows == 0 ? 1 : Double(filledRows) / Double(totalRows) }
        var isComplete: Bool { totalRows > 0 && filledRows == totalRows }
    }

    static func evaluate(snapshot: Snapshot,
                         accounts: [Account],
                         receivables: [Receivable]) -> Result {
        let activeAccounts = accounts.filter { $0.isActive }
        let applicableRcv = receivables.filter { $0.isActive && $0.startDate <= snapshot.date }

        // Map snapshot rows by id for O(1) lookup.
        let avByAccount: [UUID: Double] = Dictionary(uniqueKeysWithValues:
            snapshot.values.compactMap { v in
                guard let id = v.account?.id else { return nil }
                return (id, v.nativeValue)
            }
        )
        let rvByReceivable: [UUID: Double] = Dictionary(uniqueKeysWithValues:
            snapshot.receivableValues.compactMap { v in
                guard let id = v.receivable?.id else { return nil }
                return (id, v.nativeValue)
            }
        )

        var missingAccts = Set<UUID>()
        var filledAccts = 0
        for a in activeAccounts {
            let val = avByAccount[a.id] ?? 0
            // Debt accounts are "filled" when value is non-zero (debts can be negative
            // but stored as positive native amounts in this codebase).
            if abs(val) > 0.0001 { filledAccts += 1 } else { missingAccts.insert(a.id) }
        }

        var missingRcv = Set<UUID>()
        var filledRcv = 0
        for r in applicableRcv {
            let val = rvByReceivable[r.id] ?? 0
            if abs(val) > 0.0001 { filledRcv += 1 } else { missingRcv.insert(r.id) }
        }

        return Result(
            filledAccounts: filledAccts,
            totalAccounts: activeAccounts.count,
            filledReceivables: filledRcv,
            totalReceivables: applicableRcv.count,
            missingAccountIDs: missingAccts,
            missingReceivableIDs: missingRcv
        )
    }
}

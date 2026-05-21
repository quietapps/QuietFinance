import SwiftUI
import SwiftData
import Combine

final class UndoStash: ObservableObject {
    let objectWillChange = ObservableObjectPublisher()

    struct SnapshotStash {
        let id: UUID
        let date: Date
        let label: String
        let usdToInrRate: Double
        let isLocked: Bool
        let lockedAt: Date?
        let notes: String
        let createdAt: Date
        let values: [(accountID: UUID, nativeValue: Double, note: String)]
    }

    struct AccountStash {
        let id: UUID
        let name: String
        let nativeCurrency: Currency
        let institution: String
        let notes: String
        let isActive: Bool
        let createdAt: Date
        let personID: UUID?
        let countryID: UUID?
        let assetTypeID: UUID?
        let values: [(snapshotID: UUID, nativeValue: Double, note: String)]
    }

    enum Pending {
        case snapshot(SnapshotStash)
        case account(AccountStash)

        var label: String {
            switch self {
            case .snapshot(let s): return "Snapshot “\(s.label)” deleted"
            case .account(let a):  return "Account “\(a.name)” deleted"
            }
        }
    }

    private(set) var pending: Pending? {
        willSet { objectWillChange.send() }
    }
    private(set) var remaining: TimeInterval = 0 {
        willSet { objectWillChange.send() }
    }
    private(set) var restoreError: String? {
        willSet { objectWillChange.send() }
    }

    private var expireTask: Task<Void, Never>?
    private let ttl: TimeInterval = 10

    func capture(snapshot s: Snapshot) -> SnapshotStash {
        SnapshotStash(
            id: s.id,
            date: s.date,
            label: s.label,
            usdToInrRate: s.usdToInrRate,
            isLocked: s.isLocked,
            lockedAt: s.lockedAt,
            notes: s.notes,
            createdAt: s.createdAt,
            values: s.values.compactMap { v in
                guard let accID = v.account?.id else { return nil }
                return (accID, v.nativeValue, v.note)
            }
        )
    }

    func capture(account a: Account) -> AccountStash {
        AccountStash(
            id: a.id,
            name: a.name,
            nativeCurrency: a.nativeCurrency,
            institution: a.institution,
            notes: a.notes,
            isActive: a.isActive,
            createdAt: a.createdAt,
            personID: a.person?.id,
            countryID: a.country?.id,
            assetTypeID: a.assetType?.id,
            values: a.values.compactMap { v in
                guard let snapID = v.snapshot?.id else { return nil }
                return (snapID, v.nativeValue, v.note)
            }
        )
    }

    func stash(_ p: Pending) {
        pending = p
        remaining = ttl
        expireTask?.cancel()
        expireTask = Task { [weak self] in
            guard let self else { return }
            let start = Date()
            while !Task.isCancelled {
                let elapsed = Date().timeIntervalSince(start)
                let r = max(0, self.ttl - elapsed)
                await MainActor.run { self.remaining = r }
                if r <= 0 { break }
                try? await Task.sleep(nanoseconds: 100_000_000)
            }
            if !Task.isCancelled {
                await MainActor.run {
                    self.pending = nil
                    self.remaining = 0
                }
            }
        }
    }

    func clear() {
        expireTask?.cancel()
        expireTask = nil
        pending = nil
        remaining = 0
    }

    func clearRestoreError() { restoreError = nil }

    func restore(context: ModelContext,
                 people: [Person],
                 countries: [Country],
                 types: [AssetType],
                 accounts: [Account],
                 snapshots: [Snapshot]) {
        guard let p = pending else { return }
        switch p {
        case .snapshot(let st):
            let s = Snapshot(date: st.date, label: st.label, usdToInrRate: st.usdToInrRate, notes: st.notes)
            s.id = st.id
            s.isLocked = st.isLocked
            s.lockedAt = st.lockedAt
            s.createdAt = st.createdAt
            context.insert(s)
            let accByID = Dictionary(uniqueKeysWithValues: accounts.map { ($0.id, $0) })
            for v in st.values {
                guard let acc = accByID[v.accountID] else { continue }
                let av = AssetValue(snapshot: s, account: acc, nativeValue: v.nativeValue, note: v.note)
                context.insert(av)
            }
        case .account(let st):
            guard
                let person = st.personID.flatMap({ id in people.first { $0.id == id } }),
                let country = st.countryID.flatMap({ id in countries.first { $0.id == id } }),
                let type = st.assetTypeID.flatMap({ id in types.first { $0.id == id } })
            else {
                // Missing parent entity — cannot reconstruct
                clear()
                return
            }
            let a = Account(
                name: st.name,
                person: person,
                country: country,
                assetType: type,
                nativeCurrency: st.nativeCurrency,
                institution: st.institution,
                notes: st.notes,
                isActive: st.isActive
            )
            a.id = st.id
            a.createdAt = st.createdAt
            context.insert(a)
            let snapByID = Dictionary(uniqueKeysWithValues: snapshots.map { ($0.id, $0) })
            for v in st.values {
                guard let snap = snapByID[v.snapshotID] else { continue }
                let av = AssetValue(snapshot: snap, account: a, nativeValue: v.nativeValue, note: v.note)
                context.insert(av)
            }
        }
        do {
            try context.save()
            restoreError = nil
        } catch {
            restoreError = "Restore failed: \(error.localizedDescription)"
            context.rollback()
        }
        clear()
    }
}

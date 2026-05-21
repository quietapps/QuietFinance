import Foundation
import AppKit
import SwiftData

enum BackupInterval: String, CaseIterable, Identifiable {
    case daily, weekly, monthly
    var id: String { rawValue }
    var label: String {
        switch self { case .daily: return "Daily"; case .weekly: return "Weekly"; case .monthly: return "Monthly" }
    }
    var seconds: TimeInterval {
        switch self {
        case .daily:   return 24 * 3600
        case .weekly:  return 7 * 24 * 3600
        case .monthly: return 30 * 24 * 3600
        }
    }
}

enum BackupService {
    nonisolated static let storeFilename = "default.store"
    nonisolated private static let backupsDirName = "QuietFinance-Backups"
    nonisolated private static let autoPrefix = "QuietFinance-auto-"
    nonisolated private static let manualPrefix = "QuietFinance-backup-"
    nonisolated static let lockPrefix = "QuietFinance-snapshot-"
    nonisolated static let quitPrefix = "QuietFinance-quit-"
    // Legacy prefixes recognized when listing existing backups.
    nonisolated private static let legacyAutoPrefix = "FinanceTracker-auto-"
    nonisolated private static let legacyManualPrefix = "FinanceTracker-backup-"
    nonisolated static let legacyLockPrefix = "FinanceTracker-snapshot-"
    nonisolated static let legacyQuitPrefix = "FinanceTracker-quit-"
    nonisolated private static let customRotateKeep = 3

    // MARK: - Paths

    nonisolated static func storeURL() -> URL? {
        guard let appSupport = try? FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask,
            appropriateFor: nil, create: false
        ) else { return nil }
        return appSupport.appendingPathComponent(storeFilename)
    }

    nonisolated static func backupsDir() -> URL? {
        guard let appSupport = try? FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask,
            appropriateFor: nil, create: true
        ) else { return nil }
        let dir = appSupport.appendingPathComponent(backupsDirName, isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    // MARK: - Listing

    struct BackupFile: Identifiable, Hashable {
        let id: URL
        let url: URL
        let date: Date
        let size: Int64
        let kind: Kind
        enum Kind { case auto, manual, other }
        var name: String { url.lastPathComponent }
    }

    nonisolated static func list() -> [BackupFile] {
        guard let dir = backupsDir() else { return [] }
        let files = (try? FileManager.default.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey]
        )) ?? []
        return files.compactMap { url -> BackupFile? in
            guard url.pathExtension == "store" else { return nil }
            let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey])
            let date = values?.contentModificationDate ?? .distantPast
            let size = Int64(values?.fileSize ?? 0)
            let kind: BackupFile.Kind
            let name = url.lastPathComponent
            if name.hasPrefix(autoPrefix) || name.hasPrefix(legacyAutoPrefix) { kind = .auto }
            else if name.hasPrefix(manualPrefix) || name.hasPrefix(legacyManualPrefix) { kind = .manual }
            else { kind = .other }
            return BackupFile(id: url, url: url, date: date, size: size, kind: kind)
        }
        .sorted { $0.date > $1.date }
    }

    // MARK: - Auto backup

    /// Runs an auto backup if the configured interval has elapsed.
    /// Always prunes auto-prefix backups to "Keep last" regardless of whether
    /// a new backup was written this launch.
    @discardableResult
    static func runIfDue() -> URL? {
        let defaults = UserDefaults.standard
        let keep = max(1, defaults.object(forKey: "autoBackupKeep") as? Int ?? 10)
        defer { pruneAuto(keep: keep) }

        let enabled = defaults.object(forKey: "autoBackupEnabled") as? Bool ?? true
        guard enabled else { return nil }

        let raw = defaults.string(forKey: "autoBackupInterval") ?? BackupInterval.weekly.rawValue
        let interval = BackupInterval(rawValue: raw) ?? .weekly
        let last = defaults.double(forKey: "lastAutoBackupAt")
        let now = Date().timeIntervalSince1970
        if last > 0, now - last < interval.seconds { return nil }

        guard let dir = backupsDir(), let src = storeURL(),
              FileManager.default.fileExists(atPath: src.path) else { return nil }
        let stamp = timestamp()
        let dest = dir.appendingPathComponent("\(autoPrefix)\(stamp).store")
        guard copyStore(from: src, to: dest) else { return nil }

        defaults.set(now, forKey: "lastAutoBackupAt")
        return dest
    }

    /// Backup triggered on snapshot lock. Stored in default backups dir
    /// AND mirrored to user-chosen export path if configured. Keeps last 3 in each location.
    @discardableResult
    static func backupOnLock(label: String) -> URL? {
        guard let dir = backupsDir(), let src = storeURL(),
              FileManager.default.fileExists(atPath: src.path) else { return nil }
        let safe = label
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: " ", with: "_")
        let dest = dir.appendingPathComponent("\(lockPrefix)\(safe)-\(timestamp()).store")
        guard copyStore(from: src, to: dest) else { return nil }
        prune(prefix: lockPrefix, keep: customRotateKeep, in: dir)

        // Also mirror to custom export folder if configured.
        _ = exportToCustomLocation(prefix: lockPrefix, label: safe)
        return dest
    }

    /// Backup triggered on app quit, written to user-chosen folder if set.
    /// Keeps last 3 quit-prefix files in that folder.
    @discardableResult
    static func backupOnQuit() -> URL? {
        return exportToCustomLocation(prefix: quitPrefix, label: "quit")
    }

    /// Resolves the security-scoped bookmark stored in defaults, copies the
    /// live store there, prunes older files matching the same prefix to last 3.
    @discardableResult
    private static func exportToCustomLocation(prefix: String, label: String) -> URL? {
        guard let bookmark = UserDefaults.standard.data(forKey: "customBackupBookmark"),
              let src = storeURL(),
              FileManager.default.fileExists(atPath: src.path) else { return nil }

        var stale = false
        guard let folder = try? URL(resolvingBookmarkData: bookmark,
                                    options: [.withSecurityScope],
                                    relativeTo: nil,
                                    bookmarkDataIsStale: &stale),
              folder.startAccessingSecurityScopedResource()
        else { return nil }
        defer { folder.stopAccessingSecurityScopedResource() }

        let dest = folder.appendingPathComponent("\(prefix)\(label)-\(timestamp()).store")
        guard copyStore(from: src, to: dest) else { return nil }
        prune(prefix: prefix, keep: customRotateKeep, in: folder)
        return dest
    }

    private static func prune(prefix: String, keep: Int, in folder: URL) {
        let fm = FileManager.default
        let files = (try? fm.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: [.contentModificationDateKey]
        )) ?? []
        let matching = files
            .filter { $0.pathExtension == "store" && $0.lastPathComponent.hasPrefix(prefix) }
            .sorted { lhs, rhs in
                let l = (try? lhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                let r = (try? rhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                return l > r
            }
        guard matching.count > keep else { return }
        for url in matching.dropFirst(keep) {
            try? fm.removeItem(at: url)
            try? fm.removeItem(at: sidecar(url, "-wal"))
            try? fm.removeItem(at: sidecar(url, "-shm"))
        }
    }

    nonisolated private static func sidecar(_ url: URL, _ suffix: String) -> URL {
        URL(fileURLWithPath: url.path + suffix)
    }

    // MARK: - Verify backup integrity

    struct VerifyResult {
        let url: URL
        let people: Int
        let accounts: Int
        let snapshots: Int
        let values: Int
        let assetTypes: Int
        let countries: Int
        let receivables: Int
        let receivableValues: Int
        let error: String?
        var isOk: Bool { error == nil }
        var summary: String {
            if let error { return "Failed: \(error)" }
            return "\(people)p · \(accounts)a · \(snapshots)snap · \(values)val · \(assetTypes)t · \(countries)c · \(receivables)r · \(receivableValues)rv"
        }
    }

    @MainActor
    static func verify(_ url: URL) -> VerifyResult {
        let fm = FileManager.default
        guard fm.fileExists(atPath: url.path) else {
            return VerifyResult(url: url, people: 0, accounts: 0, snapshots: 0, values: 0,
                                assetTypes: 0, countries: 0, receivables: 0, receivableValues: 0,
                                error: "File missing")
        }
        // Copy to temp so opening doesn't pollute backup with wal/shm.
        let tmpDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("quietfinance-verify-\(UUID().uuidString)", isDirectory: true)
        do {
            try fm.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        } catch {
            return VerifyResult(url: url, people: 0, accounts: 0, snapshots: 0, values: 0,
                                assetTypes: 0, countries: 0, receivables: 0, receivableValues: 0,
                                error: "Temp dir: \(error.localizedDescription)")
        }
        defer { try? fm.removeItem(at: tmpDir) }

        let tmpStore = tmpDir.appendingPathComponent("verify.store")
        do {
            try fm.copyItem(at: url, to: tmpStore)
            for suffix in ["-wal", "-shm"] {
                let s = sidecar(url, suffix)
                if fm.fileExists(atPath: s.path) {
                    try? fm.copyItem(at: s, to: sidecar(tmpStore, suffix))
                }
            }
        } catch {
            return VerifyResult(url: url, people: 0, accounts: 0, snapshots: 0, values: 0,
                                assetTypes: 0, countries: 0, receivables: 0, receivableValues: 0,
                                error: "Copy: \(error.localizedDescription)")
        }

        do {
            let schema = Schema([
                Person.self, Country.self, AssetType.self,
                Account.self, Snapshot.self, AssetValue.self,
                Receivable.self, ReceivableValue.self,
                ExchangeRateHistory.self
            ])
            let config = ModelConfiguration(schema: schema, url: tmpStore)
            let container = try ModelContainer(for: schema, configurations: [config])
            let ctx = ModelContext(container)
            let p = (try? ctx.fetchCount(FetchDescriptor<Person>())) ?? 0
            let a = (try? ctx.fetchCount(FetchDescriptor<Account>())) ?? 0
            let s = (try? ctx.fetchCount(FetchDescriptor<Snapshot>())) ?? 0
            let v = (try? ctx.fetchCount(FetchDescriptor<AssetValue>())) ?? 0
            let t = (try? ctx.fetchCount(FetchDescriptor<AssetType>())) ?? 0
            let c = (try? ctx.fetchCount(FetchDescriptor<Country>())) ?? 0
            let r = (try? ctx.fetchCount(FetchDescriptor<Receivable>())) ?? 0
            let rv = (try? ctx.fetchCount(FetchDescriptor<ReceivableValue>())) ?? 0
            return VerifyResult(url: url, people: p, accounts: a, snapshots: s, values: v,
                                assetTypes: t, countries: c, receivables: r, receivableValues: rv,
                                error: nil)
        } catch {
            return VerifyResult(url: url, people: 0, accounts: 0, snapshots: 0, values: 0,
                                assetTypes: 0, countries: 0, receivables: 0, receivableValues: 0,
                                error: error.localizedDescription)
        }
    }

    static func backupNow() -> URL? {
        guard let dir = backupsDir(), let src = storeURL(),
              FileManager.default.fileExists(atPath: src.path) else { return nil }
        let dest = dir.appendingPathComponent("\(manualPrefix)\(timestamp()).store")
        return copyStore(from: src, to: dest) ? dest : nil
    }

    private static func pruneAuto(keep: Int) {
        let autos = list().filter { $0.kind == .auto }
        guard autos.count > keep else { return }
        for b in autos.dropFirst(keep) {
            try? FileManager.default.removeItem(at: b.url)
            try? FileManager.default.removeItem(at: sidecar(b.url, "-wal"))
            try? FileManager.default.removeItem(at: sidecar(b.url, "-shm"))
        }
    }

    // MARK: - Restore

    // MARK: - Pending restore (applied at next launch, before ModelContainer opens)

    nonisolated private static let pendingFlagFilename = ".pending-restore"
    nonisolated private static let pendingStoreFilename = "pending-restore.store"

    /// Stage a backup so the next app launch replaces the live store before
    /// opening the ModelContainer. Avoids SwiftData's in-memory state
    /// overwriting our restore on terminate.
    nonisolated static func stagePendingRestore(from backupURL: URL) throws {
        guard let appSupport = try? FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask,
            appropriateFor: nil, create: true
        ) else {
            throw NSError(domain: "Backup", code: -10,
                          userInfo: [NSLocalizedDescriptionKey: "App Support unavailable."])
        }
        let fm = FileManager.default
        let pendStore = appSupport.appendingPathComponent(pendingStoreFilename)

        // Acquire security scope if backup file came from outside the sandbox container.
        let needsScope = backupURL.startAccessingSecurityScopedResource()
        defer { if needsScope { backupURL.stopAccessingSecurityScopedResource() } }

        for suffix in ["", "-wal", "-shm"] {
            let p = sidecar(pendStore, suffix)
            if fm.fileExists(atPath: p.path) { try fm.removeItem(at: p) }
        }
        try fm.copyItem(at: backupURL, to: pendStore)
        for suffix in ["-wal", "-shm"] {
            let s = sidecar(backupURL, suffix)
            if fm.fileExists(atPath: s.path) {
                try? fm.copyItem(at: s, to: sidecar(pendStore, suffix))
            }
        }
        // Flag file marks restore intent.
        let flag = appSupport.appendingPathComponent(pendingFlagFilename)
        try? Data().write(to: flag)
    }

    /// Called from app init before creating ModelContainer. If a pending
    /// restore is staged, copy it over the live store and clear the flag.
    @discardableResult
    nonisolated static func applyPendingRestoreIfAny() -> Bool {
        guard let appSupport = try? FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask,
            appropriateFor: nil, create: false
        ) else { return false }
        let fm = FileManager.default
        let flag = appSupport.appendingPathComponent(pendingFlagFilename)
        guard fm.fileExists(atPath: flag.path) else { return false }
        let pendStore = appSupport.appendingPathComponent(pendingStoreFilename)
        guard fm.fileExists(atPath: pendStore.path),
              let dst = storeURL() else {
            try? fm.removeItem(at: flag)
            return false
        }

        // Safety: snapshot current live store as pre-restore backup.
        if fm.fileExists(atPath: dst.path), let dir = backupsDir() {
            let safety = dir.appendingPathComponent("\(autoPrefix)pre-restore-\(timestamp()).store")
            _ = copyStore(from: dst, to: safety)
        }

        // Wipe live store + sidecars.
        for suffix in ["", "-wal", "-shm"] {
            let p = sidecar(dst, suffix)
            if fm.fileExists(atPath: p.path) {
                do { try fm.removeItem(at: p) }
                catch { NSLog("QuietFinance: failed remove \(p.path): \(error)") }
            }
        }
        // Move pending into place.
        do {
            try fm.copyItem(at: pendStore, to: dst)
        } catch {
            NSLog("QuietFinance: applyPendingRestore — copy failed: \(error)")
            try? fm.removeItem(at: flag)
            return false
        }
        for suffix in ["-wal", "-shm"] {
            let s = sidecar(pendStore, suffix)
            let d = sidecar(dst, suffix)
            if fm.fileExists(atPath: s.path) {
                try? fm.copyItem(at: s, to: d)
            }
        }
        // Cleanup staged + flag.
        try? fm.removeItem(at: pendStore)
        for suffix in ["-wal", "-shm"] {
            try? fm.removeItem(at: sidecar(pendStore, suffix))
        }
        try? fm.removeItem(at: flag)
        return true
    }

    /// Replaces the live store files with those from `backupURL`.
    /// Caller must then quit & relaunch — the in-memory ModelContainer still
    /// points at the old file handles.
    static func restore(from backupURL: URL) throws {
        guard let dst = storeURL() else {
            throw NSError(domain: "Backup", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "App Support unavailable."])
        }
        let fm = FileManager.default

        // Safety: copy live store to a "pre-restore" backup first.
        if fm.fileExists(atPath: dst.path), let dir = backupsDir() {
            let safety = dir.appendingPathComponent("\(autoPrefix)pre-restore-\(timestamp()).store")
            _ = copyStore(from: dst, to: safety)
        }

        for suffix in ["", "-wal", "-shm"] {
            let dstPath = sidecar(dst, suffix)
            if fm.fileExists(atPath: dstPath.path) {
                try fm.removeItem(at: dstPath)
            }
        }

        try fm.copyItem(at: backupURL, to: dst)
        for suffix in ["-wal", "-shm"] {
            let srcSide = sidecar(backupURL, suffix)
            let dstSide = sidecar(dst, suffix)
            if fm.fileExists(atPath: srcSide.path) {
                try? fm.copyItem(at: srcSide, to: dstSide)
            }
        }
    }

    // MARK: - Helpers

    @discardableResult
    nonisolated private static func copyStore(from src: URL, to dst: URL) -> Bool {
        let fm = FileManager.default
        do {
            if fm.fileExists(atPath: dst.path) { try fm.removeItem(at: dst) }
            try fm.copyItem(at: src, to: dst)
            let now = Date()
            try? fm.setAttributes([.modificationDate: now, .creationDate: now], ofItemAtPath: dst.path)
            for suffix in ["-wal", "-shm"] {
                let s = sidecar(src, suffix)
                let d = sidecar(dst, suffix)
                if fm.fileExists(atPath: d.path) { try? fm.removeItem(at: d) }
                if fm.fileExists(atPath: s.path) {
                    try? fm.copyItem(at: s, to: d)
                    try? fm.setAttributes([.modificationDate: now, .creationDate: now], ofItemAtPath: d.path)
                }
            }
            return true
        } catch {
            return false
        }
    }

    nonisolated private static func timestamp() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd-HHmmss"
        return f.string(from: Date())
    }

    nonisolated static func lastAutoBackupDate() -> Date? {
        let t = UserDefaults.standard.double(forKey: "lastAutoBackupAt")
        return t > 0 ? Date(timeIntervalSince1970: t) : nil
    }
}

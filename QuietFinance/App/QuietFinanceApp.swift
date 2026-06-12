import SwiftUI
import SwiftData

@main
struct QuietFinanceApp: App {
    let container: ModelContainer
    /// Set when the on-disk store could not be opened and the app fell back to
    /// a temporary in-memory container. RootView surfaces this as a banner so
    /// the user knows their changes won't persist until they recover.
    static var safeModeReason: String? = nil
    @StateObject private var app = AppState()
    @StateObject private var systemAppearance = SystemAppearanceObserver()
    @StateObject private var undo = UndoStash()
    @StateObject private var lockGate: AppLockGate = {
        // Default to ON when key absent — matches AppState's AppStorage default.
        let defaults = UserDefaults.standard
        let locked = defaults.object(forKey: "requireAppLock") as? Bool ?? true
        return AppLockGate(initiallyLocked: locked)
    }()
    @NSApplicationDelegateAdaptor(QuitBackupDelegate.self) private var quitDelegate

    init() {
        FontRegistrar.registerIfNeeded()
        BackupService.applyPendingRestoreIfAny()
        let schema = Schema([
            Person.self, Country.self, AssetType.self,
            Account.self, Snapshot.self, AssetValue.self,
            Receivable.self, ReceivableValue.self,
            ExchangeRateHistory.self
        ])
        var safeMode = false
        if let storeURL = BackupService.storeURL() {
            let config = ModelConfiguration(schema: schema, url: storeURL)
            do {
                container = try ModelContainer(for: schema, configurations: [config])
            } catch {
                // A corrupt or schema-incompatible store would otherwise crash-loop
                // the app on every launch. Fall back to a non-persistent in-memory
                // container so the app opens, leaving the on-disk file untouched for
                // recovery (Settings → restore from backup, or manual file fix).
                safeMode = true
                Self.safeModeReason = "Your data file couldn’t be opened, so Quiet Finance is running in temporary safe mode. Changes made now will NOT be saved. Your file on disk is untouched — restore a backup from Settings, then relaunch.\n\nDetails: \(error.localizedDescription)"
                container = Self.makeInMemoryContainer(schema: schema)
            }
        } else {
            // Application Support could not be resolved (sandbox/permission issue).
            // Same safe-mode treatment as a corrupt store: open in memory, warn.
            safeMode = true
            Self.safeModeReason = "Quiet Finance couldn’t access its data folder (Application Support), so it is running in temporary safe mode. Changes made now will NOT be saved. Check disk permissions, then relaunch."
            container = Self.makeInMemoryContainer(schema: schema)
        }
        if !safeMode {
            SeedData.seedIfEmpty(context: container.mainContext)
            Self.backfillAccountSortIndex(context: container.mainContext)
            // Skip backup/reminder writes in safe mode: the on-disk store is the
            // corrupt one we deliberately left alone, and we must not overwrite
            // good backups with it.
            _ = BackupService.runIfDue()
            ReminderScheduler.check(context: container.mainContext)
        }
        DispatchQueue.main.async { [container] in
            // One-time migration: old default was "dusk"; new default is "classic".
            // If user never explicitly changed the icon, silently upgrade them.
            if !UserDefaults.standard.bool(forKey: "iconDefaultMigratedV2") {
                if UserDefaults.standard.string(forKey: "appIconChoice") == "dusk" {
                    UserDefaults.standard.set(AppIconChoice.classic.rawValue, forKey: "appIconChoice")
                }
                UserDefaults.standard.set(true, forKey: "iconDefaultMigratedV2")
            }
            let raw = UserDefaults.standard.string(forKey: "appIconChoice") ?? AppIconChoice.classic.rawValue
            AppIconSwitcher.apply(AppIconChoice(rawValue: raw) ?? .classic)
            MenuBarController.shared.attach(container: container)
            let mb = UserDefaults.standard.object(forKey: "menuBarEnabled") as? Bool ?? false
            MenuBarController.shared.setEnabled(mb)
        }
    }

    /// Concrete scheme to force. `.system` resolves to the live OS scheme so the
    /// switch lands on the first click and still tracks System Settings changes.
    private var effectiveColorScheme: ColorScheme? {
        switch app.theme {
        case .light:  return .light
        case .dark:   return .dark
        case .system: return systemAppearance.scheme
        }
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                RootView()
                    .environmentObject(app)
                    .environmentObject(undo)
                    .environmentObject(lockGate)
                    .environmentObject(ToastCenter.shared)
                    .onAppear {
                        if !lockGate.isLocked { lockGate.startIdleMonitorIfConfigured() }
                    }
                    .blur(radius: lockGate.isLocked ? 18 : 0)
                    .allowsHitTesting(!lockGate.isLocked)
                if lockGate.isLocked {
                    LockScreen(gate: lockGate)
                        .environmentObject(app)
                        .transition(.opacity)
                        .zIndex(10_000)
                }
            }
            .animation(.easeInOut(duration: 0.18), value: lockGate.isLocked)
            // Single source of truth for theme. Drives the SwiftUI color scheme
            // (window chrome included) so the dynamic light/dark tokens resolve
            // deterministically. `.system` resolves to the CONCRETE OS scheme
            // (never nil) — nil doesn't re-resolve colors in the same pass, which
            // made selecting System need a second click. Do NOT also set
            // `window.appearance` imperatively; a second writer races this one.
            .preferredColorScheme(effectiveColorScheme)
        }
        .modelContainer(container)
        .defaultSize(width: 1400, height: 1000)
        .windowResizability(.contentMinSize)
        .commands {
            NavCommands()
            SnapshotCommands()
            SearchCommands()
            UndoDeleteCommands()
        }
    }

    /// Build the non-persistent fallback container used by safe mode. If even
    /// this fails the Schema itself is invalid — a programmer error that can't
    /// occur in a shipped build — so crashing with a clear message is correct.
    private static func makeInMemoryContainer(schema: Schema) -> ModelContainer {
        let memConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        do {
            return try ModelContainer(for: schema, configurations: [memConfig])
        } catch {
            fatalError("Failed to create in-memory fallback ModelContainer: \(error)")
        }
    }

    /// Assign a stable sortIndex to existing accounts on first launch after the
    /// field is introduced. Detected by all rows still being 0. Order seeded
    /// by name so the user starts with a reasonable arrangement.
    private static func backfillAccountSortIndex(context: ModelContext) {
        guard let accounts = try? context.fetch(FetchDescriptor<Account>()),
              !accounts.isEmpty,
              accounts.allSatisfy({ $0.sortIndex == 0 }) else { return }
        let sorted = accounts.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        for (i, a) in sorted.enumerated() { a.sortIndex = i + 1 }
        try? context.save()
    }
}

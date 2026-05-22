import SwiftUI
import SwiftData

@main
struct QuietFinanceApp: App {
    let container: ModelContainer
    @StateObject private var app = AppState()
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
        do {
            let schema = Schema([
                Person.self, Country.self, AssetType.self,
                Account.self, Snapshot.self, AssetValue.self,
                Receivable.self, ReceivableValue.self,
                ExchangeRateHistory.self
            ])
            guard let storeURL = BackupService.storeURL() else {
                fatalError("Could not resolve store URL")
            }
            let config = ModelConfiguration(schema: schema, url: storeURL)
            container = try ModelContainer(for: schema, configurations: [config])
            SeedData.seedIfEmpty(context: container.mainContext)
            Self.backfillAccountSortIndex(context: container.mainContext)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
        _ = BackupService.runIfDue()
        ReminderScheduler.check(context: container.mainContext)
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

    var body: some Scene {
        WindowGroup {
            ZStack {
                RootView()
                    .environmentObject(app)
                    .environmentObject(undo)
                    .environmentObject(lockGate)
                    .onChange(of: app.theme) { _, newTheme in
                        applyWindowAppearance(newTheme)
                    }
                    .onAppear {
                        applyWindowAppearance(app.theme)
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

    private func applyWindowAppearance(_ theme: AppTheme) {
        let appearance: NSAppearance? = {
            switch theme {
            case .system: return nil
            case .light:  return NSAppearance(named: .aqua)
            case .dark:   return NSAppearance(named: .darkAqua)
            }
        }()
        for window in NSApp.windows {
            window.appearance = appearance
        }
    }
}

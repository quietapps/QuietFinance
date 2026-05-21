import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import AppKit
import Charts
import Combine

struct SettingsView: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var lockGate: AppLockGate
    @Environment(\.modelContext) private var context
    @Query(sort: \Snapshot.date, order: .reverse) private var snapshots: [Snapshot]
    @Query(sort: \Account.name) private var accounts: [Account]
    @AppStorage("reminderEnabled") private var reminderEnabled: Bool = true

    @State private var pendingExport: PendingExport?
    @State private var confirmingReset = false
    @State private var backupMessage: String?
    @State private var categoryColorRefresh = UUID()
    @State private var backupsTick: Int = 0
    @StateObject private var backupsCache = BackupsCache()
    @State private var verifyResults: [URL: BackupService.VerifyResult] = [:]
    @State private var verifyingURL: URL?
    @State private var pendingRestore: URL?
    @State private var showingRelaunchAlert = false
    @State private var showingImportPicker = false
    @State private var importResult: String?
    @State private var importIsError: Bool = false
    @AppStorage("autoBackupEnabled")   private var autoBackupEnabled: Bool = true
    @AppStorage("autoBackupInterval")  private var autoBackupIntervalRaw: String = BackupInterval.weekly.rawValue
    @AppStorage("autoBackupKeep")      private var autoBackupKeep: Int = 10
    @AppStorage("customBackupPath")    private var customBackupPath: String = ""

    private struct PendingExport: Identifiable {
        let id = UUID()
        let document: CSVDocument
        let defaultFilename: String
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            PageHero(eyebrow: "SYSTEM · PREFERENCES",
                     title: "Settings",
                     titleItalic: "— configuration")

            HStack(alignment: .top, spacing: 18) {
                VStack(spacing: 18) {
                    displayPanel
                    appIconPanel
                    dashboardWidgetsPanel
                    categoryColorsPanel
                    fxRatePanel
                    dataPanel
                }
                .frame(maxWidth: .infinity, alignment: .top)

                VStack(spacing: 18) {
                    securityPanel
                    remindersPanel
                    autoBackupPanel
                    exportPanel
                    importPanel
                }
                .frame(maxWidth: .infinity, alignment: .top)
            }
        }
        .frame(maxWidth: 980, alignment: .leading)
        .task { await backupsCache.loadIfNeeded() }
        .task(id: backupsTick) {
            guard backupsTick > 0 else { return }
            await backupsCache.refresh()
        }
        .confirmationDialog("Reset all data?",
                            isPresented: $confirmingReset,
                            titleVisibility: .visible) {
            Button("Delete all and re-seed", role: .destructive) {
                resetAllData()
            }
            .keyboardShortcut(.defaultAction)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Deletes every person, country, account, snapshot, and value. Re-seeds with sample data. Cannot be undone.")
        }
        .confirmationDialog(
            pendingRestore.map { "Restore from \($0.lastPathComponent)?" } ?? "",
            isPresented: Binding(
                get: { pendingRestore != nil },
                set: { if !$0 { pendingRestore = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Restore & Relaunch", role: .destructive) {
                if let url = pendingRestore { performRestore(url) }
                pendingRestore = nil
            }
            .keyboardShortcut(.defaultAction)
            Button("Cancel", role: .cancel) { pendingRestore = nil }
        } message: {
            Text("Current data will be replaced. A safety copy of the current store is saved to the backups folder before restore. App will quit after restore — relaunch to load the restored data.")
        }
        .alert("Restore staged", isPresented: $showingRelaunchAlert) {
            Button("Quit Now") { NSApp.terminate(nil) }
                .keyboardShortcut(.defaultAction)
        } message: {
            Text("Backup will replace the live store on next launch. Quit now, then reopen Quiet Finance — the restore applies before any data loads. A safety copy of the current store is saved automatically.")
        }
        .fileImporter(
            isPresented: $showingImportPicker,
            allowedContentTypes: [.commaSeparatedText, .plainText],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                performImport(url)
            }
        }
        .alert(importIsError ? "Import failed" : "Import complete",
               isPresented: Binding(
                get: { importResult != nil },
                set: { if !$0 { importResult = nil } })) {
            Button("OK") { importResult = nil }
                .keyboardShortcut(.defaultAction)
        } message: {
            Text(importResult ?? "")
        }
        .fileExporter(
            isPresented: Binding(
                get: { pendingExport != nil },
                set: { if !$0 { pendingExport = nil } }
            ),
            document: pendingExport?.document,
            contentType: .commaSeparatedText,
            defaultFilename: pendingExport?.defaultFilename ?? "export.csv"
        ) { result in
            pendingExport = nil
            if case .failure(let err) = result {
                print("Export failed: \(err)")
            }
        }
    }

    // MARK: - Panels

    private var securityPanel: some View {
        Panel {
            VStack(alignment: .leading, spacing: 0) {
                PanelHead(title: "Security",
                          meta: app.requireAppLock ? "Lock on" : "Unlocked")
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .center, spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(app.requireAppLock
                                      ? Color.lGain.opacity(0.14)
                                      : Color.lInk3.opacity(0.10))
                                .frame(width: 36, height: 36)
                            Image(systemName: app.requireAppLock ? "lock.fill" : "lock.open.fill")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(app.requireAppLock ? Color.lGain : Color.lInk3)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Require unlock on launch")
                                .font(Typo.sans(13, weight: .semibold))
                                .foregroundStyle(Color.lInk)
                            Text(AppLockGate.available
                                 ? "Touch ID, Apple Watch, or system password."
                                 : "No biometric or password method available on this device.")
                                .font(Typo.sans(11))
                                .foregroundStyle(Color.lInk3)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 6)
                        Toggle("", isOn: Binding(
                            get: { app.requireAppLock },
                            set: { app.requireAppLock = $0 }
                        ))
                        .toggleStyle(.switch)
                        .labelsHidden()
                        .disabled(!AppLockGate.available)
                        .pointerStyle(.link)
                        .onChange(of: app.requireAppLock) { _, _ in
                            lockGate.reapplyIdleSetting()
                        }
                    }

                    Divider().overlay(Color.lLine)

                    HStack(alignment: .center, spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(app.autoLockIdleMinutes > 0
                                      ? Color.lGain.opacity(0.14)
                                      : Color.lInk3.opacity(0.10))
                                .frame(width: 36, height: 36)
                            Image(systemName: "clock.badge.xmark")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(app.autoLockIdleMinutes > 0 ? Color.lGain : Color.lInk3)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Auto-lock when idle")
                                .font(Typo.sans(13, weight: .semibold))
                                .foregroundStyle(Color.lInk)
                            Text("Re-engage the lock after no key or mouse activity in-app. Off when set to Never.")
                                .font(Typo.sans(11))
                                .foregroundStyle(Color.lInk3)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 6)
                        Picker("", selection: Binding(
                            get: { app.autoLockIdleMinutes },
                            set: { newVal in
                                app.autoLockIdleMinutes = newVal
                                lockGate.reapplyIdleSetting()
                            }
                        )) {
                            Text("Never").tag(0)
                            Text("1 min").tag(1)
                            Text("5 min").tag(5)
                            Text("15 min").tag(15)
                            Text("30 min").tag(30)
                            Text("60 min").tag(60)
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .frame(width: 110)
                        .disabled(!app.requireAppLock || !AppLockGate.available)
                    }

                    Divider().overlay(Color.lLine)

                    HStack(alignment: .center, spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(app.menuBarEnabled
                                      ? Color.lInk.opacity(0.10)
                                      : Color.lInk3.opacity(0.10))
                                .frame(width: 36, height: 36)
                            Image(systemName: "menubar.rectangle")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(app.menuBarEnabled ? Color.lInk : Color.lInk3)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Menu bar item")
                                .font(Typo.sans(13, weight: .semibold))
                                .foregroundStyle(Color.lInk)
                            Text("Net worth + QoQ delta in the system menu bar. Refreshes every minute.")
                                .font(Typo.sans(11))
                                .foregroundStyle(Color.lInk3)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 6)
                        Toggle("", isOn: Binding(
                            get: { app.menuBarEnabled },
                            set: { newOn in
                                app.menuBarEnabled = newOn
                                MenuBarController.shared.setEnabled(newOn)
                                if newOn {
                                    MenuBarController.shared.setDisplayCurrency(app.displayCurrency)
                                    MenuBarController.shared.setStealth(app.stealthMode)
                                }
                            }
                        ))
                        .toggleStyle(.switch)
                        .labelsHidden()
                        .pointerStyle(.link)
                    }

                    Divider().overlay(Color.lLine)

                    HStack(alignment: .center, spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(app.stealthMode
                                      ? Color.lInk.opacity(0.10)
                                      : Color.lInk3.opacity(0.10))
                                .frame(width: 36, height: 36)
                            Image(systemName: app.stealthMode ? "eye.slash.fill" : "eye.fill")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(app.stealthMode ? Color.lInk : Color.lInk3)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Stealth mode")
                                .font(Typo.sans(13, weight: .semibold))
                                .foregroundStyle(Color.lInk)
                            Text("Blurs amounts everywhere. Hover to reveal individual values.")
                                .font(Typo.sans(11))
                                .foregroundStyle(Color.lInk3)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 6)
                        Toggle("", isOn: Binding(
                            get: { app.stealthMode },
                            set: { app.stealthMode = $0 }
                        ))
                        .toggleStyle(.switch)
                        .labelsHidden()
                        .pointerStyle(.link)
                    }

                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 10))
                            .foregroundStyle(Color.lInk3)
                            .padding(.top, 2)
                        Text("Shoulder-surf protection only. The SwiftData store on disk stays unencrypted — anyone with file access can still read it.")
                            .font(Typo.sans(10.5))
                            .foregroundStyle(Color.lInk3)
                            .lineSpacing(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, 10).padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.lSunken.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .padding(.horizontal, 18).padding(.vertical, 14)
            }
        }
    }

    private var dashboardWidgetsPanel: some View {
        Panel {
            VStack(alignment: .leading, spacing: 0) {
                PanelHead(title: "Dashboard widgets",
                          meta: "\(app.dashboardWidgetOrder.filter { !app.dashboardWidgetsHidden.contains($0) }.count) of \(DashboardWidget.allCases.count) shown")
                VStack(alignment: .leading, spacing: 6) {
                    Text("Drag rows to reorder. Toggle to show/hide.")
                        .font(Typo.sans(11))
                        .foregroundStyle(Color.lInk3)
                        .padding(.horizontal, 18).padding(.top, 12)
                    ForEach(Array(app.dashboardWidgetOrder.enumerated()), id: \.element) { idx, w in
                        widgetRow(w: w, idx: idx)
                    }
                    HStack {
                        Spacer()
                        GhostButton(action: {
                            app.dashboardWidgetOrderRaw = ""
                            app.dashboardWidgetsHiddenRaw = ""
                        }) { Text("Reset to defaults") }
                    }
                    .padding(.horizontal, 18).padding(.vertical, 10)
                }
            }
        }
    }

    @ViewBuilder
    private func widgetRow(w: DashboardWidget, idx: Int) -> some View {
        let order = app.dashboardWidgetOrder
        let hidden = app.dashboardWidgetsHidden.contains(w)
        HStack(spacing: 10) {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 11))
                .foregroundStyle(Color.lInk4)
            Image(systemName: w.icon)
                .font(.system(size: 12))
                .foregroundStyle(hidden ? Color.lInk4 : Color.lInk2)
                .frame(width: 18)
            Text(w.label)
                .font(Typo.sans(12.5, weight: .medium))
                .foregroundStyle(hidden ? Color.lInk3 : Color.lInk)
            Spacer()
            Button {
                guard idx > 0 else { return }
                var copy = order
                copy.swapAt(idx, idx - 1)
                app.dashboardWidgetOrder = copy
            } label: {
                Image(systemName: "chevron.up")
                    .font(.system(size: 10, weight: .bold))
            }
            .buttonStyle(.plain).pointerStyle(.link)
            .disabled(idx == 0)
            .opacity(idx == 0 ? 0.3 : 1)
            Button {
                guard idx < order.count - 1 else { return }
                var copy = order
                copy.swapAt(idx, idx + 1)
                app.dashboardWidgetOrder = copy
            } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .bold))
            }
            .buttonStyle(.plain).pointerStyle(.link)
            .disabled(idx == order.count - 1)
            .opacity(idx == order.count - 1 ? 0.3 : 1)
            Toggle("", isOn: Binding(
                get: { !app.dashboardWidgetsHidden.contains(w) },
                set: { newOn in
                    var h = app.dashboardWidgetsHidden
                    if newOn { h.remove(w) } else { h.insert(w) }
                    app.dashboardWidgetsHidden = h
                }
            ))
            .toggleStyle(.switch)
            .labelsHidden()
            .controlSize(.small)
        }
        .padding(.horizontal, 18).padding(.vertical, 6)
        .background(idx.isMultiple(of: 2) ? Color.clear : Color.lSunken.opacity(0.4))
        .draggable(w.rawValue) {
            HStack(spacing: 6) {
                Image(systemName: w.icon)
                Text(w.label).font(Typo.sans(12, weight: .medium))
            }
            .padding(8)
            .background(Color.lPanel)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.lLine, lineWidth: 1))
        }
        .dropDestination(for: String.self) { items, _ in
            guard let raw = items.first, let dragged = DashboardWidget(rawValue: raw) else { return false }
            var copy = app.dashboardWidgetOrder
            guard let from = copy.firstIndex(of: dragged) else { return false }
            copy.remove(at: from)
            let insertIdx = min(idx, copy.count)
            copy.insert(dragged, at: insertIdx)
            app.dashboardWidgetOrder = copy
            return true
        }
    }

    private var appIconPanel: some View {
        Panel {
            VStack(alignment: .leading, spacing: 0) {
                PanelHead(title: "App icon",
                          meta: "Dock + window menu")
                VStack(alignment: .leading, spacing: 10) {
                    Text("Updates while the app runs. The bundle's default icon shows when the app is closed.")
                        .font(Typo.sans(11))
                        .foregroundStyle(Color.lInk3)
                    HStack(spacing: 14) {
                        ForEach(AppIconChoice.allCases) { choice in
                            iconChoiceCard(choice)
                        }
                        Spacer(minLength: 0)
                    }
                }
                .padding(.horizontal, 18).padding(.vertical, 14)
            }
        }
    }

    @ViewBuilder
    private func iconChoiceCard(_ choice: AppIconChoice) -> some View {
        let selected = app.appIconChoice == choice
        Button {
            app.appIconChoice = choice
        } label: {
            VStack(spacing: 8) {
                Image(choice.assetName)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(selected ? Color.lInk : Color.lLine,
                                    lineWidth: selected ? 2 : 1)
                    )
                VStack(spacing: 1) {
                    Text(choice.label)
                        .font(Typo.sans(12, weight: .semibold))
                        .foregroundStyle(Color.lInk)
                    Text(choice.subtitle)
                        .font(Typo.sans(10.5))
                        .foregroundStyle(Color.lInk3)
                        .lineLimit(1)
                }
                if selected {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 10))
                        Text("Active")
                            .font(Typo.eyebrow).tracking(1.2)
                    }
                    .foregroundStyle(Color.lGain)
                } else {
                    Text(" ").font(Typo.eyebrow)
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 10)
            .background(Color.lPanel.opacity(0.001))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .pointerStyle(.link)
    }

    private var displayPanel: some View {
        Panel {
            VStack(spacing: 0) {
                PanelHead(title: "Display")
                VStack(spacing: 0) {
                    settingRow(label: "Default currency") {
                        SegControl(
                            options: Currency.allCases.map { ($0.rawValue, $0) },
                            selection: Binding(
                                get: { app.displayCurrency },
                                set: { app.displayCurrency = $0 }
                            )
                        )
                    }
                    Divider().overlay(Color.lLine)
                    settingRow(label: "Theme") {
                        SegControl(
                            options: [("● System", AppTheme.system),
                                      ("☼ Light", AppTheme.light),
                                      ("☾ Dark", AppTheme.dark)],
                            selection: Binding(
                                get: { app.theme },
                                set: { app.theme = $0 }
                            )
                        )
                    }
                    Divider().overlay(Color.lLine)
                    settingRow(label: "Label mode") {
                        SegControl(
                            options: [("$", LabelMode.dollar),
                                      ("%", LabelMode.percent),
                                      ("Both", LabelMode.both)],
                            selection: Binding(
                                get: { app.labelMode },
                                set: { app.labelMode = $0 }
                            )
                        )
                    }
                    Divider().overlay(Color.lLine)
                    settingRow(label: "Include illiquid in net worth",
                               sublabel: "Real estate, land, vehicles, collectibles") {
                        Toggle("", isOn: Binding(
                            get: { app.includeIlliquidInNetWorth },
                            set: { app.includeIlliquidInNetWorth = $0 }
                        ))
                        .toggleStyle(.switch)
                        .labelsHidden()
                    }
                    Divider().overlay(Color.lLine)
                    settingRow(label: "Compact mode",
                               sublabel: "Shrinks padding + headers for laptop screens.") {
                        Toggle("", isOn: Binding(
                            get: { app.compactMode },
                            set: { app.compactMode = $0 }
                        ))
                        .toggleStyle(.switch)
                        .labelsHidden()
                    }
                    Divider().overlay(Color.lLine)
                    settingRow(label: "Net worth goal",
                               sublabel: "Target line on Dashboard + Trends. Set to 0 to disable.") {
                        HStack(spacing: 6) {
                            TextField("0", value: Binding(
                                get: { app.netWorthGoal },
                                set: { app.netWorthGoal = max(0, $0) }
                            ), format: .number)
                            .textFieldStyle(.roundedBorder)
                            .font(Typo.mono(12))
                            .frame(width: 130)
                            SegControl<Currency>(
                                options: Currency.allCases.map { (label: $0.rawValue, value: $0) },
                                selection: Binding(
                                    get: { app.netWorthGoalCurrency },
                                    set: { app.netWorthGoalCurrency = $0 }
                                )
                            )
                        }
                    }
                    Divider().overlay(Color.lLine)
                    settingRow(label: "Goal target date",
                               sublabel: "Optional. Drives ETA and progress pacing on Dashboard.") {
                        HStack(spacing: 6) {
                            DatePicker("",
                                       selection: Binding(
                                        get: { app.netWorthGoalDate ?? Date.now.addingTimeInterval(86400 * 365) },
                                        set: { app.netWorthGoalDate = $0 }),
                                       displayedComponents: .date)
                                .labelsHidden()
                                .disabled(app.netWorthGoal <= 0)
                            if app.netWorthGoalDate != nil {
                                Button {
                                    app.netWorthGoalDate = nil
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 11))
                                        .foregroundStyle(Color.lInk3)
                                }
                                .buttonStyle(.plain)
                                .pointerStyle(.link)
                                .help("Clear target date")
                            }
                        }
                    }
                }
                .padding(.horizontal, 18).padding(.vertical, 4)
            }
        }
    }


    private var categoryColorsPanel: some View {
        Panel {
            VStack(spacing: 0) {
                PanelHead(title: "Category colors",
                          meta: "\(AssetCategory.allCases.count) categories")
                VStack(spacing: 0) {
                    ForEach(Array(AssetCategory.allCases.enumerated()), id: \.element) { idx, cat in
                        CategoryColorRow(category: cat)
                            .padding(.horizontal, 18).padding(.vertical, 10)
                            .background(idx.isMultiple(of: 2) ? Color.clear : Color.lSunken.opacity(0.5))
                        if idx < AssetCategory.allCases.count - 1 {
                            Divider().overlay(Color.lLine)
                        }
                    }
                }
                .id(categoryColorRefresh)
                Divider().overlay(Color.lLine)
                HStack {
                    Text("Clear overrides, use built-in palette.")
                        .font(Typo.serifItalic(12))
                        .foregroundStyle(Color.lInk3)
                    Spacer()
                    GhostButton(action: {
                        for cat in AssetCategory.allCases {
                            CategoryColorStore.setHex(nil, for: cat)
                        }
                        categoryColorRefresh = UUID()
                    }) { Text("Reset defaults") }
                }
                .padding(.horizontal, 18).padding(.vertical, 12)
            }
        }
    }

    private var autoBackupPanel: some View {
        Panel {
            VStack(spacing: 0) {
                PanelHead(title: "Auto backup", meta: autoBackupMeta)
                VStack(alignment: .leading, spacing: 12) {
                    Toggle(isOn: $autoBackupEnabled) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Automatic backups")
                                .font(Typo.sans(12, weight: .medium))
                                .foregroundStyle(Color.lInk)
                            Text("Copies the database on launch if the interval has elapsed.")
                                .font(Typo.sans(11))
                                .foregroundStyle(Color.lInk3)
                        }
                    }
                    .toggleStyle(.switch)

                    HStack {
                        Text("Interval")
                            .font(Typo.sans(12, weight: .medium))
                            .foregroundStyle(Color.lInk)
                        Spacer()
                        SegControl<BackupInterval>(
                            options: BackupInterval.allCases.map { ($0.label, $0) },
                            selection: Binding(
                                get: { BackupInterval(rawValue: autoBackupIntervalRaw) ?? .weekly },
                                set: { autoBackupIntervalRaw = $0.rawValue }
                            )
                        )
                    }
                    .disabled(!autoBackupEnabled)
                    .opacity(autoBackupEnabled ? 1 : 0.5)

                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Keep last")
                                .font(Typo.sans(12, weight: .medium))
                                .foregroundStyle(Color.lInk)
                            Text("Auto + pre-restore only. Manual, snapshot-lock, and quit backups have separate retention.")
                                .font(Typo.sans(10.5))
                                .foregroundStyle(Color.lInk3)
                        }
                        Spacer()
                        Stepper(value: $autoBackupKeep, in: 1...50) {
                            Text("\(autoBackupKeep)")
                                .font(Typo.mono(12, weight: .semibold))
                                .foregroundStyle(Color.lInk)
                                .monospacedDigit()
                        }
                        .fixedSize()
                    }

                    Divider().overlay(Color.lLine)

                    HStack(spacing: 8) {
                        GhostButton(action: backupNow) {
                            HStack(spacing: 5) {
                                Image(systemName: "externaldrive.badge.plus").font(.system(size: 10, weight: .bold))
                                Text("Backup now")
                            }
                        }
                        GhostButton(action: pickRestoreFile) {
                            HStack(spacing: 5) {
                                Image(systemName: "arrow.counterclockwise").font(.system(size: 10, weight: .bold))
                                Text("Restore from file…")
                            }
                        }
                        Spacer()
                        if let dir = backupsCache.filesDir {
                            GhostButton(action: {
                                NSWorkspace.shared.activateFileViewerSelecting([dir])
                            }) {
                                HStack(spacing: 5) {
                                    Image(systemName: "folder").font(.system(size: 10, weight: .bold))
                                    Text("Reveal folder")
                                }
                            }
                        }
                    }

                    Divider().overlay(Color.lLine)

                    customFolderRow

                    backupList
                }
                .padding(18)
            }
        }
    }

    private var customFolderRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Custom backup folder")
                        .font(Typo.sans(12, weight: .medium))
                        .foregroundStyle(Color.lInk)
                    Text(customBackupPath.isEmpty
                         ? "Auto-saves on snapshot lock and on app quit. Keeps last 3."
                         : customBackupPath)
                        .font(Typo.sans(11))
                        .foregroundStyle(Color.lInk3)
                        .lineLimit(2)
                        .truncationMode(.middle)
                }
                Spacer()
                GhostButton(action: pickCustomBackupFolder) {
                    HStack(spacing: 5) {
                        Image(systemName: "folder.badge.gearshape").font(.system(size: 10, weight: .bold))
                        Text(customBackupPath.isEmpty ? "Choose…" : "Change…")
                    }
                }
                if !customBackupPath.isEmpty {
                    GhostButton(action: clearCustomBackupFolder) {
                        Text("Clear")
                    }
                }
            }
        }
    }

    private func pickCustomBackupFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.prompt = "Choose"
        panel.title = "Choose backup folder"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let bookmark = try url.bookmarkData(
                options: [.withSecurityScope],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            UserDefaults.standard.set(bookmark, forKey: "customBackupBookmark")
            customBackupPath = url.path
        } catch {
            backupMessage = "Could not save bookmark: \(error.localizedDescription)"
        }
    }

    private func clearCustomBackupFolder() {
        UserDefaults.standard.removeObject(forKey: "customBackupBookmark")
        customBackupPath = ""
    }

    private var autoBackupMeta: String {
        if let last = backupsCache.lastAuto {
            let f = RelativeDateTimeFormatter()
            f.unitsStyle = .short
            return "last auto: \(f.localizedString(for: last, relativeTo: Date()))"
        }
        return autoBackupEnabled ? "no auto backup yet" : "disabled"
    }

    @ViewBuilder
    private var backupList: some View {
        if backupsCache.files.isEmpty {
            Text(backupsCache.loading
                 ? "Loading backups…"
                 : "No backups yet. Automatic backups will appear here after the app launches past the interval.")
                .font(Typo.serifItalic(11))
                .foregroundStyle(Color.lInk3)
        } else {
            VStack(spacing: 0) {
                HStack {
                    Text("RECENT BACKUPS")
                        .font(Typo.eyebrow).tracking(1.2)
                        .foregroundStyle(Color.lInk3)
                    Spacer()
                    Text("\(backupsCache.files.count) total")
                        .font(Typo.sans(11))
                        .foregroundStyle(Color.lInk3)
                }
                .padding(.bottom, 6)
                ForEach(backupsCache.files.prefix(6)) { b in
                    backupRow(b)
                    Divider().overlay(Color.lLine)
                }
            }
        }
    }

    private func backupRow(_ b: BackupService.BackupFile) -> some View {
        HStack(spacing: 10) {
            Image(systemName: b.kind == .auto ? "clock.arrow.circlepath" : "externaldrive")
                .font(.system(size: 11))
                .foregroundStyle(Color.lInk3)
                .frame(width: 16)
            VStack(alignment: .leading, spacing: 1) {
                Text(b.name)
                    .font(Typo.mono(11, weight: .medium))
                    .foregroundStyle(Color.lInk)
                    .lineLimit(1)
                    .truncationMode(.middle)
                HStack(spacing: 6) {
                    Text(b.date, format: .dateTime.year().month().day().hour().minute())
                        .font(Typo.sans(10.5))
                        .foregroundStyle(Color.lInk3)
                    Text("·").foregroundStyle(Color.lInk4)
                    Text(byteString(b.size))
                        .font(Typo.mono(10))
                        .foregroundStyle(Color.lInk3)
                    Text(b.kind == .auto ? "AUTO" : b.kind == .manual ? "MANUAL" : "")
                        .font(Typo.eyebrow).tracking(1.0)
                        .foregroundStyle(Color.lInk3)
                }
                if let res = verifyResults[b.url] {
                    verifySummary(res)
                }
            }
            Spacer(minLength: 8)
            GhostButton(action: { verifyBackup(b.url) }) {
                if verifyingURL == b.url {
                    ProgressView().controlSize(.mini)
                } else {
                    Text("Verify")
                }
            }
            .disabled(verifyingURL != nil)
            GhostButton(action: { pendingRestore = b.url }) { Text("Restore") }
        }
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private func verifySummary(_ res: BackupService.VerifyResult) -> some View {
        if let err = res.error {
            HStack(alignment: .top, spacing: 6) {
                Image(systemName: "xmark.octagon.fill").font(.system(size: 9))
                Text("Verify failed: \(err)")
                    .font(Typo.mono(10))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(Color.lLoss)
            .padding(.top, 2)
        } else {
            HStack(alignment: .top, spacing: 6) {
                Image(systemName: "checkmark.seal.fill").font(.system(size: 9))
                    .foregroundStyle(Color.lGain)
                    .padding(.top, 2)
                Text(verifyText(res))
                    .font(Typo.mono(10))
                    .foregroundStyle(Color.lInk2)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.top, 3)
        }
    }

    private func verifyText(_ r: BackupService.VerifyResult) -> String {
        "People \(r.people) · Accounts \(r.accounts) · Snapshots \(r.snapshots) · Asset values \(r.values) · Asset types \(r.assetTypes) · Countries \(r.countries) · Receivables \(r.receivables) · Receivable values \(r.receivableValues)"
    }

    @MainActor
    private func verifyBackup(_ url: URL) {
        verifyingURL = url
        Task { @MainActor in
            let result = BackupService.verify(url)
            verifyResults[url] = result
            verifyingURL = nil
        }
    }

    private func backupNow() {
        if let url = BackupService.backupNow() {
            backupMessage = "Backup saved: \(url.lastPathComponent)"
            backupsTick &+= 1
        } else {
            backupMessage = "Backup failed."
        }
    }

    private func pickRestoreFile() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [UTType(filenameExtension: "store") ?? .data]
        panel.title = "Choose backup to restore"
        panel.prompt = "Restore"
        panel.directoryURL = backupsCache.filesDir
        guard panel.runModal() == .OK, let url = panel.url else { return }
        pendingRestore = url
    }

    private func performRestore(_ url: URL) {
        do {
            try BackupService.stagePendingRestore(from: url)
            backupMessage = "Restore staged. Quit to apply."
            showingRelaunchAlert = true
        } catch {
            backupMessage = "Restore failed: \(error.localizedDescription)"
        }
    }

    private func byteString(_ bytes: Int64) -> String {
        let f = ByteCountFormatter()
        f.countStyle = .file
        return f.string(fromByteCount: bytes)
    }

    private var exportPanel: some View {
        Panel {
            VStack(spacing: 0) {
                PanelHead(title: "Export")
                VStack(alignment: .leading, spacing: 10) {
                    exportRow(
                        icon: "tablecells",
                        title: "Full history",
                        subtitle: "Flat · all snapshots × accounts"
                    ) {
                        let text = CSVExporter.flatAssetValues(snapshots: snapshots)
                        pendingExport = PendingExport(
                            document: CSVDocument(text: text),
                            defaultFilename: "finance_history_\(datestamp()).csv"
                        )
                    }
                    exportRow(
                        icon: "creditcard",
                        title: "Accounts list",
                        subtitle: "One row per account"
                    ) {
                        let text = CSVExporter.accounts(accounts)
                        pendingExport = PendingExport(
                            document: CSVDocument(text: text),
                            defaultFilename: "finance_accounts_\(datestamp()).csv"
                        )
                    }
                    exportRow(
                        icon: "chart.line.uptrend.xyaxis",
                        title: "Snapshot totals",
                        subtitle: "One row per snapshot"
                    ) {
                        let text = CSVExporter.snapshotTotals(snapshots: snapshots)
                        pendingExport = PendingExport(
                            document: CSVDocument(text: text),
                            defaultFilename: "finance_totals_\(datestamp()).csv"
                        )
                    }
                    exportRow(
                        icon: "hourglass",
                        title: "Receivables history",
                        subtitle: "Pending money owed · all snapshots"
                    ) {
                        let text = CSVExporter.receivables(snapshots: snapshots)
                        pendingExport = PendingExport(
                            document: CSVDocument(text: text),
                            defaultFilename: "finance_receivables_\(datestamp()).csv"
                        )
                    }
                    Divider().overlay(Color.lLine)
                    exportRow(
                        icon: "doc.richtext",
                        title: "Dashboard PDF",
                        subtitle: "Headline, distributions, chart, movers"
                    ) { exportDashboardPDF() }
                }
                .padding(18)
            }
        }
    }

    private var dataPanel: some View {
        Panel {
            VStack(spacing: 0) {
                PanelHead(title: "Data")
                VStack(alignment: .leading, spacing: 12) {
                    if let url = storeURL() {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("DATABASE")
                                .font(Typo.eyebrow).tracking(1.2)
                                .foregroundStyle(Color.lInk3)
                            Text(url.path)
                                .font(Typo.mono(10.5))
                                .foregroundStyle(Color.lInk2)
                                .textSelection(.enabled)
                                .lineLimit(2)
                                .truncationMode(.middle)
                        }
                        HStack(spacing: 8) {
                            GhostButton(action: {
                                NSWorkspace.shared.activateFileViewerSelecting([url])
                            }) {
                                HStack(spacing: 5) {
                                    Image(systemName: "folder").font(.system(size: 10, weight: .bold))
                                    Text("Reveal")
                                }
                            }
                            GhostButton(action: backupDatabase) {
                                HStack(spacing: 5) {
                                    Image(systemName: "externaldrive.badge.plus").font(.system(size: 10, weight: .bold))
                                    Text("Backup")
                                }
                            }
                            Spacer()
                            GhostButton(action: { confirmingReset = true }) {
                                HStack(spacing: 5) {
                                    Image(systemName: "trash").font(.system(size: 10, weight: .bold))
                                    Text("Reset…")
                                }
                            }
                        }
                    }
                    if let msg = backupMessage {
                        Text(msg)
                            .font(Typo.serifItalic(12))
                            .foregroundStyle(Color.lInk3)
                    }
                }
                .padding(18)
            }
        }
    }

    private var fxRatePanel: some View {
        FXRateHistoryPanel(snapshots: snapshots)
    }

    private var remindersPanel: some View {
        Panel {
            VStack(spacing: 0) {
                PanelHead(title: "Reminders")
                VStack(alignment: .leading, spacing: 10) {
                    Toggle(isOn: Binding(
                        get: { reminderEnabled },
                        set: { newValue in
                            reminderEnabled = newValue
                            ReminderScheduler.applyPreference(enabled: newValue, context: context)
                        }
                    )) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Quarterly update reminder")
                                .font(Typo.sans(12, weight: .medium))
                                .foregroundStyle(Color.lInk)
                            Text("Fires when last snapshot is older than 90 days.")
                                .font(Typo.sans(11))
                                .foregroundStyle(Color.lInk3)
                        }
                    }
                    .toggleStyle(.switch)
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // MARK: - Row helpers

    @ViewBuilder
    private func settingRow<Control: View>(label: String, sublabel: String? = nil, @ViewBuilder control: () -> Control) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(Typo.sans(12, weight: .medium))
                    .foregroundStyle(Color.lInk)
                if let sublabel {
                    Text(sublabel)
                        .font(Typo.sans(10.5))
                        .foregroundStyle(Color.lInk3)
                }
            }
            Spacer()
            control()
        }
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private var importPanel: some View {
        Panel {
            VStack(spacing: 0) {
                PanelHead(title: "Import", meta: "CSV · history or accounts")
                VStack(alignment: .leading, spacing: 10) {
                    Text("Merges a Full history or Accounts list CSV export back into the local store. Format is auto-detected. Existing snapshots, accounts, people, countries, and types are matched and not duplicated.")
                        .font(Typo.sans(11.5))
                        .foregroundStyle(Color.lInk3)
                        .lineSpacing(2)
                    exportRow(
                        icon: "square.and.arrow.down",
                        title: "Import CSV…",
                        subtitle: "Full history or Accounts list export",
                        actionLabel: "Import"
                    ) { showingImportPicker = true }
                }
                .padding(18)
            }
        }
    }

    @MainActor
    private func performImport(_ url: URL) {
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }
        do {
            let text = try String(contentsOf: url, encoding: .utf8)
            let report = try CSVImporter.importAuto(csv: text, context: context)
            importIsError = false
            importResult = report.summary
        } catch {
            importIsError = true
            importResult = error.localizedDescription
        }
    }

    private func exportRow(icon: String, title: String, subtitle: String, actionLabel: String = "Export", action: @escaping () -> Void) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(Color.lInk2)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Typo.sans(12.5, weight: .medium))
                    .foregroundStyle(Color.lInk)
                Text(subtitle)
                    .font(Typo.sans(11))
                    .foregroundStyle(Color.lInk3)
            }
            Spacer()
            GhostButton(action: action) { Text(actionLabel) }
        }
    }

    // MARK: - Helpers

    private func datestamp() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }

    private func storeURL() -> URL? {
        guard let appSupport = try? FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask,
            appropriateFor: nil, create: false
        ) else { return nil }
        return appSupport.appendingPathComponent("default.store")
    }

    private func backupDatabase() {
        try? context.save()
        guard let src = storeURL(), FileManager.default.fileExists(atPath: src.path) else {
            backupMessage = "Database file not found."
            return
        }
        let panel = NSSavePanel()
        panel.title = "Backup Database"
        panel.nameFieldStringValue = "QuietFinance-backup-\(datestamp()).store"
        panel.allowedContentTypes = [UTType(filenameExtension: "store") ?? .data]
        guard panel.runModal() == .OK, let dest = panel.url else { return }
        do {
            if FileManager.default.fileExists(atPath: dest.path) {
                try FileManager.default.removeItem(at: dest)
            }
            try FileManager.default.copyItem(at: src, to: dest)
            let wal = src.appendingPathExtension("wal")
            let shm = src.appendingPathExtension("shm")
            if FileManager.default.fileExists(atPath: wal.path) {
                try? FileManager.default.copyItem(at: wal, to: dest.appendingPathExtension("wal"))
            }
            if FileManager.default.fileExists(atPath: shm.path) {
                try? FileManager.default.copyItem(at: shm, to: dest.appendingPathExtension("shm"))
            }
            backupMessage = "Backed up to \(dest.lastPathComponent)."
        } catch {
            backupMessage = "Backup failed: \(error.localizedDescription)"
        }
    }

    @MainActor
    private func exportDashboardPDF() {
        let result = DashboardPDFExporter.export(
            snapshots: Array(snapshots),
            displayCurrency: app.displayCurrency,
            activeSnapshotID: app.activeSnapshotID,
            theme: app.theme
        )
        switch result {
        case .exported(let msg): backupMessage = msg
        case .failed(let msg):   backupMessage = msg
        case .cancelled:         break
        }
    }

    private func resetAllData() {
        deleteAll(AssetValue.self)
        deleteAll(Snapshot.self)
        deleteAll(Account.self)
        deleteAll(AssetType.self)
        deleteAll(Country.self)
        deleteAll(Person.self)
        deleteAll(ExchangeRateHistory.self)
        try? context.save()
        SeedData.seedIfEmpty(context: context)
        try? context.save()
        backupMessage = "Reset complete. Sample data re-seeded."
    }

    private func deleteAll<T: PersistentModel>(_ type: T.Type) {
        let fd = FetchDescriptor<T>()
        if let items = try? context.fetch(fd) {
            for item in items { context.delete(item) }
        }
    }
}

private struct CategoryColorRow: View {
    let category: AssetCategory
    @State private var color: Color = .gray

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(color)
                .frame(width: 12, height: 12)
                .overlay(Circle().stroke(Color.lLine, lineWidth: 0.5))
            Text(category.rawValue)
                .font(Typo.sans(12.5, weight: .medium))
                .foregroundStyle(Color.lInk)
            Spacer()
            ColorPicker("", selection: Binding(
                get: { color },
                set: { newColor in
                    color = newColor
                    CategoryColorStore.setHex(newColor.toHex(), for: category)
                }
            ), supportsOpacity: false)
            .labelsHidden()
        }
        .onAppear { color = Palette.color(for: category) }
    }
}

@MainActor
final class BackupsCache: ObservableObject {
    @Published var files: [BackupService.BackupFile] = []
    @Published var filesDir: URL?
    @Published var lastAuto: Date?
    @Published var loading: Bool = false
    private var loaded: Bool = false

    func loadIfNeeded() async {
        guard !loaded else { return }
        await refresh()
    }

    func refresh() async {
        if files.isEmpty { loading = true }
        let payload = await Task.detached(priority: .utility) { () -> ([BackupService.BackupFile], URL?, Date?) in
            (BackupService.list(), BackupService.backupsDir(), BackupService.lastAutoBackupDate())
        }.value
        files = payload.0
        filesDir = payload.1
        lastAuto = payload.2
        loading = false
        loaded = true
    }
}


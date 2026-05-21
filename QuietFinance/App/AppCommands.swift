import SwiftUI
import SwiftData

// MARK: - Focused values

private struct AppStateKey: FocusedValueKey {
    typealias Value = AppState
}

private struct UndoStashKey: FocusedValueKey {
    typealias Value = UndoStash
}

private struct ModelContextKey: FocusedValueKey {
    typealias Value = ModelContext
}

private struct RestoreDeleteKey: FocusedValueKey {
    typealias Value = () -> Void
}

extension FocusedValues {
    var appState: AppState? {
        get { self[AppStateKey.self] }
        set { self[AppStateKey.self] = newValue }
    }
    var undoStash: UndoStash? {
        get { self[UndoStashKey.self] }
        set { self[UndoStashKey.self] = newValue }
    }
    var sceneModelContext: ModelContext? {
        get { self[ModelContextKey.self] }
        set { self[ModelContextKey.self] = newValue }
    }
    var restoreDelete: (() -> Void)? {
        get { self[RestoreDeleteKey.self] }
        set { self[RestoreDeleteKey.self] = newValue }
    }
}

// MARK: - Commands

struct NavCommands: Commands {
    @FocusedValue(\.appState) var app

    var body: some Commands {
        CommandMenu("Go") {
            navItem("Dashboard",    .dashboard,  "1")
            navItem("Allocation",   .breakdown,  "2")
            navItem("Trends",       .trends,     "3")
            navItem("Snapshots",    .snapshots,  "4")
            Button("Diff") { app?.selectedScreen = .diff }
                .keyboardShortcut("d", modifiers: [.command, .shift])
                .disabled(app == nil)
            navItem("Accounts",     .accounts,   "5")
            navItem("People",       .people,     "6")
            navItem("Countries",    .countries,  "7")
            navItem("Asset Types",  .assetTypes, "8")
            navItem("Settings",     .settings,   "9")
        }
    }

    @ViewBuilder
    private func navItem(_ label: String, _ screen: Screen, _ key: String) -> some View {
        Button(label) { app?.selectedScreen = screen }
            .keyboardShortcut(KeyEquivalent(Character(key)), modifiers: .command)
            .disabled(app == nil)
    }
}

struct SnapshotCommands: Commands {
    @FocusedValue(\.appState) var app

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New Snapshot") {
                app?.selectedScreen = .snapshots
                app?.newSnapshotRequested = true
            }
            .keyboardShortcut("n", modifiers: .command)
            .disabled(app == nil)
        }
    }
}

struct SearchCommands: Commands {
    @FocusedValue(\.appState) var app

    var body: some Commands {
        CommandGroup(after: .textEditing) {
            Button("Find") { app?.globalSearchFocusTick &+= 1 }
                .keyboardShortcut("f", modifiers: .command)
                .disabled(app == nil)
            Button("Quick Jump") { app?.globalSearchFocusTick &+= 1 }
                .keyboardShortcut("p", modifiers: .command)
                .disabled(app == nil)
        }
    }
}

struct UndoDeleteCommands: Commands {
    @FocusedValue(\.undoStash) var undo
    @FocusedValue(\.restoreDelete) var restore

    var body: some Commands {
        CommandGroup(replacing: .undoRedo) {
            Button("Undo Delete") { restore?() }
                .keyboardShortcut("z", modifiers: .command)
                .disabled(undo?.pending == nil || restore == nil)
        }
    }
}

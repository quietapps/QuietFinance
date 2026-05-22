# CLAUDE.md — Quiet Finance

Context for AI assistants and contributors working in this repo. For agent workflow, licensing reminders, and changelog hygiene, see **`AGENTS.md`**. Cursor loads extra rules from **`.cursor/rules/*.mdc`**.

## What this is

**Quiet Finance** is a **native macOS** app: **SwiftUI** UI, **SwiftData** persistence, **100% local** (no bundled cloud sync). Users track net worth through dated **snapshots** of account balances (and **receivables**), with USD/INR conversion and charts.

## Build and run

- Open **`QuietFinance.xcodeproj`** at the repo root.
- Target **My Mac**. Swift language version is set in the project (Swift 5.x).
- **Sandbox**: the app expects user-selected file read/write (exports, backups) and outgoing network (FX). Match entitlements to feature work.
- Entry: `QuietFinance/App/QuietFinanceApp.swift` — constructs `ModelContainer`, registers schema, runs `SeedData.seedIfEmpty`, `BackupService`, `ReminderScheduler`.

## Architecture (mental model)

| Piece | Role |
|--------|------|
| `AppState` | `ObservableObject`: `@AppStorage` prefs, `selectedScreen` (`Screen` enum), active snapshot id, theme, chart styles |
| `UndoStash` | Soft-delete restore path; exposed via environment and menu commands |
| `RootView` | `NavigationSplitView`-style shell: `Sidebar` + `TopBar` + screen switcher; injects `focusedSceneValue` keys for commands |
| SwiftData `@Model` types | Source of truth; views use `@Query` / `@Environment(\.modelContext)` |
| `BackupService` | Store URL, manual/auto/quit backups, optional restore |
| `FXService` / `CurrencyConverter` | frankfurter.app rates; respects snapshot date and lock rules in UI flows |
| `CSVExporter` / `CSVImporter` | Data interchange (exporter includes receivable columns where applicable) |

New screens: add a `Screen` case in `AppState.swift`, handle it in `RootView.content`, and add sidebar + `NavCommands` entries if user-navigable.

## Schema changes

1. Add or edit `@Model` types under `QuietFinance/Models/`.
2. Register every model in **`Schema([...])`** in `QuietFinanceApp.init()` — omission causes runtime issues.
3. Update **seed** / **import-export** if the feature is user-visible in those paths.
4. Prefer additive attributes for SwiftData auto-migration; plan manual migration if you make breaking changes.

## UI conventions

- Shared styling: `Utils/Theme.swift`, `Views/Shared/Primitives.swift`.
- **Compact mode** propagates via `environment(\.compactMode, ...)`.
- Window chrome: theme applied per-window in `QuietFinanceApp` using `NSAppearance` for light/dark/system.
- Keyboard shortcuts and menus: `App/AppCommands.swift` — relies on `FocusedValues` set from `RootView`.

## Product rules (do not accidental regress)

- **Locked snapshots** must stay immutable for rates and stored values in user flows that respect lock.
- **FX fetch** must not overwrite locked snapshot data.
- Preserve **cascade delete** semantics and any user-facing delete confirmations already in manage views.

## Testing

There is **no** XCTest target in-tree as of this writing; verify changes by running the app and exercising the relevant screen + Settings (exports, backup path).

## Files worth reading first

- `QuietFinanceApp.swift` — app lifecycle, schema list
- `ViewModels/AppState.swift` — navigation + prefs
- `Views/RootView.swift` — screen routing
- `Models/Snapshot.swift` — snapshot + `ExchangeRateHistory`
- `Utils/BackupService.swift` — persistence paths and safety nets

## Bundle identifier

Project setting: **`app.quiet.QuietFinance`** (used for sandbox container paths). Change only with awareness of user data location.

## App icon

Icons follow the **Quiet Apps icon standard** for macOS 26 Tahoe compatibility:

- **Canvas:** 1024×1024 px transparent PNG
- **Outer padding:** 9% transparent on all sides → artwork in center 82%. Outer ring fully transparent — Dock composites it at correct visual weight alongside system icons.
- **Squircle shape:** true superellipse (n=5), NOT `CGPath(roundedRect:)`. Corner radius ≈ 22% of art area width (~188px on an 840×840 art area).
- **Background fill:** fills the squircle only — never the full 1024px canvas.

Reference implementation: `scripts/GenerateIcon.swift` → `squirclePath(in:exponent:)` with `exponent: 5.0` and `pad: 0.09`.

## Commit conventions

- Never include `Co-Authored-By: Claude` or any AI authorship trailer in commit messages.

## License

The project is proprietary; see **`LICENSE`** in the repo root. No use or repurposing without written approval from the copyright holder.

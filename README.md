# Quiet Finance

Offline personal wealth tracker for **macOS**. Built with **SwiftUI** and **SwiftData**. Everything stays on your machine — no cloud service, no subscription, and no Apple Developer Program account is required to build and run locally.

Supports multiple people, countries, and currencies (notably **USD** and **INR**). Net worth is tracked through **snapshots** (point-in-time records) with charts-first navigation.

---

## Features (high level)

| Area | What it does |
|------|----------------|
| **Dashboard** | Hero net worth with embedded sparkline + inline delta chip, compare bar (vs Previous / Year ago), customizable widgets, Goal progress + ETA, Liquidity / runway, KPI cards, allocation breakdowns, movers, history, **Watchlist of pinned accounts** |
| **Allocation (Breakdown)** | Treemap, stacked bars, filters, accounts table with % of total; cross-link from Dashboard slices |
| **Trends** | Time-series with hover tooltips, range filters, **forecast panel** (Linear / CAGR with ±1σ band) |
| **Snapshots** | List, create, lock/unlock, edit per-account values with live totals and deltas; **completeness badge**, **pinned snapshot tabs**, missing-row highlights, stale-account flag |
| **Diff** (`⌘⇧D`) | Snapshot diff between two dates, with **Money Flow** Sankey visual of where value moved per account |
| **Reports** | Period compare, **QoQ heatmap** (quarters × categories), CAGR & monthly drift, asset-type drilldown |
| **Manage** | Inline-edit grids for **people** (name, color, "In NW" toggle, quick-add row), countries, asset types, **accounts** (optional cost basis + Unrealized column, **drag-reorder**, **pin to watchlist**, **multi-select with Bulk Edit and Account Merge**), and **receivables** (money owed to you, with start dates) |
| **Grids** | **Sortable column headers** on every grid (ASC → DESC → unsorted, persisted), resizable columns |
| **Import / Export** | CSV export of full history, accounts list, snapshot totals, receivables; **auto-detecting CSV import** that handles both Full history and Accounts list (creates or updates existing accounts) |
| **Settings** | Display, **App icon** picker (Quiet Finance · Classic · Vault · Strata), **Dashboard widgets** show/hide/reorder, category colors, FX, backups, reminders, **Security** (App lock + **Auto-lock when idle** + Stealth mode + Menu bar item) |
| **Productivity** | **⌘K command palette**, **recently viewed** list (deleted entries dimmed and struck through), search jumps directly into editors, three-level breadcrumb |
| **Privacy** | **App lock** on launch (Touch ID / Apple Watch / system password) with **idle auto-lock**, **Stealth mode** to blur amounts |

**FX**: Live **USD→INR** fetch via [frankfurter.app](https://www.frankfurter.app/) (no API key). Rates can be pinned per snapshot; locked snapshots are not rewritten.

**Data safety**: Manual and automatic SQLite backups, optional restore on launch, quit-time backup hook, snapshot pre-caching for fast renders.

---

## Data model (SwiftData)

Core entities:

- `Person`, `Country`, `AssetType`, `Account`, `Snapshot`, `AssetValue`
- `Receivable`, `ReceivableValue` — receivables and their per-snapshot balances
- `ExchangeRateHistory` — cached FX history

Asset categories (see `Enums.swift`): Cash, Investment, Retirement, Crypto, Insurance, Debt.

---

## Requirements

- **macOS** matching the project’s deployment target (see **Xcode → target → General → Minimum Deployments**; currently set in the project to a recent macOS SDK).
- **Xcode** with Swift 5 (project uses Swift 5.0 setting).

---

## Run from source

1. Install **Xcode** from the Mac App Store and open it once to accept the license.
2. Open **`QuietFinance.xcodeproj`** at the repository root.
3. **Signing**: for local runs, you can use **Sign to Run Locally** or **Team: None** as appropriate for your machine.
4. **App Sandbox** (typical for this app):
   - **User Selected File** → **Read/Write** (CSV/PDF save panels, backups).
   - **Outgoing Connections (Client)** (FX fetch).
5. Select the **My Mac** destination and press **⌘R**.

On first launch with an empty store, **`SeedData`** inserts sample people, countries, asset types, accounts, and snapshots.

---

## Repository layout

```
QuietFinance.xcodeproj/     Xcode project
QuietFinance/
  App/                       App entry, model container, window commands, delegates
  Models/                    SwiftData @Model types, enums, seed data
  ViewModels/                AppState (global UI prefs + navigation)
  Views/                     Screens: Dashboard, Breakdown, Trends, Snapshots, …
  Utils/                     FX, CSV, PDF, backups, formatters, theme, undo stash
  Assets.xcassets/           App icons and colors
```

---

## Where data lives

Sandboxed installs store the SQLite file under the app’s container, for example:

`~/Library/Containers/app.quiet.QuietFinance/Data/Library/Application Support/default.store`

Use **Settings** to reveal the path, run **Backup database**, or copy the `.store` (and associated `-wal`/`-shm` if present when the app is quit).

Bundle identifier is defined in Xcode as **`app.quiet.QuietFinance`** — if you change it, the container path changes accordingly.

---

## Export

- **CSV**: Full history, accounts list, snapshot totals, and **receivable rows** per snapshot (see `CSVExporter`).
- **PDF**: Dashboard snapshot via `DashboardPDFExporter`; snapshot-detail PDF via `SnapshotPDFExporter`.

---

## Stack notes

- **SwiftData** on SQLite. Lightweight schema tweaks often auto-migrate; there is no custom migration versioning layer in-repo.
- **@AppStorage** for many UI preferences; **UserDefaults** for some overrides (e.g. category colors).
- **Swift Charts** for donut, line, area, and bar visuals.
- **Local notifications** for stale snapshot reminders (`ReminderScheduler`).
- Menu commands wire through **`focusedSceneValue`** for `AppState`, `UndoStash`, and `ModelContext` (see `AppCommands.swift` and `RootView`).

---

## Sharing a release build

1. Scheme → **Run** → **Build Configuration**: Release (for a lean binary).
2. **Product → Archive**, then distribute (e.g. **Copy App**).

Unsigned builds trigger **Gatekeeper** warnings on other Macs until the user uses **Right-click → Open** or adjusts **Privacy & Security**. Notarized distribution requires a paid Apple Developer account.

**Wrap in a DMG (quick `hdiutil` example)**

```bash
mkdir QuietFinance-dmg
cp -R QuietFinance.app QuietFinance-dmg/
ln -s /Applications QuietFinance-dmg/Applications
hdiutil create -volname "QuietFinance" -srcfolder QuietFinance-dmg -ov -format UDZO QuietFinance.dmg
rm -rf QuietFinance-dmg
```

**Pretty (create-dmg):**
```bash
brew install create-dmg
create-dmg --volname "QuietFinance" --window-size 500 300 \
  --icon "QuietFinance.app" 120 120 \
  --app-drop-link 380 120 \
  QuietFinance.dmg QuietFinance.app
```

### Friend's First Launch (unsigned = Gatekeeper warning)
1. Open DMG → drag app to Applications.
2. **Right-click app → Open** → confirm dialog.
3. If still blocked (Sequoia+): **System Settings → Privacy & Security** → scroll to "was blocked" → **Open Anyway**.
4. CLI fallback: `xattr -cr /Applications/QuietFinance.app`.

Unsigned path is free but shows "unidentified developer" warning. Clean distribution requires $99/yr Apple Developer account + notarization.

---

## Troubleshooting

| Symptom | Check |
|---------|--------|
| Save panel / export failures | Sandbox **User Selected File** must allow **Read/Write** |
| FX never updates | Sandbox **Outgoing Connections (Client)** |
| No reminder notifications | **System Settings → Notifications** for the app |
| Wrong data folder after fork | Bundle ID / container path (see above) |

---

## License

Proprietary — **all rights reserved**. Use, redistribution, modification, derivative works, and repurposing are **not** permitted without **written approval** from the copyright holder. See [`LICENSE`](LICENSE).

## Changelog

Release notes are in [`CHANGELOG.md`](CHANGELOG.md).

## AI assistants

[`AGENTS.md`](AGENTS.md) summarizes how agents should work in this repo; [`CLAUDE.md`](CLAUDE.md) has deeper technical context. Cursor loads rules from **`.cursor/rules/`**.

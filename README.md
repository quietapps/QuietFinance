<div align="center">

<img src="QuietFinance/Assets.xcassets/AppIcon.appiconset/icon_512x512.png" alt="Quiet Finance" width="128" height="128" />

# Quiet Finance

**Track your net worth. Offline. No subscriptions. No cloud.**

A native macOS app that tracks net worth through dated snapshots of account balances — with charts, FX conversion, and privacy controls, all stored locally on your machine. Part of the [Quiet Apps](https://github.com/quietapps) family.

[![macOS](https://img.shields.io/badge/macOS-26.0+-000000?logo=apple&logoColor=white)](https://www.apple.com/macos/)
[![Swift](https://img.shields.io/badge/Swift-5.9-F05138?logo=swift&logoColor=white)](https://swift.org)
[![SwiftUI](https://img.shields.io/badge/SwiftUI-SwiftData-2396F3?logo=swift&logoColor=white)](https://developer.apple.com/xcode/swiftui/)
[![License: Proprietary](https://img.shields.io/badge/License-Proprietary-red.svg)](LICENSE)
[![Release](https://img.shields.io/github/v/release/quietapps/QuietFinance?display_name=tag)](https://github.com/quietapps/QuietFinance/releases)
[![Downloads](https://img.shields.io/github/downloads/quietapps/QuietFinance/total.svg)](https://github.com/quietapps/QuietFinance/releases)
[![Stars](https://img.shields.io/github/stars/quietapps/QuietFinance?style=social)](https://github.com/quietapps/QuietFinance/stargazers)

[Install](#install) · [Features](#features) · [Build from source](#build-from-source) · [Data & Exports](#data--exports) · [FAQ](#faq)

</div>

---

## Install

### Homebrew (recommended)

```bash
brew tap quietapps/quietfinance
brew install --cask quietfinance
```

**Update:**
```bash
brew update && brew upgrade --cask quietfinance
```

**Uninstall:**
```bash
brew uninstall --cask quietfinance
brew untap quietapps/quietfinance
```

> Quiet Finance is distributed unsigned. The Homebrew cask strips the Gatekeeper quarantine attribute automatically. If the app refuses to launch after a manual install, run `xattr -cr "/Applications/Quiet Finance.app"` once in Terminal.

### Manual

Download the latest ZIP from [Releases](https://github.com/quietapps/QuietFinance/releases), unzip, and drag **Quiet Finance.app** to `/Applications`. If Gatekeeper blocks launch: right-click → Open → confirm, or run `xattr -cr "/Applications/Quiet Finance.app"`.

---

## Why

Every finance app wants your bank login, a monthly fee, or both. Quiet Finance wants neither. Snapshots are point-in-time records of what each account is worth — enter them manually, see a chart, understand your trajectory. USD↔INR FX is fetched live but never rewrites a locked snapshot. Nothing leaves your machine.

## Features

### Dashboard
- Hero net worth with embedded sparkline and inline delta chip
- Compare bar (vs Previous / Year ago)
- Customizable widgets: Goal progress + ETA, Liquidity / runway, KPI cards, allocation breakdowns, movers, history
- **Watchlist** of pinned accounts surfaced inline

### Allocation & Trends
- **Breakdown** — Treemap, stacked bars, filters, accounts table with % of total; cross-link from Dashboard slices
- **Trends** — Time-series with hover tooltips, range filters, **forecast panel** (Linear / CAGR with ±1σ band)

### Snapshots
- Create, lock/unlock, edit per-account values with live totals and deltas
- Completeness badge, pinned snapshot tabs, missing-row highlights, stale-account flag
- **Diff** (`⌘⇧D`) — compare two dates with a **Money Flow** Sankey visual of where value moved

### Reports
- Period compare, **QoQ heatmap** (quarters × categories), CAGR & monthly drift, asset-type drilldown

### Manage
- Inline-edit grids for people, countries, asset types, and accounts
- Optional cost basis + Unrealized column per account
- **Drag-reorder**, **pin to watchlist**, **multi-select with Bulk Edit and Account Merge**
- **Receivables** — money owed to you, with start dates and per-snapshot balances

### Import / Export
- CSV export: full history, accounts list, snapshot totals, receivables
- **Auto-detecting CSV import** handles both Full history and Accounts list formats (creates or updates existing accounts)
- PDF export: Dashboard snapshot and snapshot-detail reports

### Privacy & Security
- **App lock** on launch (Touch ID / Apple Watch / system password)
- **Idle auto-lock** with configurable timeout
- **Stealth mode** — blurs all amounts when active
- **Menu bar item** for quick access without exposing the main window

### Productivity
- **⌘K command palette** for instant navigation
- **Recently viewed** list with dimmed deleted entries
- Sortable + resizable column headers on every grid, persisted across sessions
- Three-level breadcrumb and search that jumps directly into editors

### App icon picker
Settings → **App icon** — choose from Quiet Finance, Classic, Vault, or Strata. Switches the Dock + App Switcher icon live.

### FX
Live **USD↔INR** fetch via [frankfurter.app](https://www.frankfurter.app/) (no API key required). Rates are pinned per snapshot; locked snapshots are never rewritten.

### Data safety
Manual and automatic SQLite backups, optional restore on launch, quit-time backup hook, snapshot pre-caching for fast renders.

---

## Build from source

### Requirements
- macOS 26.0 or later
- Xcode 16.0 or later

### Steps

```bash
git clone <repo-url>
cd QuietFinance
open QuietFinance.xcodeproj
```

**Signing** — for local runs, use **Sign to Run Locally** or **Team: None** as appropriate.

**Sandbox entitlements** needed:
- **User Selected File → Read/Write** (CSV/PDF save panels, backups)
- **Outgoing Connections (Client)** (FX fetch)

Select the **My Mac** destination and press **⌘R**.

On first launch with an empty store, `SeedData` inserts sample people, countries, asset types, accounts, and snapshots.

### Project layout

```
QuietFinance.xcodeproj/
QuietFinance/
├── App/             # App entry, model container, window commands, delegates
├── Models/          # SwiftData @Model types, enums, seed data
├── ViewModels/      # AppState (global UI prefs + navigation)
├── Views/           # Screens: Dashboard, Breakdown, Trends, Snapshots, …
└── Utils/           # FX, CSV, PDF, backups, formatters, theme, undo stash
```

### Stack

- **SwiftData** on SQLite. Lightweight schema tweaks auto-migrate; no custom migration layer.
- **@AppStorage** for UI preferences; **UserDefaults** for category color overrides.
- **Swift Charts** for donut, line, area, and bar visuals.
- **Local notifications** for stale snapshot reminders (`ReminderScheduler`).
- Menu commands wire through **`focusedSceneValue`** (`AppCommands.swift`, `RootView`).

---

## Data & Exports

### Where data lives

Sandboxed installs store the SQLite file at:

```
~/Library/Containers/app.quiet.QuietFinance/Data/Library/Application Support/default.store
```

Use **Settings → Backup** to reveal the path, run a manual backup, or copy the `.store` (and `-wal`/`-shm` files if the app is running) to a safe location.

### Data model

Core entities: `Person`, `Country`, `AssetType`, `Account`, `Snapshot`, `AssetValue`, `Receivable`, `ReceivableValue`, `ExchangeRateHistory`.

Asset categories: Cash, Investment, Retirement, Crypto, Insurance, Debt.

### Export formats

- **CSV** — Full history, accounts list, snapshot totals, receivable rows per snapshot (`CSVExporter`)
- **PDF** — Dashboard snapshot (`DashboardPDFExporter`), snapshot-detail (`SnapshotPDFExporter`)

---

## Configuration

Settings live in `UserDefaults` (container-scoped). Reset everything with:

```bash
defaults delete app.quiet.QuietFinance
```

---

## Uninstalling

**If installed via Homebrew** (recommended — handles app + quarantine cleanup):
```bash
brew uninstall --cask quietfinance
brew untap quietapps/quietfinance
```

**Manual removal:**
```bash
rm -rf "/Applications/Quiet Finance.app"
```

**Remove all user data** (settings, caches, container):
```bash
defaults delete app.quiet.QuietFinance 2>/dev/null
rm -rf ~/Library/Containers/app.quiet.QuietFinance \
       ~/Library/Preferences/app.quiet.QuietFinance.plist \
       ~/Library/Caches/app.quiet.QuietFinance \
       ~/Library/Saved\ Application\ State/app.quiet.QuietFinance.savedState
```

> **Warning:** Deleting `~/Library/Containers/app.quiet.QuietFinance` removes all your financial data, backups, and settings permanently. Export a CSV backup first from **Settings → Export** if you want to preserve your history.

---

## Distributing a build

1. Scheme → **Run** → **Build Configuration: Release**.
2. **Product → Archive**, then **Distribute → Copy App**.

Unsigned builds trigger Gatekeeper on other Macs. Recipient steps:

1. Drag app to `/Applications`.
2. **Right-click → Open** → confirm dialog.
3. If still blocked: **System Settings → Privacy & Security → Open Anyway**.
4. CLI fallback: `xattr -cr "/Applications/Quiet Finance.app"`.

Notarized distribution requires a paid Apple Developer account ($99/yr).

---

## FAQ

**Does it sync to iCloud or any server?**
No. Everything stays in your Mac's sandbox container. FX rates are the only outbound network call, and only when you explicitly refresh them.

**What happens if I lock a snapshot?**
Locked snapshots are immutable — FX fetches and manual edits are blocked for locked entries. Unlock first if you need to change values.

**Save panels or export failing?**
Sandbox entitlement **User Selected File → Read/Write** must be enabled. Check Xcode → target → Signing & Capabilities.

**FX rates never update?**
Sandbox entitlement **Outgoing Connections (Client)** must be enabled.

**No reminder notifications?**
Open **System Settings → Notifications** and allow notifications for Quiet Finance.

**Wrong data folder after changing bundle ID?**
The container path is tied to the bundle identifier (`app.quiet.QuietFinance`). Changing it creates a new empty container. Export your data before changing it.

**How do I back up my data?**
Settings → Backup → **Back Up Now**. The app also backs up automatically on quit. You can copy the `.store` file directly for a manual snapshot.

---

## Changelog

Release notes are in [`CHANGELOG.md`](CHANGELOG.md).

## AI assistants

[`AGENTS.md`](AGENTS.md) summarizes agent workflow conventions for this repo. [`CLAUDE.md`](CLAUDE.md) has deeper technical context. Cursor loads rules from **`.cursor/rules/`**.

---

## License

Proprietary — **all rights reserved**. Use, redistribution, modification, derivative works, and repurposing are **not** permitted without written approval from the copyright holder. See [`LICENSE`](LICENSE).

---

<div align="center">
If Quiet Finance helps you understand your money, you're already ahead.
</div>

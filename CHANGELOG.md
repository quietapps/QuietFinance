# Changelog

All notable changes to **QuietFinance** (Quiet Finance) are documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).  
Version headings match **semver** derived from **`git log`** (newest-first). Xcode **`MARKETING_VERSION`** reads the same numeric line (e.g. `2.4` ≡ `2.4.0`); **`CURRENT_PROJECT_VERSION`** is the **build**.

## [Unreleased]

---

## [3.0.0] - 2026-05-21

### Added

- **Keyboard-first snapshot creation** — Return advances focus to the next account field in the snapshot editor; hint text shows the shortcut. ⌘S saves draft without lifting hands from keyboard.
- **Snapshot share card** — "Copy card" button in the snapshot editor header renders a branded PNG (net worth, delta pill, date) and copies it to the clipboard. Ready to paste into any chat or doc.
- **Anomaly flag on Dashboard** — statistical outlier detection (≥2σ from trailing mean of consecutive % deltas). A banner on the hero widget surfaces unusual jumps or drops with the magnitude in sigmas.
- **Year in review panel** — trailing-12-month summary sheet: net change + %, highest net worth snapshot, best and worst quarter, biggest mover account. Accessible from the Dashboard hero widget.
- **Breakeven calculator in Goal panel** — when a goal target date is set, a "Monthly needed" stat shows the savings rate required to reach the goal by the deadline.
- **Modern design system** — a refreshed visual layer built on the Quiet Apps design tokens (cool neutral palette, Quiet Blue `#1E88E5` accent, Geist Mono numerics, 14px card radius, layered shadows). New design is the default for all users; existing design is preserved as **Classic**.
- **Design switcher in Settings** — Settings → App design lets users toggle between New and Classic with visual preview swatches and an "Active" badge. Switching is instant and does not affect any data or functionality.

### Changed

- **Classic icon redesigned and set as default** — new brand-blue gradient (#3D93D8→#0E4E8A) with ascending snapshot bars and a glow dot. All AppIcon sizes regenerated from source. Fresh installs and existing users who had Dusk migrate automatically; existing custom choices are preserved.
- **Vault icon redesigned** — distinct dark ink gradient (#222436→#0B0D11) with a concentric arc / timeline motif. True n=5 superellipse, matches Quiet Apps icon standard.
- **Strata icon redesigned** — distinct cool slate gradient (#23303F→#0D111A) with left-aligned horizontal allocation bars. True n=5 superellipse, matches Quiet Apps icon standard.
- **All icons standardised** — switched from `CGPath(roundedRect:)` to a true parametric n=5 superellipse with 9% transparent safe-area ring, matching the Quiet Apps macOS 26 icon standard across Classic, Vault, and Strata.
- **Settings layout** — display and UI panels (App design, Display, App icon, Dashboard widgets, Category colors, FX rate) on the left; system panels (Security, Reminders, Auto backup, Export, Import, Data) on the right. Both columns center-aligned in the content area.
- **PDF export logo** — Dashboard PDF header now renders the current app icon instead of the legacy "L" placeholder glyph.
- **Trajectory chart fill** — area fill in the net worth trajectory chart (Dashboard and Trends) uses Quiet Blue in modern mode and the ink color in classic mode, replacing the near-white slab that appeared in dark mode.

### Fixed

- SwiftUI "Publishing changes from within view updates" warning in Sidebar — selection binding now defers the mutation with `DispatchQueue.main.async`.
- PDF export crash (`No ObservableObject of type AppState found`) — stealth mode modifier converted from `@EnvironmentObject` to `@Environment` key with a safe default; `ImageRenderer` isolation no longer triggers a fatal error.
- Design switch crash when sheets were open — removed `.id(app.useModernDesign)` from the detail stack; design changes propagate through environment without destroying the view subtree.

---

## [2.6.0] (1) - 2026-05-21

### Changed

- **App renamed to Quiet Finance** — product name, bundle identifier (`app.quiet.QuietFinance`), backup folder (`QuietFinance-Backups`), and all file prefixes updated. Legacy `FinanceTracker-*` backup files remain readable.

---

## [2.5.0] (5) - 2026-05-08

### Added

- **Account merge** — combine two accounts into one. Use it when a broker is renamed or duplicates appear; history is preserved on the surviving account, with overlapping snapshot values summed and cost basis combined.
- **Bulk edit accounts** — select multiple accounts and update person, country, asset type, status (Active / Retired), or group label in a single action. Each field is opt-in, so untoggled fields stay untouched.
- **Multi-select mode in All Assets** — a "Select" toggle reveals row checkboxes plus an action bar with Select all / Clear, and triggers for Bulk Edit and Merge.

### Changed

- **All Assets row highlight** — selected rows are visually emphasized while in selection mode.
- **Merge preview** — the merge sheet shows moved snapshots, overlap behavior, and the combined cost basis before confirmation. A currency-mismatch guard blocks merges across different native currencies to avoid silent FX conversion of stored values.

---

## [2.5.0] (4) - 2026-05-09

### Added

- **Accounts CSV import** — re-import the Accounts list export back into the store. Format is auto-detected against the Full history CSV.
- **Auto-lock when idle** — re-engage the App Lock after a configurable period of in-app inactivity. Picker in Settings → Security: Off / 1 / 5 / 15 / 30 / 60 min.
- **Sortable column headers** — every grid (Accounts, People, Countries, Asset Types, Receivables, Snapshots, Diff, Breakdown, Trends). Click cycles ASC → DESC → unsorted with an arrow indicator; preference persists per-table.
- **Watchlist on Dashboard** — pin accounts from the Accounts grid (star icon) to a dashboard panel showing current value and delta vs prior snapshot. Click a row to focus the account.
- **Drag-reorder accounts** — grip handle on each Accounts row; custom ordering persists across launches and is the default sort.

### Changed

- **CSV import upserts accounts** — re-importing the Accounts list now updates currency, institution, notes, active flag, cost basis, and asset type on existing rows instead of skipping duplicates. Summary reports updated vs unchanged counts.
- **New entry forms default to display currency** — New Account, New Receivable, and New Country preselect the user's chosen display currency instead of always USD.
- **Deleted items in sidebar Recent** are now struck through and disabled; clicks no longer silently no-op.
- **Recent list trimmed** from 6 entries to 5.
- **Friendlier import error** when the supplied CSV matches neither Full history nor Accounts list format.

---

## [2.5.0] (1) - 2026-05-08

### Added

- **App lock on launch** — Touch ID, Apple Watch unlock, or system password before the UI appears. Defaults to on; toggle in Settings → Security.
- **Stealth mode** — blurs every amount across Dashboard, KPI cards, breakdowns, and snapshot list; hover to reveal individual values.
- **Menu bar item** — net worth + QoQ delta in the system menu bar, refreshes every minute, click to open or refresh.
- **Goal target date + progress** — set a date alongside the value, get a progress bar, trend ETA, and "on track / behind" pacing.
- **Net-worth forecasting** — linear and CAGR projection with ±1σ confidence band on Trends; toggle method.
- **Liquidity / runway panel** — cash on hand, average monthly net change, runway in months at current burn rate.
- **Cost basis per account** — optional starting basis; "Unrealized" column on accounts shows gain/loss vs current value.
- **QoQ heatmap** in Reports — quarters × categories grid coloured by quarter-over-quarter Δ%.
- **Snapshot completeness badge** — chip on snapshot list and editor showing filled vs missing rows; missing rows highlighted red in editor.
- **Stale-account flag** — accounts whose last 3 snapshot values are within 0.5% are tagged STALE.
- **Auto-backfill new accounts** into past unlocked snapshots when opened, so values can be added retroactively. Same for receivables (with start-date awareness).
- **⌘K command palette** — fuzzy jump to any screen, snapshot, account, person, country, or quick action; arrow keys + Enter to fire.
- **Pinned snapshot tabs** above the snapshot list for fast switching between recent / important snapshots.
- **Recently viewed list** in the sidebar (expanded mode) — last 6 accounts and snapshots clicked.
- **Customizable Dashboard widgets** — show / hide / reorder all panels via Settings, including drag-and-drop.
- **Per-person "Include in net worth"** toggle — track parents / partners alongside without inflating own totals; "OFF NW" badge surfaces excluded accounts. Toggle directly from the People grid.
- **Inline-editable People grid** — name, color, "In NW" toggle, "Active" toggle, and a quick-add row at the bottom are all edited directly in the table; no editor sheet.
- **Inline-editable Countries grid** — code, name, flag (click to open picker), color, default currency, and inline add row. Editor sheet retired.
- **Person isActive flag** — archived persons hide by default via "Show inactive" header toggle; rendered dim. Net-worth aggregation still uses the separate "In NW" flag.
- **Sidebar collapse + resize** — auto-collapse to icons below 140 pt with hover labels, draggable divider, manual toggle button, last expanded width remembered.
- **Compare bar on Dashboard** — segmented "vs Previous / vs Year ago" drives the hero delta chip and KPI deltas.
- **Hover tooltips** on Trends total chart and Account history chart — vertical rule + point + annotation card with date and value.
- **Three-level breadcrumb** — `Screen › Filter › Snapshot` in TopBar, with active snapshot context where it matters.
- **Pre-cached snapshot totals** on lock for fast Dashboard / list rendering.
- **Backup verify counters** for Receivables and Receivable Values.
- **Two new app icon options**: **Vault** and **Strata**, alongside Quiet Finance default and Classic.
- **Money Flow** view in the snapshot diff screen — Sankey-style visual showing how each account's value moved between two snapshots, with new and dropped accounts highlighted.

### Changed

- **App display name** is now **Quiet Finance** everywhere user-facing (was "Finanace Tracker"). Bundle name fixed so the Dock tooltip and About panel match.
- **New default app icon** — gold L monogram with ledger lines on a dark squircle. Old icon kept as "Classic" option.
- **Hero on Dashboard** — embedded full-width sparkline below the figure (previously a separate panel), inline delta chip beside the number, eyebrow + compare bar on a single row, footnote moved below.
- **Hand cursor** appears on every clickable element — buttons, chips, theme toggle, share icon, slice rows, search results, and more.
- **⌘S** saves any open editor sheet; **Esc** closes; if there are unsaved changes Esc / Cancel prompts to save / discard / cancel.
- **Enter** triggers the primary button on every confirmation dialog and popup (delete, restore, lock, unlock, reset, save, etc.).
- **Snapshot editor** rows sort alphabetically by account name.
- **Search dropdown** results now open the relevant editor / detail sheet directly instead of just landing on the screen.
- **Active snapshot chip** is always pinned in the TopBar across all screens; placeholder shown when no snapshots exist yet.
- **Color-coded chart series** — Account history, Account detail trajectory, and Reports drilldown chart now use the asset-type's category color instead of single ink.
- **Click on a Dashboard donut slice** navigates to Breakdown filtered to that slice (no hover-redirect side-effect).
- **App icon picker tiles** redesigned: smaller previews, tighter spacing.
- **Backup file naming** moved to `Quiet Finance-*` prefixes; legacy `QuietFinance-*` files still listed and restorable.
- **Verify backup summary** is now a wrapping multi-line readable line with full label names instead of a truncated single line.
- **Settings → Security** panel redesigned with grouped row icons, status meta, and dedicated disclaimer; placed at the top of the right column.
- **Sidebar** shows the chosen app icon (instead of a static "L"); resize is now smooth (no jitter from per-frame disk writes).
- **Account editor** removes the unused "Group" field. Adds optional cost-basis input.
- **Empty-state screens** replace the lone "—" with a contextual SF Symbol illustration in a subtle disc.
- **KPI deltas** automatically switch label and reference between QoQ and YoY based on the Dashboard compare bar.

### Fixed

- Dock and Finder tooltip showing **QuietFinance**; now reads **Quiet Finance**.
- Sidebar resize jitter under live drag.
- Several confirmation dialogs missing default Enter shortcut.
- Snapshot editor: receivables and newly-added accounts not appearing in older snapshots — now auto-backfill on open (unlocked snapshots only).

---

## [2.4.0] - 2026-05-01

_Source: git `121f19c`_

### Added

- **`Receivable` / `ReceivableValue`** SwiftData models; **`Snapshot.receivableValues`** relationship.
- **Receivables** management UI: `ReceivablesView`, `ReceivableEditorSheet`.
- **CSV** and **PDF** export paths extended for receivable rows.
- **Dashboard** treatment for pending receivables (shown outside net worth).

### Changed

- **App** schema and navigation updated for receivables; **QuietFinanceApp** SwiftData **`Schema`** includes new models.

---

## [2.3.0] - 2026-05-01

_Source: git `d593785`_

### Added

- **Quick Jump** (menu / command) wired through **SearchCommands** next to Find.
- **Quit-time backups**: **`QuitBackupDelegate`**, backup trigger on quit; **`BackupService`** extended; **QuietFinanceApp** applies **pending restore** on launch when applicable.
- **`Account.groupName`** for grouping/organization.
- **`AccountAnalysis`** utility for snapshot-based account analytics.
- **`SnapshotPDFExporter`** for snapshot PDF export with revised layout.

### Changed

- **CurrencyConverter** extended for **illiquid** asset handling (alongside **`AppState`** / net-worth prefs).
- **Window appearance** tracked with theme changes (**`NSAppearance`**) alongside **`preferredColorScheme`**.
- **DashboardView**, **BreakdownView**, and related views refreshed for new behavior and UX.

---

## [2.2.0] - 2026-04-24

_Source: git `322a5e9`_

### Changed

- **Breakdown**: **`StackedBarsView`** replaces the previous treemap visualization; **`TreemapView` / `TreemapLayout`** removed.
- **BreakdownView**: cached data for performance, **search**, improved **empty** state.

### Removed

- Treemap implementation files (per refactor above).

---

## [2.1.0] - 2026-04-24

_Source: git `178ec15`_

### Added

- **`BackupService`**: automatic and **manual** database backups; listing and management surfaced in **Settings**.
- **Snapshot `notes`** field for free-form context on each snapshot.

### Changed

- **Dashboard**, **SnapshotEditor**, and related views updated for notes and backup-related flows; layout/responsiveness tweaks.

---

## [2.0.0] - 2026-04-23

_Source: git `5f5a44f`_

### Added

- **`AppCommands`**: menu commands for **Go** navigation, **New Snapshot**, **Find** / search focus, **Undo Delete** (via **`FocusedValues`**).
- **`UndoStash`** and restore pipeline for soft-delete recovery.
- **`DashboardPDFExporter`** for dashboard PDF export.
- **Caching** in **BreakdownView** and **DashboardView** for smoother updates.

### Changed

- **AppState**: **pending breakdown filter**, **global search** tick, and related navigation state.
- Main app file consolidated; older **QuietFinanceApp** layout replaced in favor of command-driven structure.

### Removed

- **`DistributionCard`**, **`HeadlineCard`** (superseded by newer dashboard pieces).

---

## [1.1.0] - 2026-04-22

_Source: git `0f8b42c`_

### Added

- **Custom fonts**: Geist, Geist Mono, Instrument Serif (registration + asset bundle).
- **Formatters**: compact currency and grouped integer helpers.

### Changed

- **RootView**, **BreakdownView**, **DashboardView**, **AccountsView**, **AssetTypesView** — layout, headers/tables, and styling updates.

---

## [1.0.0] - 2026-04-21

_Sources: git `adcd0e7`, `2c18486`, `b5d29a5`_

### Added

- **Initial codebase** — Quiet Finance macOS app (SwiftUI/SwiftData).
- **Marketing / docs**: **`V 1.0.0`** first-release marker; **README** updated for **Quiet Finance** positioning and feature overview (multi-person, multi-currency, snapshots, exports, etc.).

---

## Repository note

These sections were **backfilled from `git log`** (no **`git tags`** in-repo at authoring time). **2.0.0–2.4.0** are **sequential semver slices** of that history so **2.4.0** matches the current Xcode **2.4** product line; only **1.0.0** was named in a commit message. If you retroactively tag releases, use e.g. **`v2.4.0`** consistent with the headings above.

## Versioning cheat sheet

When you ship:

1. Update **`MARKETING_VERSION`** / **`CURRENT_PROJECT_VERSION`** in Xcode.
2. Append a **`## [x.y.z] - YYYY-MM-DD`** section below **`[Unreleased]`** (Include **`_Source: git <sha>_`** if helpful).
3. Optionally **`git tag vX.Y.Z`**.

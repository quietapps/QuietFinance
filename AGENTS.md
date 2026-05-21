# AGENTS.md — AI & automation context

Instructions for **AI coding assistants**, **bots**, and **humans** using them in this repository.

## Read first

1. **`CLAUDE.md`** — Architecture, SwiftData schema rules, navigation, files to open first.
2. **`LICENSE`** — Proprietary; no use or repurposing without **written approval** from the copyright holder. Do not suggest open-sourcing or permissive relicensing unless the owner asks.
3. **`CHANGELOG.md`** — Release history and what to bump when versioning.

## Project

| Item | Value |
|------|--------|
| Platform | macOS native app |
| UI | SwiftUI |
| Persistence | SwiftData (SQLite) |
| Entry project | `QuietFinance.xcodeproj` |
| Source root | `QuietFinance/` |

## Agent behavior

- **Scope discipline** — Implement only what the user asked for; avoid drive-by refactors and unrelated edits.
- **Consistency** — Match existing naming, file layout, Swift style, and comment density in nearby code.
- **Correctness hotspots** — When touching snapshots or FX: **never** mutate **locked** snapshot data via fetch flows; preserve delete cascades and user confirmations documented in manage views.
- **Schema** — Every new `@Model` must appear in **`Schema([...])`** in `QuietFinanceApp.swift`. Update seed/CSV paths when data shape affects users.
- **Verification** — There is **no** XCTest target; validate by running the app and exercising affected screens plus Settings/export if relevant.

## Cursor-specific rules

Project rules live in **`.cursor/rules/`** (`.mdc` files). They augment this file with always-on or path-scoped guidance.

## Changelog hygiene

When the user ships a meaningful change set, remind them (or append) **`CHANGELOG.md`**: **`[Unreleased]`** bullets or a new version section aligned with Xcode's **`MARKETING_VERSION`**.

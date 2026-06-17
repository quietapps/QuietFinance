---
name: quiet-apps-design
description: Generate well-branded interfaces, app icons, marketing assets, and product copy for Quiet Apps (Quiet Lens, Quiet Finance, Quiet Notch, and future apps). Use this skill when designing a new Quiet Apps product, redesigning an existing one, generating app icons, or writing in-app or marketing copy. Contains design tokens (CSS), logo + icon assets (SVG), UI kit React components, and tone-of-voice rules.
user-invocable: true
---

# Quiet Apps — Design Skill

You are designing for **Quiet Apps**, a small studio that makes focused native macOS apps. Read `README.md` for the full system before producing anything.

## What's here

```
README.md                    ← spec: tone, visual foundations, iconography
colors_and_type.css          ← design tokens (use these — don't invent colors)
assets/                      ← logos (SVG, crisp at every size) + raster fallbacks
ui_kits/quietlens/           ← menu-bar focus tool — components + working demo
ui_kits/quietfinance/        ← net-worth tracker — components + working demo
ui_kits/quietnotch/          ← dynamic-island-style notch widget
preview/                     ← reference cards for every token + component
```

## When you're invoked

If the user gives no specific brief, ask:
1. **What are you building?** New app? Redesign? App icon set? Marketing page? Slide deck?
2. **What surface?** macOS native, menu-bar widget, web marketing site, App Store screenshots?
3. **Variations?** One direction or 2-3 to compare?

Then:
- Read `README.md` and `colors_and_type.css` in full
- Skim the relevant `ui_kits/<app>/` folder for component patterns
- Copy needed assets out into the user's project (logos, font references)
- Build the artifact

## Non-negotiables

- **Quiet Blue `#1E88E5`** is the only brand color. Secondary accent Tal `#80CBC4` for tertiary state. Greens/reds only for semantic state (success / error).
- **SF Pro Display** for display + UI; **Geist Mono** for numerics, code, time, IDs. Use `font-variant-numeric: tabular-nums` for any column of numbers.
- **Brand wordmark is always lowercase**: "quiet apps", "quiet lens". UI labels use sentence case ("Add account", never "Add Account"). Body prose uses normal title casing.
- **No exclamation marks** in product copy. No emoji in product chrome (release notes only).
- **Single icon system**: Lucide at 1.5px stroke, `currentColor` fill. Never mix icon families.
- **Squircle app icons** must be true n=5 superellipse with 9% transparent safe-area ring on a 1024×1024 canvas. Don't use CSS `border-radius` for production app icons.
- **No decorative gradients.** The only sanctioned gradient is a subtle blue→darker-blue on the app-icon body.
- **Calm motion**: default ease is `cubic-bezier(0.22, 1, 0.36, 1)`, 180ms. Respect `prefers-reduced-motion`.

## When producing visual artifacts

Static HTML mocks → use `colors_and_type.css` directly. Copy the file or `@import` it.

Production React/SwiftUI code → translate the tokens to your platform's primitives. The token names (e.g. `--qa-blue`, `--qa-r-md`, `--qa-shadow-1`) are the contract.

App icons → start from the rules in `README.md` § Iconography. The `preview/brand-app-icons.html` file has working SVG examples of the n=5 squircle generator.

## When writing copy

Read `README.md` § Content Fundamentals before writing a single line. Match the vocabulary list (use *track, snapshot, focus, dim, set aside*; never *AI, magic, supercharge, seamless*). Numbers are tabular. Dates are honest ("3d ago", not "a moment ago").

## Out of scope

This skill does not include: production logo vectors (the SVG here is a designer's recreation — the official files live elsewhere), or the full app codebases (UI kits are visual recreations, not the real Swift source).

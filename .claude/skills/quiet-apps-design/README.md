# Quiet Apps — Design System

A unifying visual + interaction language for the **Quiet Apps** family: small, focused macOS tools built around the idea of *less, but better* — calmer interfaces, local-first data, and one job done well per app.

> This system is **forward-looking**: existing apps will be re-skinned to match it. Pixel-perfect parity with the apps as-they-ship-today is intentionally not a goal.

## Use this with Claude Code

This folder is a self-contained Agent Skill. Drop it into your Claude Code project as a skill directory (e.g. `.claude/skills/quiet-apps-design/`) and invoke it whenever you're designing a Quiet Apps product, building an icon, or writing in-app copy. See `SKILL.md` for the invocation contract.

For quick generation:
- **New app or redesign** → "Use the quiet-apps-design skill to mock the [screen name] for [app]"
- **App icon** → "Generate an app icon for [app] following the quiet-apps-design skill — explain the metaphor before drawing"
- **Marketing page** → "Write the hero section for [app]'s landing page using the quiet-apps-design tone"
- **Copy review** → "Critique this copy against the quiet-apps-design content fundamentals"

---

## Sources used

| Source | Where | Used for |
|---|---|---|
| Brand business-card mockup | `uploads/SCR-20260518-njai.png` | Logo, primary blue (sampled `#1E88E5`), wordmark style |
| Quiet Apps GitHub org | https://github.com/orgs/quietapps/repositories | Product roster, app taglines |
| QuietFinance repo | https://github.com/quietapps/QuietFinance | Net-worth tracker, SwiftUI + SwiftData, local-only |
| QuietLens repo | https://github.com/quietapps/QuietLens | Menu bar app — dims/blurs unfocused windows |
| QuietNotch repo | https://github.com/quietapps/QuietNotch | Dynamic-island-style widget for MacBooks |
| homebrew-quietlens | https://github.com/quietapps/homebrew-quietlens | Distribution tap for QuietLens |

> ⚠ Repo READMEs were not directly fetched in this build — the sandbox could not reach github.com directly. App descriptions and feature inferences come from the public org listing only. Where I had to guess, I've flagged it inline. If you connect GitHub or paste each README, I'll tighten everything in a second pass.

---

## What Quiet Apps makes

**Tagline (proposed):** *Small Mac apps that get out of the way.*

| App | One-line | Surface |
|---|---|---|
| **Quiet Lens** | Dim & blur every window except the one you're working in. | Menu bar app + global overlay |
| **Quiet Finance** | Local-only net-worth tracker. Your money, your machine. | Standard macOS window |
| **Quiet Notch** | A small ambient widget that lives inside the MacBook notch. | Notch overlay |
| *(homebrew-quietlens)* | Homebrew tap for installing Quiet Lens. | CLI |

Common DNA across all four:
- **Native macOS**, SwiftUI-first
- **Single-purpose** — each app does *one* thing
- **Local-first / privacy-respecting** — no accounts, no cloud
- **Menu bar or low-chrome** presence — they hide until needed

---

## Content fundamentals

**Voice.** Plain, quiet, capable. Speaks the way the app behaves — minimal, helpful, never selling. We are not loud. We do not exclaim. We rarely use emoji.

**Tone shifts** by context:
- **Marketing pages** — confident, short sentences, a touch wry.
- **In-app copy** — neutral, functional, second-person ("Track your net worth.").
- **Empty states & errors** — direct + a small kindness ("No accounts yet. Add one to get started.").

**Style rules.**
- **Lowercase brand** wherever it's a wordmark or in headlines: *quiet apps*, *quiet lens*. Use title case in body prose: *Quiet Lens dims unfocused windows.*
- **Sentence case** for UI labels, headings, buttons. Never title case in chrome ("Add account", not "Add Account").
- **You**, not we. We never say "we" inside the app.
- **No exclamation marks** in product copy. They feel needy.
- **No em-dashes** in headlines (they read as filler). Use them in long-form prose freely.
- **Numbers are tabular.** Currency uses the locale glyph + grouped digits: `$1,284.50`, not `USD 1284.5`.
- **Honest dates.** "Today", "Yesterday", "3d ago", "Mar 18" — not "Just now" / "A moment ago".
- **Emoji**: only in release notes / changelogs, and only as section bullets (✦ for features, ⚙ for fixes). Never inside the product chrome.

**Vocabulary we use.** *track, snapshot, focus, dim, hide, quiet, set aside, archive, local, account, balance.*

**Vocabulary we avoid.** *AI, magic, smart, supercharge, revolutionary, seamless, beautiful, delight, journey, unleash, sync* (when we mean copy), *get notified*.

**Example pairings.**

| Avoid | Prefer |
|---|---|
| "✨ Magically track your net worth!" | "Track your net worth. Locally." |
| "Welcome to QuietFinance — let's get you set up!" | "Add your first account." |
| "Oops! Something went wrong 😢" | "Couldn't save. Try again." |
| "Click here to add an account" | "Add account" |
| "You don't have any snapshots yet" | "No snapshots yet." |

---

## Visual foundations

### Color
- **Quiet Blue `#1E88E5`** is the brand. Used at full strength on the primary CTA, app icon backgrounds, and accent strokes. Sparingly elsewhere.
- **Secondary accent `#80CBC4`** (Light Tal) for tertiary highlights and the focus indicator chip in Quiet Lens.
- **Focus Grey `#E0E0E0`** for HUD chip backgrounds and the in-Lens controls.
- **Neutrals are cool-neutral**, not warm. Page canvas is `#F7F8FA`, not cream.
- **No purples, no gradients-as-decoration.** A subtle blue→darker-blue gradient on the app icon mark is the only sanctioned gradient.
- **Dark surfaces** are near-black `#0B0D11`, not gray. Used for menu bar overlays, the Lens dimming scrim, and the Notch widget.
- The full token set lives in `colors_and_type.css`.

### Type
- **SF Pro Display** does the heavy lifting — display, headings, UI. The brand font is vendored under `fonts/` (uploaded OTFs).
- **Geist Mono** for numerals, currency, code, file paths.
- **Bold weights** (700) only at display sizes — they're the brand's signature voice. Everything ≤ 20px is 400–500.
- Tracking is **tight** at large sizes (`-0.02em`), neutral at body.

### Spacing
- 4pt base, scale: 4 / 8 / 12 / 16 / 20 / 24 / 32 / 40 / 48 / 64 / 80 / 96.
- **Generous outer padding, tight inner.** A primary window has `--qa-space-8` (32px) page padding; a list row uses `--qa-space-3` (12px) vertical.
- Group related elements at 8px; separate sections at 24–32px.

### Backgrounds
- **Solid surfaces only.** White (`--qa-bg-1`) or canvas gray (`--qa-bg-2`).
- The **only** decorative background is the **Lens scrim** — a dark frosted blur applied behind dimmed windows.
- Marketing pages use full-bleed *photography* (a quiet desk, a window, a Mac) — never illustration, never abstract gradient blobs.
- No hand-drawn illustrations. No textures. No grain.

### Animation
- **Calm settle, not bounce.** Default ease is `cubic-bezier(0.22, 1, 0.36, 1)` — quick to start, decelerates to a stop.
- Spring (`--qa-ease-spring`) reserved for the Notch widget expanding open.
- Durations: 120ms for hover state changes, 180ms for in-place transitions, 280ms for content swap, 420ms for the menu-bar dropdown opening.
- **No autoplay video. No carousels.** Marketing scrolls; nothing moves until the user moves.

### Interaction states

| State | Treatment |
|---|---|
| **Hover** (button) | Background shifts 1 step darker (`--qa-blue-600` for primary). No scale, no shadow change. |
| **Hover** (row) | Background fills with `--qa-bg-3`. No border change. |
| **Press** | Background shifts another step + content scales to `0.98` for 80ms, then snaps back. |
| **Focus (keyboard)** | 3px `rgba(30, 136, 229,0.35)` outline ring offset 2px. Never removed. |
| **Disabled** | 40% opacity. No interaction styles. |
| **Loading** | Indeterminate horizontal bar at the top of the surface, 2px tall, `--qa-blue` traveling. |

### Borders
- **One hairline.** `1px solid #E4E6EA`. We don't have heavy borders.
- Cards stack via shadow, not border, on `--qa-bg-2`.
- Inputs get a border, not a shadow, on rest. They swap to a focus ring on focus.

### Shadows / elevation
- 4 levels: hairline (just `0 0 0 1px`), card (`shadow-1`), pop (`shadow-2`), float (`shadow-3`), window (`shadow-4` + ring).
- Shadows are **near-black, very low alpha** (`rgba(14,17,22,0.05–0.16)`). Never colored.
- No inner shadows on inputs.

### Transparency & blur
- Native macOS vibrancy where the OS gives it (window backgrounds, sheets).
- Lens overlay uses real Gaussian blur (`60px`) over a `rgba(11,13,17,0.55)` scrim.
- We don't simulate vibrancy on the web — pages are solid. Use `backdrop-filter: blur(28px)` only when recreating the desktop overlays.

### Corner radius
- Buttons: `--qa-r-md` (10px).
- Inputs: `--qa-r-md` (10px).
- Cards: `--qa-r-lg` (14px).
- Sheets / windows: `--qa-r-xl` (20px).
- Pills / chips: `--qa-r-pill`.
- **App icons**: `--qa-r-app-icon` (22.37%) — the exact Big-Sur-era squircle ratio.

### Cards
A canonical card is: white surface, `--qa-r-lg` radius, `--qa-shadow-1`, padding `--qa-space-5` to `--qa-space-6`. No border in addition to the shadow. Hover lifts to `--qa-shadow-2`.

### Layout
- Marketing: max `1080px`, content centered, generous side padding.
- App windows: variable width, sidebar fixed `220–260px`.
- The status-bar/menu-bar surface is always **right-aligned** in the menu bar; dropdowns open with a small `--qa-r-lg` panel, `--qa-shadow-3`, anchored to the menu bar item.

---

## Iconography

**Approach.** Quiet Apps uses a **single coherent line-icon set** — fixed stroke weight, rounded caps + joins, no fills. We do not mix icon styles.

**System.** [Lucide](https://lucide.dev/) at **1.5px stroke**, **20px** default. CDN-loaded for prototypes; vendor as SVG sprites for production. We chose Lucide because:
- it's the same family Apple's SF Symbols feel adjacent to (geometric, rounded, single-weight)
- it's open source (ISC)
- it ships ~1,500 icons covering everything our apps need

⚠ **Flagged substitution.** Production apps may eventually move to SF Symbols (native, free on Apple platforms). Lucide is the system-of-record for *cross-platform* assets (web, marketing site, docs) — it travels.

**SVG conventions.**
- 24×24 viewBox by default
- `stroke="currentColor"`, `fill="none"`, `stroke-width="1.5"`, `stroke-linecap="round"`, `stroke-linejoin="round"`
- Icons inherit text color via `currentColor` — never hardcode

**Emoji.** Reserved for release notes / changelogs / blog post bullets. **Never** inside product chrome.

**Unicode chars as icons.** Permitted for keyboard cues only: `⌘ ⌥ ⌃ ⇧ ↵ ⌫ ␣`. Set in `var(--qa-font-mono)` so they sit aligned with text.

**Logo & app-icon kit.**
- `assets/logo-mark.svg` — color mark on white
- `assets/logo-mark-white.svg` — white mark on color
- `assets/logo-wordmark-on-white.png` — full lockup, extracted from the business card
- `assets/logo-wordmark-on-blue.png` — reverse, extracted from the business card

> The SVG mark is an **approximation** drawn from the business card raster. Replace with the canonical vector when you have it.

---

## File index

```
.
├── README.md                    ← this file
├── SKILL.md                     ← agent-skill manifest (Claude Code-compatible)
├── colors_and_type.css          ← the source of truth for tokens
├── assets/                      ← logos, marks, business-card raster
├── fonts/                       ← (intentionally empty — fonts pulled from Google Fonts CDN, flagged)
├── preview/                     ← cards that populate the Design System tab
└── ui_kits/
    ├── quietlens/               ← menu bar app + global overlay
    ├── quietfinance/            ← net-worth tracker window
    └── quietnotch/              ← dynamic-notch widget
```

Each `ui_kits/<app>/` contains a `README.md`, `index.html` demo, and one or more `.jsx` component files.

---

## Open questions & flagged substitutions

1. **Real logo vector** — current SVG is a trace of the business card raster. Send the AI/SVG and I'll replace `assets/logo-mark.svg`.
2. **Repo READMEs** — couldn't fetch from GitHub directly in this sandbox. Paste them or connect GitHub and the tone/feature notes will get sharper.
4. **App icon system** — once you finalise the icon for each app, drop them into `assets/app-icons/` and I'll wire them into the previews.
5. **Marketing photography** — none provided yet. The Visual Foundations section reserves a slot.

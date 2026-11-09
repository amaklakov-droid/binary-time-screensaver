# CLAUDE.md — Binary Time screensaver

Native **macOS screen saver** (`.saver`) that shows the date and time in binary. Black and white only, 6 languages, 4 calendars, location or "space" mode behind a VPN.

## Read first
1. `TASK.md`: the task, scope, milestones, definition of done.
2. `SPEC.md`: product and visual behaviour. §9 is the acceptance checklist.
3. `MACOS.md`: stack, ScreenSaver.framework workarounds, API mapping, project layout.
4. `reference/screenshots/`: what it must look like (rendered from `prototype/`).

## Sources of truth (do not duplicate values in code)
- `design/tokens.json`: colours, opacities, type, spacing formulas, bit states, motion.
- `data/i18n.json`: every user-visible string and per-language rules (dir, digits, caps, fonts).
- `data/celestial-catalog.json`: space objects for VPN mode.
Bundle these JSON files as resources and decode them at runtime, or generate Swift from them in a build step. Never hand-copy values.

## Hard rules
- Swift + AppKit + Core Animation. **No WKWebView, no web code in the product.** `prototype/` is a behavioural reference only.
- macOS 26+, Apple silicon only (arm64). No CoreLocation. No network calls unless the user enables the online VPN check.
- The bit grid is **always LTR, most significant bit on the left**, in every language, including Hebrew and Arabic.
- Bundle all fonts (OFL); never rely on system or online fonts.
- Apply all lifecycle workarounds from `MACOS.md` §2. The legacy screen-saver host on Sonoma–Tahoe leaks instances.
- Keep logic in the AppKit-free `Core` package with unit tests; the views stay thin.
- Never log or persist coordinates or IP data.

## Working agreement
- Propose a plan before the first code change and after each milestone in `TASK.md`.
- When the spec is ambiguous, ask. Don't invent behaviour. If the prototype contradicts `SPEC.md`, the spec wins; report the mismatch.
- Before saying a milestone is done, run the tests and compare against `reference/screenshots/`.
- Strings marked `review: true` in `i18n.json` (he, ar, bo) are provisional. Don't "fix" them yourself; flag issues instead.

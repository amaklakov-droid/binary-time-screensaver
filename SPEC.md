# Binary Time — screensaver specification v1.0

Single-project spec. Visual source of truth: `design/tokens.json` (+ `tokens.css`). Copy: `data/i18n.json`. Celestial catalog: `data/celestial-catalog.json`. Behavioural reference: `prototype/` (open `prototype/index.html` in a browser).

When the prototype and this document disagree, **this document wins**; report the mismatch.

---

## 1. Product

A full-screen screensaver that shows the current date and time in binary, in black and white, in six languages and four calendars, with the viewer's location (or, behind a VPN, a random place in space).

## 2. Screen layout

Four zones, top to bottom, inside a padding of `--pad`:

| Zone | Left (LTR) | Right (LTR) |
|---|---|---|
| **Header** | Kicker «Binary time» · calendar name (+ «auto») · full localized date line | Pulse dot + location source · place (L1) · coordinates or time zone (L2) · optional L3 |
| **Date group** | 3 rows: Year, Month, Day — small bits (0.56 × b), all at 66 % opacity | |
| **Separator** | Label «Time» + 1 px rule at 50 % across the full width | |
| **Time group** | 4 rows: Hours, Minutes, Seconds, Hundredths — full-size bits, the main visual layer | |
| **Footer** | Full decimal readout `YYYY·MM·DD  HH:MM:SS.cc` (+ AM/PM) · legend `● 1 ○ 0 UTC±hh:mm` | Control pills |

A place-value header row (`2ⁿ`: 4096 … 1) sits above the date group; hidden on narrow screens.

### 2.0 Composition
Header and footer span the full width. The bit block (place values, date group, separator, time group) is **one column as wide as its widest row, centred horizontally and vertically** in the remaining space. On narrow screens it takes the full width. See `reference/screenshots/` (ultrawide, portrait, narrow).

### 2.1 Row anatomy
`[label + sub-label] [bit grid] [decimal value]`
- Label column `--lab`, decimal column `--dec` (fills remaining width, text aligned to the end edge).
- The bit grid is **always LTR, most significant bit on the left**, in every language.
- All rows share the same column count `w` and are right-aligned: positions a metric does not use are rendered as **void** dots, so place values line up vertically.

### 2.2 Bit widths
| Metric | Bits | Range |
|---|---|---|
| Year | `bitLength(year)` (Gregorian 2026 → 11, Hebrew 5787 → 13, Buddhist 2569 → 12, Islamic 1448 → 11) | — |
| Month | 4 | 1–12 (Hebrew 1–13) |
| Day | 5 | 1–31 |
| Hours | 5 (24 h) / 4 (12 h) | 0–23 / 1–12 |
| Minutes | 6 | 0–59 |
| Seconds | 6 | 0–59 |
| Hundredths | 7 | 0–99 |

`w = clamp(bitLength(year), 7, 14)`.

### 2.3 Responsive
- Everything derives from the screen via container units (`cqmin`, `cqw`, `cqh`) and `clamp()` — see tokens `space.*`, `bit.size.*`.
- **Narrow** (container width ≤ 680 px): header blocks stack; each row becomes `label · sub … decimal` on one line with bits full-width beneath; place-value row hidden; controls wrap and align to start.
- Must work on any aspect ratio (16:9, 16:10, 21:9, portrait, multi-monitor each with its own instance) and any DPI. No horizontal scrolling, no clipping.

## 3. Visual system (summary — values in tokens)
- Two colours only: ink `#000` and paper `#FFF`. Themes: **dark** (default) and **light** (inverted). Theme switch animates 600 ms.
- Hierarchy by opacity: 100 / 66 / 42 / 22 %, plus 50 % for the separator rule.
- Bit states: **on** = filled; **off** = outline 5.5 % of b at 42 %; **void** = 10 % dot at 22 %. Shapes: dot (default) or square (radius 12 % of b).
- Font: JetBrains Mono 300/400/600 with Noto fallbacks per script, tabular numerals. **Bundle fonts locally** (screensavers run offline).
- Motion: bit change 180 ms; hundredths row has no transition; location pulse 2 s; respect reduced-motion.

## 4. Data

### 4.1 Time
- Local system time and time zone. Update the display every 10 ms (one frame per hundredth); use `requestAnimationFrame` (or the platform equivalent) and touch only cells whose state changed.
- 12/24 h setting. In 12 h mode the hours row sub-label shows the localized day period (AM/PM), also appended to the readout.

### 4.2 Calendars
Options: `auto` (default), `gregory`, `islamic` (ICU `islamic-umalqura`), `hebrew`, `buddhist`.

`auto` resolves in this order:
1. The user's own OS calendar setting, if it is one of the four (macOS: Language & Region › Calendar).
2. The system time zone:

| Time zones | Calendar |
|---|---|
| Asia/Riyadh | islamic |
| Asia/Jerusalem (alias Asia/Tel_Aviv) | hebrew |
| Asia/Bangkok | buddhist |
| anything else / undetermined | **gregory** |

Numeric Y/M/D come from `Intl.DateTimeFormat('en-u-ca-<id>')` parts. Hebrew month is numbered from Tishri (1) to Elul (12/13); if ICU returns a non-numeric month, map by name (see prototype `dateParts`). Era shown as the year row sub-label (`i18n.era`).

> Decided: keep the time-zone map minimal. Other Muslim-majority countries use the Gregorian civil calendar day to day. Iran and Afghanistan use the Solar Hijri calendar, which is not supported, so they fall to Gregorian.

### 4.3 Location
Priority (macOS — see MACOS.md §3):
1. **IP lookup** (only when the optional online check is on): city-level coordinates to 2 decimals `55.76° N · 37.62° E`; source tag «Geolocation». No CoreLocation.
2. **Time zone**: city = last segment of the IANA zone (`Europe/Moscow` → Moscow); country = IANA `zone1970.tab` → ISO code → localized region name; source tag «By time zone».
3. Neither: «Location unknown» + the zone id.

(The web prototype uses browser geolocation and a hard-coded city map. Those are prototype shortcuts and do not ship.)

L1 = `City · Country` (or coordinates if no city); L2 = coordinates or zone id; L3 = zone id when coordinates are shown.

### 4.4 VPN mode («changed» location)
- When a VPN is detected (or forced by the setting), never show the real place. Show a random object from `celestial-catalog.json`, rotating every 20 s, starting at a random index.
- L1 = localized name, L2 = coordinates (RA/Dec J2000 or surface lat/lon), L3 = kind · designation · distance in light-years (localized digits, `≈` when approximate). Tag: «VPN · real location hidden».
- **Detection, decided (two layers, details in MACOS.md §3):**
  1. Local, default on: the primary network interface is `utun*` / `ipsec*` / `ppp*` ⇒ VPN. No network call.
  2. Online, default off (opt-in, user's own key): IPLocate.io `is_vpn || is_proxy`, or a mismatch between the IP's time zone/country and the system's ⇒ VPN. 10 min cache, 3 s timeout, falls back to layer 1.
- The setting `location: auto | vpn` forces space mode for testing and for users who always want it.
- Privacy: without the opt-in there are no network calls (fonts are bundled). Never persist or log coordinates or IP data.

## 5. Languages
`en, ru, he, ar, bo, ja` — all copy in `data/i18n.json`; per-language rules in `i18n.meta`.

- **Default**: first of the system/browser languages that is supported (`iw` → `he`), else `en`.
- **Switcher**: first control pill, globe icon + the language's own name; cycles in the order above. Persisted.
- **RTL** (`he`, `ar`): `dir="rtl"` on the root; layout mirrors via logical properties (`margin-inline-start`, `text-align: end`, flex order). Bits and the readout stay LTR (`direction: ltr` / `dir="ltr"`).
- **Digits**: `ar` → Arabic-Indic `٠–٩`, `bo` → Tibetan `༠–༩`, others Latin. Applied to decimals, place values, sub-labels, readout, distances. Coordinates stay Latin.
  - In the readout insert LRM (`U+200E`) around separators for non-Latin digits, otherwise Unicode bidi rule N1 reverses the groups. For Arabic use `/` as the date separator (the Arabic zero `٠` is visually a dot).
- **Case & tracking**: only for `en`, `ru`. Others: `letter-spacing: normal`, no `text-transform` (tracking breaks Arabic joining).
- **Tibetan**: line-height 1.7; ICU has little `bo` data, so weekday/day-period/date line come from `i18n.strings.bo` and Intl calls use `en` as fallback; celestial names fall back to English.
- Dates (`dateLine`, weekday, day period) use `Intl.DateTimeFormat(<lang>-u-ca-<calendar>-nu-latn)` then the digit mapping.
- ⚠ `he`, `ar`, `bo` copy (`meta.review: true`) must be reviewed by native speakers before release — Tibetan first.

## 6. Settings
| Key | Values | Default | Control |
|---|---|---|---|
| `lang` | auto, en, ru, he, ar, bo, ja | auto | pill «🌐 <native name>» |
| `hourFormat` | 24, 12 | 24 | pill |
| `calendar` | auto, gregory, islamic, hebrew, buddhist | auto | pill «Calendar: …» (cycles) |
| `location` | auto, vpn | auto | pill «Location: auto/VPN» |
| `theme` | dark, light | dark | pill «Invert» |
| `bitShape` | dot, square | dot | settings only |
| `showControls` | bool | true | settings only |

Persist settings per user (`ScreenSaverDefaults`). Any input dismisses a screen saver, so on macOS these settings live in the **Options sheet** (`configureSheet`), and the pills are not shown on the running saver. They remain in the DebugHost app for design review (`showControls`). Options also add: Online VPN check (off) + API key. Pills: 44 px min height, 66 % at rest, 100 % on hover/focus, visible focus ring.

## 7. Accessibility
- Each bit grid: `role="img"` with label `<metric> <decimal> — <binary>`; groups labelled «Date» / «Time».
- Contrast as per tokens (text ≥ 7:1, off-bit outline ≥ 3:1).
- `prefers-reduced-motion` (or OS equivalent): no transitions, no pulse.
- Controls are real buttons, keyboard-reachable.

## 8. Performance
- Target 60 fps with < 3 % CPU on a 2020 laptop. Rebuild DOM only when `w` or language changes; otherwise mutate classes/text in place.
- Cache `Intl` formatters. No layout thrash: sizes come from CSS, not JS measurement.

## 9. Acceptance checklist
- [ ] Fills any screen size/aspect without scroll or clipping; narrow layout at ≤ 680 px.
- [ ] Binary values correct for all 7 metrics, incl. 12 h (12 → `1100`) and hundredths 0–99.
- [ ] Place values align across all rows for each calendar (w = 11/12/13).
- [ ] Theme invert animates; both themes meet contrast.
- [ ] All six languages render with correct fonts; he/ar mirror; bits stay LTR; ar/bo digits; readout order correct in ar.
- [ ] `auto` calendar resolves by time zone; default Gregorian.
- [ ] Location: geolocation → time zone → unknown fallbacks.
- [ ] VPN mode never reveals the real place; rotates every 20 s; localized names.
- [ ] Settings persist; reduced motion respected; fonts work offline.

## 10. Decisions
1. **Platform: macOS only.** Native Swift `.saver` with Core Animation rendering, no WKWebView. Min macOS 14. See `MACOS.md`.
2. **VPN detection:** local primary-interface check by default; optional IPLocate.io check with the user's own key (§4.4).
3. **Auto calendar:** OS calendar setting first, then a minimal time-zone map (§4.2).
4. **Still open:** native-speaker review of he/ar/bo strings (Tibetan first); verification of catalog coordinates (SIMBAD, USGS Gazetteer). Neither blocks development.

# Binary Time — macOS implementation guide

Platform decision: **macOS only**. Behaviour and design are defined in `SPEC.md`; this file covers how to build it on macOS. The web prototype is a reference only and does not ship.

## 1. Stack

| Topic | Decision | Why |
|---|---|---|
| Product type | `.saver` bundle (ScreenSaver.framework, `ScreenSaverView` subclass) | The only way to appear in System Settings › Wallpaper › Screen Saver |
| Language | Swift 5.10+/6, AppKit | |
| Rendering | **Native Core Animation** (CALayer per bit, NSTextField / CoreText for text). **No WKWebView.** | WKWebView in savers has known multi-monitor failures (FB17938870), higher memory, and since instances leak on Sonoma–Tahoe (below), each leaked web view is expensive. The UI is simple enough that native code is shorter than wrapping web code. |
| Min OS | macOS 26 Tahoe | Customer decision 2026-11-09 (SPEC §10.5): one supported host generation, no Sonoma or Sequoia test VMs. The code itself needs only macOS 14 (`NSView.displayLink(target:selector:)`) |
| Architectures | Apple silicon only (arm64) | Same decision; Apple announced Tahoe as the last macOS for Intel Macs |
| Distribution | Developer ID signed + notarized `.saver` in a `.dmg` (or a small installer app) | The App Store does not distribute screen savers |

## 2. Known ScreenSaver.framework problems and required workarounds

The legacy engine (`legacyScreenSaver.appex`) is buggy on Sonoma, Sequoia and Tahoe, and Apple has said a modern API won't arrive in macOS 26. Build these in from day one (the open-source **ScreenSaverMinimal** template collects them):

1. **Instances are not torn down.** Each activation creates a new `ScreenSaverView` while old ones keep running. → Listen for the distributed notification `com.apple.screensaver.willstop`; on it, stop timers and call `exit(0)` (not `NSApplication.terminate`). Guard against two live instances on the same screen.
2. **`stopAnimation` isn't called** outside the System Settings thumbnail. → Don't rely on it for cleanup (see 1).
3. **`animateOneFrame` is unreliable.** → Drive updates from your own timer, not the framework's animation timer. The display changes once a second (SPEC §10.4), so a `Timer` re-armed for each second boundary is enough; a `CADisplayLink` would wake the process at the display rate for nothing.
4. **`isPreview` may be wrong on Tahoe** and the settings dialog can spawn an extra full-screen instance. → Also treat a view smaller than ~400 pt as a preview; keep preview rendering cheap.
5. **Multi-monitor:** one view per screen; each computes its own layout from its own bounds. Test with 2 displays of different sizes and scales.
6. **Settings UI changed in Tahoe** (screen savers are now under Wallpaper). The `configureSheet` still works; don't deep-link to the old settings pane URL.
7. **Xcode 26 SDK + XIB with scroll/outline views crashes** on older macOS. → Build the configure sheet in code (or SwiftUI via `NSHostingView`), not XIB.
8. **The System Settings thumbnail never gets `startAnimation`** (observed on macOS 27). WallpaperAgent creates a 1440×900 instance in its own host, snapshots it once, and shows the snapshot scaled down; the 0×0 instance in the System Settings host only supplies the `configureSheet`. When the Options sheet ends it creates a fresh instance at once and that instance reads the stored settings. → Draw the current frame as soon as the view has a window, not only in `startAnimation`; otherwise the thumbnail is black. Save the settings *before* `endSheet`, or the thumbnail shows the previous settings. The thumbnail is static.
9. **The full-screen saver is hosted through WallpaperAgent too** (observed on macOS 27). ScreenSaverEngine runs, but the `legacyScreenSaver` host is an XPC service of WallpaperAgent, which restarts it at once if it quits while in use. Watching for the engine with `NSRunningApplication` works, but the list can come back empty for a moment while LaunchServices updates it; one such miss once quit a host whose engine kept running. → Count the engine as gone only after several misses in a row (`EngineWatch.missesToStop`), and log why the host quits.

## 3. Mapping the spec to Apple APIs

### Time and rendering
- Timer on each second boundary → build the frame for the current second. Update only layers whose state changed. Wrap updates in `CATransaction` with implicit actions disabled, except for the 180 ms bit fade (explicit `CABasicAnimation` on `opacity`/`backgroundColor`).
- Layout: compute token formulas from `bounds` (`cqmin = min(w, h) / 100`, `cqw = w / 100`, `cqh = h / 100`) in `layout()`; narrow layout when `w ≤ 680 pt`.
- Respect `NSWorkspace.shared.accessibilityDisplayShouldReduceMotion`.

### Calendars (Foundation, no ICU strings needed)
| Setting | `Calendar.Identifier` |
|---|---|
| gregory | `.gregorian` |
| islamic | `.islamicUmmAlQura` |
| hebrew | `.hebrew` |
| buddhist | `.buddhist` |

- **Hebrew month ordinal:** Foundation numbers Hebrew months 1–13 with month 6 = Adar I (leap years only) and 7 = Adar / Adar II. Display the **ordinal within the year**: in a non-leap year, months ≥ 7 display as `month − 1` (Elul = 12); in a leap year display as is (Elul = 13). The "of 12 / of 13" sub-label follows the leap status.
- Localized date line, weekday, AM/PM: `DateFormatter` with `calendar` set and `locale` = `<lang>@numbers=latn`, then map digits per `i18n.json` (`arab`, `tibt`). For `bo` use the strings from `i18n.json` (Foundation has little Tibetan data).

### Auto calendar (recommended rule)
1. If the user's own macOS calendar (`Locale.current.calendar.identifier`, set in System Settings › General › Language & Region) is one of the four, use it. **This is the strongest signal.**
2. Else by time zone: `Asia/Jerusalem` → hebrew · `Asia/Bangkok` → buddhist · `Asia/Riyadh` → islamic.
3. Else **gregory**.

Other Muslim-majority countries use the Gregorian civil calendar day to day, and Iran/Afghanistan use the Solar Hijri (Persian) calendar, which is not in our set, so they fall to Gregorian.

### Location
- **No CoreLocation.** A screen saver cannot reliably show the location-permission prompt, and the spec doesn't need precise coordinates.
- City: last segment of `TimeZone.current.identifier`, localized where possible.
- Country: bundle IANA `zone1970.tab` (public domain, from tzdata) → time zone → ISO 3166 code → `Locale(identifier: lang).localizedString(forRegionCode:)`. This replaces the prototype's hard-coded city map.
- Coordinates: shown only if they come from the optional IP lookup (§VPN), rounded to 2 decimals (city level).
- Nothing resolvable (e.g. `GMT`) → "Location unknown" + zone id.

### VPN detection (recommended: two layers)
1. **Local check, default ON, no network, free.** Read the primary interface from `SCDynamicStore` key `State:/Network/Global/IPv4` (`PrimaryInterface`). If it is `utun*`, `ipsec*` or `ppp*` → VPN. Re-check on `SCDynamicStore` change notifications and on wake. macOS always has idle `utun0–3` (iCloud, Continuity), so check only the **primary** interface, never "any utun exists". Catches full-tunnel VPNs (WireGuard, OpenVPN, IKEv2, most commercial apps); misses split-tunnel setups.
2. **IP cross-check, default OFF (opt-in in Options).** Uses **IPLocate.io**: free tier 1,000 requests/day, returns `is_vpn`/`is_proxy`, `country_code`, `time_zone`. VPN if `is_vpn || is_proxy` or the IP's `time_zone`/country differs from the system's. Cache for 10 min, timeout 3 s, and on failure fall back to the local result. The user enters their own API key in Options, because one shared key in a distributed binary will hit the free limit. If you later ship with a company key, the lowest paid plan is $25/month for 100k requests, about 700 users at one lookup per 10 minutes of active screen saver.
- The real location is never shown or logged in VPN mode.

### Fonts and text
- Bundle in `Resources/Fonts`: JetBrains Mono (300/400/600), Noto Sans Hebrew, Noto Sans Arabic, Noto Serif Tibetan, Noto Sans JP. All are OFL; include the licenses. Register with `CTFontManagerRegisterFontsForURL(url, .process, nil)` at load.
- Build one `CTFontDescriptor` from JetBrains Mono with a `kCTFontCascadeListAttribute` of the Noto faces in token order, so mixed-script strings render correctly.
- Monospaced digits: JetBrains Mono digits are already tabular; for Noto faces use `kNumberSpacingType`/`kMonospacedNumbersSelector`.
- RTL (`he`, `ar`): mirror the layout manually (labels on the right, decimals on the left), `NSParagraphStyle.baseWritingDirection = .rightToLeft` for text. The bit grid and the readout stay LTR. Add LRM (`\u{200E}`) around readout separators for Arabic/Tibetan digits, and use `/` as the Arabic date separator.

### Settings (`configureSheet`)
- Storage: `ScreenSaverDefaults(forModuleWithName: bundleIdentifier)`.
- Controls: Language (Auto + 6, in their own names) · Time format (24/12) · Calendar (Auto + 4) · Theme (Dark/Light) · Bit shape (Dot/Square) · Location mode (Auto / Always space) · Online VPN check (off) + API key field.
- The control pills from the design are **not shown on the running screen saver** (any input dismisses it). Keep them in the debug host app (below) for design review.
- The sheet itself is localized via `i18n.json` + a few extra keys.

## 4. Project layout (suggested)

```
BinaryTime/
├── BinaryTime.xcodeproj
├── Saver/                     ← .saver target
│   ├── BinaryTimeView.swift   (ScreenSaverView subclass, lifecycle workarounds)
│   ├── ClockScene.swift       (layers, layout from tokens)
│   ├── ConfigureSheet.swift
│   └── Resources/ i18n.json, celestial-catalog.json, tokens.json, zone1970.tab, Fonts/
├── Core/                      ← pure Swift package, no AppKit — unit-testable
│   ├── BinaryModel.swift      (bit widths, place values, row states)
│   ├── CalendarService.swift  (auto rule, Hebrew ordinal, eras)
│   ├── Localization.swift     (i18n.json, digit mapping, bidi marks)
│   ├── LocationService.swift  (zone1970.tab, VPN local + IP)
│   └── Tokens.swift           (decoded tokens.json)
├── DebugHost/                 ← tiny app embedding BinaryTimeView in a resizable window, with the pills shown
└── Tests/                     ← Core tests + snapshot tests per language × theme × size
```

## 5. Definition of done (macOS-specific, in addition to SPEC §9)
- [ ] Installs by double-click; appears in Wallpaper › Screen Saver on Tahoe and later.
- [ ] No accumulating processes after 20 activate/dismiss cycles (Activity Monitor: one `legacyScreenSaver` per screen at most while running, none piling up after).
- [ ] Two monitors with different sizes and scales both render correctly.
- [ ] CPU < 5 % on an M1 at 60 Hz; memory stable over 8 h.
- [ ] VPN on/off switches mode within 5 s without reactivation.
- [ ] Signed with Developer ID, notarized, stapled.

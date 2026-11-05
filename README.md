# Binary Time

A macOS screen saver that shows the date and time in binary. Black and white only, six languages, four calendars.

Each row is one value: year, month and day, then hours, minutes and seconds. A filled dot is 1, an empty dot is 0,
and the most significant bit is on the left. The decimal value is next to every row, so you can check yourself.

- **Languages:** English, Русский, עברית, العربية, བོད་ཡིག, 日本語 (Auto follows the system language).
- **Calendars:** Gregorian, Islamic (Umm al-Qura), Hebrew, Buddhist (Auto follows the system calendar).
- **Location:** the city and country come from the Mac's time zone. When a VPN carries all traffic, the saver
  hides the real location and shows a space object instead.
- **Options:** language, 24 or 12 hours, calendar, dark or light theme, round or square bits, location mode.

Requires macOS 14 Sonoma or later, on Apple silicon or Intel.

## Install

1. Download `BinaryTime-<version>.dmg` from [Releases](https://github.com/amaklakov-droid/binary-time-screensaver/releases)
   and open it.
2. Double-click **Binary Time.saver**. macOS asks whether to install it for you only or for all users.
3. System Settings opens the screen saver list: **Wallpaper › Screen Saver** on macOS 26 and later,
   **Screen Saver** on Sonoma and Sequoia. Select **Binary Time**.
4. **Options…** next to the preview sets the language, calendar, theme and the rest.

**Update:** quit System Settings, then double-click the new `Binary Time.saver` and choose **Replace**. If the old
version still runs, log out and back in: macOS keeps screen saver code loaded in a background process.

**Uninstall:** in the screen saver list, Control-click **Binary Time** and choose **Delete "Binary Time"**, or delete
`Binary Time.saver` from `~/Library/Screen Savers` (or `/Library/Screen Savers` for all users).

## Privacy

- No network access. A future version may add an online VPN check; it will be off by default.
- No Location Services. The place shown comes from the time zone only.
- The VPN check reads which network interface is primary on this Mac; nothing leaves the computer.
- The settings are stored locally under `io.github.amaklakov-droid.binarytime`. The saver logs only why it
  quits, with no personal data.

## Known limitations

- The preview in System Settings is a still picture; the screen saver itself updates every second.
- The Hebrew, Arabic and Tibetan texts are drafts awaiting review by native speakers. Corrections are welcome.

## Development

Swift, AppKit and Core Animation; no web views. Logic lives in the AppKit-free `Packages/BinaryTimeCore` with unit
tests; `Packages/BinaryTimeUI` draws the scene; `Saver/` is the `.saver` bundle; `DebugHost/` is a resizable window
for design review with the control pills and keyboard shortcuts.

| File | What it is |
|---|---|
| `SPEC.md` | Product and visual behaviour; §9 is the acceptance checklist |
| `MACOS.md` | Stack, ScreenSaver.framework workarounds, API mapping |
| `TASK.md` | Milestones and definition of done (Russian) |
| `CLAUDE.md` | Rules for the coding agent |
| `design/tokens.json`, `data/*.json` | Design tokens, UI strings, space objects: the only sources of these values |
| `reference/screenshots/` | Reference renders from `prototype/` (still with the hundredths row, removed in 1.0) |
| `prototype/` | Behavioural reference in HTML/JS; not shipped |

```bash
brew install xcodegen
xcodegen generate                     # BinaryTime.xcodeproj from project.yml
(cd Packages/BinaryTimeCore && swift test)
(cd Packages/BinaryTimeUI && swift test)
xcodebuild -project BinaryTime.xcodeproj -scheme BinaryTimeSaver -configuration Release -derivedDataPath build/DerivedData build
```

Scripts: `fetch-fonts.sh` downloads the bundled fonts; `render-references.sh` and `render-thumbnail.sh` render
with DebugHost; `saver-cycles.sh`, `saver-cpu.sh` and `saver-soak.sh` check the installed saver;
`release.sh` builds, signs and notarizes the `.dmg` (see the comments at its top).

## License

MIT, see `LICENSE`. The bundled fonts are under the SIL Open Font License 1.1; see `THIRD-PARTY-NOTICES.md`.

---

## По-русски

Скринсейвер для macOS: дата и время в двоичном виде, только чёрное и белое, 6 языков, 4 календаря. Нужна macOS 14
Sonoma или новее.

**Установка.** Скачайте `BinaryTime-<версия>.dmg` из
[Releases](https://github.com/amaklakov-droid/binary-time-screensaver/releases), откройте его и дважды щёлкните
**Binary Time.saver**. macOS спросит, ставить ли только для вас или для всех пользователей. Затем в Системных
настройках выберите **Binary Time**: «Обои › Заставка» на macOS 26 и новее, «Заставка» на Sonoma и Sequoia.
Кнопка «Параметры…» открывает настройки.

**Обновление.** Закройте Системные настройки, дважды щёлкните новый `Binary Time.saver` и выберите «Заменить». Если
работает старая версия, выйдите из системы и войдите снова.

**Удаление.** В списке заставок щёлкните Binary Time с Control и выберите «Удалить», или удалите `Binary Time.saver`
из `~/Library/Screen Savers`.

**Приватность.** Скринсейвер не ходит в сеть и не использует службы геолокации: место берётся из часового пояса.

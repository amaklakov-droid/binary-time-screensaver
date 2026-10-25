# Bundled fonts

Font files for the screensaver live here and are copied into `Contents/Resources/Fonts` of the `.saver` and DebugHost.
Expected families (tokens `font.stack`): JetBrains Mono (300/400/600), Noto Sans Hebrew, Noto Sans Arabic,
Noto Serif Tibetan, Noto Sans JP. All are SIL Open Font License 1.1; keep each family's `OFL.txt` next to its files.

Until the files are added, `FontRegistry` falls back to the system monospace font and DebugHost prints a warning.

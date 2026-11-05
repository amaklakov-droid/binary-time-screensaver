# Third-party material

Binary Time's own code is under the MIT License (`LICENSE`). The screen saver also ships the material below.
Each font's full license text is bundled next to its files in `Fonts/<family>/OFL.txt` and inside the
`.saver` at `Contents/Resources/Fonts/<family>/OFL.txt`.

## Fonts (SIL Open Font License 1.1)

| Family | Files | Copyright |
|---|---|---|
| JetBrains Mono 2.304 | Light, Regular, SemiBold | Copyright 2020 The JetBrains Mono Project Authors (https://github.com/JetBrains/JetBrainsMono) |
| Noto Sans Hebrew | variable | Copyright 2022 The Noto Project Authors (https://github.com/notofonts/hebrew) |
| Noto Sans Arabic | variable | Copyright 2022 The Noto Project Authors (https://github.com/notofonts/arabic) |
| Noto Serif Tibetan | variable | Copyright 2022 The Noto Project Authors (https://github.com/notofonts/tibetan) |
| Noto Sans JP | variable | Copyright 2014-2021 Adobe (http://www.adobe.com/), with Reserved Font Name 'Source' |

The fonts are bundled unmodified. `Scripts/fetch-fonts.sh` downloads them from their upstream releases.

## Time zone data

`data/zone.tab` comes from the IANA Time Zone Database (tzdata) and is in the public domain.

## Space objects

`data/celestial-catalog.json` lists well-known astronomical objects with J2000 coordinates and surface
features of planets and moons. Names and positions are public scientific data; reference sources are SIMBAD
(https://simbad.cds.unistra.fr) and the USGS Gazetteer of Planetary Nomenclature
(https://planetarynames.wr.usgs.gov).

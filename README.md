# Binary Time — macOS screensaver · task package

Everything Claude Code needs to build the screensaver. Unpack this folder as the root of a new repository.

```
binary-time-screensaver/
├── CLAUDE.md                  ← project rules (Claude Code reads this automatically)
├── TASK.md                    ← the task: scope, milestones, acceptance (RU)
├── SPEC.md                    ← product + visual spec, acceptance checklist §9, decisions §10
├── MACOS.md                   ← macOS stack, ScreenSaver.framework workarounds, API mapping, layout
├── README.md                  ← this file
├── design/
│   ├── tokens.json            ← design system v1.0 (source of truth)
│   └── tokens.css             ← same tokens as CSS (used by the prototype)
├── data/
│   ├── i18n.json              ← UI copy: en, ru, he, ar, bo, ja + per-language rules
│   └── celestial-catalog.json ← 17 space objects for VPN mode
├── reference/screenshots/     ← 11 reference renders (languages, themes, ultrawide, portrait, narrow, DebugHost)
└── prototype/                 ← behavioural reference (vanilla HTML/CSS/JS), not shipped
```

## Starting Claude Code
1. Unpack the archive, `cd binary-time-screensaver`, `git init`.
2. Run `claude` in that folder and paste:

> Прочитай `CLAUDE.md` и `TASK.md`, затем `SPEC.md` и `MACOS.md`, посмотри `reference/screenshots/`. Предложи план работ по этапам из `TASK.md` и структуру Xcode-проекта. Код не пиши, пока я не подтвержу план.

## Prototype
Open `prototype/index.html` in a browser. URL parameters: `?lang=ar&theme=light&hourFormat=12&calendar=islamic&location=vpn&bitShape=square&showControls=0`. Keys: **L** language · **H** 12/24 · **C** calendar · **V** location · **I** invert · **S** controls.

After editing `data/*.json`, regenerate `prototype/data.js`:
```bash
python3 -c "import json;d={'i18n':json.load(open('data/i18n.json')),'catalog':json.load(open('data/celestial-catalog.json'))};open('prototype/data.js','w').write('/* GENERATED from ../data/*.json — do not edit by hand */\nwindow.BT_DATA = '+json.dumps(d,ensure_ascii=False)+';\n')"
```

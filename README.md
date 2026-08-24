# Balatro Mode Switcher

Windows tools to pick a **Balatro launch mode** before starting the game (Steam).

Each mode can control:

- **Lovely** on/off (`version.dll` ↔ `version.dll.disabled`)
- **Profile slot** (1–3 in `settings.jkr`)
- **Which mod folders are active** under `%AppData%\Balatro\Mods` (optional)

Modes are defined in a JSON config — add as many modpacks / setups as you want.

> Not affiliated with LocalThunk, Steam, or Balatro Multiplayer. Use with a legitimate Steam copy.

---

## Requirements

- Windows + PowerShell 5.1+
- [Balatro](https://store.steampowered.com/app/2379780/Balatro/) on Steam
- For any **modded** mode: Lovely (`version.dll`) installed next to `Balatro.exe` (e.g. via [Balatro Multiplayer](https://github.com/Balatro-Multiplayer/BalatroMultiplayer) / Multiplayer Launcher)
- Mods live in `%AppData%\Balatro\Mods`

---

## Linux (Proton)

Balatro on Linux runs under **Proton** (no official native build). Use the bash tools:

→ See **[linux/README.md](linux/README.md)**

```bash
cd linux && chmod +x *.sh lib/*.sh lib/*.py
./setup-steam-launch.sh
./balatro-mode.sh
```

Optional per-mode Proton tool via `"proton": "proton_experimental"` in `modes.json`.

---

## Quick start (Windows)

1. Clone or download this repo.
2. Close Balatro.
3. Double-click:

| File | Action |
|------|--------|
| **`Balatro Mode.bat`** | Menu from your config → apply → launch |
| **`Balatro-Singleplayer.bat`** | Apply mode id `vanilla` + launch |
| **`Balatro-Multiplayer.bat`** | Apply mode id `multiplayer` + launch |
| **`Balatro-Status.bat`** | List config modes + Lovely status |
| **`Edit-Modes-Config.bat`** | Open `modes.json` in Notepad |
| **`Setup-Steam-Launch-Menu.bat`** | Install Steam Play wrapper + config copy |

---

## Custom modes (`modes.json`)

### Where the config lives

First file found wins:

1. `%LocalAppData%\BalatroMode\modes.json` (created by Setup — best for Steam Play)
2. `config\modes.json` in this repo

Template with extra examples: [`config/modes.example.json`](config/modes.example.json)

### Schema

```json
{
  "gameDir": "",
  "modsDir": "",
  "modes": [
    {
      "id": "vanilla",
      "label": "Single-player (vanilla)",
      "description": "Lovely off — stock Balatro",
      "lovely": false,
      "profile": 1
    },
    {
      "id": "multiplayer",
      "label": "Multiplayer",
      "description": "Lovely on — SMODS + Multiplayer",
      "lovely": true,
      "profile": 2,
      "enabledMods": ["smods", "multiplayer*"]
    },
    {
      "id": "my-pack",
      "label": "My modpack",
      "lovely": true,
      "profile": 3,
      "enabledMods": ["smods", "Cryptid", "Talisman"]
    }
  ]
}
```

| Field | Meaning |
|-------|---------|
| `id` | Stable id for shortcuts (`-ModeId my-pack`) |
| `label` | Text shown in the menu |
| `description` | Optional subtitle |
| `lovely` | `true` = enable Lovely; `false` = disable |
| `profile` | Optional Balatro profile slot `1`–`3` |
| `enabledMods` | Optional. If set, **only** matching mod folders stay active; others are renamed to `Name.disabled`. Supports `*` / `?` globs. Omit the field to leave Mods untouched. |
| `gameDir` / `modsDir` | Optional per-mode overrides (else top-level / auto-detect) |
| `proton` | **Linux only.** Steam compat tool name (`proton_experimental`, `proton_9`, GE folder name, …). Omit to leave Steam’s setting alone. |

**Notes**

- The `lovely` dump folder under Mods is never disabled.
- Close Balatro before switching.
- After Steam updates, Lovely may need reinstalling if `version.dll` disappears.

### Example: add a third modpack

1. Install the mods into `%AppData%\Balatro\Mods`.
2. Run **`Edit-Modes-Config.bat`** (or edit `%LocalAppData%\BalatroMode\modes.json`).
3. Append a mode with `"enabledMods": ["smods", "YourMod", ...]`.
4. Save. Next Steam Play / `Balatro Mode.bat` shows the new entry.

Shortcut for a fixed mode (create your own `.bat`):

```bat
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\Invoke-BalatroMode.ps1" -ModeId my-pack -Launch
```

---

## Steam Play menu

1. Run **`Setup-Steam-Launch-Menu.bat`** (copies scripts + `modes.json` into `%LocalAppData%\BalatroMode\`).
2. Steam → Balatro → Properties → **Launch Options** → paste the copied line, e.g.

```text
C:\Windows\System32\cmd.exe /c C:\Users\<YOU>\AppData\Local\BalatroMode\steam-gate.cmd %command%
```

3. **Play** → choose a mode from your config.

**Undo:** clear Launch Options.

**Log:** `Open-SteamGate-Log.bat` or `%LocalAppData%\BalatroMode\steam-gate.log`

---

## Repo layout

```text
.
├── README.md
├── LICENSE
├── Balatro Mode.bat
├── Balatro-Singleplayer.bat      # ModeId=vanilla
├── Balatro-Multiplayer.bat       # ModeId=multiplayer
├── Balatro-Status.bat
├── Edit-Modes-Config.bat
├── Setup-Steam-Launch-Menu.bat
├── Open-SteamGate-Log.bat
├── config/
│   ├── modes.json                # default (vanilla + multiplayer)
│   └── modes.example.json        # extra examples
├── scripts/                      # Windows engine
│   ├── Invoke-BalatroMode.ps1
│   ├── Balatro-SteamGate.bat
│   ├── steam-gate-ui.cmd
│   ├── Set-BalatroProfile.ps1
│   └── balatro-mode.ps1
└── linux/                        # Linux / Proton (see linux/README.md)
    ├── balatro-mode.sh
    ├── steam-gate.sh
    └── lib/
```

### CLI

```powershell
.\scripts\Invoke-BalatroMode.ps1 -List
.\scripts\Invoke-BalatroMode.ps1 -Menu -Launch
.\scripts\Invoke-BalatroMode.ps1 -ModeId multiplayer -Launch
```

---

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| Play does nothing | Re-run Setup; check Launch Options; read `steam-gate.log` |
| Unknown mode id | Ids must match `modes.json`; shortcuts use `vanilla` / `multiplayer` by default |
| Wrong mods loaded | Set `enabledMods` on that mode; check for `*.disabled` folders in Mods |
| Cannot rename `version.dll` | Close game; run as Administrator |
| Profile not changing | Close Balatro; ensure `settings.jkr` exists (launch once normally) |

---

## Disclaimer

Renaming files under the Balatro install / Mods folder and editing `settings.jkr` is at your own risk. Keep backups / Steam Cloud in mind.

---

## Publishing this repo to GitHub

```powershell
cd path\to\balatro_mod
git add .
git commit -m "Your message"
git push -u origin main
```

---

## License

MIT — see [LICENSE](LICENSE).

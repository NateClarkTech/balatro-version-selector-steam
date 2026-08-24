# Balatro Mode Switcher

Windows helpers to switch **Steam Balatro** between:

| Mode | Lovely / mods | Profile slot |
|------|----------------|--------------|
| **Single-player** | Off (`version.dll` → `version.dll.disabled`) | **1** |
| **Multiplayer** | On (Lovely + SMODS + Balatro Multiplayer) | **2** |

Also optional: a **Steam Play menu** so clicking Play asks vanilla vs modded.

> Not affiliated with LocalThunk, Steam, or Balatro Multiplayer. For personal use with a legitimate Steam copy.

---

## Requirements

- Windows
- [Balatro](https://store.steampowered.com/app/2379780/Balatro/) on Steam
- For multiplayer: [Balatro Multiplayer](https://github.com/Balatro-Multiplayer/BalatroMultiplayer) (or the Multiplayer Launcher) so that:
  - `version.dll` (Lovely) exists next to `Balatro.exe`
  - `%AppData%\Balatro\Mods` contains **smods** and **multiplayer\***
- PowerShell 5.1+ (built into Windows 10/11)

---

## Quick start (double-click)

1. Download or clone this repo anywhere you like.
2. Close Balatro if it is open.
3. Double-click one of:

| File | Action |
|------|--------|
| **`Balatro Mode.bat`** | Menu: switch and/or launch |
| **`Balatro-Singleplayer.bat`** | Vanilla + profile 1 + launch via Steam |
| **`Balatro-Multiplayer.bat`** | Modded + profile 2 + launch via Steam |
| **`Balatro-Status.bat`** | Show current Lovely on/off state |

If renaming `version.dll` fails, right-click → **Run as administrator**, or fix permissions on the Balatro install folder.

---

## Optional: Steam Play menu (vanilla vs modded)

This makes **Steam → Play** open a small console asking `[1] Single-player` / `[2] Multiplayer`.

### Setup

1. Double-click **`Setup-Steam-Launch-Menu.bat`**.
   - Copies scripts into `%LocalAppData%\BalatroMode\`
   - Copies the Launch Options line to your clipboard
2. Steam Library → right-click **Balatro** → **Properties** → **Launch Options**
3. Clear the box, paste **exactly**:

```text
C:\Windows\System32\cmd.exe /c C:\Users\<YOU>\AppData\Local\BalatroMode\steam-gate.cmd %command%
```

(Use the line Setup printed / copied — it already has your username.)

4. Click **Play**. A window titled **Balatro Mode** should appear.

### Undo

Clear Balatro’s **Launch Options** field.

### Logs

If Play does nothing or fails:

- Double-click **`Open-SteamGate-Log.bat`**, or open  
  `%LocalAppData%\BalatroMode\steam-gate.log`

---

## How it works

1. **Mods on/off**  
   Balatro Multiplayer loads via the Lovely injector (`version.dll` beside `Balatro.exe`).  
   Single-player renames that DLL to `version.dll.disabled`. Mods stay in `%AppData%\Balatro\Mods` but do not load without Lovely.

2. **Profile slots**  
   The last-used profile is stored in `%AppData%\Balatro\settings.jkr` as `["profile"]=N`.  
   Scripts patch that file (deflate-compressed Lua table) before launch:
   - single-player → profile **1**
   - multiplayer → profile **2**

3. **Steam gate**  
   Launch Options wrap the real game command so a visible console can ask which mode to use, then start `Balatro.exe`.

---

## Repo layout

```text
.
├── README.md
├── LICENSE
├── Setup-Steam-Launch-Menu.bat   # one-time Steam Play setup
├── Balatro Mode.bat              # offline menu
├── Balatro-Singleplayer.bat
├── Balatro-Multiplayer.bat
├── Balatro-Status.bat
├── Open-SteamGate-Log.bat
└── scripts/
    ├── Balatro-SteamGate.bat     # installed as steam-gate.cmd
    ├── steam-gate-ui.cmd         # menu + mode + profile + launch
    ├── Set-BalatroProfile.ps1    # edit settings.jkr profile slot
    └── balatro-mode.ps1          # optional CLI (status / switch)
```

### Optional PowerShell CLI

```powershell
cd path\to\balatro_mod
.\scripts\balatro-mode.ps1 status
.\scripts\balatro-mode.ps1 singleplayer
.\scripts\balatro-mode.ps1 multiplayer -Launch
.\scripts\Set-BalatroProfile.ps1 -Profile 1
```

---

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| Play does nothing | Re-run Setup; check Launch Options; open `steam-gate.log` |
| `...SteamGate.bat C:\Program` error | Do **not** wrap `%command%` inside the same quotes as the script path |
| Cannot rename `version.dll` | Close Balatro; run as admin |
| Wrong profile | Confirm slots 1/2 in-game; ensure game was closed when switching |
| Multiplayer missing after Steam update | Steam may overwrite `version.dll` — reinstall Lovely / Multiplayer Launcher, then use Multiplayer mode again |
| Profile script errors | Launch Balatro once normally so `settings.jkr` exists |

---

## Disclaimer

- Renaming files under `steamapps\common\Balatro` and editing `settings.jkr` is at your own risk. Keep Steam Cloud / backups in mind.
- After a Balatro update, re-check Lovely and Launch Options.
- This does not redistribute Balatro, Lovely, SMODS, or the multiplayer mod.

---

## Publishing this repo to GitHub

```powershell
cd path\to\balatro_mod
git init
git add .
git commit -m "Initial commit: Balatro vanilla/multiplayer mode switcher"
gh repo create balatro-mode-switcher --public --source=. --remote=origin --push
```

Or create an empty repo on github.com first, then:

```powershell
git remote add origin https://github.com/<you>/<repo>.git
git branch -M main
git push -u origin main
```

---

## License

MIT — see [LICENSE](LICENSE).

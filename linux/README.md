# Balatro Mode Switcher - Linux (Proton)

Balatro has **no official native Linux build**; it runs under **Steam Play / Proton**.  
These bash scripts mirror the Windows tool: pick a mode from `modes.json`, then launch.

## Dependencies

```bash
# Debian/Ubuntu
sudo apt install jq python3

# Fedora
sudo dnf install jq python3

# Arch
sudo pacman -S jq python
```

Also: Steam with Balatro installed, launched **at least once** under Proton (creates `compatdata/2379780`).

## Quick start

```bash
cd linux
chmod +x *.sh lib/*.sh lib/*.py
./setup-steam-launch.sh    # installs config + prints Launch Options line
./balatro-mode.sh          # menu → apply → launch
# or
./balatro-singleplayer.sh
./balatro-multiplayer.sh
./balatro-status.sh
./list-proton.sh           # installed Proton / GE tool names
```

## Steam Play menu

1. Run `./setup-steam-launch.sh`
2. Steam → Balatro → Properties → **Launch Options** → paste something like:

```text
/home/YOU/.../balatro_mod/linux/steam-gate.sh %command%
```

3. Click **Play** → choose a mode → game starts.

## Paths (Proton)

| What | Typical path |
|------|----------------|
| Game (`Balatro.exe`, `version.dll`) | `.../steamapps/common/Balatro/` |
| Mods / `settings.jkr` | `.../steamapps/compatdata/2379780/pfx/drive_c/users/steamuser/AppData/Roaming/Balatro/` |
| User config | `~/.local/share/balatro-mode/modes.json` |
| Log | `~/.local/share/balatro-mode/balatro-mode.log` |

Flatpak Steam uses `~/.var/app/com.valvesoftware.Steam/data/Steam` (auto-detected).

## Config: modes + optional Proton

Same `modes.json` schema as Windows, plus optional **`proton`**:

```json
{
  "id": "multiplayer",
  "label": "Multiplayer",
  "lovely": true,
  "profile": 2,
  "enabledMods": ["smods", "multiplayer*"],
  "proton": "proton_experimental"
}
```

| `proton` value | Effect |
|----------------|--------|
| omitted | Do not change Steam’s compat tool |
| `"proton_experimental"`, `"proton_9"`, … | Force that Steam Proton tool for app `2379780` |
| `"GE-Proton9-25"` (etc.) | Force a tool from `compatibilitytools.d` |
| `"default"` / `"none"` / `""` | Clear override (Steam default) |

Tool names are listed by `./list-proton.sh`.

**Important:** editing `config.vdf` while Steam is open can be overwritten when Steam exits. Prefer:

1. Close Steam  
2. Apply a mode that sets `proton` (or run the helper)  
3. Start Steam and play  

You can also set Proton in Steam → Properties → Compatibility; the config field is for automation per mode.

## Files

```text
linux/
  balatro-mode.sh
  balatro-singleplayer.sh
  balatro-multiplayer.sh
  balatro-status.sh
  list-proton.sh
  setup-steam-launch.sh
  edit-modes-config.sh
  steam-gate.sh
  lib/
    balatro-common.sh
    balatro-engine.sh
    set-profile.py
    set-proton.py
```

#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${DIR}/lib/balatro-common.sh"

bash "${DIR}/lib/balatro-engine.sh" list
echo
if game="$(find_balatro_game_dir 2>/dev/null)"; then
  echo "Game: $game"
  if [[ -f "$game/version.dll" ]]; then
    echo "Lovely: ACTIVE"
  elif [[ -f "$game/version.dll.disabled" ]]; then
    echo "Lovely: disabled"
  else
    echo "Lovely: missing"
  fi
else
  echo "Game: (not found)"
fi
if mods="$(default_mods_dir 2>/dev/null)"; then
  echo "Mods: $mods"
  if [[ -d "$mods" ]]; then
    echo "Mod folders:"
    find "$mods" -mindepth 1 -maxdepth 1 -type d -printf '  %f\n' 2>/dev/null || ls -1 "$mods"
  fi
fi
if root="$(find_steam_root 2>/dev/null)"; then
  echo "Steam: $root"
  if [[ -f "$root/config/config.vdf" ]]; then
    echo "Current CompatToolMapping for $BALATRO_APPID:"
    sed -n "/CompatToolMapping/,/^[[:space:]]*}/p" "$root/config/config.vdf" | grep -A5 "\"$BALATRO_APPID\"" || echo "  (none / Steam default)"
  fi
fi

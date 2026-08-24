#!/usr/bin/env bash
# Shared helpers for Balatro mode switcher (Linux / Proton).
# shellcheck disable=SC2034

set -euo pipefail

BALATRO_APPID="${BALATRO_APPID:-2379780}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LINUX_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
REPO_ROOT="$(cd "${LINUX_ROOT}/.." && pwd)"
INSTALL_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/balatro-mode"
LOG_FILE="${INSTALL_DIR}/balatro-mode.log"
STEAM_APPID="$BALATRO_APPID"

mkdir -p "$INSTALL_DIR"

log() {
  local msg="[$(date '+%Y-%m-%d %H:%M:%S')] $*"
  printf '%s\n' "$msg" | tee -a "$LOG_FILE" >/dev/null
  printf '%s\n' "$*"
}

die() {
  log "ERROR: $*"
  exit 1
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "Missing dependency: $1"
}

find_steam_root() {
  local c
  for c in \
    "${STEAM_ROOT:-}" \
    "$HOME/.steam/steam" \
    "$HOME/.local/share/Steam" \
    "$HOME/.steam/root" \
    "$HOME/.var/app/com.valvesoftware.Steam/data/Steam"
  do
    [[ -n "$c" && -d "$c" ]] || continue
    if [[ -f "$c/steamapps/libraryfolders.vdf" || -d "$c/steamapps" ]]; then
      printf '%s\n' "$c"
      return 0
    fi
  done
  return 1
}

# Print steam library roots (paths containing steamapps/)
list_steam_libraries() {
  local root libfolders line path
  root="$(find_steam_root)" || return 1
  printf '%s\n' "$root"
  libfolders="$root/steamapps/libraryfolders.vdf"
  [[ -f "$libfolders" ]] || return 0
  # "path"	"/some/path"
  while IFS= read -r line; do
    if [[ "$line" =~ \"path\"[[:space:]]*\"([^\"]+)\" ]]; then
      path="${BASH_REMATCH[1]}"
      path="${path//\\\\//}"
      [[ -d "$path/steamapps" ]] && printf '%s\n' "$path"
    fi
  done < "$libfolders"
}

find_balatro_game_dir() {
  local lib
  while IFS= read -r lib; do
    if [[ -x "$lib/steamapps/common/Balatro/Balatro.exe" || -f "$lib/steamapps/common/Balatro/Balatro.exe" ]]; then
      printf '%s\n' "$lib/steamapps/common/Balatro"
      return 0
    fi
  done < <(list_steam_libraries)
  return 1
}

# Proton prefix for Balatro (Windows AppData lives here)
find_compatdata() {
  local lib
  while IFS= read -r lib; do
    if [[ -d "$lib/steamapps/compatdata/$BALATRO_APPID" ]]; then
      printf '%s\n' "$lib/steamapps/compatdata/$BALATRO_APPID"
      return 0
    fi
  done < <(list_steam_libraries)
  return 1
}

default_mods_dir() {
  local compat pfx
  compat="$(find_compatdata)" || die "compatdata for app $BALATRO_APPID not found. Launch Balatro once under Proton first."
  pfx="$compat/pfx/drive_c/users/steamuser/AppData/Roaming/Balatro/Mods"
  printf '%s\n' "$pfx"
}

default_settings_jkr() {
  local compat
  compat="$(find_compatdata)" || die "compatdata for app $BALATRO_APPID not found."
  printf '%s\n' "$compat/pfx/drive_c/users/steamuser/AppData/Roaming/Balatro/settings.jkr"
}

resolve_config_path() {
  local c
  for c in \
    "${BALATRO_MODES_CONFIG:-}" \
    "$INSTALL_DIR/modes.json" \
    "$REPO_ROOT/config/modes.json" \
    "$LINUX_ROOT/modes.json"
  do
    [[ -n "$c" && -f "$c" ]] || continue
    printf '%s\n' "$c"
    return 0
  done
  die "No modes.json found. Copy config/modes.example.json to $INSTALL_DIR/modes.json"
}

require_jq() {
  need_cmd jq
}

balatro_running() {
  pgrep -f '[Bb]alatro\.exe' >/dev/null 2>&1 || pgrep -x Balatro >/dev/null 2>&1
}

#!/usr/bin/env bash
# Apply a Balatro mode from modes.json (Linux / Proton).
# Usage:
#   balatro-engine.sh list
#   balatro-engine.sh menu [--launch]
#   balatro-engine.sh apply <mode-id> [--launch]
#   balatro-engine.sh list-proton
#
# shellcheck source=balatro-common.sh

set -euo pipefail

LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${LIB_DIR}/balatro-common.sh"

LAUNCH=0
MODE_ID=""
ACTION=""

usage() {
  cat <<EOF
Usage: $(basename "$0") <list|menu|apply|list-proton> [mode-id] [--launch]

  list          Show modes from config
  menu          Interactive picker (implies launch unless --no-launch)
  apply <id>    Apply mode by id
  list-proton   Show installed Proton / compat tools
EOF
}

parse_args() {
  [[ $# -ge 1 ]] || { usage; exit 1; }
  ACTION="$1"
  shift
  local no_launch=0
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --launch) LAUNCH=1; shift ;;
      --no-launch) no_launch=1; shift ;;
      -h|--help) usage; exit 0 ;;
      *)
        if [[ -z "$MODE_ID" && "$ACTION" == "apply" ]]; then
          MODE_ID="$1"; shift
        else
          die "Unknown arg: $1"
        fi
        ;;
    esac
  done
  if [[ "$ACTION" == "menu" && "$no_launch" -eq 0 ]]; then
    LAUNCH=1
  fi
}

list_proton_tools() {
  local root lib
  root="$(find_steam_root)" || die "Steam root not found"
  echo "Steam root: $root"
  echo
  echo "Official / library Proton folders:"
  while IFS= read -r lib; do
    local d
    for d in "$lib"/steamapps/common/Proton*; do
      [[ -e "$d" ]] || continue
      echo "  $(basename "$d")"
    done
  done < <(list_steam_libraries)
  echo
  echo "Custom tools (compatibilitytools.d):"
  local ctd
  for ctd in "$root/compatibilitytools.d" "$HOME/.steam/root/compatibilitytools.d"; do
    [[ -d "$ctd" ]] || continue
    local t
    for t in "$ctd"/*; do
      [[ -d "$t" ]] || continue
      echo "  $(basename "$t")"
    done
  done
  echo
  echo "Common Steam tool names for config \"proton\":"
  echo "  proton_experimental  proton_hotfix  proton_10  proton_9  proton_8"
  echo "  (or exact GE folder name, e.g. GE-Proton9-25)"
}

glob_match() {
  # $1 name  $2 pattern with * ?
  local name="$1" pat="$2"
  case "$name" in
    $pat) return 0 ;;
    *) return 1 ;;
  esac
}

base_mod_name() {
  local n="$1"
  if [[ "$n" == *.disabled ]]; then
    printf '%s\n' "${n%.disabled}"
  else
    printf '%s\n' "$n"
  fi
}

set_lovely() {
  local game_dir="$1" enabled="$2"
  local on="$game_dir/version.dll"
  local off="$game_dir/version.dll.disabled"

  if [[ "$enabled" == "true" || "$enabled" == "1" ]]; then
    if [[ -f "$on" ]]; then
      log "Lovely already active."
      return 0
    fi
    if [[ -f "$off" ]]; then
      mv -f "$off" "$on"
      log "Lovely enabled (version.dll.disabled -> version.dll)."
      return 0
    fi
    die "Lovely not found in $game_dir (need version.dll or version.dll.disabled)."
  fi

  if [[ -f "$off" ]]; then
    if [[ -f "$on" ]]; then
      rm -f "$on"
      log "Removed active version.dll; left version.dll.disabled."
    else
      log "Lovely already disabled."
    fi
    return 0
  fi
  if [[ -f "$on" ]]; then
    mv -f "$on" "$off"
    log "Lovely disabled (version.dll -> version.dll.disabled)."
    return 0
  fi
  log "No version.dll present - already vanilla."
}

set_enabled_mods() {
  local mods_dir="$1"
  shift
  local patterns=("$@")

  if [[ ${#patterns[@]} -eq 0 ]]; then
    log "No enabledMods - leaving Mods unchanged."
    return 0
  fi
  [[ -d "$mods_dir" ]] || { log "WARN: Mods dir missing: $mods_dir"; return 0; }

  local d base should name
  for d in "$mods_dir"/*/; do
    [[ -d "$d" ]] || continue
    name="$(basename "$d")"
    base="$(base_mod_name "$name")"
    if [[ "${base,,}" == "lovely" ]]; then
      if [[ "$name" == *.disabled ]]; then
        mv -f "$d" "$mods_dir/$base" 2>/dev/null || true
      fi
      continue
    fi

    should=0
    local pat
    for pat in "${patterns[@]}"; do
      if glob_match "$base" "$pat"; then
        should=1
        break
      fi
    done

    if [[ "$should" -eq 1 ]]; then
      if [[ "$name" == *.disabled ]]; then
        if [[ -e "$mods_dir/$base" ]]; then
          log "WARN: cannot enable $name - $base exists"
        else
          mv -f "$d" "$mods_dir/$base"
          log "Mod enabled: $base"
        fi
      else
        log "Mod already active: $base"
      fi
    else
      if [[ "$name" == *.disabled ]]; then
        log "Mod already disabled: $base"
      else
        if [[ -e "$mods_dir/$base.disabled" ]]; then
          log "WARN: cannot disable $base - ${base}.disabled exists"
        else
          mv -f "$d" "$mods_dir/$base.disabled"
          log "Mod disabled: $base -> ${base}.disabled"
        fi
      fi
    fi
  done
}

set_proton_tool() {
  local tool="${1:-}"
  local root
  root="$(find_steam_root)" || die "Steam root not found"
  need_cmd python3
  log "Setting Steam compat tool for app $BALATRO_APPID -> ${tool:-default}"
  python3 "${LIB_DIR}/set-proton.py" --steam-root "$root" --appid "$BALATRO_APPID" --tool "$tool"
}

apply_mode() {
  local id="$1"
  local cfg game_dir mods_dir settings lovely profile proton
  local -a enabled_mods=()

  require_jq
  need_cmd python3
  cfg="$(resolve_config_path)"
  log "Config: $cfg"

  if balatro_running; then
    die "Balatro appears to be running - close it first."
  fi

  local mode_json
  mode_json="$(jq -c --arg id "$id" '.modes[] | select(.id == $id)' "$cfg")"
  [[ -n "$mode_json" ]] || die "Unknown mode id: $id (use list)"

  local cfg_game cfg_mods
  cfg_game="$(jq -r '.gameDir // empty' "$cfg")"
  cfg_mods="$(jq -r '.modsDir // empty' "$cfg")"
  game_dir="$(jq -r '.gameDir // empty' <<<"$mode_json")"
  mods_dir="$(jq -r '.modsDir // empty' <<<"$mode_json")"
  [[ -n "$game_dir" ]] || game_dir="$cfg_game"
  [[ -n "$mods_dir" ]] || mods_dir="$cfg_mods"
  if [[ -z "$game_dir" ]]; then
    game_dir="$(find_balatro_game_dir)" || die "Balatro game dir not found. Set gameDir in modes.json."
  fi
  if [[ -z "$mods_dir" ]]; then
    mods_dir="$(default_mods_dir)"
  fi
  settings="$(default_settings_jkr)"

  lovely="$(jq -r 'if has("lovely") then (.lovely|tostring) else "true" end' <<<"$mode_json")"
  profile="$(jq -r '.profile // empty' <<<"$mode_json")"
  proton="$(jq -r '.proton // empty' <<<"$mode_json")"

  mapfile -t enabled_mods < <(jq -r '.enabledMods // empty | if . == null then empty elif type=="array" then .[] else empty end' <<<"$mode_json")

  log "Applying mode id=$id"
  log "GameDir: $game_dir"
  log "ModsDir: $mods_dir"

  if [[ -n "$proton" ]]; then
    set_proton_tool "$proton"
  else
    log "No proton field - leaving Steam compat tool unchanged."
  fi

  set_lovely "$game_dir" "$lovely"

  if [[ -n "$profile" ]]; then
    log "Setting profile slot $profile"
    python3 "${LIB_DIR}/set-profile.py" --settings "$settings" --profile "$profile"
  else
    log "No profile in mode - leaving settings.jkr unchanged."
  fi

  if [[ ${#enabled_mods[@]} -gt 0 ]]; then
    set_enabled_mods "$mods_dir" "${enabled_mods[@]}"
  else
    set_enabled_mods "$mods_dir"
  fi

  log "Mode ready: $id"
}

launch_balatro() {
  log "Launching Balatro via Steam (app $BALATRO_APPID)..."
  if command -v steam >/dev/null 2>&1; then
    steam "steam://rungameid/$BALATRO_APPID" >/dev/null 2>&1 &
  elif command -v flatpak >/dev/null 2>&1 && flatpak info com.valvesoftware.Steam >/dev/null 2>&1; then
    flatpak run com.valvesoftware.Steam "steam://rungameid/$BALATRO_APPID" >/dev/null 2>&1 &
  else
    die "steam command not found. Start Balatro from Steam manually."
  fi
}

cmd_list() {
  require_jq
  local cfg
  cfg="$(resolve_config_path)"
  echo "Config: $cfg"
  jq -r '
    .modes
    | to_entries[]
    | "[\(.key+1)] id=\(.value.id)  label=\(.value.label)  lovely=\(.value.lovely // "?")  profile=\(.value.profile // "-")  proton=\(.value.proton // "(unchanged)")  mods=\((.value.enabledMods // [])|join(", "))"
  ' "$cfg"
}

cmd_menu() {
  require_jq
  local cfg n choice
  cfg="$(resolve_config_path)"
  echo
  echo "  ========================================"
  echo "   BALATRO MODE SELECTOR (Linux / Proton)"
  echo "  ========================================"
  echo
  jq -r '
    .modes
    | to_entries[]
    | "  [\(.key+1)]  \(.value.label)" + (if .value.description then " - \(.value.description)" else "" end)
  ' "$cfg"
  echo "  [0]  Cancel"
  echo
  read -r -p "  Choose: " choice
  [[ "$choice" == "0" || -z "$choice" ]] && { log "Cancelled."; exit 0; }
  [[ "$choice" =~ ^[0-9]+$ ]] || die "Invalid choice"
  n=$((choice - 1))
  MODE_ID="$(jq -r --argjson i "$n" '.modes[$i].id // empty' "$cfg")"
  [[ -n "$MODE_ID" ]] || die "Invalid choice"
  apply_mode "$MODE_ID"
  [[ "$LAUNCH" -eq 1 ]] && launch_balatro
}

main() {
  parse_args "$@"
  mkdir -p "$INSTALL_DIR"
  case "$ACTION" in
    list) cmd_list ;;
    list-proton) list_proton_tools ;;
    apply)
      [[ -n "$MODE_ID" ]] || die "apply requires mode id"
      apply_mode "$MODE_ID"
      [[ "$LAUNCH" -eq 1 ]] && launch_balatro
      ;;
    menu) cmd_menu ;;
    *) usage; exit 1 ;;
  esac
}

main "$@"

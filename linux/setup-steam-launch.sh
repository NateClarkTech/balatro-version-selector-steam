#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "${DIR}/.." && pwd)"
# shellcheck disable=SC1091
source "${DIR}/lib/balatro-common.sh"

mkdir -p "$INSTALL_DIR"

# Install config if missing
if [[ ! -f "$INSTALL_DIR/modes.json" ]]; then
  if [[ -f "$REPO/config/modes.json" ]]; then
    cp -f "$REPO/config/modes.json" "$INSTALL_DIR/modes.json"
  else
    cp -f "$REPO/config/modes.example.json" "$INSTALL_DIR/modes.json"
  fi
  echo "Installed config: $INSTALL_DIR/modes.json"
else
  echo "Keeping existing config: $INSTALL_DIR/modes.json"
fi

GATE="$(readlink -f "${DIR}/steam-gate.sh")"
chmod +x \
  "$DIR"/*.sh \
  "$DIR/lib"/*.sh \
  "$DIR/lib"/*.py 2>/dev/null || true

LINE="${GATE} %command%"

echo
echo "============================================================"
echo " Steam Balatro launch menu (Linux / Proton)"
echo "============================================================"
echo
echo " Dependencies: bash, jq, python3"
echo " Config: $INSTALL_DIR/modes.json"
echo " Log:    $INSTALL_DIR/balatro-mode.log"
echo
echo " Paste this into Steam -> Balatro -> Properties -> Launch Options:"
echo
echo "  $LINE"
echo
echo " Optional per-mode Proton: set \"proton\" in modes.json"
echo "   e.g. \"proton\": \"proton_experimental\""
echo "   Run ./list-proton.sh to see installed tools."
echo
echo " Prefer closing Steam before changing Proton via this tool,"
echo " then reopen Steam so CompatToolMapping is picked up."
echo

if command -v xclip >/dev/null 2>&1; then
  printf '%s' "$LINE" | xclip -selection clipboard && echo "Copied to clipboard (xclip)."
elif command -v wl-copy >/dev/null 2>&1; then
  printf '%s' "$LINE" | wl-copy && echo "Copied to clipboard (wl-copy)."
else
  echo "(Install xclip or wl-copy to auto-copy the launch line.)"
fi

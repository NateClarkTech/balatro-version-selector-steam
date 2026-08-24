#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${DIR}/lib/balatro-common.sh"
REPO="$(cd "${DIR}/.." && pwd)"

cfg="$INSTALL_DIR/modes.json"
if [[ ! -f "$cfg" ]]; then
  mkdir -p "$INSTALL_DIR"
  if [[ -f "$REPO/config/modes.json" ]]; then
    cp -f "$REPO/config/modes.json" "$cfg"
  else
    cp -f "$REPO/config/modes.example.json" "$cfg"
  fi
fi

editor="${EDITOR:-${VISUAL:-nano}}"
echo "Opening: $cfg"
exec "$editor" "$cfg"

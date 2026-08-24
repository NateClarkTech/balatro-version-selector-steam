#!/usr/bin/env bash
# Steam Launch Options wrapper (Linux):
#   /full/path/to/linux/steam-gate.sh %command%
#
# Shows the config mode menu, applies lovely/profile/mods/proton, then runs Steam's command.
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${DIR}/lib/balatro-common.sh"
mkdir -p "$INSTALL_DIR"
LOG_FILE="${INSTALL_DIR}/balatro-mode.log"

log "Steam gate start args=$*"

# Interactive menu without auto steam:// launch - we exec %command% instead
bash "${DIR}/lib/balatro-engine.sh" menu --no-launch

rc=$?
if [[ $rc -ne 0 ]]; then
  log "Mode apply failed rc=$rc"
  exit "$rc"
fi

if [[ $# -eq 0 ]]; then
  log "No %command% from Steam - launching via steam:// "
  if command -v steam >/dev/null 2>&1; then
    exec steam "steam://rungameid/$BALATRO_APPID"
  fi
  die "Nothing to exec"
fi

log "Executing Steam command..."
exec "$@"

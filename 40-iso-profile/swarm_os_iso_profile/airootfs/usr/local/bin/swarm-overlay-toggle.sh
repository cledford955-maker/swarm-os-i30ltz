#!/bin/sh
# Toggles the SWARM Overlay dashboard (now-playing, Lucille chat) on/off.
# Bound to Shift+Tab in labwc (Steam's own overlay convention) — see rc.xml.
#
# Deliberately kill-and-relaunch rather than show/hide: swarm-overlay has no
# background/hidden mode today, it just opens a visible window immediately.
# A future version could keep it running invisibly and toggle visibility
# instead, but that needs real support in swarm-overlay itself first.
set -eu

BIN="/opt/swarm_os/swarm-overlay/swarm-overlay"

ACTION="${1:-toggle}"
case "$ACTION" in
  show|hide|toggle) ;;
  *) echo 'Usage: swarm-overlay-toggle.sh [show|hide|toggle]' >&2; exit 2 ;;
esac
if pgrep -f "$BIN dashboard" >/dev/null 2>&1; then
  if [ "$ACTION" != show ]; then pkill -f "$BIN dashboard"; fi
elif [ "$ACTION" != hide ]; then
  "$BIN" dashboard &
fi

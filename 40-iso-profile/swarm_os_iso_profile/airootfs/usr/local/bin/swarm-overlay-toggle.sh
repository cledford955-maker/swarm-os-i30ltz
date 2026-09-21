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

if pgrep -f "$BIN dashboard" >/dev/null 2>&1; then
  pkill -f "$BIN dashboard"
else
  "$BIN" dashboard &
fi

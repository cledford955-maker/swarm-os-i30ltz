#!/usr/bin/env bash
# /usr/lib/swarm/swarm-ui-cleanup.sh — end every trace of the kiosk desktop.
#
# Run as root from swarm-ui.service ExecStartPre (stale session from a crash)
# and ExecStopPost (normal or abnormal stop).
#
# Why not KillMode=control-group alone: PAMName=login makes pam_systemd move
# the desktop launcher into a logind session-N.scope. Only the (sd-pam) helper
# stays in swarm-ui.service's cgroup, so stopping the service never reached
# labwc/Flutter/swarm-slint, and KillUserProcesses=no leaves that scope
# running as an abandoned "closing" session. Killing the launcher reproduced
# orphaned desktop processes (70-scripts/DESKTOP_BOOT_REPAIR.md, 2026-09-24).
# Terminating the tty1 session stops the whole scope, whatever is in it.
#
# The desktop user is read from the unit, because the installer rewrites
# User=swarm to User=i30ltz; hardcoding either misses the other system.
#
# SWARM_LOGINCTL / SWARM_SYSTEMCTL / SWARM_PKILL exist so tests can stub them.

# Not -e: cleanup must attempt every step even when one fails.
set -uo pipefail

LOGINCTL="${SWARM_LOGINCTL:-/usr/bin/loginctl}"
SYSTEMCTL="${SWARM_SYSTEMCTL:-/usr/bin/systemctl}"
PKILL="${SWARM_PKILL:-/usr/bin/pkill}"
UNIT="swarm-ui.service"
DESKTOP_TTY="tty1"
DESKTOP_VT="1"
# All ExecStopPost lines share TimeoutStopSec=10; keep this well below it.
GRACE_SECONDS="${SWARM_CLEANUP_GRACE:-3}"
# Fallback only, for when logind cannot be asked. Programs that only the
# kiosk runs; never broad names a user might run in another session.
DESKTOP_PROGRAMS=(labwc swarm_flutter swarm-slint)

log() { echo "[swarm-ui-cleanup] $*" >&2; }

desktop_user="$("$SYSTEMCTL" show -p User --value "$UNIT" 2>/dev/null)"
desktop_user="${desktop_user:-swarm}"

# Print the ids of this user's sessions on the desktop VT, closing ones included.
desktop_sessions() {
    local id key value name tty vt
    "$LOGINCTL" list-sessions --no-legend 2>/dev/null | awk '{print $1}' |
    while read -r id; do
        [[ -n "$id" ]] || continue
        name='' tty='' vt=''
        while IFS='=' read -r key value; do
            case "$key" in
                Name) name="$value" ;;
                TTY) tty="$value" ;;
                VTNr) vt="$value" ;;
            esac
        done < <("$LOGINCTL" show-session "$id" -p Name -p TTY -p VTNr 2>/dev/null)
        [[ "$name" == "$desktop_user" ]] || continue
        if [[ "$tty" == "$DESKTOP_TTY" || "$vt" == "$DESKTOP_VT" ]]; then
            echo "$id"
        fi
    done
}

mapfile -t sessions < <(desktop_sessions)
for id in "${sessions[@]}"; do
    log "terminating session $id ($desktop_user on $DESKTOP_TTY)"
    "$LOGINCTL" terminate-session "$id" 2>/dev/null || log "terminate-session $id failed"
done

if (( ${#sessions[@]} )); then
    for (( i = 0; i < GRACE_SECONDS * 4; i++ )); do
        mapfile -t remaining < <(desktop_sessions)
        (( ${#remaining[@]} )) || break
        sleep 0.25
    done
    mapfile -t remaining < <(desktop_sessions)
    for id in "${remaining[@]}"; do
        log "session $id outlived ${GRACE_SECONDS}s; sending SIGKILL"
        "$LOGINCTL" kill-session --signal=SIGKILL "$id" 2>/dev/null || true
    done
fi

# Fallback for processes logind never tracked (e.g. logind unavailable).
strays=0
for program in "${DESKTOP_PROGRAMS[@]}"; do
    if "$PKILL" -TERM -u "$desktop_user" -x "$program" 2>/dev/null; then
        log "stopping stray $program outside any desktop session"
        strays=1
    fi
done
if (( strays )); then
    sleep 1
    for program in "${DESKTOP_PROGRAMS[@]}"; do
        "$PKILL" -KILL -u "$desktop_user" -x "$program" 2>/dev/null || true
    done
fi

exit 0

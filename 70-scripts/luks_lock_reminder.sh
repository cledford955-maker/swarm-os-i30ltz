#!/usr/bin/env bash
# luks_lock_reminder.sh — desktop notification when the lucy-master LUKS volume
# is plugged in but still locked (so the nightly mirror in sync_lucille_ai.sh
# would silently skip it). Runs as the logged-in USER (a root unit cannot post
# desktop notifications), once per login via luks-lock-reminder.service.
#
#   * drive not attached  -> silent (the normal state when the T7 is unplugged)
#   * attached + unlocked -> silent
#   * attached + locked   -> one notification with the unlock command
#
# Looked up by UUID, never /dev/sdX (letters swap between boots). Interim aid
# only: the planned TPM auto-unlock (see the Secure Boot plan) makes it moot.
#
#   luks_lock_reminder.sh            check once and notify if needed
#   luks_lock_reminder.sh --status   print locked / unlocked / absent, no notification
#   luks_lock_reminder.sh --install  install + enable the user unit (run as your user)
set -euo pipefail

LUKS_UUID="${LUKS_UUID:-a24202ce-4d76-4eb7-8923-8e8ddbacdaa7}"
DEV="/dev/disk/by-uuid/$LUKS_UUID"

state() {
    if [ ! -e "$DEV" ]; then echo absent; return; fi
    # An opened LUKS device shows a child of TYPE "crypt" whatever mapper name was used.
    if lsblk -nro TYPE "$DEV" 2>/dev/null | grep -qx crypt; then echo unlocked; else echo locked; fi
}

case "${1:-}" in
    --status) state ;;
    --install)
        here="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
        mkdir -p "$HOME/.config/systemd/user"
        sed "s#@SCRIPT@#$here/luks_lock_reminder.sh#" "$here/luks-lock-reminder.service" \
            > "$HOME/.config/systemd/user/luks-lock-reminder.service"
        systemctl --user daemon-reload
        systemctl --user enable luks-lock-reminder.service
        echo "installed; it runs at your next login (or: systemctl --user start luks-lock-reminder.service)" ;;
    "")
        if [ "$(state)" = locked ]; then
            cmd="sudo cryptsetup open $DEV luks-$LUKS_UUID"
            command -v notify-send >/dev/null 2>&1 \
                && notify-send -u normal -a "SWARM OS" "lucy-master is locked" \
                    "The backup drive is attached but not unlocked, so the Lucille-AI mirror will skip it.\nUnlock: $cmd" \
                || echo "lucy-master is locked. Unlock: $cmd" >&2
        fi ;;
    *) echo "usage: $0 [--status|--install]" >&2; exit 2 ;;
esac

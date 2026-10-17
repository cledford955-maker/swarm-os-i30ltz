#!/usr/bin/env bash
# fix_swarm_root_ownership.sh — give SWARM OS's system directories back to root.
#
#   sudo fix_swarm_root_ownership.sh             # dry run: counts and samples, changes nothing
#   sudo fix_swarm_root_ownership.sh --apply     # chown root:root, writes an undo list first
#   sudo fix_swarm_root_ownership.sh --only etc,usr,boot [--apply]   # just those folders (plus "/" itself); skip /opt for now
#
# Why (found 2026-10-14): on the installed SWARM root (/mnt/swarm/@) hundreds of system entries are owned
# by uid 1000 (the normal user): /, /etc, /etc/pam.d, /etc/sudoers.d, /usr/bin, /usr/lib, /boot, /opt...
# The installer copies the repo's airootfs with 'cp -a', which keeps the repo's owner. A process running as
# that user can then replace /etc/pam.d/sudo, drop a sudoers rule or swap a binary root later runs, which
# makes both the sudo password AND the hardware key pointless. System paths must be root-owned.
#
# Only entries owned by uid/gid 1000 under /, /etc, /usr, /boot, /opt are touched. Left alone on purpose
# (runtime state written by services running as the user): /etc/swarm_os (gaming.db, lucy/), /opt/swarm_os/models.
# /home and /var are never touched. Undo: the list in <root>/root/ownership-undo-<date>.txt (path<TAB>uid:gid).
set -euo pipefail
export PATH="/usr/sbin:/sbin:/usr/bin:/bin"

ROOT="/mnt/swarm/@"; UID_FROM=1000; MODE=dry; ONLY="etc usr boot opt"
while [ $# -gt 0 ]; do
    case "$1" in
        --apply) MODE=apply ;;
        --root) ROOT="${2:?path}"; shift ;;
        --uid) UID_FROM="${2:?uid}"; shift ;;
        --only) ONLY="$(echo "${2:?etc,usr,boot,opt}" | tr ',' ' ')"; shift ;;
        -h|--help) sed -n '2,17p' "$0"; exit 0 ;;
        *) echo "unknown option: $1" >&2; exit 2 ;;
    esac
    shift
done
[ "$(id -u)" -eq 0 ] || { echo "run as root: sudo $0 $*" >&2; exit 1; }
[ -d "$ROOT/etc/pam.d" ] || { echo "no SWARM root at $ROOT" >&2; exit 1; }
# Safety: the user at uid 1000 on that system must really be the normal user, not a system account.
nm="$(awk -F: -v u="$UID_FROM" '$3==u{print $1}' "$ROOT/etc/passwd")"
[ -n "$nm" ] && [ "$nm" != root ] || { echo "uid $UID_FROM is not a normal user on $ROOT (got '${nm:-none}'); refusing" >&2; exit 1; }
echo "uid $UID_FROM on $ROOT is '$nm'"

LIST="$(mktemp)"; trap 'rm -f "$LIST"' EXIT
find "$ROOT" -maxdepth 0 \( -uid "$UID_FROM" -o -gid "$UID_FROM" \) -print0 >> "$LIST" || true
for d in $ONLY; do
    case "$d" in etc|usr|boot|opt) ;; *) echo "--only: unknown folder '$d' (etc, usr, boot, opt)" >&2; exit 2;; esac
    [ -d "$ROOT/$d" ] || continue
    find "$ROOT/$d" -xdev \
        \( -path "$ROOT/etc/swarm_os" -o -path "$ROOT/etc/swarm_os/*" -o -path "$ROOT/opt/swarm_os/models" -o -path "$ROOT/opt/swarm_os/models/*" \) -prune -o \
        \( -uid "$UID_FROM" -o -gid "$UID_FROM" \) -print0 >> "$LIST" || true
done
total="$(tr -cd '\0' < "$LIST" | wc -c)"
echo "entries to hand back to root: $total"
for d in $ONLY; do
    printf '  %-5s %s\n' "$d" "$(tr '\0' '\n' < "$LIST" | grep -c "^$ROOT/$d\(/\|$\)" || true)"
done
echo "sample:"; tr '\0' '\n' < "$LIST" | head -8 | sed 's/^/  /'

if [ "$MODE" = dry ]; then echo "DRY RUN — nothing changed. Add --apply."; exit 0; fi
[ "$total" -gt 0 ] || { echo "nothing to do"; exit 0; }
UNDO="$ROOT/root/ownership-undo-$(date +%Y%m%d-%H%M%S).txt"
mkdir -p "$ROOT/root"
xargs -0 stat -c '%n	%u:%g' < "$LIST" > "$UNDO"
xargs -0 chown -h root:root < "$LIST"
echo "done: $total entries now root:root. Undo list: $UNDO"
echo "Check:  ls -ld $ROOT/etc $ROOT/etc/pam.d $ROOT/etc/sudoers.d $ROOT/usr/bin"

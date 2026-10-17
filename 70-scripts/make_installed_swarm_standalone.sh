#!/usr/bin/env bash
# Apply the 2026-10-09 "SWARM OS runs standalone from the internal NVMe" fixes to the INSTALLED system
# without rebuilding the ISO. Two targeted edits (never a file overwrite - the installed swarm-ui.service
# has User=i30ltz, the repo copy has User=swarm):
#   swarm-ui.service               crash logs -> /var/log/swarm-ui (copied to /mnt/Lucy/logs only if that is mounted)
#   swarm-workspace-parity.service skip silently unless /mnt/Lucy AND the external lucy-master mirror are present
#
#   sudo 70-scripts/make_installed_swarm_standalone.sh [--root DIR] [--dry-run]
#   default --root: "/" when run on SWARM OS itself, else /mnt/swarm/@ (the installed root's btrfs subvolume)
#
# Safe: computes both new files first, aborts without changing anything if any expected text is not found,
# backs the originals up under <root>/var/backups/swarm-standalone-<stamp>/, and is idempotent.
# Does NOT touch GRUB, the ESP, fstab or any binary. Takes effect on the next boot (or daemon-reload on the live system).
set -euo pipefail
ROOT=""; DRY=0
while [[ $# -gt 0 ]]; do case $1 in --root) ROOT=${2:?}; shift 2 ;; --dry-run) DRY=1; shift ;; -h|--help) sed -n '2,15p' "$0"; exit 0 ;; *) echo "unknown option $1" >&2; exit 2 ;; esac; done
if [[ -z $ROOT ]]; then
  if [[ -f /etc/swarm-release ]]; then ROOT=/; else ROOT=/mnt/swarm/@; fi
fi
[[ $DRY -eq 1 || $EUID -eq 0 ]] || { echo "needs sudo (or use --dry-run): sudo $0 $*" >&2; exit 1; }
[[ -f $ROOT/etc/swarm-release ]] || { echo "ABORT: $ROOT is not an installed SWARM OS root (no etc/swarm-release)" >&2; exit 1; }
UI=$ROOT/etc/systemd/system/swarm-ui.service
PAR=$ROOT/etc/systemd/system/swarm-workspace-parity.service
for f in "$UI" "$PAR"; do [[ -f $f ]] || { echo "ABORT: missing $f" >&2; exit 1; }; done

STAMP=$(date +%Y%m%d-%H%M%S); NEW=$(mktemp -d); trap 'rm -rf "$NEW"' EXIT
python3 - "$UI" "$PAR" "$NEW" <<'PY'
import sys, os
ui, par, out = sys.argv[1:4]
def edit(path, pairs, done_marker, name):
    s = open(path).read()
    if done_marker in s:
        print(f"already patched: {name}"); return None
    for old, new in pairs:
        if s.count(old) != 1:
            sys.exit(f"ABORT: {name}: expected text not found exactly once (installed file differs from what this script was written for):\n  {old[:90]}")
        s = s.replace(old, new)
    open(os.path.join(out, name), 'w').write(s); print(f"will patch:      {name}")
edit(ui, [
 ("repeatedly since at least 2026-09-15 (see /mnt/Lucy/logs/swarm-ui-*.log) —",
  "repeatedly since at least 2026-09-15 (see /var/log/swarm-ui/swarm-ui-*.log; copied to /mnt/Lucy/logs when that drive is mounted) —"),
 ("ExecStartPre=+/usr/bin/mkdir -p /mnt/Lucy/logs",
  "# Logs live on the OS's own disk so the system is standalone (2026-10-09): /mnt/Lucy is optional and may be absent.\nExecStartPre=+/usr/bin/mkdir -p /var/log/swarm-ui"),
 ("ExecStopPost=+/usr/bin/bash -c 'sleep 1; { echo \"=== systemctl status ===\";",
  "ExecStopPost=+/usr/bin/bash -c 'sleep 1; f=/var/log/swarm-ui/swarm-ui-$(date +%%Y%%m%%d-%%H%%M%%S).log; { echo \"=== systemctl status ===\";"),
 ("journalctl -b --no-pager -g \"drm|seat|wlroots|labwc\" -n 200; } > /mnt/Lucy/logs/swarm-ui-$(date +%%Y%%m%%d-%%H%%M%%S).log 2>&1 || true'",
  "journalctl -b --no-pager -g \"drm|seat|wlroots|labwc\" -n 200; } > \"$$f\" 2>&1 || true; if mountpoint -q /mnt/Lucy; then mkdir -p /mnt/Lucy/logs && cp -f \"$$f\" /mnt/Lucy/logs/ || true; fi'"),
], "/var/log/swarm-ui", "swarm-ui.service")
edit(par, [
 ("After=local-fs.target\n",
  "After=local-fs.target\n# Dev-machine feature: needs /mnt/Lucy AND the external lucy-master mirror. On a standalone SWARM OS skip silently.\nConditionPathIsMountPoint=/mnt/Lucy\nConditionPathExists=/run/media/i30ltz/lucy-master\n"),
], "ConditionPathExists=/run/media/i30ltz/lucy-master", "swarm-workspace-parity.service")
PY

shopt -s nullglob; todo=("$NEW"/*)
[[ ${#todo[@]} -gt 0 ]] || { echo "nothing to do"; exit 0; }
if [[ $DRY -eq 1 ]]; then echo "[dry-run] would back up and replace ${#todo[@]} file(s) under $ROOT/etc/systemd/system"; exit 0; fi
BK=$ROOT/var/backups/swarm-standalone-$STAMP/etc/systemd/system; install -d "$BK"
for f in "${todo[@]}"; do
  n=$(basename "$f"); cp -a "$ROOT/etc/systemd/system/$n" "$BK/$n"
  install -m 644 -o root -g root "$f" "$ROOT/etc/systemd/system/$n"; echo "patched $ROOT/etc/systemd/system/$n  (backup: $BK/$n)"
done
[[ $ROOT == / ]] && systemctl daemon-reload && echo "daemon-reload done" || echo "installed root is offline: changes apply on its next boot"
echo "undo: copy the files from $BK back."

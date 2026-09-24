#!/usr/bin/env bash
# One privileged application of the reviewed inventory and archive mount setup.
set -euo pipefail
[[ $EUID == 0 ]] || { echo 'Run with sudo to manage the root-owned Ventoy files.' >&2; exit 1; }
ROOT=/mnt/Lucy
python3 "$ROOT/70-scripts/apply_iso_cleanup.py" --apply
if ! mountpoint -q /mnt/boltz; then
  mount -U 689e6547-b439-4e7f-93c9-a6dcfabed46b /mnt/boltz
fi
# Validate UUID before creating anything: never archive onto an unmounted folder.
python3 -c 'import sys; sys.path.insert(0,"/mnt/Lucy/70-scripts"); import swarm_iso_manager as m; m.require_archive()'
install -d -m 0755 -o "$(stat -c %u "$ROOT")" -g "$(stat -c %g "$ROOT")" /mnt/boltz/ISO/SWARM_OS/weekly
python3 "$ROOT/70-scripts/swarm_iso_manager.py" archive-weekly

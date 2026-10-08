#!/usr/bin/env bash
# make_swarm_persistence.sh — create swarm-persist.img on the Ventoy USB.
# The live ISO (usr/lib/swarm/swarm-persist.sh) finds this file at boot and keeps
# the session's state on it. Run as a normal user:
#   70-scripts/make_swarm_persistence.sh [SIZE_GB]      (default 8)
# Never overwrites an existing image — delete it by hand to start over.
set -euo pipefail

SIZE_GB=${1:-8}
MOUNT=/mnt/ventoy
IMG=$MOUNT/swarm-persist.img
LUCY=/mnt/Lucy

[[ $SIZE_GB =~ ^[0-9]+$ && $SIZE_GB -ge 1 ]] || { echo 'SIZE_GB must be a whole number >= 1' >&2; exit 1; }
# Aborts unless the real Ventoy stick (UUID 5ABB-83DF) is mounted at /mnt/ventoy.
python3 "$LUCY/70-scripts/swarm_iso_manager.py" check >/dev/null
[[ ! -e $IMG ]] || { echo "$IMG already exists; refusing to overwrite." >&2; exit 1; }

free_gb=$(( $(df --output=avail -B1G "$MOUNT" | tail -n1) ))
(( free_gb > SIZE_GB )) || { echo "Only ${free_gb} GB free on Ventoy; need more than ${SIZE_GB} GB." >&2; exit 1; }

trap 'rm -f "$IMG"' ERR
echo "Creating ${SIZE_GB} GB persistence image on Ventoy..."
# truncate, not fallocate: exFAT's fallocate writes every byte (8 GB at ~1 MB/s on a
# slow stick = hours). The lazy mkfs options likewise skip zeroing inode tables and journal.
truncate -s "${SIZE_GB}G" "$IMG"
# -m 0: no root reserve on a single-purpose image. Label is informational only.
mkfs.ext4 -F -q -m 0 -L SWARM_PERSIST -J size=32 \
  -E lazy_itable_init=1,lazy_journal_init=1,nodiscard "$IMG"
e2fsck -fn "$IMG" >/dev/null
sync
trap - ERR
echo "Done: $IMG ($(blkid -o value -s TYPE "$IMG"))."
echo "Boot the USB; swarm-persist.service will mount it. Check with: journalctl -u swarm-persist"

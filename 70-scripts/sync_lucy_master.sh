#!/usr/bin/env bash
# Two-way sync of the live project (/mnt/Lucy) and the encrypted lucy-master volume (user decision 2026-10-10:
# "make sure lucy master and lucy project are syncing, not deleting new data, just what has actually been deleted").
#
#   sync_lucy_master.sh --list-top                      list lucy-master's top-level folders (read-only), to choose --subdir
#   sync_lucy_master.sh --subdir NAME                   show the plan, change nothing
#   sync_lucy_master.sh --subdir NAME --apply           do it
#
# NAME is the folder ON lucy-master that mirrors /mnt/Lucy. It is required on purpose: lucy-master is much bigger than
# /mnt/Lucy (683 GB vs 250 GB) and holds the whole old world, so syncing its root would pour that into the project drive.
#
# Rules (same engine as Lucy <-> swarmbuild, 70-scripts/swarm_twoway_sync.py):
#   * a file on only one side is NEW and is copied over, unless the saved history says both sides once had it and one side
#     has since deleted it: only then is the deletion carried over (the copy goes to <root>/.sync-trash/<run>/, never lost)
#   * edited on both sides: the newer wins, the other copy goes to the trash. An edit beats a deletion.
#   * the FIRST run has no history, so it can never delete anything: every difference is treated as new or changed
#   * it refuses to start a copy that does not fit (free space minus a margin) and refuses mass deletions
#   * what is never synced is 70-scripts/swarm_sync.exclude (.git, build output, ...)
# The history lives in /mnt/Lucy/.swarm-sync/master/ (separate from the swarmbuild sync's).
#
# lucy-master is a LUKS volume and is found by the UUID of the filesystem inside it, whatever the mount name:
#   sudo cryptsetup open /dev/disk/by-uuid/a24202ce-4d76-4eb7-8923-8e8ddbacdaa7 lucy-master   (asks for the passphrase)
#   ls /mnt/storage >/dev/null                          (Debian: the fstab automount line mounts it on first use)
set -euo pipefail
export PATH=/usr/sbin:/sbin:$PATH

HERE=$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")
LUCY=${LUCY_ROOT:-/mnt/Lucy}
MASTER_FS_UUID=${LUCY_MASTER_FS_UUID:-2de6ca36-421c-4c3e-8bc4-fbe3e6f66238}      # ext4 inside the LUKS container a24202ce-...
LUKS_UUID=a24202ce-4d76-4eb7-8923-8e8ddbacdaa7
STATE=$LUCY/.swarm-sync/master
SUBDIR="" LIST_TOP=0 PASS=()
while [[ $# -gt 0 ]]; do case $1 in
  --subdir)   SUBDIR=${2:?--subdir needs a folder name}; shift 2 ;;
  --list-top) LIST_TOP=1; shift ;;
  -h|--help)  sed -n '2,29p' "$0"; exit 0 ;;
  *)          PASS+=("$1"); shift ;;       # --apply, --list N, --allow-mass-delete, ... go to the engine
esac; done

die() { printf 'ABORT: %s\n' "$*" >&2; exit 1; }

# --- find lucy-master (mounted), or say exactly how to unlock it
master_mount() {
  if [[ -n ${LUCY_MASTER_MOUNT:-} ]]; then printf '%s' "$LUCY_MASTER_MOUNT"; return; fi
  findmnt -rn -S "UUID=$MASTER_FS_UUID" -o TARGET 2>/dev/null | head -1 || true
}
MASTER=$(master_mount)
if [[ -z $MASTER ]]; then
  # Debian's fstab line is an automount: touching the mount point mounts it if the volume is already unlocked
  [[ -d /mnt/storage ]] && ls /mnt/storage >/dev/null 2>&1 || true
  MASTER=$(master_mount)
fi
if [[ -z $MASTER ]]; then
  if [[ -e /dev/disk/by-uuid/$MASTER_FS_UUID ]]; then
    die "lucy-master is unlocked but not mounted. Mount it: sudo mount /dev/disk/by-uuid/$MASTER_FS_UUID /mnt/storage"
  fi
  die "lucy-master is locked (or the Samsung T7 is not plugged in). Unlock it, then run this again:
       sudo cryptsetup open /dev/disk/by-uuid/$LUKS_UUID lucy-master
       ls /mnt/storage > /dev/null"
fi
[[ -d $MASTER ]] || die "lucy-master mount $MASTER is not a directory"

if (( LIST_TOP )); then
  echo "lucy-master is mounted at $MASTER. Top-level folders (name, size of files directly inside is not counted):"
  find "$MASTER" -mindepth 1 -maxdepth 1 -type d -not -name 'lost+found' -printf '  %f\n' | sort
  echo; echo "Free: $(df -h --output=avail "$MASTER" | tail -1 | tr -d ' ') on lucy-master, $(df -h --output=avail "$LUCY" | tail -1 | tr -d ' ') on $LUCY"
  echo "Pick the folder that mirrors the project and run:  $0 --subdir NAME"
  exit 0
fi

[[ -n $SUBDIR ]] || die "--subdir NAME is required (the folder on lucy-master that mirrors /mnt/Lucy). See: $0 --list-top"
[[ $SUBDIR != /* && $SUBDIR != *..* ]] || die "--subdir must be a plain folder name or relative path on lucy-master"
ROOT_B=$MASTER/$SUBDIR
[[ -d $ROOT_B ]] || die "$ROOT_B does not exist. See: $0 --list-top (to start a new mirror, create the folder yourself first: mkdir '$ROOT_B')"
mkdir -p "$STATE"
[[ -f $STATE/manifest.sqlite ]] || echo "note: no history for this pair yet, so this first run cannot delete anything: every difference is treated as new or changed."

ARGS=(--root-a "$LUCY" --root-b "$ROOT_B" --state-dir "$STATE" --label-a "Lucy project" --label-b "lucy-master"
      --exclude '/lost+found/')
if [[ ${LUCY_MASTER_NO_MOUNT_CHECK:-0} == 1 ]]; then ARGS+=(--no-mount-check)      # tests only
else ARGS+=(--mount-a "$LUCY" --mount-b "$MASTER"); fi
exec python3 "$HERE/swarm_twoway_sync.py" "${ARGS[@]}" "${PASS[@]}"

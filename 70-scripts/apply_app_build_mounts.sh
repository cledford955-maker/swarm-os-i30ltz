#!/usr/bin/env bash
# Mount the three partitions added 2026-10-09 at their canonical points (policy: CLAUDE.md "App build partitions").
#   sudo 70-scripts/apply_app_build_mounts.sh            do it
#   70-scripts/apply_app_build_mounts.sh --dry-run       show what would change, touch nothing (no sudo needed)
#
#   /mnt/lucillebuild  C. Lucille build     ext4   UUID 93037d5a-...        Lucille Assistant build
#   /mnt/boltzbuild    D. BOLTZ Recovery    ntfs   UUID 67C2E9F8241FD7AE    i30ltz Recovery app build
#   /mnt/recoveryos    Recovery OS          btrfs  UUID 490b9e60-...        Recovery OS root/home
#
# Only touches the fstab lines for these mountpoints (and the old typo'd /mnt/llucillebuild).
# Never formats, never writes to a partition. /etc/fstab is backed up first. Safe to re-run.
set -euo pipefail
DRY=0; [[ ${1:-} == --dry-run ]] && DRY=1
[[ $DRY -eq 0 && $EUID -ne 0 ]] && { echo "needs sudo:  sudo $0" >&2; exit 1; }
OWNER_UID=${SUDO_UID:-$(id -u)}; OWNER_GID=${SUDO_GID:-$(id -g)}
HEADER="# ==== App build partitions (user decision 2026-10-09) - see /mnt/Lucy/CLAUDE.md ===="

LINES=(
  "UUID=93037d5a-5b82-484c-ac20-28211c09e1c0	/mnt/lucillebuild	ext4	defaults,nofail,x-systemd.automount	0	2"
  "UUID=67C2E9F8241FD7AE	/mnt/boltzbuild	ntfs3	uid=$OWNER_UID,gid=$OWNER_GID,umask=022,nofail,x-systemd.automount	0	0"
  "UUID=490b9e60-afb2-45c6-91ce-2c6b1ea5a2f3	/mnt/recoveryos	btrfs	defaults,nofail,x-systemd.automount	0	2"
)
MPS=(/mnt/lucillebuild /mnt/boltzbuild /mnt/recoveryos)
DROP_MPS=(/mnt/llucillebuild "${MPS[@]}")

run() { if [[ $DRY -eq 1 ]]; then echo "[dry-run] $*"; else "$@"; fi; }

# Every device must really be attached.
for l in "${LINES[@]}"; do
  src=${l%%$'\t'*}; dev=$(readlink -f "/dev/disk/by-uuid/${src#UUID=}" 2>/dev/null || true)
  [[ -b ${dev:-} ]] || { echo "ABORT: $src is not attached (no /dev/disk/by-uuid/${src#UUID=})" >&2; exit 1; }
  echo "found   $src -> $dev"
done

# 1. fstab: drop existing lines for these mountpoints (and our old header), append the canonical ones.
tmp=$(mktemp); trap 'rm -f "$tmp"' EXIT
awk -v list="${DROP_MPS[*]}" -v hdr="$HEADER" '
  BEGIN { n = split(list, a, " "); for (i = 1; i <= n; i++) drop[a[i]] = 1 }
  $0 == hdr { next }
  /^[[:space:]]*#/ || NF < 2 { print; next }
  !($2 in drop) { print }' /etc/fstab > "$tmp"
{ echo "$HEADER"; printf '%s\n' "${LINES[@]}"; } >> "$tmp"
if [[ $DRY -eq 1 ]]; then
  echo "--- /etc/fstab would end with:"; tail -n 4 "$tmp"
else
  cp -a /etc/fstab "/etc/fstab.bak-$(date +%Y%m%d-%H%M%S)"
  install -m 644 "$tmp" /etc/fstab
fi

# 2. Release the old typo'd mount (same device, wrong name) so the device can be mounted at the right place.
if findmnt -rn -M /mnt/llucillebuild >/dev/null 2>&1; then
  run umount /mnt/llucillebuild || { echo "ABORT: /mnt/llucillebuild is busy (close shells/editors in it, then re-run)" >&2; exit 1; }
fi

# 3. Mountpoints + mount.
run install -d "${MPS[@]}"
run systemctl daemon-reload
for mp in "${MPS[@]}"; do run mount "$mp" || echo "FAILED  mount $mp" >&2; done

# 4. Result.
if [[ $DRY -eq 0 ]]; then
  for mp in "${MPS[@]}"; do stat "$mp" >/dev/null 2>&1 || true; done   # fire any automount
  echo; findmnt -rn -o TARGET,SOURCE,FSTYPE,OPTIONS | grep -E '^/mnt/(lucillebuild|boltzbuild|recoveryos) ' | grep -v autofs || true
  echo; bash "$(dirname "$(readlink -f "$0")")/check_mounts.sh" || true
fi

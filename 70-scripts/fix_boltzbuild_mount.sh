#!/usr/bin/env bash
# Make /mnt/boltzbuild mount after D was reformatted ext4 outside apply_app_build_mounts.sh (2026-10-09, GNOME Disks).
#
#   sudo 70-scripts/fix_boltzbuild_mount.sh             fix /etc/fstab, reset the stale automount, mount, chown
#   70-scripts/fix_boltzbuild_mount.sh --dry-run        show the plan, change nothing (no sudo needed)
#
# Why it was stuck: the reformat gave the partition a new identity (label "Boltz Built", UUID below, new PARTUUID),
# but /etc/fstab still named the old NTFS UUID 67C2E9F8241FD7AE plus a second GNOME-Disks line for the same mountpoint,
# and systemd's mnt-boltzbuild.automount was still loaded from the NTFS entry ("No such device").
#
# Only fstab lines whose mountpoint is /mnt/boltzbuild are replaced; /etc/fstab is backed up first. Nothing is formatted.
set -euo pipefail
export PATH=/usr/sbin:/sbin:$PATH

MP=/mnt/boltzbuild
WANT_UUID=6f7c7656-2984-4fb0-81c8-bfc11ca81461
DRY=0
case "${1:-}" in
  "") ;; --dry-run) DRY=1 ;; -h|--help) sed -n '2,12p' "$0"; exit 0 ;;
  *) echo "unknown option: $1 (see --help)" >&2; exit 2 ;;
esac
[[ $DRY -eq 0 && $EUID -ne 0 ]] && { echo "needs sudo:  sudo $0" >&2; exit 1; }
OWNER_UID=${SUDO_UID:-$(id -u)}; OWNER_GID=${SUDO_GID:-$(id -g)}

run() { if [[ $DRY -eq 1 ]]; then echo "[dry-run] $*"; else "$@"; fi; }
die() { echo "ABORT: $*" >&2; exit 1; }

# ---- 0. the right partition?
dev=$(readlink -f "/dev/disk/by-uuid/$WANT_UUID" 2>/dev/null || true)
[[ -b ${dev:-} ]] || die "no device with UUID $WANT_UUID is attached (is the Micron drive plugged in?)"
fs=$(lsblk -dno FSTYPE "$dev")
[[ $fs == ext4 ]] || die "$dev is '$fs', expected ext4"
pk=$(lsblk -dno PKNAME "$dev"); model=$(lsblk -dno MODEL "/dev/$pk" | tr -d ' ')
[[ $model == CT2000X9* ]] || die "$dev is on disk '$model', expected the Micron CT2000X9 build drive"
size=$(lsblk -bdno SIZE "$dev")
(( size > 150000000000 && size < 180000000000 )) || die "$dev is $size bytes, expected 150-180 GB (163 GiB)"
echo "found   $MP -> $dev  (ext4, $WANT_UUID, label '$(lsblk -dno LABEL "$dev")', $((size/1000000000)) GB on $model)"

# ---- 1. anything holding the mountpoint? (a shell whose cwd is inside it blocks the unmount)
holders=$(fuser -vm "$MP" 2>&1 | grep -v -E 'kernel mount|USER' || true)
[[ -z $holders ]] || echo "note: processes are using $MP - if the unmount below says busy, 'cd ~' in those shells:"$'\n'"$holders"

# ---- 2. fstab: drop every row for this mountpoint, add the UUID row
tmp=$(mktemp); trap 'rm -f "$tmp"' EXIT
awk -v mp="$MP" '/^[[:space:]]*#/ || NF < 2 { print; next } $2 != mp { print }' /etc/fstab > "$tmp"
printf 'UUID=%s\t%s\text4\tdefaults,nofail,x-systemd.automount,x-systemd.device-timeout=3s\t0\t2\n' "$WANT_UUID" "$MP" >> "$tmp"
if [[ $DRY -eq 1 ]]; then
  echo; echo "--- rows for $MP in /etc/fstab now:"; awk -v mp="$MP" '$1 !~ /^#/ && $2 == mp' /etc/fstab
  echo "--- would become:"; awk -v mp="$MP" '$1 !~ /^#/ && $2 == mp' "$tmp"
else
  cp -a /etc/fstab "/etc/fstab.bak-$(date +%Y%m%d-%H%M%S)"
  install -m 644 "$tmp" /etc/fstab
  findmnt --verify --tab-file /etc/fstab >/dev/null 2>&1 || echo "note: 'findmnt --verify' reports issues (may be pre-existing); check with: findmnt --verify"
fi

# ---- 3. reset the stale automount/mount (they were loaded from the old NTFS row), then mount
run systemctl stop mnt-boltzbuild.automount mnt-boltzbuild.mount || true
if findmnt -rn -M "$MP" >/dev/null 2>&1; then run umount "$MP" || die "$MP is busy - 'cd ~' in any shell inside it, then re-run"; fi
run install -d "$MP"
run systemctl daemon-reload
run mount "$MP"

# ---- 4. a freshly formatted ext4 root is owned by root; the build belongs to the user
if [[ $DRY -eq 0 ]]; then
  stat "$MP" >/dev/null 2>&1 || true
  findmnt -rn -M "$MP" -t ext4 >/dev/null 2>&1 || die "$MP did not mount as ext4 - check: journalctl -b -u mnt-boltzbuild.mount"
  chown "$OWNER_UID:$OWNER_GID" "$MP"; chmod 755 "$MP"
  echo; findmnt -rn -o TARGET,SOURCE,FSTYPE,OPTIONS | grep -E "^$MP " | grep -v autofs
  echo "OK: $MP is mounted ext4 and owned by uid $OWNER_UID"
fi

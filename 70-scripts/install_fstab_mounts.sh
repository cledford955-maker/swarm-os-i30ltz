#!/usr/bin/env bash
# Persist the canonical shared /mnt mount points in /etc/fstab, mount them, then unmount everything under /media/i30ltz.
# Run: sudo bash 70-scripts/install_fstab_mounts.sh
set -euo pipefail
[[ $EUID -eq 0 ]] || { echo "run with sudo" >&2; exit 1; }

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CANONICAL="${1:-$HERE/fstab.canonical}"
[[ -r $CANONICAL ]] || { echo "canonical fstab not found: $CANONICAL" >&2; exit 1; }

cp -a /etc/fstab "/etc/fstab.bak.$(date +%Y%m%d-%H%M%S)"

# Create mount points and append entries if not already in fstab
while read -r line || [[ -n $line ]]; do
  case "$line" in
    ''|'#'*) continue ;;
  esac
  set -- $line
  src=$1; mp=$2; fs=$3; opts=$4; dump=${5:-0}; pass=${6:-2}
  install -d "$mp"
  if ! grep -qE "(^|[[:space:]])$mp([[:space:]]|$)" /etc/fstab; then
    printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$src" "$mp" "$fs" "$opts" "$dump" "$pass" >> /etc/fstab
    echo "Added $mp ($src) to /etc/fstab"
  fi
done < "$CANONICAL"

systemctl daemon-reload

# Mount all /mnt mountpoints
while read -r line || [[ -n $line ]]; do
  case "$line" in
    ''|'#'*) continue ;;
  esac
  mp=$(echo "$line" | awk '{print $2}')
  [[ -n $mp && $mp == /mnt/* ]] || continue
  mountpoint -q "$mp" || mount "$mp" 2>/dev/null || echo "note: $mp not mounted (drive may be detached or LUKS locked)"
done < "$CANONICAL"

# Unmount /media copies (deepest first), then remove the empty dirs.
findmnt -rn -o TARGET | grep '^/media/i30ltz/' | sort -r | while read -r t; do
  umount "$t" && echo "unmounted $t" || echo "WARN: $t busy"
done
rmdir /media/i30ltz/* 2>/dev/null || true
echo "done; canonical mounts active:"
findmnt -rn -o TARGET,SOURCE | grep -E '^/mnt' || true

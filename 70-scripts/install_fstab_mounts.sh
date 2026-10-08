#!/usr/bin/env bash
# Persist the SWARM /mnt mount points in /etc/fstab, mount them, then unmount everything under /media/i30ltz.
# Run: sudo bash 70-scripts/install_fstab_mounts.sh   (copy it off the /media drive first if you like)
set -euo pipefail
[[ $EUID -eq 0 ]] || { echo "run with sudo" >&2; exit 1; }
U=${SUDO_UID:-1000}; G=${SUDO_GID:-1000}

# UUID | mountpoint | fstype | options
ENTRIES=(
  "62f0e009-43c2-4760-8d6c-d7c445f5f3df|/mnt/Lucy|ext4|defaults,noatime,nofail"
  "fba1b27f-407b-4385-9dfa-851833f249db|/mnt/brains|ext4|defaults,noatime,nofail"
  "5ABB-83DF|/mnt/ventoy|exfat|uid=$U,gid=$G,umask=022,noatime,nofail"
  "a409250b-3973-4448-aeda-94a911538eb4|/mnt/recoverybuild|btrfs|defaults,noatime,nofail"
  "c400a0ee-6710-4fe7-ad7a-c80dc3f402ca|/mnt/lucy_master|ext4|ro,noatime,nofail"
  "LABEL=swarm-build|/mnt/swarmbuild|ext4|defaults,noatime,nofail"
  "689e6547-b439-4e7f-93c9-a6dcfabed46b|/mnt/boltz|ext4|defaults,noatime,nofail"
)

cp -a /etc/fstab "/etc/fstab.bak.$(date +%Y%m%d-%H%M%S)"
for e in "${ENTRIES[@]}"; do
  IFS='|' read -r uuid mp fs opts <<<"$e"
  install -d "$mp"
  src=$uuid; [[ $src == LABEL=* ]] || src="UUID=$uuid"
  grep -qE "^$src[[:space:]]" /etc/fstab || \
    printf '%s %s %s %s 0 0\n' "$src" "$mp" "$fs" "$opts" >> /etc/fstab
done
systemctl daemon-reload

# Mount the new points first, so nothing is lost if one fails.
for e in "${ENTRIES[@]}"; do
  IFS='|' read -r uuid mp _ _ <<<"$e"
  mountpoint -q "$mp" || mount "$mp" || echo "WARN: could not mount $mp"
done

# Unmount /media copies (deepest first), then remove the empty dirs.
findmnt -rn -o TARGET | grep '^/media/i30ltz/' | sort -r | while read -r t; do
  umount "$t" && echo "unmounted $t" || echo "WARN: $t busy"
done
rmdir /media/i30ltz/* 2>/dev/null || true
echo done; findmnt -rn -o TARGET,SOURCE | grep -E '^/mnt|^/media' || true

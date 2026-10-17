#!/usr/bin/env bash
# Create and mount all SWARM project mount points. Run: sudo 70-scripts/mount_project_points.sh
# Idempotent: skips anything already mounted; warns (does not abort) if a device is absent.
set -euo pipefail
[[ $EUID -eq 0 ]] || { echo "run with sudo" >&2; exit 1; }
OWNER_UID=${SUDO_UID:-1000}; OWNER_GID=${SUDO_GID:-1000}

# mountpoint | UUID | fs options
MOUNTS=(
  "/mnt/Lucy|62f0e009-43c2-4760-8d6c-d7c445f5f3df|defaults,noatime"          # nvme0n1p4 'Swarm Build' (live project)
  "/mnt/brains|fba1b27f-407b-4385-9dfa-851833f249db|defaults,noatime"        # nvme0n1p5 i30ltz-brains
  "/mnt/ventoy|5ABB-83DF|uid=$OWNER_UID,gid=$OWNER_GID,umask=022,noatime"    # sdc1 Ventoy (exfat; ISOs)
  "/mnt/recoverybuild|a409250b-3973-4448-aeda-94a911538eb4|defaults,noatime" # sda6 Recovery-build
  "/mnt/lucy_master|c400a0ee-6710-4fe7-ad7a-c80dc3f402ca|ro,noatime"         # sda3 read-only mirror
  "/mnt/swarmbuild|LABEL=swarm-build|defaults,noatime"    # sda4 swarm-build (build/backup)
  "/mnt/boltz|689e6547-b439-4e7f-93c9-a6dcfabed46b|defaults,noatime"         # i30ltz-AI (shared archive)
)

for entry in "${MOUNTS[@]}"; do
  IFS='|' read -r mp uuid opts <<<"$entry"
  install -d "$mp"
  if mountpoint -q "$mp"; then echo "ok      $mp (already mounted)"; continue; fi
  if [[ $uuid == LABEL=* ]]; then dev=/dev/disk/by-label/${uuid#LABEL=}; else dev=/dev/disk/by-uuid/$uuid; fi
  if [[ ! -e $dev ]]; then echo "SKIP    $mp ($uuid not present)"; continue; fi
  mount "$dev" -o "$opts" "$mp" && echo "mounted $mp"
done

#!/usr/bin/env bash
# Verify the SWARM mount points. Run at the start of every session, on every OS.
#   70-scripts/check_mounts.sh            report only (exit 1 if a required mount is missing)
#   sudo 70-scripts/check_mounts.sh --fix add missing entries to THIS OS's /etc/fstab and mount them
set -uo pipefail
FIX=0; [[ ${1:-} == --fix ]] && FIX=1
[[ $FIX -eq 1 && $EUID -ne 0 ]] && { echo "--fix needs sudo" >&2; exit 1; }
OWNER_UID=${SUDO_UID:-$(id -u)}; OWNER_GID=${SUDO_GID:-$(id -g)}
. /etc/os-release 2>/dev/null; echo "OS: ${PRETTY_NAME:-unknown}  (fstab: /etc/fstab)"

# mountpoint | fstab source | fstype | options | required(1/0)
TABLE=(
  "/mnt/Lucy|UUID=62f0e009-43c2-4760-8d6c-d7c445f5f3df|ext4|defaults,noatime,nofail|1"
  # swarmbuild was LABEL=swarm-build; the partition was relabeled "A. swarm-build" on 2026-10-09, so match by UUID.
  "/mnt/swarmbuild|UUID=5c84ef0e-d7b8-4b36-b1c4-58817b483dda|ext4|defaults,noatime,nofail|1"
  "/mnt/brains|UUID=fba1b27f-407b-4385-9dfa-851833f249db|ext4|defaults,noatime,nofail|1"
  "/mnt/ventoy|UUID=5ABB-83DF|exfat|uid=$OWNER_UID,gid=$OWNER_GID,umask=022,noatime,nofail|1"
  "/mnt/recoverybuild|UUID=a409250b-3973-4448-aeda-94a911538eb4|btrfs|defaults,noatime,nofail|1"
  # App build partitions (user decision 2026-10-09), all on the 1.8 TB build drive. See CLAUDE.md "App build partitions".
  "/mnt/lucillebuild|UUID=93037d5a-5b82-484c-ac20-28211c09e1c0|ext4|defaults,noatime,nofail|1"
  # boltzbuild: created NTFS (UUID 67C2E9F8241FD7AE) by mistake, reformatted ext4 2026-10-09 by apply_app_build_mounts.sh --reformat-boltz
  # with this fixed UUID. Reports MISSING/ELSEWHERE until that has been run.
  "/mnt/boltzbuild|UUID=e195839a-f617-4abd-9bf3-b64a679b7474|ext4|defaults,noatime,nofail|1"
  # Recovery OS installed root/home lives on the Samsung T7, not the build drive, so it may legitimately be unplugged.
  "/mnt/recoveryos|UUID=490b9e60-afb2-45c6-91ce-2c6b1ea5a2f3|btrfs|defaults,noatime,nofail|0"
  "/mnt/lucy_master|UUID=c400a0ee-6710-4fe7-ad7a-c80dc3f402ca|ext4|ro,noatime,nofail|1"
  "/mnt/boltz|UUID=689e6547-b439-4e7f-93c9-a6dcfabed46b|ext4|defaults,noatime,nofail|0"
)

# Real source device of a mountpoint. systemd automounts (x-systemd.automount)
# stack an autofs row ("systemd-1") over the real mount, and btrfs subvolume
# mounts report "/dev/sdX[/@]" - skip the autofs row and strip the suffix.
mounted_source() {
  findmnt -rno SOURCE,FSTYPE -M "$1" 2>/dev/null | awk '$2!="autofs"{sub(/\[.*/,"",$1); print $1; exit}'
}
# Where else is this device mounted (non-autofs)? Prints "TARGET ro|rw".
mounted_elsewhere() {
  findmnt -rno TARGET,FSTYPE,OPTIONS -S "$1" 2>/dev/null |
    awk '$2!="autofs"{print $1, ($3 ~ /(^|,)ro(,|$)/ ? "ro" : "rw"); exit}'
}

bad=0
for row in "${TABLE[@]}"; do
  IFS='|' read -r mp src fs opts req <<<"$row"
  want=$(readlink -f "/dev/disk/by-$(tr A-Z a-z <<<"${src%%=*}")/${src#*=}" 2>/dev/null || true)
  if [[ ! -e ${want:-/nonexistent} ]]; then
    [[ $req == 1 ]] && { echo "ABSENT  $mp ($src not attached)"; bad=1; } || echo "absent  $mp (optional, $src not attached)"; continue
  fi
  stat "$mp" >/dev/null 2>&1 || true   # trigger a not-yet-fired automount
  have=$(mounted_source "$mp")
  if [[ -n $have && $(readlink -f "$have") == "$(readlink -f "$want")" ]]; then
    echo "ok      $mp  <- $want"; continue
  fi
  other=$(mounted_elsewhere "$want")
  if [[ -n $other ]]; then
    # Same device already mounted under another name on this OS (record it in
    # CLAUDE.md). Never mount it a second time - ext4 refuses mixed ro/rw.
    echo "ELSEWHERE $mp  ($want is mounted at ${other% *}, ${other#* })"
    [[ $opts == ro,* && ${other#* } == rw ]] && echo "WARN    $mp is meant to be read-only but ${other% *} is mounted rw"
    continue
  fi
  echo "MISSING $mp  ($src -> $want)"; bad=1
  if [[ $FIX -eq 1 ]]; then
    install -d "$mp"
    # Skip the append when this mountpoint already has an fstab line (any source spelling).
    awk -v m="$mp" '$1 !~ /^#/ && $2 == m {f=1} END {exit !f}' /etc/fstab ||
      grep -qE "^$src[[:space:]]" /etc/fstab ||
      printf '%s %s %s %s 0 0\n' "$src" "$mp" "$fs" "$opts" >> /etc/fstab
    systemctl daemon-reload; mount "$mp" && { echo "fixed   $mp"; bad=0; } || echo "FAILED  $mp"
  fi
done
[[ $bad -eq 0 ]] || echo "Some mounts are missing. Run: sudo $0 --fix"
exit $bad

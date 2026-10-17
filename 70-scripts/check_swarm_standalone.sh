#!/usr/bin/env bash
# Read-only: does the INSTALLED SWARM OS run completely off the internal NVMe, with no external drive needed?
# (user requirement 2026-10-09: "SWARM OS needs to run completely off of the internal drive, standalone")
#   70-scripts/check_swarm_standalone.sh [--root DIR]        most checks work without root
#   sudo 70-scripts/check_swarm_standalone.sh [--root DIR]   also checks the ESP, grub.cfg and the UEFI boot entries
# default --root: "/" when run on SWARM OS itself, else /mnt/swarm/@ (installed root's btrfs subvolume, mounted from Debian)
# Internal = a disk with TRAN=nvme. Exit 1 if any FAIL. Never writes anything.
set -uo pipefail
export PATH=/usr/sbin:/sbin:$PATH
ROOT=""; while [[ $# -gt 0 ]]; do case $1 in --root) ROOT=${2:?}; shift 2 ;; *) echo "usage: $0 [--root DIR]" >&2; exit 2 ;; esac; done
[[ -n $ROOT ]] || { [[ -f /etc/swarm-release ]] && ROOT=/ || ROOT=/mnt/swarm/@; }
[[ -f $ROOT/etc/swarm-release ]] || { echo "ABORT: $ROOT is not an installed SWARM OS root" >&2; exit 2; }
fails=0; warns=0
pass() { printf '  PASS  %s\n' "$*"; }
warn() { printf '  WARN  %s\n' "$*"; warns=$((warns+1)); }
fail() { printf '  FAIL  %s\n' "$*"; fails=$((fails+1)); }
info() { printf '  info  %s\n' "$*"; }
skip() { printf '  skip  %s\n' "$*"; }

# where_is SOURCE -> prints "internal" | "external" | "absent"
where_is() {
  local src=$1 dev pk
  case $src in
    UUID=*) dev=$(readlink -f "/dev/disk/by-uuid/${src#UUID=}" 2>/dev/null) ;;
    LABEL=*) dev=$(readlink -f "/dev/disk/by-label/${src#LABEL=}" 2>/dev/null) ;;
    PARTUUID=*) dev=$(readlink -f "/dev/disk/by-partuuid/${src#PARTUUID=}" 2>/dev/null) ;;
    /dev/mapper/*) echo "absent"; return ;;   # LUKS volume: only present after an unlock
    *) dev=$src ;;
  esac
  [[ -b ${dev:-} ]] || { echo absent; return; }
  pk=$(lsblk -no PKNAME "$dev" 2>/dev/null | head -1); [[ -n $pk ]] || pk=$(basename "$dev")
  [[ $(lsblk -dno TRAN "/dev/$pk" 2>/dev/null) == nvme ]] && echo internal || echo external
}

echo "== SWARM OS standalone check  (root: $ROOT, $(grep -m1 '^SWARM_VERSION=' "$ROOT/etc/swarm-release" 2>/dev/null))"
echo "-- 1. /etc/fstab: everything the OS requires must be on the internal NVMe"
while read -r src mp fs opts _; do
  [[ -z ${src:-} || $src == \#* ]] && continue
  loc=$(where_is "$src")
  if [[ $opts == *nofail* || $opts == *noauto* ]]; then
    case $loc in
      internal) info "optional   $mp  (internal)" ;;
      external) warn "optional   $mp  lives on an EXTERNAL drive - harmless (nofail/noauto) but not part of a standalone OS" ;;
      absent)   info "optional   $mp  (not present right now - fine)" ;;
    esac
  else
    case $loc in
      internal) pass "required   $mp  ($fs) is on the internal NVMe" ;;
      external) fail "required   $mp  is on an EXTERNAL drive - the OS would not boot without it" ;;
      absent)   fail "required   $mp  source $src not found on this machine right now" ;;
    esac
  fi
done < <(grep -vE '^\s*(#|$)' "$ROOT/etc/fstab")

echo "-- 2. kernel command line root"
cmdroot=$(grep -oE 'root=UUID=[0-9a-fA-F-]+' "$ROOT/etc/default/grub" 2>/dev/null | head -1)
if [[ -n $cmdroot ]]; then
  case $(where_is "${cmdroot#root=}") in internal) pass "$cmdroot is internal" ;; external) fail "$cmdroot is EXTERNAL" ;; absent) warn "$cmdroot: device not visible from here" ;; esac
else warn "no root=UUID= in /etc/default/grub"; fi

echo "-- 3. units: nothing may HARD-require another drive"
hard=$(grep -rlE '^(RequiresMountsFor|Requires|BindsTo)=.*(/mnt/|mnt-)' "$ROOT/etc/systemd/system" 2>/dev/null | grep -v '\.wants/' | head)
[[ -z $hard ]] && pass "no unit Requires=/RequiresMountsFor= a /mnt drive" || { for f in $hard; do fail "hard mount dependency in $f"; done; }
if grep -q '/mnt/Lucy/logs' "$ROOT/etc/systemd/system/swarm-ui.service" 2>/dev/null; then
  warn "swarm-ui.service still logs to /mnt/Lucy/logs (lands on the root fs if Lucy is absent) - run make_installed_swarm_standalone.sh"
else pass "swarm-ui.service logs to the system's own disk"; fi
if [[ -f $ROOT/etc/systemd/system/swarm-workspace-parity.service ]] && ! grep -q '^ConditionPathExists=/run/media' "$ROOT/etc/systemd/system/swarm-workspace-parity.service"; then
  warn "swarm-workspace-parity.service has no condition - fails every run without the external mirror - run make_installed_swarm_standalone.sh"
else pass "dev-only timers are conditional"; fi

echo "-- 4. apps are on the root filesystem"
miss=0; for b in LucyServer/lucy-server GamingAgent/gaming-agent swarm_flutter/swarm_flutter swarm-slint/swarm-slint; do
  [[ -x $ROOT/opt/swarm_os/$b ]] || { fail "missing or not executable: /opt/swarm_os/$b"; miss=1; }; done
[[ $miss -eq 0 ]] && pass "LucyServer, GamingAgent, Flutter shell, swarm-slint are in /opt/swarm_os"
out=$(find "$ROOT/opt" "$ROOT/etc" "$ROOT/usr/local" "$ROOT/home" -xdev -type l \( -lname '/mnt/*' -o -lname '/run/media/*' -o -lname '/media/*' \) 2>/dev/null | head -3)
[[ -z $out ]] && pass "no symlink points out of the root filesystem" || fail "symlink(s) out of the root fs: $out"

echo "-- 5. boot path (needs root)"
if [[ $EUID -ne 0 ]]; then skip "run with sudo to check the ESP, grub.cfg and UEFI entries"; else
  esp=$(grep -E '/boot/efi' "$ROOT/etc/fstab" | awk '{print $1}' | head -1)
  if [[ -n $esp && $(where_is "$esp") == internal ]]; then
    t=$(mktemp -d); if mount -o ro "$(readlink -f "/dev/disk/by-uuid/${esp#UUID=}")" "$t" 2>/dev/null; then
      [[ -f $t/EFI/BOOT/BOOTX64.EFI ]] && pass "ESP has the fallback loader EFI/BOOT/BOOTX64.EFI (boots even if the UEFI entry is lost)" || warn "ESP has no EFI/BOOT/BOOTX64.EFI fallback"
      ls "$t"/EFI/*/grubx64.efi >/dev/null 2>&1 && pass "ESP has a GRUB loader: $(ls -d "$t"/EFI/*/ | xargs -n1 basename | tr '\n' ' ')" || fail "no grubx64.efi on the internal ESP"
      umount "$t"; else warn "could not mount the ESP read-only"; fi; rmdir "$t"
  else fail "the ESP ($esp) is not on the internal NVMe"; fi
  if [[ -r $ROOT/boot/grub/grub.cfg ]]; then
    for u in $(grep -oE -- '--fs-uuid[^|]*--set=[a-z_]+ +[0-9A-Fa-f-]+|search .*--set=root +[0-9A-Fa-f-]+' "$ROOT/boot/grub/grub.cfg" | grep -oE '[0-9A-Fa-f]{4,}(-[0-9A-Fa-f]{4,})+$|[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}' | sort -u); do
      case $(where_is "UUID=$u") in internal) info "grub.cfg refers to $u (internal)" ;; external) warn "grub.cfg menu entry refers to external $u (e.g. the Debian chainload) - only that entry fails without the drive; default boot is unaffected" ;; absent) info "grub.cfg refers to $u (not attached)" ;; esac
    done
    grep -q 'root=UUID=' "$ROOT/boot/grub/grub.cfg" && pass "kernel entries pass root=UUID=" || warn "no root=UUID= in grub.cfg"
  fi
  if command -v efibootmgr >/dev/null; then
    ipu=$(lsblk -no PARTUUID "$(readlink -f /dev/disk/by-uuid/${esp#UUID=} 2>/dev/null)" 2>/dev/null | head -1)
    if [[ -n ${ipu:-} ]] && efibootmgr -v 2>/dev/null | grep -qi "$ipu"; then pass "UEFI has a boot entry for the internal ESP"; else warn "no UEFI boot entry for the internal ESP found (the fallback loader would be used)"; fi
  else skip "efibootmgr not installed"; fi
fi

echo "-- 6. runtime references that are OPTIONAL (informational)"
info "Dr. Boltz persona prompt + shared memory log live on /mnt/brains (internal nvme0n1p5, not in the root fs); without it the server uses a built-in prompt"
info "LucyServer scans /mnt/ventoy/ISO/SWARM_OS and /mnt/Lucy/10-releases for update ISOs; absent drives just mean 'no updates found'"
echo; echo "== result: $fails FAIL, $warns WARN"
exit $((fails > 0))

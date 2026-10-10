#!/usr/bin/env bash
# Functional test of the SWARM OS / Recovery OS / Ventoy menu entries in a REAL GRUB (UEFI, QEMU/OVMF).
#   swarm-grub/tests/qemu_entries.sh          (about two minutes; needs qemu, OVMF, grub-mkstandalone, socat)
#
# The shipped entries/20_swarm_entries is run unchanged, except that the SWARM and Recovery EFI-partition
# UUIDs are swapped for the one QEMU's virtual FAT drive reports (FABE-1AFD). Stand-in "bootloaders" (tiny
# standalone GRUBs) sit where the real ones live and announce themselves on the serial port, which this script
# reads. Ventoy is found through its label (VTOYEFI), exactly the fallback the entry has. Cases run in parallel.
# It does not touch this machine's disks or boot setup; it cannot prove the real disks boot, only that the
# entry logic finds a partition, picks the right file in the right order, chainloads it, and fails politely.
set -Eeuo pipefail
HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ENTRIES=${ENTRIES:-$HERE/../entries/20_swarm_entries}   # override to test a modified copy
CODE=/usr/share/OVMF/OVMF_CODE_4M.fd VARS=/usr/share/OVMF/OVMF_VARS_4M.fd
QEMU_UUID=FABE-1AFD
die() { echo "qemu_entries.sh: $*" >&2; exit 1; }
for t in qemu-system-x86_64 grub-mkstandalone socat; do command -v "$t" >/dev/null || die "$t not found"; done
[[ -f $CODE && -f $VARS ]] || die "OVMF firmware not found (package ovmf)"
ACCEL=tcg; [[ -r /dev/kvm ]] && ACCEL=kvm
MODS='part_gpt part_msdos fat normal configfile echo test sleep serial terminal terminfo chain boot search search_fs_uuid search_label reboot halt'

WORK=$(mktemp -d)
trap 'pkill -P $$ qemu-system-x86_64 2>/dev/null || true; rm -rf "$WORK"' EXIT

standin() {  # standin NAME OUT.efi : a GRUB that reports STANDIN-<NAME>-REACHED on the serial port and waits
  local cfg=$WORK/standin-$1.cfg
  printf '%s\n' 'serial --unit=0' 'terminal_input console serial' 'terminal_output console serial' \
    "echo STANDIN-$1-REACHED" 'sleep 300' >"$cfg"
  grub-mkstandalone -O x86_64-efi -o "$2" --modules="$MODS" "boot/grub/grub.cfg=$cfg" >/dev/null 2>&1
}

main_cfg() {  # main_cfg real|vv OUT : the shipped entries behind a plain text menu that also talks on serial
  local mode=$1
  {
    printf '%s\n' 'serial --unit=0' 'terminal_input console serial' 'terminal_output console serial' \
      'set timeout=-1' 'echo MAIN-GRUB-READY'
    if [[ $mode == vv ]]; then
      sh "$ENTRIES" | sed -e "s/FE19-A70F/$QEMU_UUID/" -e "s/A367-87E3/$QEMU_UUID/"
    else
      sh "$ENTRIES"
    fi
  } >"$2"
}

# run_case NAME MODE(real|vv) STANDINS(yes|no) VENTOY(standin|empty|none) "KEYS" "pattern;pattern;..." [MAIN_GRUB_COUNT]
run_case() {
  local name=$1 mode=$2 standins=$3 ventoy=$4 keys=$5 expect=$6 maincount=${7:-}
  local d=$WORK/$name; mkdir -p "$d/main/EFI/BOOT" "$d/vt/EFI/BOOT"
  main_cfg "$mode" "$d/grub.cfg"
  grub-mkstandalone -O x86_64-efi -o "$d/main/EFI/BOOT/BOOTX64.EFI" --modules="$MODS" "boot/grub/grub.cfg=$d/grub.cfg" >/dev/null 2>&1
  if [[ $standins == yes ]]; then
    mkdir -p "$d/main/EFI/SWARM_OS" "$d/main/EFI/i30ltz"
    cp "$WORK/swarm.efi" "$d/main/EFI/SWARM_OS/grubx64.efi"
    cp "$WORK/recovery.efi" "$d/main/EFI/i30ltz/shimx64.efi"
  fi
  [[ $ventoy == standin ]] && cp "$WORK/ventoy.efi" "$d/vt/EFI/BOOT/BOOTX64.EFI"
  cp "$VARS" "$d/vars.fd"
  local drives=(-drive "file=fat:rw:$d/main,format=raw,if=ide,index=0")
  [[ $ventoy != none ]] && drives+=(-drive "file.driver=vvfat,file.dir=$d/vt,file.label=VTOYEFI,file.rw=on,file.fat-type=16,if=ide,index=1,format=raw")
  qemu-system-x86_64 -machine q35,accel=$ACCEL -m 512 -display none -vga std -no-reboot \
    -drive if=pflash,format=raw,readonly=on,file="$CODE" -drive if=pflash,format=raw,file="$d/vars.fd" \
    "${drives[@]}" -serial "file:$d/serial.log" -monitor "unix:$d/mon,server,nowait" >/dev/null 2>&1 &
  local qpid=$! i k
  for ((i = 0; i < 240; i++)); do grep -q MAIN-GRUB-READY "$d/serial.log" 2>/dev/null && break; sleep 1; done
  sleep 3
  for k in $keys; do printf 'sendkey %s\n' "$k" | socat - UNIX-CONNECT:"$d/mon" >/dev/null; sleep 1.5; done
  local ok=1 pat
  IFS=';' read -ra pats <<<"$expect"
  for pat in "${pats[@]}"; do
    for ((i = 0; i < 40; i++)); do grep -qF -- "$pat" "$d/serial.log" 2>/dev/null && break; sleep 1; done
    grep -qF -- "$pat" "$d/serial.log" || { ok=0; echo "  [$name] missing: $pat"; }
  done
  if [[ -n $maincount ]]; then
    local got; got=$(grep -c MAIN-GRUB-READY "$d/serial.log" || true)
    [[ $got == "$maincount" ]] || { ok=0; echo "  [$name] MAIN-GRUB-READY seen $got times, expected $maincount"; }
  fi
  kill "$qpid" 2>/dev/null || true; wait "$qpid" 2>/dev/null || true
  if ((ok)); then echo "PASS $name"; else echo "FAIL $name"; sed -E 's/\x1b\[[0-9;?]*[A-Za-z]//g' "$d/serial.log" | tr -c '[:print:]\n' ' ' | tr -s ' ' | grep -E 'MAIN-GRUB|STANDIN|SWARM|Recovery|Ventoy|error|Looked' | tail -6 | cut -c1-200 | sed 's/^/    | /'; return 1; fi
}

standin SWARM "$WORK/swarm.efi"; standin RECOVERY "$WORK/recovery.efi"; standin VENTOY "$WORK/ventoy.efi"

echo "running 6 cases in parallel (QEMU $ACCEL)..."
declare -a pids=() names=()
start() { run_case "$@" >"$WORK/result-$1.txt" 2>&1 & pids+=($!); names+=("$1"); }
#     name              uuids  standins ventoy   keys        expect
start swarm_chainload  vv     yes      standin  "ret"          "STANDIN-SWARM-REACHED"                                  1
start recovery_prefers_shim vv yes      standin  "down ret"     "STANDIN-RECOVERY-REACHED"                               1
start ventoy_by_label  vv     yes      standin  "down down ret" "STANDIN-VENTOY-REACHED"                                 1
start disk_unplugged   real   no        none     "ret"          "SWARM OS: its EFI partition (FE19-A70F) was not found."
start fallback_loader  vv     no        none     "ret"          "" 2
start ventoy_no_files  vv     no        empty    "down down ret" "Ventoy: its EFI partition is there but has none of the expected boot files.;Looked for: /EFI/BOOT/BOOTX64.EFI /EFI/BOOT/grubx64.efi /EFI/ventoy/grubx64.efi"

fail=0
for i in "${!pids[@]}"; do
  wait "${pids[$i]}" || fail=1
  cat "$WORK/result-${names[$i]}.txt"
done
((fail)) && { echo "SOME CASES FAILED"; exit 1; }
echo "all entry cases passed"

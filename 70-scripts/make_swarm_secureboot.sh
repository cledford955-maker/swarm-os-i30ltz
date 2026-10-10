#!/usr/bin/env bash
# Make SWARM OS (Arch) bootable with UEFI Secure Boot ON, using sbctl and your own keys (kept alongside Microsoft's and the
# firmware vendor's, so Debian's and Recovery OS's Microsoft-signed shim keep working).
#
# RUN THIS INSIDE SWARM OS, as root. Every phase is a DRY RUN unless you add --apply. Phases, in the order to run them:
#
#   check    read-only: what is installed, what the firmware says, what is signed        (default)
#   keys     install sbctl, create your Secure Boot keys, back them up                    --apply
#   grub     build a NEW signed GRUB in \EFI\SWARM_OS_SB and sign the kernel(s)           --apply
#   hooks    pacman hook so the signed GRUB is rebuilt after a grub update                --apply
#   enroll   put your keys into the firmware (+ Microsoft's + the vendor's)               --apply AND firmware in Setup Mode
#   entry    add a firmware boot entry "SWARM OS (Secure Boot)" for the new GRUB          --apply
#   verify   sbctl status + sbctl verify + reminder
#
#   sudo 70-scripts/make_swarm_secureboot.sh check
#   sudo 70-scripts/make_swarm_secureboot.sh keys --apply
#   ... then grub, hooks, (firmware: reset to Setup Mode), enroll, entry, then turn Secure Boot ON in the firmware and boot-test.
#
# What it NEVER does: remove or change the existing \EFI\SWARM_OS loader or its boot entry (your way back, with Secure Boot
# off), touch Debian's or Recovery OS's partitions, or turn Secure Boot on (a firmware setting only you can change).
# NOT TESTED on a real Arch install by the machine that wrote it (it has no Arch): the logic is covered by a stubbed test,
# 70-scripts/tests/test_make_swarm_secureboot.sh, but read each dry run before you add --apply.
set -euo pipefail
export PATH=/usr/sbin:/sbin:$PATH

PHASE=${1:-check}; shift || true
APPLY=0
[[ $PHASE == -h || $PHASE == --help ]] && { sed -n '2,23p' "$0"; exit 0; }
for a in "$@"; do case $a in --apply) APPLY=1 ;; -h|--help) sed -n '2,23p' "$0"; exit 0 ;; *) echo "unknown option: $a" >&2; exit 2 ;; esac; done

# --- test hooks: every path/command below can be replaced so the test can run it against stubs and temp directories ---
TEST=${SWARM_SB_TEST:-0}
EFIVARS=${SWARM_SB_EFIVARS:-/sys/firmware/efi/efivars}
BOOT_DIR=${SWARM_SB_BOOT:-/boot}
SBCTL_DIR=${SWARM_SB_SBCTL_DIR:-/var/lib/sbctl}
HOOK_DIR=${SWARM_SB_HOOK_DIR:-/etc/pacman.d/hooks}
HELPER=${SWARM_SB_HELPER:-/usr/local/bin/swarm-sb-grub-refresh}
BACKUP_DIR=${SWARM_SB_BACKUP_DIR:-/root}
SBCTL=${SBCTL:-sbctl}
EFIBOOTMGR=${EFIBOOTMGR:-efibootmgr}
PACMAN=${PACMAN:-pacman}
GRUB_INSTALL=${GRUB_INSTALL:-grub-install}

SWARM_ESP_UUID=FE19-A70F                       # SWARM OS's own EFI partition on the internal NVMe
ESP=${SWARM_ESP:-$(findmnt -rn -S "UUID=$SWARM_ESP_UUID" -o TARGET 2>/dev/null | head -1 || true)}
ESP=${ESP:-/boot/efi}
BOOTLOADER_ID=SWARM_OS_SB
ENTRY_LABEL="SWARM OS (Secure Boot)"
GRUB_EFI="$ESP/EFI/$BOOTLOADER_ID/grubx64.efi"
STAMP=$(date +%Y%m%d-%H%M%S)
# Under Secure Boot GRUB refuses to load modules from disk, so everything the menu needs must be built INTO the image.
GRUB_MODULES="all_video boot btrfs cat chain configfile echo efifwsetup efinet ext2 fat font gettext gfxmenu gfxterm gfxterm_background gzio halt help iso9660 jpeg keystatus loadenv loopback linux ls lsefi minicmd normal part_gpt part_msdos png probe reboot regexp search search_fs_uuid search_fs_file search_label sleep test true video tpm"

say()  { printf '%s\n' "$*"; }
die()  { printf 'ABORT: %s\n' "$*" >&2; exit 1; }
run()  { if (( APPLY )); then say "+ $*"; "$@"; else say "[dry-run] $*"; fi; }
note_dry() { (( APPLY )) || say "(phase '$PHASE' only shows its plan without --apply)"; }
have() { command -v "$1" >/dev/null 2>&1; }

if (( ! TEST )); then
  [[ -f /etc/arch-release ]] || die "this is not Arch/SWARM OS. Run it inside SWARM OS (your Debian is not the target)."
  (( EUID == 0 )) || die "run as root: sudo $0 $PHASE${APPLY:+ --apply}"
  [[ -d /sys/firmware/efi ]] || die "not booted via UEFI"
  mountpoint -q "$ESP" || die "$ESP is not mounted (SWARM's EFI partition, UUID $SWARM_ESP_UUID). Mount it, or set SWARM_ESP=/where/it/is"
fi

efivar_byte() { od -An -tu1 -j4 -N1 "$EFIVARS/$1-8be4df61-93ca-11d2-aa0d-00e098032b8c" 2>/dev/null | tr -d ' ' || true; }
sb_on()    { [[ $(efivar_byte SecureBoot) == 1 ]]; }
setup_on() { [[ $(efivar_byte SetupMode) == 1 ]]; }

kernels() { local f; for f in "$BOOT_DIR"/vmlinuz-*; do [[ -f $f ]] && printf '%s\n' "$f"; done; return 0; }
# "not signed" lines from sbctl verify that concern the files WE care about (the new GRUB and the kernels)
unsigned_ours() {
  local out; out=$("$SBCTL" verify 2>&1 || true)
  grep -i 'not signed' <<< "$out" | grep -F -e "$GRUB_EFI" -e "$BOOT_DIR/vmlinuz-" || true
}

phase_check() {
  say "== state"
  say "Secure Boot: $(sb_on && echo ON || echo off)   Setup Mode: $(setup_on && echo 'YES (firmware accepts new keys)' || echo 'no')"
  say "sbctl installed: $(have "$SBCTL" && echo yes || echo no)   keys created: $([[ -d $SBCTL_DIR/keys ]] && echo yes || echo no)"
  say "EFI partition: $ESP"
  local k; k=$(kernels)
  if [[ -z $k ]]; then say "kernels in $BOOT_DIR: none found"; else
    say "kernels in $BOOT_DIR: $(tr '\n' ' ' <<< "$k")"
    if have "$SBCTL" && [[ -d $SBCTL_DIR/keys ]]; then
      local u; u=$(unsigned_ours); say "unsigned (ours): ${u:-none}"
    else say "signed? (sbctl not set up yet)"; fi
  fi
  say "new signed GRUB $GRUB_EFI: $([[ -f $GRUB_EFI ]] && echo present || echo 'not built yet')"
  say "existing loader (your way back, never touched): $([[ -f $ESP/EFI/SWARM_OS/grubx64.efi ]] && echo "$ESP/EFI/SWARM_OS/grubx64.efi" || echo 'not found')"
  if have "$EFIBOOTMGR"; then say "firmware entries:"; "$EFIBOOTMGR" 2>/dev/null | head -12 | sed 's/^/  /'; fi
  say ""; say "== plan, in order"
  say "  keys   -> pacman -S --needed sbctl ; sbctl create-keys ; back the keys up (root-only tar)"
  say "  grub   -> grub-install into \\EFI\\$BOOTLOADER_ID with the modules built in ; sbctl sign -s GRUB and the kernel(s)"
  say "  hooks  -> keep the signed GRUB current after a grub update (sbctl's own hook keeps the kernel signed)"
  say "  [you]  -> firmware: Security > Secure Boot > reset to Setup Mode (keep Secure Boot OFF for now)"
  say "  enroll -> sbctl enroll-keys --microsoft --firmware-builtin"
  say "  entry  -> efibootmgr entry '$ENTRY_LABEL' (the old SWARM_OS entry stays)"
  say "  [you]  -> firmware: turn Secure Boot ON, pick '$ENTRY_LABEL', boot-test SWARM, Debian and Recovery OS"
}

phase_keys() {
  note_dry
  have "$PACMAN" || die "pacman not found"
  run "$PACMAN" -S --needed --noconfirm sbctl
  if [[ -d $SBCTL_DIR/keys ]]; then say "keys already exist in $SBCTL_DIR/keys: not creating new ones"
  else run "$SBCTL" create-keys; fi
  local bak="$BACKUP_DIR/sbctl-keys-backup-$STAMP.tar"
  if (( APPLY )); then
    [[ -d $SBCTL_DIR ]] || die "$SBCTL_DIR does not exist after create-keys: something went wrong"
    ( umask 077; tar -C "$(dirname "$SBCTL_DIR")" -cf "$bak" "$(basename "$SBCTL_DIR")" )
    chmod 600 "$bak"
    say "keys backed up to $bak (root-only). These are PRIVATE signing keys: copy the file off this machine to an encrypted place,"
    say "and never to anything other people can read. Without them you cannot sign future kernels."
  else
    say "[dry-run] tar the keys into $bak (root-only)"
  fi
}

phase_grub() {
  note_dry
  have "$SBCTL" || die "run the 'keys' phase first"
  [[ -d $SBCTL_DIR/keys ]] || die "no keys yet: run the 'keys' phase first"
  local ks; ks=$(kernels); [[ -n $ks ]] || die "no $BOOT_DIR/vmlinuz-* kernel found"
  say "Building a NEW GRUB in \\EFI\\$BOOTLOADER_ID; the working \\EFI\\SWARM_OS is not touched."
  run "$GRUB_INSTALL" --target=x86_64-efi --efi-directory="$ESP" --bootloader-id="$BOOTLOADER_ID" \
      --modules="$GRUB_MODULES" --disable-shim-lock --no-nvram --recheck
  run "$SBCTL" sign -s "$GRUB_EFI"
  local k; while IFS= read -r k; do run "$SBCTL" sign -s "$k"; done <<< "$ks"
  say "initramfs images are NOT signed: GRUB does not check them; only GRUB and the kernel must carry your signature."
  say "Note: btrfs snapshots from BEFORE this change hold an unsigned kernel; those snapshot entries will not boot with Secure Boot on."
}

phase_hooks() {
  note_dry
  say "sbctl's own pacman hook re-signs the files it knows (the kernel) after every update. GRUB's EFI image is built by grub-install"
  say "and is NOT refreshed by pacman, so this adds a hook that rebuilds and re-signs it when the grub package is upgraded."
  if (( APPLY )); then
    install -d "$HOOK_DIR" "$(dirname "$HELPER")"
    cat > "$HELPER" <<EOF
#!/usr/bin/env bash
# Rebuild and re-sign the Secure Boot GRUB after the grub package changes (installed by make_swarm_secureboot.sh).
set -euo pipefail
grub-install --target=x86_64-efi --efi-directory=$ESP --bootloader-id=$BOOTLOADER_ID --modules="$GRUB_MODULES" --disable-shim-lock --no-nvram --recheck
$SBCTL sign -s $GRUB_EFI
EOF
    chmod 755 "$HELPER"
    cat > "$HOOK_DIR/95-swarm-sb-grub.hook" <<EOF
[Trigger]
Type = Package
Operation = Upgrade
Target = grub

[Action]
Description = Rebuilding and signing the Secure Boot GRUB (SWARM)
When = PostTransaction
Exec = $HELPER
EOF
    say "installed $HELPER and $HOOK_DIR/95-swarm-sb-grub.hook"
  else
    say "[dry-run] would install $HELPER and $HOOK_DIR/95-swarm-sb-grub.hook (runs after any 'grub' upgrade)"
  fi
}

phase_enroll() {
  note_dry
  have "$SBCTL" || die "run the 'keys' phase first"
  [[ -f $GRUB_EFI ]] || die "build and sign the new GRUB first (phase 'grub'): enrolling keys before things are signed leaves nothing bootable"
  local u; u=$(unsigned_ours)
  [[ -z $u ]] || die "still unsigned: $u -- run the 'grub' phase again"
  if ! setup_on; then
    say "The firmware is NOT in Setup Mode, so it will not accept new keys."
    say "Reboot into the firmware setup (Lenovo: F1 at the logo) > Security > Secure Boot: keep Secure Boot OFF and choose 'Reset to Setup Mode'"
    say "(or 'Clear all Secure Boot keys'). Boot back into SWARM OS and run this phase again."
    (( ! APPLY )) || exit 1
  fi
  say "Keeping Microsoft's keys (Debian's and Recovery OS's shim are Microsoft-signed) and the firmware vendor's keys."
  run "$SBCTL" enroll-keys --microsoft --firmware-builtin
}

phase_entry() {
  note_dry
  [[ -f $GRUB_EFI ]] || die "no signed GRUB yet (phase 'grub')"
  if "$EFIBOOTMGR" | grep -q -F -e " $ENTRY_LABEL"; then say "firmware entry '$ENTRY_LABEL' already exists: nothing to do"; return 0; fi
  local dev disk part
  if [[ -n ${SWARM_SB_DISK:-} ]]; then disk=$SWARM_SB_DISK part=${SWARM_SB_PART:-1}
  else
    dev=$(findmnt -no SOURCE "$ESP"); disk=/dev/$(lsblk -ndo PKNAME "$dev"); part=$(cat "/sys/class/block/$(basename "$dev")/partition")
  fi
  say "Adding '$ENTRY_LABEL' ($disk partition $part). Existing entries, including the old SWARM_OS one, stay."
  local before; before=$("$EFIBOOTMGR" | sed -n 's/^BootOrder: //p')
  run "$EFIBOOTMGR" -c -d "$disk" -p "$part" -L "$ENTRY_LABEL" -l "\\EFI\\$BOOTLOADER_ID\\grubx64.efi"
  if (( APPLY )); then
    # a new entry goes FIRST by default: keep the order you had and put the new one LAST until you have boot-tested it
    local new="" line after
    while IFS= read -r line; do
      [[ $line == Boot[0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f]*" $ENTRY_LABEL"* ]] && new=${line:4:4}
    done < <("$EFIBOOTMGR")
    if [[ -z $new ]]; then
      say "WARNING: could not find the new entry afterwards; BootOrder left as the firmware set it (new entry first). Check 'efibootmgr'."
    else
      after=$(tr ',' '\n' <<< "$before" | { grep -vix -e "$new" -e '' || true; } | paste -sd, -)
      "$EFIBOOTMGR" -o "${after:+$after,}$new" >/dev/null
      say "BootOrder: ${after:+$after,}$new  (new entry last; pick it from the F12 menu to test, move it first once it works)"
    fi
  fi
}

phase_verify() {
  have "$SBCTL" || die "sbctl is not installed"
  say "== sbctl status"; "$SBCTL" status || true
  say "== signed files"; "$SBCTL" verify || true
  say "== reminder"
  say "Secure Boot is $(sb_on && echo ON || echo OFF). If OFF: enable it in the firmware, then boot '$ENTRY_LABEL' from the F12 menu."
  say "If SWARM does not start with Secure Boot on: turn Secure Boot off again, or boot Debian/Recovery OS from F12; nothing was removed."
}

case $PHASE in
  check)  phase_check ;;
  keys)   phase_keys ;;
  grub)   phase_grub ;;
  hooks)  phase_hooks ;;
  enroll) phase_enroll ;;
  entry)  phase_entry ;;
  verify) phase_verify ;;
  *) die "unknown phase '$PHASE' (check keys grub hooks enroll entry verify)" ;;
esac
if [[ $PHASE != check && $PHASE != verify ]] && (( ! APPLY )); then say "(dry run: nothing was changed. Add --apply to do it.)"; fi

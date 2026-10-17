#!/usr/bin/env bash
# Tests make_swarm_secureboot.sh against stub sbctl / efibootmgr / pacman / grub-install and temp directories.
# Nothing real is touched: the script's test hooks (SWARM_SB_TEST=1 and the *_DIR / command overrides) point it at $T.
# Run: bash 70-scripts/tests/test_make_swarm_secureboot.sh
set -euo pipefail
HERE=$(cd "$(dirname "$0")/.." && pwd); S="$HERE/make_swarm_secureboot.sh"
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
fail() { echo "FAIL: $*"; exit 1; }; ok() { echo "ok   $*"; }
mkdir -p "$T/bin" "$T/esp/EFI/SWARM_OS" "$T/boot" "$T/efivars"
: > "$T/esp/EFI/SWARM_OS/grubx64.efi"; : > "$T/boot/vmlinuz-linux"
KERNEL="$T/boot/vmlinuz-linux"; GRUB="$T/esp/EFI/SWARM_OS_SB/grubx64.efi"; OLD="$T/esp/EFI/SWARM_OS/grubx64.efi"

# ---- stubs ----
cat > "$T/bin/sbctl" <<'EOS'
#!/usr/bin/env bash
D=$(dirname "$0"); echo "sbctl $*" >> "$D/calls"
case "$1" in
  create-keys) mkdir -p "$SWARM_SB_SBCTL_DIR/keys"; echo secret > "$SWARM_SB_SBCTL_DIR/keys/db.key" ;;
  sign) echo "$3" >> "$D/signed" ;;
  verify) for f in "$OLDGRUB" "$KERNELF" "$NEWGRUB"; do
            [[ -e $f ]] || continue
            if grep -qxF "$f" "$D/signed" 2>/dev/null; then echo "✓ $f is signed"; else echo "✗ $f is not signed"; fi
          done; exit 1 ;;     # real sbctl verify exits non-zero when anything is unsigned (even the files we do not care about)
  status) echo "Installed: yes" ;;
esac
EOS
cat > "$T/bin/pacman" <<'EOS'
#!/usr/bin/env bash
echo "pacman $*" >> "$(dirname "$0")/calls"
EOS
cat > "$T/bin/grub-install" <<'EOS'
#!/usr/bin/env bash
D=$(dirname "$0"); echo "grub-install $*" >> "$D/calls"
for a in "$@"; do case $a in --efi-directory=*) e=${a#*=};; --bootloader-id=*) i=${a#*=};; esac; done
mkdir -p "$e/EFI/$i"; : > "$e/EFI/$i/grubx64.efi"
EOS
cat > "$T/bin/efibootmgr" <<'EOS'
#!/usr/bin/env bash
D=$(dirname "$0"); S=$D/state; echo "efibootmgr $*" >> "$D/calls"
case "${1:-}" in
  "") cat "$S" ;;
  -c) lbl="" ld=""; shift; while [[ $# -gt 0 ]]; do case $1 in -L) lbl=$2; shift 2;; -l) ld=$2; shift 2;; *) shift 2;; esac; done
      printf 'Boot0006* %s\tHD(1,GPT,41cd2e0e-92fe-4300-9d8d-f37ad7f486d7,0x800,0x41a000)/File(%s)\n' "$lbl" "$ld" >> "$S"
      sed -i "s/^BootOrder: /BootOrder: 0006,/" "$S"; cat "$S" ;;
  -o) sed -i "s/^BootOrder: .*/BootOrder: $2/" "$S" ;;
esac
EOS
chmod +x "$T/bin/"*
cat > "$T/bin/state" <<'EOS'
BootCurrent: 0003
Timeout: 2 seconds
BootOrder: 0003,0000,0001
Boot0000* SWARM_OS	HD(1,GPT,41cd2e0e-92fe-4300-9d8d-f37ad7f486d7,0x800,0x41a000)/File(\EFI\SWARM_OS\grubx64.efi)
Boot0001* I30LTZ Recovery OS	HD(1,GPT,e25e5715-f3b8-4ddb-9796-d1c270804140,0x800,0x200000)/File(\EFI\i30ltz\shimx64.efi)
Boot0003* debian	HD(1,GPT,c2da7f22-db73-4cc3-b73f-6446fa6aad3d,0x800,0x219800)/File(\EFI\debian\shimx64.efi)
EOS
setup_mode() { printf '\x07\x00\x00\x00%b' "$1" > "$T/efivars/SetupMode-8be4df61-93ca-11d2-aa0d-00e098032b8c"; }   # 4 attribute bytes + value
secure_boot() { printf '\x06\x00\x00\x00%b' "$1" > "$T/efivars/SecureBoot-8be4df61-93ca-11d2-aa0d-00e098032b8c"; }
setup_mode '\x00'; secure_boot '\x00'

sb() { SWARM_SB_TEST=1 SWARM_ESP="$T/esp" SWARM_SB_BOOT="$T/boot" SWARM_SB_SBCTL_DIR="$T/var/sbctl" SWARM_SB_HOOK_DIR="$T/hooks" \
       SWARM_SB_HELPER="$T/usr/swarm-sb-grub-refresh" SWARM_SB_BACKUP_DIR="$T/root" SWARM_SB_EFIVARS="$T/efivars" SWARM_SB_DISK=/dev/nvme0n1 SWARM_SB_PART=1 \
       SBCTL="$T/bin/sbctl" EFIBOOTMGR="$T/bin/efibootmgr" PACMAN="$T/bin/pacman" GRUB_INSTALL="$T/bin/grub-install" \
       OLDGRUB="$OLD" KERNELF="$KERNEL" NEWGRUB="$GRUB" bash "$S" "$@"; }
mkdir -p "$T/root"
calls() { cat "$T/bin/calls" 2>/dev/null || true; }

# 1. check changes nothing and reports the state
out=$(sb check); [[ $out == *"Secure Boot: off"* && $out == *"keys created: no"* && $out == *"not built yet"* ]] || fail "check output: $out"
writes() { calls | grep -vE '^(efibootmgr|sbctl verify|sbctl status) *$' || true; }   # reads are fine: the plain firmware listing, verify, status
[[ -z $(writes) ]] || fail "check must not run anything but reads: $(calls)"; ok "check reports state and changes nothing"

# 2. unknown phase / option refused
sb nonsense >/dev/null 2>&1 && fail "unknown phase should fail"; sb check --bogus >/dev/null 2>&1 && fail "unknown option should fail"; ok "unknown phase and option are refused"

# 3. keys: dry run does nothing; apply creates keys and a root-only backup
out=$(sb keys); [[ $out == *"[dry-run]"* && ! -d $T/var/sbctl ]] || fail "keys dry-run must create nothing: $out"
[[ -z $(writes) ]] || fail "keys dry-run ran commands: $(calls)"
sb keys --apply >/dev/null
[[ -f $T/var/sbctl/keys/db.key ]] || fail "keys were not created"
bak=$(ls "$T"/root/sbctl-keys-backup-*.tar); [[ $(stat -c %a "$bak") == 600 ]] || fail "backup must be mode 600"
tar -tf "$bak" | grep -q 'sbctl/keys/db.key' || fail "backup does not contain the keys"
calls | grep -q 'pacman -S --needed --noconfirm sbctl' || fail "sbctl was not installed"; ok "keys: dry run inert; apply creates keys + a 0600 backup that contains them"
: > "$T/bin/calls"; sb keys --apply >/dev/null; calls | grep -q create-keys && fail "must not create new keys over existing ones"; ok "keys: existing keys are never overwritten"

# 4. grub: dry run builds nothing; apply builds into the NEW path and signs GRUB + kernel; the old loader is untouched
: > "$T/bin/calls"; out=$(sb grub); [[ ! -e $GRUB && $out == *"[dry-run]"* ]] || fail "grub dry-run built something"
[[ -z $(writes) ]] || fail "grub dry-run ran commands"
sb grub --apply >/dev/null; [[ -f $GRUB ]] || fail "new GRUB not built at $GRUB"
c=$(calls); [[ $c == *"--disable-shim-lock"* && $c == *"--no-nvram"* && $c == *"--bootloader-id=SWARM_OS_SB"* && $c == *" tpm"* ]] || fail "grub-install args: $c"
grep -qxF "$GRUB" "$T/bin/signed" && grep -qxF "$KERNEL" "$T/bin/signed" || fail "GRUB and kernel must both be signed: $(cat "$T/bin/signed")"
grep -qxF "$OLD" "$T/bin/signed" && fail "the old loader must not be touched/signed"
ok "grub: built at the new path with shim-lock disabled + tpm module, GRUB and kernel signed, old loader untouched"

# 5. hooks
sb hooks --apply >/dev/null
[[ -x $T/usr/swarm-sb-grub-refresh ]] && grep -q 'Target = grub' "$T/hooks/95-swarm-sb-grub.hook" && grep -q "Exec = $T/usr/swarm-sb-grub-refresh" "$T/hooks/95-swarm-sb-grub.hook" || fail "hook files wrong"
grep -q -- '--disable-shim-lock' "$T/usr/swarm-sb-grub-refresh" && grep -q "sign -s $GRUB" "$T/usr/swarm-sb-grub-refresh" || fail "helper content wrong"
bash -n "$T/usr/swarm-sb-grub-refresh" || fail "helper has a syntax error"; ok "hooks: helper + pacman hook installed and well-formed"

# 6. enroll: refuses unless everything is signed AND the firmware is in Setup Mode
: > "$T/bin/calls"; : > "$T/bin/signed"       # forget the signatures -> enroll must refuse
out=$(sb enroll --apply 2>&1 || true); [[ $out == *"still unsigned"* ]] || fail "enroll must refuse with unsigned files: $out"
calls | grep -q enroll-keys && fail "enrolled keys although files were unsigned"
sb grub --apply >/dev/null; : > "$T/bin/calls"
out=$(sb enroll --apply 2>&1) && fail "enroll --apply must fail when not in Setup Mode"; [[ $out == *"NOT in Setup Mode"* ]] || fail "setup-mode message: $out"
calls | grep -q enroll-keys && fail "enrolled keys outside Setup Mode"
out=$(sb enroll); [[ $out == *"NOT in Setup Mode"* && $out == *"[dry-run]"* ]] || fail "dry run should explain and show the command: $out"
setup_mode '\x01'; : > "$T/bin/calls"
out=$(sb check); [[ $out == *"Setup Mode: YES"* ]] || fail "check should see Setup Mode: $out"
sb enroll --apply >/dev/null; calls | grep -q 'enroll-keys --microsoft --firmware-builtin' || fail "enroll must keep Microsoft + firmware keys: $(calls)"
ok "enroll: refuses unsigned files and non-Setup-Mode firmware; in Setup Mode enrolls with Microsoft + firmware keys"

# 7. entry: dry run changes nothing; apply adds the entry LAST in BootOrder and leaves the others alone; idempotent
: > "$T/bin/calls"; cp "$T/bin/state" "$T/state.before"
out=$(sb entry); [[ $out == *"[dry-run]"* ]] || fail "entry dry-run: $out"; cmp -s "$T/bin/state" "$T/state.before" || fail "entry dry-run changed the firmware"
calls | grep -qE 'efibootmgr (-c|-o)' && fail "entry dry-run wrote to the firmware"
sb entry --apply >/dev/null
grep -q 'SWARM OS (Secure Boot).*SWARM_OS_SB.grubx64.efi' "$T/bin/state" || fail "new entry should point at the new GRUB: $(cat "$T/bin/state")"
grep -q '^BootOrder: 0003,0000,0001,0006$' "$T/bin/state" || fail "new entry must be LAST: $(grep BootOrder "$T/bin/state")"
grep -q 'Boot0000\* SWARM_OS' "$T/bin/state" && grep -q 'Boot0003\* debian' "$T/bin/state" && grep -q 'Boot0001\* I30LTZ' "$T/bin/state" || fail "existing entries must stay"
before=$(cat "$T/bin/state"); out=$(sb entry --apply); [[ $out == *"already exists"* && $(cat "$T/bin/state") == "$before" ]] || fail "second run should do nothing: $out"
ok "entry: added last in BootOrder pointing at the new GRUB, other entries untouched, idempotent"

# 8. entry with an EMPTY BootOrder (fresh firmware) must not crash
cat > "$T/bin/state" <<'EOS'
BootOrder:
EOS
out=$(sb entry --apply 2>&1) || fail "entry crashed on an empty BootOrder: $out"
grep -q 'SWARM OS (Secure Boot)' "$T/bin/state" || fail "entry not added with empty BootOrder"; ok "entry: works with an empty BootOrder"

# 9. verify runs and tells the truth about Secure Boot
secure_boot '\x01'; out=$(sb verify); [[ $out == *"Secure Boot is ON"* ]] || fail "verify should say ON: $out"
secure_boot '\x00'; out=$(sb verify); [[ $out == *"Secure Boot is OFF"* ]] || fail "verify should say OFF: $out"; ok "verify reports the real Secure Boot state"

# 10. outside Arch the script refuses (the real guard, not the test hook)
out=$(bash "$S" check 2>&1 || true); if [[ ! -f /etc/arch-release ]]; then [[ $out == *"not Arch"* ]] || fail "should refuse on non-Arch: $out"; ok "refuses to run outside Arch/SWARM OS"; fi
echo "ALL OK"

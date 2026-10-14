#!/usr/bin/env bash
# provision_swarm_key.sh — turn the old Ventoy stick into the SWARM OS hardware sudo key.
#
#   sudo 70-scripts/provision_swarm_key.sh             # dry run: checks everything, shows the plan, changes nothing
#   sudo 70-scripts/provision_swarm_key.sh --apply     # ERASES the stick, writes the key, wires SWARM's sudo
#   sudo 70-scripts/provision_swarm_key.sh --revoke    # delete the key registration (the stick then does nothing)
#
# What --apply does (user decision 2026-10-14: Ventoy and ISOs are retired):
#   1. Refuses unless the target is exactly the known stick (by-id name, USB, ~58.6 GB, only
#      Ventoy mounts on it). You must type its serial to continue. EVERYTHING on it is lost,
#      including the ISOs and swarm-persist.img.
#   2. Unmounts it, comments out its /etc/fstab line (backup kept), wipes every old signature
#      (Ventoy boot code, GPT, VTOYEFI) and builds a fresh GPT with a random disk GUID:
#        p1  SWARM-KEY-SECRET  1 MiB raw, random PARTUUID  - holds the 256-bit secret
#        p2  SWARM-KEY         64 MiB ext4, random UUID    - label + a text file with the key serial (no secret)
#   3. Writes the secret, reads it back and checks it (cheap sticks can lose writes silently).
#   4. On SWARM's installed root (default /mnt/swarm/@): installs the helper, writes the registry
#      /etc/swarm_os/sudo_key.conf (root:root 0600: SHA-256 of the secret + PARTUUID + the stick's
#      USB serial), and adds ONE line to /etc/pam.d/sudo (backup kept):
#        auth sufficient pam_exec.so quiet seteuid /usr/lib/swarm/swarm-key-sudo-auth
#      The password stays as the fallback. Only sudo is touched - not login, su, polkit or the lock screen.
#
# The secret is never printed, never put in this repo, and exists only on the stick (the registry
# keeps its hash). The PARTUUID, UUID and key serial are NOT secrets and are easy to copy; the
# stick's hardware serial is burned in and cannot be changed. Only the secret is the credential.
set -euo pipefail
export PATH="/usr/sbin:/sbin:/usr/bin:/bin"

STICK_BYID="/dev/disk/by-id/usb-VendorCo_ProductCode_3664251034070005592-0:0"
STICK_SERIAL="3664251034070005592"
STICK_BYTES=62914560000           # 122880000 sectors * 512, as seen 2026-10-14
SWARM_ROOT="/mnt/swarm/@"
HERE="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
HELPER_SRC="$HERE/../40-iso-profile/swarm_os_iso_profile/airootfs/usr/lib/swarm/swarm-key-sudo-auth"
PAM_LINE="auth        sufficient    pam_exec.so quiet seteuid /usr/lib/swarm/swarm-key-sudo-auth"

MODE=dry
while [ $# -gt 0 ]; do
    case "$1" in
        --apply) MODE=apply ;;
        --revoke) MODE=revoke ;;
        --swarm-root) SWARM_ROOT="${2:?path}"; shift ;;
        -h|--help) sed -n '2,28p' "$0"; exit 0 ;;
        *) echo "unknown option: $1" >&2; exit 2 ;;
    esac
    shift
done

say()  { printf '\033[1;36m[swarm-key]\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31m[swarm-key] %s\033[0m\n' "$*" >&2; exit 1; }
do_it() { if [ "$MODE" = apply ]; then "$@"; else printf '   (dry run) %s\n' "$*"; fi; }

[ "$(id -u)" -eq 0 ] || die "run as root: sudo $0 ${*:-}"
REG_DIR="$SWARM_ROOT/etc/swarm_os"
REG="$REG_DIR/sudo_key.conf"
[ -d "$SWARM_ROOT/etc/pam.d" ] || die "SWARM root not found at $SWARM_ROOT (mount it, or pass --swarm-root)"

if [ "$MODE" = revoke ]; then
    [ -e "$REG" ] || { say "nothing to revoke: $REG does not exist"; exit 0; }
    shred -u "$REG" 2>/dev/null || rm -f "$REG"
    say "revoked: $REG removed. The stick no longer authenticates sudo (the PAM line may stay; it then always falls through to the password)."
    exit 0
fi

# ── 1. Identify the stick; refuse anything that is not exactly it ────────────────────────────
for tool in sfdisk wipefs mkfs.ext4 udevadm lsblk sha256sum dd base32; do
    command -v "$tool" >/dev/null || die "missing tool: $tool"
done
[ -e "$STICK_BYID" ] || die "stick not attached: $STICK_BYID"
DEV="$(readlink -f "$STICK_BYID")"
[ -b "$DEV" ] || die "$DEV is not a block device"
TRAN="$(lsblk -dno TRAN "$DEV")"; SIZE="$(lsblk -dbno SIZE "$DEV")"
[ "$TRAN" = usb ] || die "$DEV is not a USB device (TRAN=$TRAN)"
[ "$SIZE" -ge $((STICK_BYTES - STICK_BYTES / 100)) ] && [ "$SIZE" -le $((STICK_BYTES + STICK_BYTES / 100)) ] \
    || die "$DEV is $SIZE bytes, expected about $STICK_BYTES"
HWSERIAL="$(udevadm info --query=property --name="$DEV" | sed -n 's/^ID_SERIAL_SHORT=//p')"
[ "$HWSERIAL" = "$STICK_SERIAL" ] || die "USB serial is '$HWSERIAL', expected $STICK_SERIAL"
# Only Ventoy's own mounts may be on it; anything else means a real drive or a mistake.
while read -r mp; do
    [ -z "$mp" ] && continue
    case "$mp" in /mnt/ventoy|/media/*/VTOYEFI) ;; *) die "unexpected mount on $DEV: $mp";; esac
done < <(lsblk -nro MOUNTPOINT "$DEV")
ROOTDEV="$(findmnt -no SOURCE / | sed 's/\[.*//')"
case "$ROOTDEV" in "$DEV"*) die "$DEV holds the running root";; esac

say "target: $DEV  ($((SIZE/1000000000)) GB, USB serial $HWSERIAL)"
lsblk -o NAME,SIZE,FSTYPE,LABEL,MOUNTPOINT "$DEV"
KEY_SERIAL="SWK-$(head -c 20 /dev/urandom | base32 | tr -d '=' | cut -c1-20 | sed 's/.\{5\}/&-/g;s/-$//')"
P1_UUID="$(cat /proc/sys/kernel/random/uuid)"; P2_UUID="$(cat /proc/sys/kernel/random/uuid)"
DISK_GUID="$(cat /proc/sys/kernel/random/uuid)"; FS_UUID="$(cat /proc/sys/kernel/random/uuid)"
say "plan: p1 SWARM-KEY-SECRET partuuid=$P1_UUID | p2 SWARM-KEY fs-uuid=$FS_UUID | key serial $KEY_SERIAL"
say "plan: install helper + registry + 1 PAM line in $SWARM_ROOT (backups kept)"

if [ "$MODE" = dry ]; then
    say "DRY RUN — nothing changed. Re-run with --apply to erase the stick and write the key."
    exit 0
fi

echo
echo "This ERASES ALL of $DEV (Ventoy, the ISOs, swarm-persist.img). It cannot be undone."
read -r -p "Type the stick's USB serial ($STICK_SERIAL) to continue: " typed
[ "$typed" = "$STICK_SERIAL" ] || die "serial did not match; nothing changed"

# ── 2. Release, un-fstab, wipe, partition ────────────────────────────────────────────────────
systemctl stop mnt-ventoy.automount mnt-ventoy.mount 2>/dev/null || true
while read -r mp; do [ -n "$mp" ] && umount "$mp"; done < <(lsblk -nro MOUNTPOINT "$DEV" | sort -r)
if grep -q '^UUID=5ABB-83DF' /etc/fstab; then
    cp -a /etc/fstab "/etc/fstab.bak-$(date +%Y%m%d-%H%M%S)"
    sed -i 's|^\(UUID=5ABB-83DF.*\)$|# retired 2026-10-14 (stick is now the SWARM key): \1|' /etc/fstab
    systemctl daemon-reload
    say "commented out the Ventoy line in /etc/fstab (backup kept)"
fi
for p in $(lsblk -nrpo NAME "$DEV" | tail -n +2); do wipefs -a "$p" >/dev/null; done
wipefs -a "$DEV" >/dev/null
dd if=/dev/zero of="$DEV" bs=1M count=32 conv=fsync status=none
dd if=/dev/zero of="$DEV" bs=1M count=32 seek=$(( SIZE / 1048576 - 32 )) conv=fsync status=none 2>/dev/null || true
GPT_LINUX="0FC63DAF-8483-4772-8E79-3D69D8477DE4"
sfdisk -q "$DEV" <<GPT
label: gpt
label-id: $DISK_GUID
unit: sectors
start=2048, size=2048, type=$GPT_LINUX, name="SWARM-KEY-SECRET", uuid=$P1_UUID
start=4096, size=131072, type=$GPT_LINUX, name="SWARM-KEY", uuid=$P2_UUID
GPT
partprobe "$DEV" 2>/dev/null || true; udevadm settle
P1="/dev/disk/by-partuuid/$P1_UUID"; P2="/dev/disk/by-partuuid/$P2_UUID"
for _ in $(seq 1 20); do [ -b "$P1" ] && [ -b "$P2" ] && break; sleep 0.5; done
[ -b "$P1" ] && [ -b "$P2" ] || die "new partitions did not appear"

# ── 3. Secret: write, read back, verify ──────────────────────────────────────────────────────
SECRET="$(head -c 32 /dev/urandom | od -An -tx1 | tr -d ' \n')"
[ "${#SECRET}" -eq 64 ] || die "secret generation failed"
printf 'SWK1:%s\n' "$SECRET" | dd of="$P1" bs=70 count=1 conv=fsync status=none
sync; echo 3 > /proc/sys/vm/drop_caches 2>/dev/null || true
READBACK="$(dd if="$P1" bs=70 count=1 iflag=direct status=none)"
[ "$READBACK" = "SWK1:$SECRET" ] || die "read-back mismatch — the stick is unreliable; do not use it"
SECRET_SHA="$(printf '%s' "$SECRET" | sha256sum | cut -d' ' -f1)"
unset READBACK SECRET

# ── 4. Identification partition (no secret on it) ────────────────────────────────────────────
mkfs.ext4 -q -F -L SWARM-KEY -U "$FS_UUID" "$P2"
T="$(mktemp -d)"; mount "$P2" "$T"
cat > "$T/KEY-SERIAL.txt" <<EOF
SWARM OS hardware key
Key serial : $KEY_SERIAL
Partition  : SWARM-KEY-SECRET  PARTUUID $P1_UUID
Created    : $(date -u +%Y-%m-%dT%H:%M:%SZ)

Plugged into a SWARM OS machine, this stick lets 'sudo' skip the password.
Treat it like a house key. Revoke with: sudo provision_swarm_key.sh --revoke
(The secret is not on this partition.)
EOF
umount "$T"; rmdir "$T"

# ── 5. Wire SWARM: helper, registry, PAM line ────────────────────────────────────────────────
install -D -m 0755 -o root -g root "$HELPER_SRC" "$SWARM_ROOT/usr/lib/swarm/swarm-key-sudo-auth"
install -d -m 0755 -o root -g root "$REG_DIR"
( umask 077
  cat > "$REG" <<EOF
# SWARM hardware sudo key registration (written $(date -u +%Y-%m-%dT%H:%M:%SZ)); never commit or share.
KEY_SERIAL=$KEY_SERIAL
PARTUUID=$P1_UUID
HWSERIAL=$HWSERIAL
SECRET_SHA256=$SECRET_SHA
EOF
)
chown root:root "$REG"; chmod 0600 "$REG"
PAM="$SWARM_ROOT/etc/pam.d/sudo"
if ! grep -qF 'swarm-key-sudo-auth' "$PAM"; then
    cp -a "$PAM" "$PAM.bak-$(date +%Y%m%d-%H%M%S)"
    # insert directly before the first "auth ... include system-auth" line
    awk -v line="$PAM_LINE" '!done && $1=="auth" && $2=="include" {print line; done=1} {print}' "$PAM" > "$PAM.new"
    grep -qF 'swarm-key-sudo-auth' "$PAM.new" || { rm -f "$PAM.new"; die "could not place the PAM line; $PAM unchanged"; }
    chmod --reference="$PAM" "$PAM.new"; mv "$PAM.new" "$PAM"
    say "added the key line to $PAM (backup kept)"
fi

say "DONE. Key serial $KEY_SERIAL, partuuid $P1_UUID, fs-uuid $FS_UUID. Secret was not printed."
say "Prove it on SWARM OS:  sudo -k; sudo true   (stick out: asks for the password; stick in: no prompt)"
say "Lose the stick?       sudo $0 --revoke"

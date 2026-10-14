#!/usr/bin/env bash
# provision_swarm_key.sh — make, list and revoke SWARM OS hardware sudo keys (USB sticks).
#
#   sudo provision_swarm_key.sh --list-sticks                 show attached USB disks you could turn into a key
#   sudo provision_swarm_key.sh --list                        show registered keys (no secrets)
#   sudo provision_swarm_key.sh --device <by-id path>         DRY RUN for a new key on that stick, changes nothing
#   sudo provision_swarm_key.sh --device <by-id path> --apply ERASES that stick and makes it a key
#   sudo provision_swarm_key.sh --revoke <KEY-SERIAL>         unregister ONE key (others keep working)
#   sudo provision_swarm_key.sh --revoke-all
#   sudo provision_swarm_key.sh --upgrade                     migrate older registrations + reinstall the helper (erases nothing)
#
# Any registered key lets 'sudo' skip the password on SWARM OS; the password always still works.
# Make a spare and keep it somewhere safe. If a key is lost: --revoke its serial.
#
# What --apply does to the chosen stick:
#   1. Refuses anything that is not a whole USB disk (by-id usb-*), is under 1 GB or over 256 GB, or has
#      any partition mounted outside /media or /run/media (so a system drive can never be picked).
#      You must type its USB serial to continue. EVERYTHING on it is lost.
#   2. Unmounts it, wipes old signatures, builds a fresh GPT with a random disk GUID:
#        p1  SWARM-KEY-SECRET  1 MiB raw, random PARTUUID  - the 256-bit secret
#        p2  SWARM-KEY         64 MiB ext4, random UUID    - label + KEY-SERIAL.txt (no secret)
#   3. Writes the secret, reads it back and checks it (cheap sticks can lose writes silently).
#   4. On SWARM's installed root (default /mnt/swarm/@): installs the helper, registers the key as
#      /etc/swarm_key/keys.d/<KEY-SERIAL>.conf (root:root 0600: SHA-256 of the secret + PARTUUID + the
#      stick's USB serial) and makes sure /etc/pam.d/sudo has ONE line (backup kept):
#        auth sufficient pam_exec.so quiet seteuid /usr/lib/swarm/swarm-key-sudo-auth
#      Only sudo is touched - not login, su, polkit or the lock screen.
#
# The secret is never printed or stored off the stick (the registry keeps only its hash). PARTUUID,
# UUID and key serial are NOT secrets and are copyable; a stick's own USB serial is burned in and cannot
# be changed. Only the secret is the credential.
set -euo pipefail
export PATH="/usr/sbin:/sbin:/usr/bin:/bin"

SWARM_ROOT="/mnt/swarm/@"
HERE="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
HELPER_SRC="$HERE/../40-iso-profile/swarm_os_iso_profile/airootfs/usr/lib/swarm/swarm-key-sudo-auth"
PAM_LINE="auth        sufficient    pam_exec.so quiet seteuid /usr/lib/swarm/swarm-key-sudo-auth"
MIN_BYTES=$((1 * 1000 * 1000 * 1000)); MAX_BYTES=$((256 * 1000 * 1000 * 1000))

MODE=dry; ACTION=make; DEVICE=""; REVOKE_ID=""
while [ $# -gt 0 ]; do
    case "$1" in
        --apply) MODE=apply ;;
        --device) DEVICE="${2:?by-id path}"; shift ;;
        --list) ACTION=list ;;
        --list-sticks) ACTION=sticks ;;
        --upgrade) ACTION=upgrade ;;
        --revoke) ACTION=revoke; REVOKE_ID="${2:?key serial}"; shift ;;
        --revoke-all) ACTION=revoke-all ;;
        --swarm-root) SWARM_ROOT="${2:?path}"; shift ;;
        -h|--help) sed -n "2,30p" "$0"; exit 0 ;;
        *) echo "unknown option: $1" >&2; exit 2 ;;
    esac
    shift
done

say() { printf '\033[1;36m[swarm-key]\033[0m %s\n' "$*"; }
die() { printf '\033[1;31m[swarm-key] %s\033[0m\n' "$*" >&2; exit 1; }

[ "$(id -u)" -eq 0 ] || die "run as root: sudo $0 ${*:-}"
KEYS_DIR="$SWARM_ROOT/etc/swarm_key/keys.d"
[ -d "$SWARM_ROOT/etc/pam.d" ] || die "SWARM root not found at $SWARM_ROOT (mount it, or pass --swarm-root)"

field() { sed -n "s/^$2=//p" "$1" | head -1; }

case "$ACTION" in
list)
    ls "$KEYS_DIR"/*.conf >/dev/null 2>&1 || { say "no keys registered"; exit 0; }
    for f in "$KEYS_DIR"/*.conf; do
        printf '  %-28s partuuid %s  usb-serial %s  %s\n' "$(field "$f" KEY_SERIAL)" "$(field "$f" PARTUUID)" \
            "$(field "$f" HWSERIAL)" "$(field "$f" CREATED)"
        if [ -e "/dev/disk/by-partuuid/$(field "$f" PARTUUID)" ]; then echo "      ^ plugged in now"; fi
    done
    exit 0 ;;
revoke)
    f="$KEYS_DIR/$REVOKE_ID.conf"
    [ -e "$f" ] || die "no such key: $REVOKE_ID (see --list)"
    shred -u "$f" 2>/dev/null || rm -f "$f"; say "revoked $REVOKE_ID; other keys are unaffected"; exit 0 ;;
revoke-all)
    n=0; for f in "$KEYS_DIR"/*.conf; do [ -e "$f" ] || continue; shred -u "$f" 2>/dev/null || rm -f "$f"; n=$((n+1)); done
    say "revoked $n key(s). sudo now needs the password."; exit 0 ;;
upgrade)
    # Move the first-generation registry into keys.d and install the current helper; erases nothing.
    install -D -m 0755 -o root -g root "$HELPER_SRC" "$SWARM_ROOT/usr/lib/swarm/swarm-key-sudo-auth"
    install -d -m 0755 -o root -g root "$SWARM_ROOT/etc/swarm_key" "$KEYS_DIR"
    LEGACY="$SWARM_ROOT/etc/swarm_os/sudo_key.conf"
    if [ -e "$LEGACY" ]; then
        lk="$(field "$LEGACY" KEY_SERIAL)"; [ -n "$lk" ] || die "legacy registry has no KEY_SERIAL; left as is"
        install -m 0600 -o root -g root "$LEGACY" "$KEYS_DIR/$lk.conf"
        shred -u "$LEGACY" 2>/dev/null || rm -f "$LEGACY"; say "migrated key $lk into $KEYS_DIR"
    else
        say "no first-generation registry to migrate"
    fi
    say "helper reinstalled. Keys: $(ls "$KEYS_DIR" 2>/dev/null | wc -l). Run with --list to see them."
    exit 0 ;;
sticks)
    say "USB disks (candidates). Use the by-id path with --device:"
    for l in /dev/disk/by-id/usb-*; do
        case "$l" in *-part[0-9]*) continue;; esac
        [ -e "$l" ] || continue
        d="$(readlink -f "$l")"; sz="$(lsblk -dbno SIZE "$d")"; note=""
        if [ "$sz" -lt "$MIN_BYTES" ] || [ "$sz" -gt "$MAX_BYTES" ]; then note="  (size not allowed for a key)"; fi
        printf '  %s\n      %s, %s GB%s\n' "$l" "$(lsblk -dno MODEL "$d" | sed 's/ *$//')" "$((sz/1000000000))" "$note"
    done
    exit 0 ;;
esac

# ── make a key: identify the stick; refuse anything that is not clearly a removable stick ─────
for tool in sfdisk wipefs mkfs.ext4 udevadm lsblk sha256sum dd base32; do
    command -v "$tool" >/dev/null || die "missing tool: $tool"
done
if [ -z "$DEVICE" ]; then
    "$0" --list-sticks; die "pick a stick: add  --device /dev/disk/by-id/usb-...  (a dry run unless you add --apply)"
fi
case "$DEVICE" in /dev/disk/by-id/usb-*) ;; *) die "--device must be a /dev/disk/by-id/usb-* path";; esac
case "$DEVICE" in *-part[0-9]*) die "give the whole stick, not a partition";; esac
[ -e "$DEVICE" ] || die "not attached: $DEVICE"
DEV="$(readlink -f "$DEVICE")"
[ -b "$DEV" ] || die "$DEV is not a block device"
[ "$(lsblk -dno TRAN "$DEV")" = usb ] || die "$DEV is not a USB device"
SIZE="$(lsblk -dbno SIZE "$DEV")"
if [ "$SIZE" -lt "$MIN_BYTES" ] || [ "$SIZE" -gt "$MAX_BYTES" ]; then
    die "$DEV is $((SIZE/1000000000)) GB; keys must be 1-256 GB sticks (refusing big external drives)"
fi
while read -r mp; do
    [ -z "$mp" ] && continue
    case "$mp" in /media/*|/run/media/*|/mnt/ventoy) ;; *) die "partition mounted at $mp — refusing; this does not look like a spare stick";; esac
done < <(lsblk -nro MOUNTPOINT "$DEV")
ROOTDEV="$(findmnt -no SOURCE / | sed 's/\[.*//')"
case "$ROOTDEV" in "$DEV"*) die "$DEV holds the running root";; esac
HWSERIAL="$(udevadm info --query=property --name="$DEV" | sed -n 's/^ID_SERIAL_SHORT=//p')"
CONFIRM="${HWSERIAL:-ERASE}"; REG_SERIAL="${HWSERIAL:-NONE}"
[ -n "$HWSERIAL" ] || say "note: this stick reports no USB serial; the secret is the only thing identifying it"

say "target: $DEV  ($((SIZE/1000000000)) GB, USB serial ${HWSERIAL:-none})"
lsblk -o NAME,SIZE,FSTYPE,LABEL,PARTLABEL,MOUNTPOINT "$DEV"
OLD_PARTUUIDS="$(lsblk -nro PARTUUID "$DEV" | tr 'A-Z' 'a-z' | grep . || true)"
if lsblk -nro PARTLABEL "$DEV" | grep -qx SWARM-KEY-SECRET; then
    say "this stick is ALREADY a SWARM key; it will be wiped and its old registration removed"
fi
rnd_uuid() { cat /proc/sys/kernel/random/uuid; }
KEY_SERIAL="SWK-$(head -c 20 /dev/urandom | base32 | tr -d '=' | cut -c1-20 | sed 's/.\{5\}/&-/g;s/-$//')"
P1_UUID="$(rnd_uuid)"; P2_UUID="$(rnd_uuid)"; DISK_GUID="$(rnd_uuid)"; FS_UUID="$(rnd_uuid)"
say "plan: p1 SWARM-KEY-SECRET partuuid=$P1_UUID | p2 SWARM-KEY fs-uuid=$FS_UUID | key serial $KEY_SERIAL"
say "plan: install helper, register key in $KEYS_DIR, ensure 1 PAM line in $SWARM_ROOT/etc/pam.d/sudo (backups kept)"
if [ "$MODE" = dry ]; then
    say "DRY RUN — nothing changed. Add --apply to erase the stick and write the key."; exit 0
fi

echo; echo "This ERASES ALL of $DEV. It cannot be undone."
read -r -p "Type '$CONFIRM' to continue: " typed
[ "$typed" = "$CONFIRM" ] || die "did not match; nothing changed"

# ── erase and partition ──────────────────────────────────────────────────────────────────────
systemctl stop mnt-ventoy.automount mnt-ventoy.mount 2>/dev/null || true
while read -r mp; do [ -n "$mp" ] && umount "$mp"; done < <(lsblk -nro MOUNTPOINT "$DEV" | sort -r)
for p in $(lsblk -nrpo NAME "$DEV" | tail -n +2); do wipefs -af "$p" >/dev/null; done
wipefs -af "$DEV" >/dev/null
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

# ── secret: write, read back (sector-aligned, bypassing the cache), verify ───────────────────
SECRET="$(head -c 32 /dev/urandom | od -An -tx1 | tr -d ' \n')"
[ "${#SECRET}" -eq 64 ] || die "secret generation failed"
printf 'SWK1:%s\n' "$SECRET" | dd of="$P1" bs=70 count=1 conv=fsync status=none
sync
READBACK="$(dd if="$P1" bs=512 count=1 iflag=direct status=none | head -c 70)"
[ "$READBACK" = "SWK1:$SECRET" ] || die "read-back mismatch — the stick is unreliable; do not use it"
SECRET_SHA="$(printf '%s' "$SECRET" | sha256sum | cut -d' ' -f1)"
unset READBACK SECRET

# ── identification partition (no secret on it) ───────────────────────────────────────────────
mkfs.ext4 -q -F -L SWARM-KEY -U "$FS_UUID" "$P2"
T="$(mktemp -d)"; mount "$P2" "$T"
cat > "$T/KEY-SERIAL.txt" <<EOF
SWARM OS hardware key
Key serial : $KEY_SERIAL
Partition  : SWARM-KEY-SECRET  PARTUUID $P1_UUID
Created    : $(date -u +%Y-%m-%dT%H:%M:%SZ)

Plugged into a SWARM OS machine, this stick lets 'sudo' skip the password.
Treat it like a house key. If it is lost: sudo provision_swarm_key.sh --revoke $KEY_SERIAL
(The secret is not on this partition.)
EOF
umount "$T"; rmdir "$T"

# ── wire SWARM: helper, registry, PAM line ───────────────────────────────────────────────────
install -D -m 0755 -o root -g root "$HELPER_SRC" "$SWARM_ROOT/usr/lib/swarm/swarm-key-sudo-auth"
install -d -m 0755 -o root -g root "$SWARM_ROOT/etc/swarm_key" "$KEYS_DIR"
# drop registrations of the partitions we just erased (re-keying a stick), and migrate the first-generation file
for f in "$KEYS_DIR"/*.conf; do
    [ -e "$f" ] || continue
    pu="$(field "$f" PARTUUID | tr 'A-Z' 'a-z')"
    if [ -n "$pu" ] && grep -qx "$pu" <<<"$OLD_PARTUUIDS"; then rm -f "$f"; fi
done
LEGACY="$SWARM_ROOT/etc/swarm_os/sudo_key.conf"
if [ -e "$LEGACY" ]; then
    lk="$(field "$LEGACY" KEY_SERIAL)"; lp="$(field "$LEGACY" PARTUUID | tr 'A-Z' 'a-z')"
    if [ -n "$lk" ] && ! grep -qx "$lp" <<<"$OLD_PARTUUIDS"; then
        install -m 0600 -o root -g root "$LEGACY" "$KEYS_DIR/$lk.conf"; say "migrated first key $lk into $KEYS_DIR"
    fi
    shred -u "$LEGACY" 2>/dev/null || rm -f "$LEGACY"
fi
REG="$KEYS_DIR/$KEY_SERIAL.conf"
( umask 077
  cat > "$REG" <<EOF
# SWARM hardware sudo key registration; never commit or share.
KEY_SERIAL=$KEY_SERIAL
PARTUUID=$P1_UUID
HWSERIAL=$REG_SERIAL
SECRET_SHA256=$SECRET_SHA
CREATED=$(date -u +%Y-%m-%dT%H:%M:%SZ)
EOF
)
chown root:root "$REG"; chmod 0600 "$REG"
PAM="$SWARM_ROOT/etc/pam.d/sudo"
if grep -qF 'swarm-key-sudo-auth' "$PAM"; then
    say "PAM line already present"
else
    cp -a "$PAM" "$PAM.bak-$(date +%Y%m%d-%H%M%S)"
    awk -v line="$PAM_LINE" '!done && $1=="auth" && $2=="include" {print line; done=1} {print}' "$PAM" > "$PAM.new"
    grep -qF 'swarm-key-sudo-auth' "$PAM.new" || { rm -f "$PAM.new"; die "could not place the PAM line; $PAM unchanged"; }
    chmod --reference="$PAM" "$PAM.new"; mv "$PAM.new" "$PAM"
    say "added the key line to $PAM (backup kept)"
fi

say "DONE. Key serial $KEY_SERIAL, partuuid $P1_UUID, fs-uuid $FS_UUID. Secret was not printed."
say "Prove it on SWARM OS:  sudo -k; sudo true   (stick out: asks for the password; stick in: no prompt)"
say "Keys now registered:  sudo $0 --list"

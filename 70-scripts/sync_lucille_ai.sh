#!/usr/bin/env bash
set -euo pipefail

# ─────────────────────────────────────────────────────────────────────────────
# sync_lucille_ai.sh — checksum-verified mirror to sdb8 and sda4
#
# TWO sync operations:
#
#  1. Lucille-AI full mirror:
#     /mnt/Lucy  →  {mount}/Lucille-AI/
#     Additive only (no --delete). --checksum for byte-exact verification.
#
#  2. DR. I30LTZ Recovery binary sync:
#     /mnt/Lucy/30-source/i30ltz-recovery(seperate-related-project)/target/release/i30ltz-recovery
#     →  {mount}/I30LTZ-Recovery/
#     Includes sha256 manifest. Runs on every OS that mounts sdb8 or sda4.
#
# Targets:
#   sdb8 (i30ltz-AI, ext4, /mnt/boltz) — shared across SWARM OS, Endeavor, CachyOS
#   sda4 (lucy-master, LUKS)           — master backup; only syncs if already unlocked
#
# /mnt/Lucy is MASTER. Nothing is ever deleted from it.
# ─────────────────────────────────────────────────────────────────────────────

SRC="/mnt/Lucy"
LUCILLE_FOLDER="Lucille-AI"
RECOVERY_FOLDER="I30LTZ-Recovery"
# Project dir carries a "(seperate-related-project)" suffix (renamed
# 2026-09-18) — this path went stale then and was found broken 2026-09-19
# via the build tracker showing all-dashes for this component; same bug
# existed here and in update_build_tracker.sh, fixed in the same pass.
RECOVERY_BIN="$SRC/30-source/i30ltz-recovery(seperate-related-project)/target/release/i30ltz-recovery"

LOG_DIR="$SRC/logs"
LOG_FILE="$LOG_DIR/sync_lucille_ai.log"
TRACKER="$SRC/I30LTZ_RECOVERY_BUILD_TRACKER.md"

SDB8_UUID="689e6547-b439-4e7f-93c9-a6dcfabed46b"
SDB8_MOUNT="/mnt/boltz"

SDA4_MAPPER="luks-a24202ce-4d76-4eb7-8923-8e8ddbacdaa7"
SDA4_MOUNT="/mnt/lucy-master-backup"

ok=0
fail=0

mkdir -p "$LOG_DIR"
log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"; }

# ── Lucille-AI full mirror (checksum-verified) ────────────────────────────
sync_lucille() {
    local mount="$1" label="$2"
    local dest="$mount/$LUCILLE_FOLDER"
    if ! mountpoint -q "$mount"; then
        log "SKIP Lucille-AI $label — not mounted"
        return
    fi
    mkdir -p "$dest"
    log "START Lucille-AI $label → $dest"
    if rsync -a --checksum --no-delete --human-readable --info=stats1 \
        "$SRC/" "$dest/" >> "$LOG_FILE" 2>&1; then
        log "OK    Lucille-AI $label (checksum-verified)"
        ((ok++)) || true
    else
        log "FAIL  Lucille-AI $label (exit $?)"
        ((fail++)) || true
    fi
}

# ── DR. I30LTZ Recovery binary + manifest ────────────────────────────────
sync_recovery() {
    local mount="$1" label="$2"
    local dest="$mount/$RECOVERY_FOLDER"
    if ! mountpoint -q "$mount"; then
        log "SKIP DR. I30LTZ Recovery $label — not mounted"
        return
    fi
    if [ ! -f "$RECOVERY_BIN" ]; then
        log "SKIP DR. I30LTZ Recovery $label — binary not built at $RECOVERY_BIN"
        log "     Run: cd \"$SRC/30-source/i30ltz-recovery(seperate-related-project)\" && cargo build --release"
        return
    fi
    mkdir -p "$dest"
    log "START DR. I30LTZ Recovery sync → $dest"

    # Sync binary with checksum verification
    if rsync -a --checksum "$RECOVERY_BIN" "$dest/i30ltz-recovery" >> "$LOG_FILE" 2>&1; then
        log "OK    DR. I30LTZ Recovery binary synced"
        ((ok++)) || true
    else
        log "FAIL  DR. I30LTZ Recovery binary sync (exit $?)"
        ((fail++)) || true
        return
    fi

    # Sha256 manifest for integrity verification
    local manifest="$dest/SYNC_MANIFEST.sha256"
    sha256sum "$dest/i30ltz-recovery" > "$manifest"
    # Also record source checksum for cross-reference
    sha256sum "$RECOVERY_BIN" >> "$manifest"
    log "OK    Checksum manifest written → $manifest"

    # Version stamp
    local stamp="$dest/BUILD_STAMP.txt"
    {
        echo "Synced:    $(date '+%Y-%m-%d %H:%M:%S')"
        echo "Source:    $RECOVERY_BIN"
        echo "Size:      $(stat -c %s "$RECOVERY_BIN") bytes"
        echo "SHA256:    $(sha256sum "$RECOVERY_BIN" | awk '{print $1}')"
        echo "Hostname:  $(hostname)"
        echo "OS:        $(uname -r)"
    } > "$stamp"
    log "OK    Build stamp written → $stamp"
}

# ── Update the project-root build tracker ────────────────────────────────
update_tracker() {
    if [ ! -f "$RECOVERY_BIN" ]; then
        return
    fi
    local sha256
    sha256=$(sha256sum "$RECOVERY_BIN" | awk '{print $1}')
    local size
    size=$(stat -c %s "$RECOVERY_BIN")
    local ts
    ts=$(date '+%Y-%m-%d %H:%M:%S')

    # Append a sync record to the tracker
    {
        echo ""
        echo "### Sync — $ts"
        echo "| Field | Value |"
        echo "|---|---|"
        echo "| Binary | \`$RECOVERY_BIN\` |"
        echo "| SHA256 | \`$sha256\` |"
        echo "| Size | ${size} bytes |"
        echo "| sdb8 (/mnt/boltz) | $(mountpoint -q "$SDB8_MOUNT" && echo "✓ synced" || echo "not mounted") |"
        echo "| sda4 (lucy-master) | $(mountpoint -q "$SDA4_MOUNT" && echo "✓ synced" || echo "not mounted / LUKS locked") |"
    } >> "$TRACKER"
    log "OK    Build tracker updated at $TRACKER"
}

# ─────────────────────────────────────────────────────────────────────────────

# ── sdb8 (i30ltz-AI, plain ext4) ─────────────────────────────────────────
mkdir -p "$SDB8_MOUNT"
if ! mountpoint -q "$SDB8_MOUNT"; then
    if blkid -U "$SDB8_UUID" &>/dev/null; then
        mount -U "$SDB8_UUID" "$SDB8_MOUNT" \
            && log "Mounted sdb8 (i30ltz-AI) at $SDB8_MOUNT" \
            || log "WARN: failed to mount sdb8"
    else
        log "SKIP sdb8 — drive not detected"
    fi
fi
sync_lucille "$SDB8_MOUNT" "sdb8 (i30ltz-AI)"
sync_recovery "$SDB8_MOUNT" "sdb8 (i30ltz-AI)"

# ── sda4 (lucy-master, LUKS — must be unlocked externally) ───────────────
mkdir -p "$SDA4_MOUNT"
if ! mountpoint -q "$SDA4_MOUNT"; then
    if [ -b "/dev/mapper/$SDA4_MAPPER" ]; then
        mount "/dev/mapper/$SDA4_MAPPER" "$SDA4_MOUNT" \
            && log "Mounted sda4 (lucy-master) at $SDA4_MOUNT" \
            || log "WARN: failed to mount sda4"
    else
        log "SKIP sda4 (lucy-master) — LUKS not unlocked"
        log "     Unlock: sudo cryptsetup open /dev/sda4 $SDA4_MAPPER"
    fi
fi
sync_lucille "$SDA4_MOUNT" "sda4 (lucy-master)"
sync_recovery "$SDA4_MOUNT" "sda4 (lucy-master)"

# ── Update build tracker ──────────────────────────────────────────────────
update_tracker

log "Sync complete — ok=$ok fail=$fail"
[ "$fail" -eq 0 ]

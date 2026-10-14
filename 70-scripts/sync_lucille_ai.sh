#!/usr/bin/env bash
set -euo pipefail

# ─────────────────────────────────────────────────────────────────────────────
# sync_lucille_ai.sh — checksum-verified mirror to sdb8 and sda4
#
# TWO sync operations:
#
#  1. Lucille-AI full mirror:
#     /mnt/Lucy  →  {mount}/Lucille-AI/
#     Additive only: rsync never deletes without --delete, and none is passed.
#     (There is no "--no-delete" option; rsync 3.5.0 rejects it with a usage
#     error, which made every run fail from 2026-09-22 until fixed 2026-10-14.)
#     Hourly runs compare size+mtime. Set SYNC_CHECKSUM=1 for a byte-exact
#     pass (reads ~14 GB on each side, so it is opt-in, not hourly).
#     Build output, .claude/ worktrees and other rebuildable data are skipped
#     (see MIRROR_EXCLUDES below); .git IS mirrored.
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

# Rebuildable or machine-local data that must not be mirrored (62 GB -> ~14 GB).
# Mirrors the build-output rules of 70-scripts/swarm_sync.exclude, but unlike
# that file this keeps .git, since this is a backup.
MIRROR_EXCLUDES=(
    --exclude=/.claude/ --exclude=/.sync-trash/ --exclude=/.swarm-sync/
    --exclude=/swarm_os_build_work/ --exclude=/install-env/ --exclude=/swarm_os_out/
    --exclude=/30-source/flutter-sdk/ --exclude=/30-source/LucilleAssistant/
    --exclude=/logs/ --exclude=lost+found/ --exclude='.Trash-*/'
    --exclude='**/target/' --exclude='**/node_modules/' --exclude='**/.dart_tool/'
    --exclude='**/.gradle/' --exclude='**/__pycache__/' --exclude='**/ephemeral/'
    --exclude=/30-source/frontend/build/ --exclude=/30-source/lucille-core/build/
    --exclude='/30-source/*/obj/' --exclude=/grub_themes/backups/
    --exclude='*.iso' --exclude='*.sfs' --exclude='*.qcow2' --exclude='*.img'
)
RSYNC_VERIFY=()
[ "${SYNC_CHECKSUM:-0}" = "1" ] && RSYNC_VERIFY=(--checksum)

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
    local rc=0
    rsync -a "${RSYNC_VERIFY[@]}" "${MIRROR_EXCLUDES[@]}" --human-readable --info=stats1 \
        "$SRC/" "$dest/" >> "$LOG_FILE" 2>&1 || rc=$?
    # 24 = a source file vanished mid-run (the live tree is being edited); not a failure.
    if [ "$rc" -eq 0 ] || [ "$rc" -eq 24 ]; then
        log "OK    Lucille-AI $label (${RSYNC_VERIFY[*]:-size+mtime} check, rsync exit $rc)"
        ((ok++)) || true
    else
        log "FAIL  Lucille-AI $label (rsync exit $rc)"
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
        log "     Unlock: sudo cryptsetup open /dev/disk/by-uuid/a24202ce-4d76-4eb7-8923-8e8ddbacdaa7 $SDA4_MAPPER"
    fi
fi
sync_lucille "$SDA4_MOUNT" "sda4 (lucy-master)"
sync_recovery "$SDA4_MOUNT" "sda4 (lucy-master)"

# ── Update build tracker ──────────────────────────────────────────────────
update_tracker

log "Sync complete — ok=$ok fail=$fail"
[ "$fail" -eq 0 ]

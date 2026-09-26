#!/usr/bin/env bash
# garden-content-updater.sh — offline-first strain-photo sync.
#
# Reads a configurable SOURCE directory (default:
# /mnt/lucy-master/garden-photos) and rsyncs new/updated images into
# /opt/swarm_os/garden/. Only .jpg/.jpeg/.png/.webp files are copied; anything
# else is ignored so an accidental note.txt or thumbs.db doesn't break the
# Flutter shell's per-strain lookup.
#
# Strictly local sources:
#   * A read-only mount of lucy-master (default).
#   * A separately-mounted LAN drive (SOURCE env override).
# Never fetches from the public internet.
#
# Bad states we handle:
#   * Source directory missing/unmounted: log and exit 0 (this is the normal
#     state on a fresh boot before the reference drive is plugged in).
#   * Rsync failure: log and exit non-zero so the timer notes the error.
#   * /opt/swarm_os/garden missing: create it (0755, owned by root).
#
# Run by swarm-garden-updater.timer every 6h once the destination is online.

set -uo pipefail

log() { printf '[garden-updater] %s\n' "$*" >&2; }

SOURCE="${GARDEN_PHOTOS_SOURCE:-/mnt/lucy-master/garden-photos}"
DEST="${GARDEN_PHOTOS_DEST:-/opt/swarm_os/garden}"

# Refuse to touch anything if the source or dest path looks unreasonable.
case "$SOURCE" in
    ""|"/"|"/*") log "invalid SOURCE=$SOURCE — refusing"; exit 2;;
esac
case "$DEST" in
    ""|"/"|"/*") log "invalid DEST=$DEST — refusing"; exit 2;;
esac

if [ ! -d "$SOURCE" ]; then
    log "source $SOURCE not present — skipping this run (reference mount likely offline)"
    exit 0
fi

mkdir -p "$DEST"

# --include only known image types, then --exclude '*' to drop everything else.
# --update: skip files that are newer at DEST than SOURCE (user may edit locally).
# --checksum: not enabled — mtime+size is enough and a lot cheaper.
if ! command -v rsync >/dev/null 2>&1; then
    log "rsync missing — falling back to cp for image files only"
    count=0
    while IFS= read -r -d '' f; do
        rel="${f#$SOURCE/}"
        target="$DEST/$rel"
        mkdir -p "$(dirname "$target")"
        if [ ! -e "$target" ] || [ "$f" -nt "$target" ]; then
            cp -f "$f" "$target"
            count=$((count + 1))
        fi
    done < <(find "$SOURCE" -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) -print0)
    log "cp fallback: $count file(s) synced"
    exit 0
fi

rsync -a --update \
    --include='*/' \
    --include='*.jpg' --include='*.JPG' \
    --include='*.jpeg' --include='*.JPEG' \
    --include='*.png' --include='*.PNG' \
    --include='*.webp' --include='*.WEBP' \
    --exclude='*' \
    "$SOURCE"/ "$DEST"/
rc=$?
if [ $rc -eq 0 ]; then
    log "sync ok: $SOURCE → $DEST"
else
    log "rsync failed with exit $rc"
fi
exit $rc

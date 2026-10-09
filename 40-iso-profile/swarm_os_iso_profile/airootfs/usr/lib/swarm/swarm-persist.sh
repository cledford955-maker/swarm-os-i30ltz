#!/usr/bin/env bash
# swarm-persist.sh — persistent storage for the SWARM OS live USB.
#
# Finds swarm-persist.img (an ext4 image) on the Ventoy data partition, loop-
# mounts it, then keeps session state on it:
#   /home/swarm            overlay  (upper on the stick; files you never touched
#                                    still track the ISO, so a new build's labwc/
#                                    shell config is not frozen out by old state)
#   everything in BIND_DIRS bind    (pure data: DBs, memory log, wifi, tailscale)
# Secrets are NOT persisted: swarm-secrets.service unseals them into tmpfs.
#
# Never fatal: with no stick/image the live session simply runs as before.
# Create the image on the host with 70-scripts/make_swarm_persistence.sh.
#   swarm-persist.sh start | stop
set -uo pipefail

LABEL=${SWARM_PERSIST_VENTOY_LABEL:-Ventoy}
IMG_NAME=${SWARM_PERSIST_IMG_NAME:-swarm-persist.img}
RUN=${SWARM_PERSIST_RUN:-/run/swarm-persist}
VENTOY=$RUN/ventoy
DATA=$RUN/data
MOUNTS=$RUN/mounts          # one mountpoint per line, unmounted in reverse
OVERLAY_HOME=/home/swarm
BIND_DIRS=(
  /etc/swarm_os                          # gaming.db, lucy/ state
  /mnt/brains                            # shared memory log (also a mountpoint for swarm-memory-tick)
  /var/log/swarm-ui                      # swarm-ui crash logs survive the reboot
  /var/lib/swarm
  /var/lib/tailscale
  /var/lib/bluetooth
  /var/lib/iwd
  /etc/NetworkManager/system-connections
)

log()  { echo "swarm-persist: $*"; }
skip() { log "$*; continuing without persistence"; exit 0; }

record() { echo "$1" >> "$MOUNTS"; }

bind_dir() {
  local d=$1 store=$DATA/bind$1
  mkdir -p "$d" "$store" || { log "cannot prepare $d"; return; }
  # First use: seed from whatever the ISO ships there, keeping owner and mode.
  if [ -z "$(ls -A "$store" 2>/dev/null)" ]; then
    chown --reference="$d" "$store"; chmod --reference="$d" "$store"
    [ -n "$(ls -A "$d" 2>/dev/null)" ] && cp -a "$d/." "$store/"
  fi
  mount --bind "$store" "$d" && record "$d" || log "bind of $d failed"
}

overlay_home() {
  local base=$DATA/overlay-home
  [ -d "$OVERLAY_HOME" ] || return
  mkdir -p "$base/upper" "$base/work" || return
  chown --reference="$OVERLAY_HOME" "$base/upper"; chmod --reference="$OVERLAY_HOME" "$base/upper"
  mount -t overlay overlay \
    -o "lowerdir=$OVERLAY_HOME,upperdir=$base/upper,workdir=$base/work" "$OVERLAY_HOME" \
    && record "$OVERLAY_HOME" || log "overlay of $OVERLAY_HOME failed"
}

start() {
  mkdir -p "$RUN"; : > "$MOUNTS"
  udevadm settle --timeout=10 >/dev/null 2>&1 || true
  local dev; dev=$(blkid -L "$LABEL" 2>/dev/null | head -n1)
  [ -n "$dev" ] || skip "no partition labelled '$LABEL'"

  mkdir -p "$VENTOY" "$DATA"
  mount "$dev" "$VENTOY" 2>/dev/null || skip "cannot mount $dev read-write"
  record "$VENTOY"   # first in the list = last to be unmounted
  local img=$VENTOY/$IMG_NAME
  [ -f "$img" ] || { umount "$VENTOY"; : > "$MOUNTS"; skip "no $IMG_NAME on $dev"; }
  [ "$(blkid -o value -s TYPE "$img" 2>/dev/null)" = ext4 ] || skip "$IMG_NAME is not an ext4 image"

  # A pulled stick or hard power-off leaves the journal dirty; -p only does safe repairs.
  e2fsck -p "$img" >/dev/null 2>&1; rc=$?
  [ "$rc" -lt 4 ] || skip "$IMG_NAME needs manual e2fsck (exit $rc)"

  mount -o loop,noatime "$img" "$DATA" || skip "cannot loop-mount $IMG_NAME"
  record "$DATA"

  overlay_home
  local d; for d in "${BIND_DIRS[@]}"; do bind_dir "$d"; done
  log "persistence active from $dev:$IMG_NAME"
}

stop() {
  [ -f "$MOUNTS" ] || exit 0
  sync
  local m; while read -r m; do
    [ -n "$m" ] && { umount "$m" 2>/dev/null || umount -l "$m"; }
  done < <(tac "$MOUNTS")
  : > "$MOUNTS"
  sync
}

case "${1:-}" in
  start) start ;;
  stop)  stop ;;
  *) echo "usage: $0 start|stop" >&2; exit 2 ;;
esac

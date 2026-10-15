#!/usr/bin/env bash
# Launch Lucille companion panel (Slint) on Debian or live system
set -euo pipefail

LOCATIONS=(
  "/mnt/Lucy/30-source/swarm-slint/target/release/swarm-slint"
  "/mnt/swarmbuild/30-source/swarm-slint/target/release/swarm-slint"
  "/opt/swarm_os/swarm-slint"
)

BIN=""
for loc in "${LOCATIONS[@]}"; do
  if [[ -x "$loc" ]]; then
    BIN="$loc"
    break
  fi
done

if [[ -z "$BIN" ]]; then
  echo "Error: swarm-slint binary not found in known locations." >&2
  exit 1
fi

cd "$(dirname "$BIN")"
exec "$BIN" "$@"

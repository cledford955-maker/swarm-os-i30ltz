#!/usr/bin/env bash
# Launch SWARM OS Flutter desktop shell on Debian or live system
set -euo pipefail

BUNDLE_DIRS=(
  "/mnt/Lucy/30-source/frontend/build/linux/x64/release/bundle"
  "/mnt/swarmbuild/30-source/frontend/build/linux/x64/release/bundle"
  "/opt/swarm_os/swarm_flutter"
)

APP_DIR=""
for dir in "${BUNDLE_DIRS[@]}"; do
  if [[ -x "$dir/swarm_flutter" ]]; then
    APP_DIR="$dir"
    break
  fi
done

if [[ -z "$APP_DIR" ]]; then
  echo "Error: swarm_flutter binary not found in known locations." >&2
  exit 1
fi

cd "$APP_DIR"
exec ./swarm_flutter "$@"

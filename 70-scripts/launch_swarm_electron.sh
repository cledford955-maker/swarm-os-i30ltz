#!/usr/bin/env bash
# Launch SWARM OS Desktop in an Electron window on Debian
set -euo pipefail

ELECTRON_DIR="/mnt/Lucy/30-source/swarm-electron"
cd "$ELECTRON_DIR"
ELECTRON_VERSION="$(node -p "require('./package.json').devDependencies.electron" 2>/dev/null || true)"

# Debian-only test harness. Use the project-pinned Electron version; never bundles into SWARM OS.
[[ -n "$ELECTRON_VERSION" ]] || { echo "Error: Electron version is missing from $ELECTRON_DIR/package.json" >&2; exit 1; }
if [ -x "$ELECTRON_DIR/node_modules/.bin/electron" ]; then
  INSTALLED_VERSION=$("$ELECTRON_DIR/node_modules/.bin/electron" --version 2>/dev/null | sed 's/^v//')
  [[ "$INSTALLED_VERSION" == "$ELECTRON_VERSION" ]] || { echo "Install pinned Electron $ELECTRON_VERSION: cd $ELECTRON_DIR && npm install" >&2; exit 1; }
  exec "$ELECTRON_DIR/node_modules/.bin/electron" . "$@"
elif command -v npx >/dev/null 2>&1; then
  exec npx --yes "electron@$ELECTRON_VERSION" . "$@"
elif command -v electron >/dev/null 2>&1; then
  INSTALLED_VERSION=$(electron --version 2>/dev/null | sed 's/^v//')
  [[ "$INSTALLED_VERSION" == "$ELECTRON_VERSION" ]] || { echo "System Electron is $INSTALLED_VERSION; expected $ELECTRON_VERSION. Install the pinned package with npm." >&2; exit 1; }
  exec electron . "$@"
elif command -v google-chrome >/dev/null 2>&1; then
  echo "Electron not installed, opening in standalone Chrome App window..."
  exec google-chrome --app="http://127.0.0.1:8403" "$@"
else
  echo "Error: Neither electron nor chrome found. Run: cd $ELECTRON_DIR && npm install" >&2
  exit 1
fi

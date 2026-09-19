#!/usr/bin/env bash
set -euo pipefail
for editor in code-insiders code; do
 if command -v "$editor" >/dev/null; then
  exec "$editor" --new-window /mnt/Lucy/SWARM_OS.code-workspace
 fi
done
echo 'VS Code is not installed.' >&2
exit 1

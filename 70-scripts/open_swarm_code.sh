#!/usr/bin/env bash
set -euo pipefail

project_roots=(
 /mnt/Lucy
 /mnt/recoverybuild
 /mnt/lucilleassistant
 /mnt/boltzbuild/src/I30LTZ-Recovery-companion
)
missing=()
for root in "${project_roots[@]}"; do
 if [[ ! -d "$root" ]] || [[ -z "$(find "$root" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null)" ]]; then
  missing+=("$root")
 fi
done
if ((${#missing[@]})); then
 printf 'SWARM Code cannot open the full four-project workspace; these roots are unavailable or empty:\n' >&2
 printf '  %s\n' "${missing[@]}" >&2
 printf 'Connect/mount the project drives, then try again.\n' >&2
 exit 1
fi

for editor in code-insiders code; do
 if command -v "$editor" >/dev/null; then
  exec "$editor" --new-window /mnt/Lucy/SWARM_OS.code-workspace
 fi
done
echo 'VS Code is not installed.' >&2
exit 1

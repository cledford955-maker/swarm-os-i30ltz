#!/usr/bin/env bash
# Compatibility entry: the current VM launcher selects its ISO from Ventoy.
set -euo pipefail
if [[ $# == 1 && $1 != --* ]]; then
 exec /mnt/Lucy/70-scripts/launch_swarm_vm.sh --iso "$1"
fi
exec /mnt/Lucy/70-scripts/launch_swarm_vm.sh "$@"

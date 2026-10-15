#!/usr/bin/env bash
set -euo pipefail
MANAGER=/mnt/Lucy/70-scripts/swarm_iso_manager.py
python3 "$MANAGER" list
printf '\n1) Prune to the one current project ISO\n2) Open project ISO folder\nEnter) Close\n'
read -rp 'Choose: ' choice
case "$choice" in
 1) python3 "$MANAGER" prune ;;
 2) xdg-open /mnt/Lucy/10-releases ;;
esac

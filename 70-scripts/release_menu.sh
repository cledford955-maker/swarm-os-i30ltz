#!/usr/bin/env bash
set -euo pipefail
MANAGER=/mnt/Lucy/70-scripts/manage_swarm_releases.sh
"$MANAGER" list
printf '\n1) Mark a build stable (keep until unmarked)\n2) Unmark stable\n3) Prune to newest 10 rolling builds + stable\n4) Open ISO folder\nEnter) Close\n'
read -rp 'Choose: ' choice
case "$choice" in
 1|2)
  read -rp 'ISO filename (from list above): ' iso
  if [[ $choice == 1 ]]; then
   read -rp 'Stable note: ' note
   "$MANAGER" stable "$iso" --note "$note"
  else
   "$MANAGER" unmark-stable "$iso"
  fi ;;
 3) "$MANAGER" prune ;;
 4) xdg-open /mnt/ventoy/ISO/SWARM_OS ;;
esac

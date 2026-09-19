#!/usr/bin/env bash
set -euo pipefail
MANAGER=/mnt/Lucy/70-scripts/swarm_iso_manager.py
case ${1:-list} in
 list|latest|check) exec python "$MANAGER" "${@:-list}" ;;
 *) exec sudo python "$MANAGER" "$@" ;;
esac

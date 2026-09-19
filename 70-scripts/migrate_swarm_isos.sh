#!/usr/bin/env bash
set -euo pipefail
exec sudo python /mnt/Lucy/70-scripts/swarm_iso_manager.py migrate "$@"

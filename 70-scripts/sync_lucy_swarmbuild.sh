#!/usr/bin/env bash
# Sync the project between /mnt/Lucy (source of truth) and /mnt/swarmbuild (build tree).
#   sync_lucy_swarmbuild.sh to-build   Lucy -> swarmbuild  (before building)
#   sync_lucy_swarmbuild.sh to-lucy    swarmbuild -> Lucy  (after building: VERSION, source edits)
# Never deletes. The build work dir stays on swarmbuild only. Add -n for a dry run.
set -euo pipefail
dir=${1:?usage: $0 to-build|to-lucy [-n]}; shift || true
for m in /mnt/Lucy /mnt/swarmbuild; do mountpoint -q "$m" || { echo "$m not mounted: run 70-scripts/check_mounts.sh" >&2; exit 1; }; done
# 30-source/LucilleAssistant moved to its own build partition (/mnt/lucillebuild) on 2026-10-09; never sync it
# back in either direction (to-lucy would otherwise resurrect it from swarmbuild's frozen copy).
EXCL=(--exclude=/swarm_os_build_work/ --exclude=.swarm-build.lock --exclude=/30-source/LucilleAssistant/)
case $dir in
  to-build) src=/mnt/Lucy/;       dst=/mnt/swarmbuild/ ;;
  # --update: Lucy is the source of truth, so only take files the build tree has
  # newer. Without it every file differing in size/mtime (CLAUDE.md, the
  # tracker, .git/) is overwritten with the build tree's older seed copy.
  to-lucy)  src=/mnt/swarmbuild/; dst=/mnt/Lucy/; EXCL+=(--update --exclude=/.git/) ;;
  *) echo "unknown direction $dir" >&2; exit 1 ;;
esac
rsync -aHAX --info=stats1 "${EXCL[@]}" "$@" "$src" "$dst"

#!/usr/bin/env bash
# Sync the project between /mnt/Lucy (source of truth) and /mnt/swarmbuild (build tree).
#
#   sync_lucy_swarmbuild.sh both            show what a TWO-WAY sync would do (changes nothing)
#   sync_lucy_swarmbuild.sh both --apply    do it. USE THIS ONE.
#
#     A file on only one side is NEW (it is copied over) or DELETED on the other side (it is deleted here too, to
#     <root>/.sync-trash/<run>/), and the tool knows which because it remembers both sides after every run.
#     Edited-on-both-sides: the newer file wins and the other copy goes to the trash. An edit beats a deletion.
#     What is never synced (.git, build output, the installer chroot, ...) is listed in 70-scripts/swarm_sync.exclude.
#     Engine and rules: 70-scripts/swarm_twoway_sync.py (tests: 70-scripts/tests/test_twoway_sync.py).
#     More options (--list N, --rebaseline, --allow-mass-delete, ...): `swarm_twoway_sync.py --help`.
#
#   sync_lucy_swarmbuild.sh to-build   Lucy -> swarmbuild  } older ONE-WAY modes. They never delete and cannot tell
#   sync_lucy_swarmbuild.sh to-lucy    swarmbuild -> Lucy  } "created" from "deleted", and they know nothing about the
#                                                          } exclude list. Kept so existing instructions keep working.
set -euo pipefail
dir=${1:?usage: $0 both [--apply] | to-build|to-lucy [-n]}; shift || true
for m in /mnt/Lucy /mnt/swarmbuild; do mountpoint -q "$m" || { echo "$m not mounted: run 70-scripts/check_mounts.sh" >&2; exit 1; }; done

if [[ $dir == both ]]; then
  engine="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/swarm_twoway_sync.py"
  rc=0; python3 "$engine" "$@" || rc=$?
  # The build stamps the commit it was built from using swarmbuild's own .git, so keep that a (non-deleting) mirror of
  # Lucy's, exactly as `to-build` always did. The two-way engine never touches .git. Only after a real, successful run.
  if [[ " $* " == *" --apply "* && ( $rc -eq 0 || $rc -eq 2 ) ]]; then
    rsync -aHAX /mnt/Lucy/.git/ /mnt/swarmbuild/.git/ || echo "warning: .git mirror to swarmbuild failed (the commit stamp may be stale)" >&2
  fi
  exit $rc
fi

echo "note: '$dir' is the older one-way mode. 'both' tells created from deleted; see the header of this script." >&2
# 30-source/LucilleAssistant moved to its own build partition (/mnt/lucillebuild) on 2026-10-09; never sync it
# back in either direction (to-lucy would otherwise resurrect it from swarmbuild's frozen copy).
EXCL=(--exclude=/swarm_os_build_work/ --exclude=.swarm-build.lock --exclude=/30-source/LucilleAssistant/ --exclude=/.sync-trash/ --exclude=/.swarm-sync/)
case $dir in
  to-build) src=/mnt/Lucy/;       dst=/mnt/swarmbuild/ ;;
  # --update: Lucy is the source of truth, so only take files the build tree has
  # newer. Without it every file differing in size/mtime (CLAUDE.md, the
  # tracker, .git/) is overwritten with the build tree's older seed copy.
  to-lucy)  src=/mnt/swarmbuild/; dst=/mnt/Lucy/; EXCL+=(--update --exclude=/.git/) ;;
  *) echo "unknown direction $dir" >&2; exit 1 ;;
esac
rsync -aHAX --info=stats1 "${EXCL[@]}" "$@" "$src" "$dst"

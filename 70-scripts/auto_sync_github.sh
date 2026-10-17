#!/bin/bash
# Hourly local checkpoint of /mnt/Lucy (swarm-lucy-sync.timer): commits everything locally, no-ops
# when there's nothing to commit. Since 2026-10-17 it does NOT push (see the end of this file):
# /mnt/Lucy holds personal files and the GitHub repos are public.
# The lucille-companion/ -> i30ltz-lucille-assistant leg was retired 2026-10-16 (user):
# Lucille Assistant lives on partition C now and lucille-companion/ is a frozen copy.
set -euo pipefail

REPO_DIR="${SWARM_SYNC_REPO_DIR:-/mnt/Lucy}"
cd "$REPO_DIR"
exec 9>"$(git rev-parse --git-path swarm-auto-sync.lock)"
flock -n 9 || { echo 'Another GitHub sync is already running.'; exit 0; }
status=0

# Never checkpoint an unfinished merge/rebase or somebody else's staged commit.
if [ "$(git branch --show-current)" != main ]; then
  echo 'SYNC PAUSED: local checkout is not main.' >&2
  exit 1
fi
for operation in MERGE_HEAD CHERRY_PICK_HEAD REVERT_HEAD rebase-merge rebase-apply index.lock; do
  if [ -e "$(git rev-parse --git-path "$operation")" ]; then
    echo 'SYNC PAUSED: a Git operation is in progress.' >&2
    exit 1
  fi
done

# Shared memory (2026-09-16): mirror /mnt/brains/swarm-memory into the repo so
# it is versioned and pushed with everything else. Skipped quietly when the
# brains partition isn't mounted — the last mirrored copy stays in git.
MEMORY_MIRROR="$REPO_DIR/60-boltz-brain/swarm-memory"
mirror_memory() {
if mountpoint -q /mnt/brains && [ -d /mnt/brains/swarm-memory ]; then
  if command -v swarm-memory >/dev/null 2>&1; then
    swarm-memory mirror "$MEMORY_MIRROR" >/dev/null || return 1
  else
    mkdir -p "$MEMORY_MIRROR/docs" || return 1
    rsync -a --delete /mnt/brains/swarm-memory/log/ "$MEMORY_MIRROR/log/" || return 1
    for f in PROJECT_MEMORY.md peers.json README.md; do
      if [ -f "/mnt/brains/swarm-memory/$f" ]; then
        cp -f "/mnt/brains/swarm-memory/$f" "$MEMORY_MIRROR/$f" || return 1
      fi
    done
    for f in Lucy_Core_Prompt.md Dr_Boltz_Core_Prompt.md llcy_memory.md lucille_personas_memory.json memory.json users.json; do
      if [ -f "/mnt/brains/$f" ]; then
        cp -f "/mnt/brains/$f" "$MEMORY_MIRROR/docs/$f" || return 1
      fi
    done
  fi
fi
return 0
}
if ! mirror_memory; then
  echo 'ERROR: Shared-memory mirror failed; continuing repository sync.' >&2
  status=1
fi

MAX_MB=90
if [ -n "$(git status --porcelain)" ]; then
  git add -A
  big=""
  while IFS= read -r -d '' f; do
    if [ -f "$f" ]; then
      sz=$(stat -c%s "$f" 2>/dev/null || echo 0)
      if [ "$sz" -gt $((MAX_MB * 1024 * 1024)) ]; then
        big="$big $f ($((sz / 1024 / 1024))MB)"
      fi
    fi
  done < <(git diff --cached --name-only -z)
  if [ -n "$big" ]; then
    git reset -q; echo "ERROR: files over ${MAX_MB}MB, not committing:$big" >&2; status=1
  else
    if git commit -m "auto-sync: $(date -Iseconds)" --quiet; then
      echo 'Saved local changes.'
    else
      echo 'ERROR: Could not save local changes; syncing the last committed versions.' >&2
      status=1
    fi
  fi
fi
# Each destination has a verified last-common snapshot. The helper merges
# changes from both sides before exporting a commit with destination-only history.
# Conflicts stop that project, without overwriting the remote or touching its peers.
sync_subtree() {
  if ! python3 "$(dirname "${BASH_SOURCE[0]}")/sync_project_repo.py" "$1" "$2"; then
    status=1
  fi
}
# Retired 2026-10-16 (user): Lucille Assistant moved to partition C (/mnt/lucillebuild) and
# lucille-companion/ has been frozen since 2026-10-10, so this leg had nothing left to send; it
# failed every hour because origin was mis-pointed at that repo on 10-12 and overwrote its main.
# sync_subtree "lucille-companion" i30ltz-lucille-assistant
# Recovery OS projects moved to /mnt/recoverybuild (own git repos, 2026-10-06); not synced here.
# /mnt/Lucy is local-only (user, 2026-10-17): it holds personal files, so it is never pushed. The
# SWARM GitHub repo (A-SWARM-OS-Trifecta) is published from the build partition /mnt/swarmbuild.
# Commits above stay local as a safety net. SWARM_SYNC_PUSH=1 re-enables the push, deliberately.
if [ "${SWARM_SYNC_PUSH:-0}" = 1 ]; then
  if git push origin main; then
    echo 'SYNC OK: pushed'
  else
    echo 'SYNC FAILED: push' >&2
    status=1
  fi
else
  echo 'LOCAL ONLY: /mnt/Lucy committed locally, not pushed (by design)'
fi

exit "$status"

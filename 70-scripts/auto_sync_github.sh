#!/bin/bash
# Auto-sync /mnt/Lucy to its private GitHub remotes so claude.ai/code on other
# devices sees recent work. Runs on a timer (swarm-lucy-sync.timer), no-ops
# when there's nothing to commit.
#   origin                  -> cledford955-maker/swarm-os-i30ltz (whole project)
#   i30ltz-lucille-assistant -> cledford955-maker/i30ltz-lucille-assistant (lucille-companion/ subtree)
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
if ! git diff --cached --quiet; then
  echo 'SYNC PAUSED: existing staged changes require their owner to commit.' >&2
  exit 1
fi

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

if [ -n "$(git status --porcelain)" ]; then
  if git add -A && git commit -m "auto-sync: $(date -Iseconds)" --quiet; then
    echo 'Saved local changes.'
  else
    echo 'ERROR: Could not save local changes; syncing the last committed versions.' >&2
    status=1
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
sync_subtree "lucille-companion" i30ltz-lucille-assistant
# Recovery OS projects moved to /mnt/recoverybuild (own git repos, 2026-10-06); not synced here.
# Always retry origin: an earlier failed push can leave a clean but unpushed tree.
if git push origin main; then
  echo 'SYNC OK: swarm-os-i30ltz'
else
  echo 'SYNC FAILED: swarm-os-i30ltz' >&2
  status=1
fi

exit "$status"

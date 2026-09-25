#!/bin/bash
# Auto-sync /mnt/Lucy to its private GitHub remotes so claude.ai/code on other
# devices sees recent work. Runs on a timer (swarm-lucy-sync.timer), no-ops
# when there's nothing to commit.
#   origin                  -> cledford955-maker/swarm-os-i30ltz (whole project)
#   i30ltz-recovery         -> cledford955-maker/i30ltz-recovery (30-source/i30ltz-recovery(seperate-related-project)/ subtree)
#   i30ltz-swarm-companion  -> cledford955-maker/i30ltz-swarm-companion (30-source/android_companion/swarm_os-companion/ subtree)
#   i30ltz-lucille-assistant -> cledford955-maker/i30ltz-lucille-assistant (lucille-companion/ subtree)
set -euo pipefail

REPO_DIR="${SWARM_SYNC_REPO_DIR:-/mnt/Lucy}"
cd "$REPO_DIR"
exec 9>"$(git rev-parse --git-path swarm-auto-sync.lock)"
flock -n 9 || { echo 'Another GitHub sync is already running.'; exit 0; }
status=0

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
# Always retry origin: an earlier failed push can leave a clean but unpushed tree.
if git push origin main; then
  echo 'SYNC OK: swarm-os-i30ltz'
else
  echo 'SYNC FAILED: swarm-os-i30ltz' >&2
  status=1
fi

# App repos get a SNAPSHOT of their folder, not `git subtree push`.
#
# Found 2026-09-25: after 30-source/android_companion/swarm_os-companion was
# archived (06:49) and restored (09:51), `git subtree split` matched 0 commits
# and returned a commit whose tree was the companion but whose history was the
# ENTIRE SWARM OS repo. GitHub rejected it only as non-fast-forward — a force
# push would have uploaded all of swarm-os-i30ltz into the companion repo.
#
# Snapshot sync: fetch the remote's main; if its tree already equals the
# folder's tree, do nothing; otherwise create ONE commit whose tree is exactly
# HEAD:<prefix> and whose only parent is the remote tip, and push it
# fast-forward. The pushed history is the remote's own history plus that
# commit — no main-repo commits or objects outside the folder can leak, and a
# moved/renamed/re-added folder can never break it. Never force-pushes.
#
# --prefix must exactly match the CURRENT tracked directory path; a missing
# folder fails loudly instead of pushing an empty tree.
sync_subtree() {
  local prefix=$1 remote=$2 tree remote_tip commit
  if ! tree=$(git rev-parse --verify --quiet "HEAD:$prefix^{tree}"); then
    echo "SYNC FAILED: $remote (folder '$prefix' is not in HEAD)" >&2
    status=1; return
  fi
  if ! git fetch --quiet "$remote" main; then
    echo "SYNC FAILED: $remote (fetch)" >&2
    status=1; return
  fi
  remote_tip=$(git rev-parse FETCH_HEAD)
  if [ "$(git rev-parse "$remote_tip^{tree}")" = "$tree" ]; then
    echo "SYNC OK: $remote (up to date)"
    return
  fi
  commit=$(git commit-tree "$tree" -p "$remote_tip" -m "auto-sync: $(date -Iseconds)")
  if git push --quiet "$remote" "$commit:refs/heads/main"; then
    echo "SYNC OK: $remote"
  else
    echo "SYNC FAILED: $remote" >&2
    status=1
  fi
}
sync_subtree "30-source/i30ltz-recovery(seperate-related-project)" i30ltz-recovery
sync_subtree "30-source/android_companion/swarm_os-companion" i30ltz-swarm-companion
sync_subtree "lucille-companion" i30ltz-lucille-assistant
exit "$status"

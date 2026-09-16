#!/bin/bash
# Auto-sync /mnt/Lucy to its private GitHub remotes so claude.ai/code on other
# devices sees recent work. Runs on a timer (swarm-lucy-sync.timer), no-ops
# when there's nothing to commit.
#   origin                  -> cledford955-maker/swarm-os-i30ltz (whole project)
#   i30ltz-recovery         -> cledford955-maker/i30ltz-recovery (30-source/i30ltz-recovery/ subtree)
#   i30ltz-swarm-companion  -> cledford955-maker/i30ltz-swarm-companion (30-source/android_companion/swarm_os-companion/ subtree)
set -euo pipefail

REPO_DIR="/mnt/Lucy"
cd "$REPO_DIR"

# Shared memory (2026-09-16): mirror /mnt/brains/swarm-memory into the repo so
# it is versioned and pushed with everything else. Skipped quietly when the
# brains partition isn't mounted — the last mirrored copy stays in git.
MEMORY_MIRROR="$REPO_DIR/60-boltz-brain/swarm-memory"
if mountpoint -q /mnt/brains && [ -d /mnt/brains/swarm-memory ]; then
  if command -v swarm-memory >/dev/null 2>&1; then
    swarm-memory mirror "$MEMORY_MIRROR" >/dev/null
  else
    mkdir -p "$MEMORY_MIRROR/docs"
    rsync -a --delete /mnt/brains/swarm-memory/log/ "$MEMORY_MIRROR/log/"
    for f in PROJECT_MEMORY.md peers.json README.md; do
      [ -f "/mnt/brains/swarm-memory/$f" ] && cp -f "/mnt/brains/swarm-memory/$f" "$MEMORY_MIRROR/$f"
    done
    for f in Lucy_Core_Prompt.md Dr_Boltz_Core_Prompt.md llcy_memory.md lucille_personas_memory.json memory.json users.json; do
      [ -f "/mnt/brains/$f" ] && cp -f "/mnt/brains/$f" "$MEMORY_MIRROR/docs/$f"
    done
  fi
fi

if [ -n "$(git status --porcelain)" ]; then
  git add -A
  git commit -m "auto-sync: $(date -Iseconds)" --quiet
  git push origin main
fi

# Subtree push is idempotent — a no-op push (nothing new under the prefix
# since the last split) still exits 0, so this runs every tick unconditionally.
git subtree --quiet push --prefix=30-source/i30ltz-recovery i30ltz-recovery main
git subtree --quiet push --prefix=30-source/android_companion/swarm_os-companion i30ltz-swarm-companion main

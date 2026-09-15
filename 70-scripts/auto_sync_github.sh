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

if [ -n "$(git status --porcelain)" ]; then
  git add -A
  git commit -m "auto-sync: $(date -Iseconds)" --quiet
  git push origin main
fi

# Subtree push is idempotent — a no-op push (nothing new under the prefix
# since the last split) still exits 0, so this runs every tick unconditionally.
git subtree --quiet push --prefix=30-source/i30ltz-recovery i30ltz-recovery main
git subtree --quiet push --prefix=30-source/android_companion/swarm_os-companion i30ltz-swarm-companion main

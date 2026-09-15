#!/bin/bash
# Auto-sync /mnt/Lucy to the private GitHub remote (cledford955-maker/swarm-os)
# so claude.ai/code on other devices sees recent work. Runs on a timer
# (swarm-lucy-sync.timer), no-ops when there's nothing to commit.
set -euo pipefail

REPO_DIR="/mnt/Lucy"
cd "$REPO_DIR"

if [ -n "$(git status --porcelain)" ]; then
  git add -A
  git commit -m "auto-sync: $(date -Iseconds)" --quiet
  git push origin main
fi

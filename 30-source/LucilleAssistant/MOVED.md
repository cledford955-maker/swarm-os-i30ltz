# Lucille Assistant has moved — this copy is DEPRECATED

As of 2026-10-09 (user decision) Lucille Assistant — the Go service on :8403 and the Android app(s) — is built
from its own partition: **`/mnt/lucillebuild`** (`C. Lucille build`, `UUID=93037d5a-5b82-484c-ac20-28211c09e1c0`).

- Source: `/mnt/lucillebuild/src/LucilleAssistant/` (local git repo; history before the move is in this repo, last at `ea73088`)
- Build: `/mnt/lucillebuild/scripts/build.sh` — everything it needs (Go, JDK 21, Gradle, Android SDK, caches) is on that partition
- Finished, stand-alone output: `/mnt/lucillebuild/dist/`
- Policy: `/mnt/Lucy/CLAUDE.md` → "App build partitions"

**Do not edit this copy.** It is a verified-identical leftover (only the move edits differ: standalone env lookup,
loopback-only default listen, packaging/) and is waiting for the user's OK to be deleted.
`70-scripts/sync_lucy_swarmbuild.sh` excludes this path, so the frozen copy on `/mnt/swarmbuild/30-source/LucilleAssistant`
(which the currently running user service still executes until it is cut over with
`/mnt/lucillebuild/scripts/cutover_live_service.sh`) is not synced back here.

The `.claude/worktrees/*` directory is three old Claude Code git worktrees of this repo, unrelated to the app.

# Lucille Assistant and Recovery OS sync

The existing user timer `swarm-lucy-sync.timer` runs every ten minutes while this
computer is running and `/mnt/Lucy` is available. No AI subscription is used.

- `lucille-companion` ↔ `cledford955-maker/i30ltz-lucille-assistant` main
- `30-source/i30ltz-recovery(seperate-related-project)` ↔ `cledford955-maker/i30ltz-recovery` main

The wrapper also preserves its existing SWARM main and companion destinations.
A failed destination does not skip the remaining projects. SWARM main currently
has separate divergent remote commits; a rejection there does not mean either
of these two project syncs failed. Check the per-project `SYNC OK` log entries.

## How the local sync works

The wrapper checkpoints local work using existing ignore rules. A staged commit,
merge/rebase, or non-main checkout pauses the run. `sync_project_repo.py` fetches
all project branches and reconciles main against the last common snapshot stored
in `refs/swarm-sync/<remote>/base`. On first setup, that baseline is accepted only
when local and remote trees match exactly. Missing baselines with differing trees
require manual reconciliation; never guess which tree should win.

Independent edits merge. Conflicting edits fail before touching either side.
Remote imports use an index-checked Git patch, so concurrent/ignored files cannot
silently be overwritten. The exported commit has only the destination repo's
history as its parent, preventing monorepo history from leaking into a project.
Pushes never force. If a push fails, the common snapshot is not advanced and a
later run retries. Task branches remain under `refs/remotes/<remote>/claude/*`;
unfinished tasks are not automatically merged into main.

## Claude mobile/cloud checkpoints

Both project repos include `.claude/settings.json`, `.claude/cloud_checkpoint.py`,
and `CLAUDE.md`. In a single-repository Claude cloud session, command hooks save
eligible work after Write/Edit/MultiEdit/Bash, at startup/resume, before compaction,
when Claude stops, and on StopFailure (including API rate-limit errors). The helper only runs when `CLAUDE_CODE_REMOTE=true` and the
checkout is the standalone project on a `claude/*` branch. It does not call an AI
model, change main, or merge work. Common credential filenames, generated outputs,
and common embedded key formats are excluded or rejected. Staged work is left
for its owner to commit. These checks are not a comprehensive secret scanner.

A GitHub push needs the cloud session's existing repository access. Failed pushes
emit a warning and retry at the next hook. `.git/cloud-checkpoint-status.json`
records the last successful push; compare its commit with HEAD because later
failures can make it stale. No stored credentials are added by this setup.

New sessions from updated main can load these hooks. Existing sessions must first
receive the files and load the settings; this cannot recover edits in an
inaccessible, quota-blocked session. Suspended/expired environments cannot run
hooks, and abrupt shutdown can interrupt the last save. Multi-repository cloud
sessions do not load repo hooks: use one session per repository. Merge a finished
cloud task's PR into main to have it imported into the corresponding local folder.

## Verification and status

- Tests: `python3 -m unittest discover -s 70-scripts/tests -p test_github_autosync.py -v`
- Timer: `systemctl --user status swarm-lucy-sync.timer`
- Last run: `journalctl --user -u swarm-lucy-sync.service -n 40 --no-pager`
- Immediate retry: `systemctl --user start swarm-lucy-sync.service`

The tests use disposable local bare repos and cover imports, exports, two-sided
merges, conflict preservation, missing baselines, dirty work, push retry, history
isolation, cloud branch checkpoints, credential exclusions and staged-work guards.
Actual Claude mobile hook execution still requires a cloud session to verify.

Claude hook references: https://code.claude.com/docs/en/hooks#stopfailure and
https://code.claude.com/docs/en/cloud-environments#setup-scripts-vs-sessionstart-hooks

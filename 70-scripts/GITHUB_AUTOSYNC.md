# Project repositories and automatic sync

**2026-10-16:** both repositories below are **public**, not private, and now live in the
`SWARM-OS-SUITE` org (the old `cledford955-maker/...` URLs redirect). Everything the timer
commits is published.

| Project | GitHub repository | Source on LUCILLE |
| --- | --- | --- |
| SWARM OS | `SWARM-OS-SUITE/SWARM-OS-LUCILLE` (was `swarm-os-i30ltz`) | `/mnt/Lucy` |
| Lucille Assistant | `SWARM-OS-SUITE/lucille-assistant` (was `i30ltz-lucille-assistant`) | partition C, `/mnt/lucillebuild/src/LucilleAssistant`; **no longer synced from `/mnt/Lucy`** (leg retired 2026-10-16) |

`swarm-lucy-sync.timer` runs `70-scripts/auto_sync_github.sh` every ten minutes
while the development host's user service manager is running. One timer serves
all four destinations. The three app repositories receive their own source trees
and history via Git subtree; each has its own `main` branch on GitHub.

The script commits non-ignored local changes, retries the main push even when
the working tree is clean, and attempts every destination independently. Any
failure makes the service fail visibly after the other destinations are tried.
A lock prevents overlapping manual and scheduled runs. Changes made directly on
GitHub are not automatically merged: a divergent push fails rather than forcing
over remote work.

Local root-owned boot backups and diagnostic VM artifacts are excluded. Runtime
environment files, signing keys, and other existing credential exclusions remain
ignored. The timer commits all other working-tree changes, including work from
other editors on the live drive.

Verification and manual retry:

```sh
systemctl --user status swarm-lucy-sync.timer
systemctl --user start swarm-lucy-sync.service
journalctl --user -u swarm-lucy-sync.service -n 40 --no-pager
```

Repository names are intentionally separate: I30LTZ Companion is the recovery
companion; Lucille Assistant is the assistant app. Neither replaces the other.

Verified 2026-09-24: all four destinations reported `SYNC OK` and the service
completed successfully. The previous blockage also included generated 4 GB
installer archives in unpublished history. Those archives were removed only
from unpublished commits, with the prior history preserved at
`refs/checkpoints/pre-autosync-history-repair-20260924`; the final source tree
was identical. GitHub main advanced normally without a force push.

**Moved 2026-10-06:** all Recovery OS projects now live on `/mnt/recoverybuild` with their own git repos and are no longer synced from `/mnt/Lucy`: `i30ltz-recovery` → `/mnt/recoverybuild/30-source/i30ltz-recovery`, `i30ltz-swarm-companion` → `/mnt/recoverybuild/I30LTZ-Recover`, build tree → `i30ltz-recovery-os`.

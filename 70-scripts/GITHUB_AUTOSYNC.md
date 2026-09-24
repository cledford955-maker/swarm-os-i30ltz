# Project repositories and automatic sync

All four repositories are private under `cledford955-maker`.

| Project | GitHub repository | Source on LUCILLE |
| --- | --- | --- |
| SWARM OS | `swarm-os-i30ltz` | `/mnt/Lucy` |
| I30LTZ Recovery OS | `i30ltz-recovery` | `/mnt/Lucy/30-source/i30ltz-recovery(seperate-related-project)` |
| I30LTZ Companion | `i30ltz-swarm-companion` | `/mnt/Lucy/30-source/android_companion/swarm_os-companion` |
| Lucille Assistant | `i30ltz-lucille-assistant` | `/mnt/Lucy/lucille-companion` |

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

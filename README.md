# SWARM OS — LUCILLE working drive

`/mnt/Lucy/` (capital L) is the active source and build workspace. Start with `AGENTS.md`, `SWARM_AI_FEATURES.md`, and `/mnt/brains/swarm-memory/PROJECT_MEMORY.md`.

## Build and keep releases

All active ISO files live **only** in `/mnt/ventoy/ISO/SWARM_OS/`. Keep the newest 10 rolling builds plus releases the user explicitly marks stable. Stable releases remain protected until unmarked. See [ISO_RELEASE_POLICY.md](ISO_RELEASE_POLICY.md).

Run as your normal user:

```bash
/mnt/Lucy/70-scripts/build_swarm_iso.sh
```

The build verifies Ventoy before version stamping, writes the ISO directly there, runs the boot gate, then applies retention. It never copies an ISO to the desktop or `10-releases`. Old dated build commands forward to this one implementation.

Use the **SWARM OS — Manage ISOs** desktop icon to mark/unmark stable builds. The old local ISO files can be migrated once using `70-scripts/migrate_swarm_isos.sh`, which verifies the copy before removing its source.

## Code and test from CachyOS

- **SWARM OS — Code** opens the source workspace in VS Code Insiders/VS Code.
- **SWARM OS — Launch VM** opens the latest usable Ventoy ISO in a QEMU window with a separate virtual disk. This does not boot or write to the physical SWARM installation.
- **SWARM OS — Build ISO** builds the current source directly to Ventoy.

These launchers are installed on the CachyOS desktop and application menu. Their project copies are in `70-scripts/desktop/`. Script paths and VM details are in `ISO_RELEASE_POLICY.md`.

## Working layout

| Location | Purpose |
|---|---|
| `/mnt/ventoy/ISO/SWARM_OS/` | Only active ISO store; latest pointer and stable markers |
| `10-releases/` | Non-ISO artifacts; no new ISO output |
| `20-runtime/.env` | Runtime secrets; never commit or expose |
| `30-source/frontend/` | Flutter desktop shell |
| `30-source/swarm-slint/` | Rust/Slint companion panel |
| `30-source/LucyServer-go/` | Primary Go server |
| `30-source/GamingAgent-go/` | Gaming service |
| `40-iso-profile/` | Archiso live-system profile |
| `grub_themes/` | CachyOS/SWARM GRUB themes |
| `70-scripts/` | Current build, release, VM, and support scripts |
| `80-vm/` | VM firmware, separate virtual disks, and tests |

Historical/orphaned directories and the read-only lucy-master mirror are not active build targets. Follow the restrictions in `AGENTS.md` before touching them. The Flutter SDK is on this drive; `70-scripts/setup-dev-deps.sh` prepares the host toolchain.

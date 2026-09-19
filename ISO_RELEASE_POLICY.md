# SWARM ISO release policy — 2026-09-19

User decision: every active SWARM OS ISO belongs ONLY in `/mnt/ventoy/ISO/SWARM_OS/`.

- Keep the newest **10 rolling builds**, plus any builds explicitly marked **stable**. Stable releases stay until the user unmarks them; no automatic expiry.
- A successful boot gate is not a stable designation. Never infer stable from a filename such as latest/fallback, from build success, or from a previous assistant's claim.
- Mark stable with `70-scripts/manage_swarm_releases.sh stable ISO_FILENAME --note "reason"`. A `<filename>.iso.stable` sidecar protects it. An explicit `-stable` filename is also protected.
- Unmark with `70-scripts/manage_swarm_releases.sh unmark-stable ISO_FILENAME`. Renaming is required to remove a stable designation embedded in a filename.
- The only build implementation is `70-scripts/build_swarm_iso.sh`. Run as a normal user. Historical dated entry points only forward here.
- Verify the mounted Ventoy filesystem UUID **4E21-0000** before writing or pruning. If it is absent, abort before version stamping. Never fall back to the project disk, desktop, a drive root, or a similarly named directory.
- Build ISO output directly under Ventoy `.incoming/`; publish the completed file in the same filesystem. Build intermediates, logs, and VM virtual disks may remain in `/mnt/Lucy/`; ISO copies may not.
- `latest.txt` stores one release filename because Ventoy is exFAT. Never make multi-GB latest/fallback copies. A failed boot gate does not become latest.
- Never put ISO files or ISO symlinks on the desktop. Desktop launchers open the canonical build, release manager, code workspace, or VM scripts.
- Do not recreate the obsolete push-to-Ventoy workflow: the build already outputs there.
- `migrate_swarm_isos.sh` verifies SHA-256 before removing a local source. Legacy latest/fallback copies are removed only when identical to a versioned ISO. It never labels a migrated image stable.
- Read-only mirrors and historical archives are not active release stores. Do not modify them as part of this policy.

## Desktop launchers

`SWARM OS — Launch VM` opens an isolated QEMU window using the latest usable Ventoy ISO. It uses a separate 32GB sparse virtual disk under `80-vm/desktop`, 4GB RAM and four vCPUs by default. No physical host disks are exposed. Close the VM window to stop it; the next launch boots the ISO again. Guest live-session edits are temporary unless installed on the virtual disk.

`SWARM OS — Code` opens `SWARM_OS.code-workspace` in VS Code Insiders (or VS Code).

`SWARM OS — Build ISO` runs the canonical builder. `SWARM OS — Manage ISOs` lists builds, marks/unmarks stable, and prunes.

Code edits on CachyOS affect `/mnt/Lucy/30-source`; rebuild to see them in the VM ISO. The VM is not the installed physical SWARM partition.

## Verification

Retention/migration tests: `python -m unittest discover -s 70-scripts/tests -p test_iso_retention.py`.
Read-only preview: `python 70-scripts/swarm_iso_manager.py migrate --dry-run` or `prune --dry-run`.

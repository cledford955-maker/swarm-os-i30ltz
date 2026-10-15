# SWARM OS update and ISO policy — 2026-10-14

**Current user decision:** Ventoy is destroyed and is no longer a release target.
Keep exactly one current SWARM OS ISO in `/mnt/Lucy/10-releases/`. Do not write
ISOs to Ventoy, `/mnt/boltz`, Downloads, the desktop, or other fallback stores.
Do not run old Ventoy cleanup or weekly archive procedures.

Normal software changes should be deployed live to the installed SWARM system
using the reviewed update path and a pre-update snapshot. Build a new ISO only
when the bootable installer/live image itself needs updating. The project ISO
is for the current release and VM testing; QEMU must select it from
`/mnt/Lucy/10-releases/` and must never fall back to old copies.

Electron is a Debian-only desktop test harness. Its package and launcher live
under `30-source/swarm-electron/` and `70-scripts/launch_swarm_electron.sh`.
Do not stamp Electron from the SWARM version, stage it into the ISO or installed
SWARM system, or treat Electron testing as SWARM OS release evidence.

Before an in-place system update, run `70-scripts/snapshot_before_update.sh`.
Retain the newest three snapshots. Do not prune or remove older ISOs outside
the project as part of this policy change.

The canonical builder remains `70-scripts/build_swarm_iso.sh` and must be run
as the normal user. It writes one temporary build under the project release
directory, publishes one current ISO, and runs its configured boot gate unless
explicitly skipped. The builder auto-increments `VERSION`; do not manually
change it. Source/test evidence, VM boot evidence, ISO evidence, and physical
hardware evidence remain separate.

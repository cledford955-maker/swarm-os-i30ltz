# ISO storage policy — 2026-09-24

User decision: keep **ten current operating-system ISO files total**, on Ventoy.
This applies to all operating systems, not just SWARM. It supersedes the older
"ten rolling builds plus stable exceptions" policy.

- Keep the ten newest distinct completed images by modification time. Stable
  labels do not exempt an image from the total. Weekly Boltz archives are the
  explicit exception outside this active set.
- SWARM releases live at `/mnt/ventoy/ISO/SWARM_OS/`. Other future OS installers
  may live elsewhere on Ventoy but count toward the same total of ten.
- Once per ISO calendar week, archive the newest SWARM image with a recorded
  `boot_gate=pass` to `/mnt/boltz/ISO/SWARM_OS/weekly/YYYY-Www/`. Verify source and
  destination SHA-256 checksums. Do not archive failed/untested builds, and do not
  duplicate an unchanged build across weeks. Keep historical weekly archives.
- Boltz must be the mounted ext4 filesystem UUID
  `689e6547-b439-4e7f-93c9-a6dcfabed46b`. Never write into the empty mountpoint or
  redirect an archive onto the project/system disk when Boltz is unavailable.
- Ventoy must be mounted at `/mnt/ventoy` with UUID `4E21-0000`. Missing or wrong
  media aborts release operations before version stamping.
- Use only `70-scripts/build_swarm_iso.sh` as the normal user. It creates one
  in-progress ISO directly in Ventoy `.incoming/`, publishes it on the same
  filesystem, and enforces the ten-image total. The temporary in-progress image
  is removed on normal failure; the next locked build clears interrupted output.
- No project-disk/desktop ISO copies, duplicate latest/fallback images, or separate
  push-to-Ventoy workflow. `latest.txt` is a filename pointer, never a full copy.
- A successful publication with a boot pass also attempts the weekly archive.
  If Boltz is unavailable, report the pending archive; do not invent a fallback.
- Do not modify read-only source mirrors. Never delete non-ISO source/build files
  as part of retention.

## Current cleanup

`70-scripts/iso_cleanup_20260924.json` records the reviewed 49-file inventory:
ten retained images and 39 deletion targets. It records exact paths, sizes,
inodes, device IDs and modification times, and checksums for verified duplicates.
Any changed file or missing retained source makes the cleanup refuse to proceed.
The four writable surplus files have been removed (13,559,398,400 bytes).
The remaining 35 deletions and three retained-image relocations require root.

Complete the prepared cleanup and mount/archive-directory setup:

```sh
sudo /mnt/Lucy/70-scripts/apply_iso_storage_policy.sh
```

This command validates Ventoy, preserves the ten reviewed images there, removes
only the listed surplus ISOs, mounts the identified Boltz filesystem if needed,
and prepares the weekly archive directory for the project owner. No current ISO
has recorded boot-pass metadata, so no image is currently eligible for archiving.

## Inspection and maintenance

```sh
python3 /mnt/Lucy/70-scripts/swarm_iso_manager.py prune --dry-run
python3 /mnt/Lucy/70-scripts/swarm_iso_manager.py archive-weekly
python3 -m unittest discover -s /mnt/Lucy/70-scripts/tests -p 'test_iso_*.py'
```

The existing VM launcher still reads Ventoy's canonical release store. The desktop
build launcher uses the canonical builder. New code requires rebuilding before
it appears in an ISO; a modified guest session is not proof of a new release.

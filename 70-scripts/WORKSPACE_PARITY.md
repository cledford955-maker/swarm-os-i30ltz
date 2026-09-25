# SWARM Workspace Parity

`swarm_workspace_parity.py` compares the canonical workspace with a mounted
mirror without modifying either tree. It hashes regular files, hashes symlink
targets without following them, and reports three kinds of drift:

- same path with different content or file type;
- paths present only in the source;
- paths present only in the mirror.

The generated `source.sha256`, `mirror.sha256`, and `report.json` files are
written atomically with mode 0600 outside both compared trees.

## Manual check

```bash
/mnt/Lucy/70-scripts/swarm_workspace_parity.py \
  --source /mnt/Lucy \
  --mirror /run/media/i30ltz/lucy-master \
  --manifest-dir /var/tmp/swarm-workspace-parity \
  --require-mounts
```

Exit status 0 means the included files match. Status 1 means drift was found.
Status 2 means the comparison could not be completed. Add `--skip-missing` for
scheduled checks: an absent or unmounted encrypted mirror then reports
`skipped` and exits successfully rather than generating a false failure.

The checker is read-only. It does not invoke rsync, copy, delete, reconcile, or
choose a winning side. Review a drift report before running any synchronization
command.

## Exclusions

The default scope is source and configuration content. It excludes secrets,
large SDKs, generated builds, virtual disks, ISOs, logs, caches, and release
archives. The built-in list includes `20-runtime`, `30-source/flutter-sdk`,
`build`, `target`, `.git`, `80-vm`, and common artifact extensions. Additional
patterns can be supplied with repeated `--exclude` arguments.

## Scheduled check

The ISO stages `swarm-workspace-parity.service` and enables its timer. It runs
15 minutes after boot and then every six hours with a randomized delay. The
default paths come from `/etc/default/swarm-workspace-parity`; change that file
when a host mounts the reference mirror elsewhere.

The service requires both configured roots to be active mountpoints. If the
encrypted mirror is unavailable, it records a journal `skipped` result and does
not create manifests. Reports live in `/var/lib/swarm/workspace-parity`.

## Verification boundary

Five fixture tests cover changed files, files unique to either side, exclusion
of secrets/build products, symlink handling, private atomic output, and missing
or unmounted mirrors. The systemd service and timer validate with a staged
executable. On 2026-09-25 the configured reference mirror was not mounted, so
no claim is made that the current source and mirror contents match.


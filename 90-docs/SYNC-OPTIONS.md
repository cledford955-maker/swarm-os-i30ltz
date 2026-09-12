# SWARM OS — Non-Destructive Mesh Sync Policy (SYNC-OPTIONS.md)
Version: 2026.1
Domain: Distributed Synchronization

## Core Philosophy: Zero Data Loss Invariant
Cross-device synchronization between SWARM_OS workstations, mobile companion nodes, and external storage partitions must NEVER delete or truncate existing user data on any target partition.

## Mandatory Rsync Flags
All automated synchronization tasks between nodes MUST enforce the following non-destructive flags:
- `-a` (`--archive`): Preserves permissions, timestamps, symlinks, and directory hierarchies.
- `-v` (`--verbose`): Detailed transfer logging.
- `-u` (`--update`): Skips files that are newer on the receiver.
- `-z` (`--compress`): Compresses data during transit over the Tailscale WireGuard mesh.
- `--no-delete`: **STRICT ENFORCEMENT**. Never removes files from the destination that are absent on the source.
- `--ignore-errors`: Prevents catastrophic partial state deletions if I/O hiccups occur.
- `--backup` and `--backup-dir=/var/log/swarm_sync_backups`: Creates versioned historical backups if a file is modified.

## Standard Exclusions
- `.git/`
- `build/`
- `target/`
- `node_modules/`
- `*.iso`
- `*.tmp`
- `*.swap`
- `/tmp/`
- `__pycache__/`

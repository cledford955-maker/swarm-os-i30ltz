# SWARM OS Shared Memory

v1.0.0 — 2026-09-16. Full spec: `/mnt/Lucy/90-docs/SWARM_MEMORY_SYNC_v1.0.0_2026-09-16.md`.

One append-only log shared by LUCILLE (CachyOS, SWARM OS, EndeavourOS), the three
companion phones, and Claude Code's memory files.

| Path | What |
|---|---|
| `log/<device>.jsonl` | The memory. One file per device, append-only, never edited. |
| `PROJECT_MEMORY.md` | Generated readable view for any AI. Do not edit. |
| `peers.json` | Extra sync peers for the CLI, e.g. phones: `{"peers": ["http://100.x.y.z:8402"]}` |
| `lease.json` | Current "main" device for live editing (volatile, not in git). |
| `state/` | Per-device sync cursors and Claude-memory hashes (volatile, not in git). |

Add a memory: `swarm-memory add -kind decision -key <topic> "text"` · Read: `swarm-memory list`.
Git copy: `/mnt/Lucy/60-boltz-brain/swarm-memory/` (mirrored by `70-scripts/auto_sync_github.sh`).
Restore after losing this partition: `rsync -a /mnt/Lucy/60-boltz-brain/swarm-memory/log/ /mnt/brains/swarm-memory/log/`.

# Boltz Brain — Lucille's Memory
`v1.0.0 · 2026-09-07`

Boltz Brain is the persistent memory for LUCILLE / SWARM OS. It is the one
directory on this drive that must survive every reinstall, reformat and ISO
rebuild. Treat it as the crown jewels.

## Layout

| Path | Holds | Syncs to phones |
|---|---|---|
| `identity/` | Who Boltz is — persona, voice, operating rules | yes |
| `memory/core/` | Durable facts: the user, the machine, the project | yes |
| `memory/sessions/` | Per-session transcripts and summaries | yes |
| `memory/knowledge/` | Learned facts, references, distilled notes | yes |
| `index/` | Search index / embeddings, rebuildable from memory | no |
| `logs/` | Runtime logs, rotated | no |
| `exports/` | Point-in-time snapshots | yes |

`index/` and `logs/` are derived — losing them costs a rebuild, not data.
Everything under `memory/` and `identity/` is source of truth.

## Canonical store

    memory/boltz.db          SQLite, written by lucille-core
    memory/core/*.md         Human-readable mirror, one subject per file

`lucille-core` links against `libsqlite3.so.0`, so the database is its native
format. The Markdown mirror exists so a human — or a different model — can read
the memory without the binary.

## File naming

Every file carries a version and a date:

    <subject>_v<major>.<minor>.<patch>_<YYYY-MM-DD>.md

Superseded versions move to `../99-archive/superseded/`, they are not deleted.

## Snapshot before any risky operation

    tar -czf exports/boltz-brain_$(date +%Y-%m-%d_%H%M).tar.gz identity memory

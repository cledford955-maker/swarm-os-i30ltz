# SWARM OS Shared Memory — Sync Spec & Build

**Version:** 1.0.0 · **Date:** 2026-09-16 · **Status:** Built (Go server + CLI + companion app). Supersedes the open decisions in *SWARM OS Sync Architecture v0.2.0* (artifact `EFgK3FBrJZD61QyVPTPR55`).

One memory for LUCILLE's three OSes (CachyOS, SWARM OS, EndeavourOS), the three companion phones, and Claude Code — online, offline, and with Tailscale down.

---

## 1. Where it lives

| Path | Role |
|---|---|
| `/mnt/brains/swarm-memory/log/<device>.jsonl` | **The memory.** Append-only, one file per device. |
| `/mnt/brains/swarm-memory/PROJECT_MEMORY.md` | Generated plain-text view any AI can read cold. |
| `/mnt/brains/swarm-memory/peers.json` | Extra sync peers for the CLI: `{"peers": ["http://<phone tailnet ip>:8402"]}` |
| `/mnt/brains/swarm-memory/lease.json` | Write lease (volatile). |
| `/mnt/brains/swarm-memory/state/` | Per-device cursors and Claude-memory hashes (volatile). |
| `/mnt/Lucy/60-boltz-brain/swarm-memory/` | **Git copy**: `log/`, `PROJECT_MEMORY.md`, `peers.json`, `README.md`, and `docs/` (the six core files). Written by `70-scripts/auto_sync_github.sh` before every auto-commit. |

`/mnt/brains` is nvme0n1p5, mounted by every OS, so the three OSes share the log directly. Phones sync over HTTP.

**Restore** after losing the partition: `rsync -a /mnt/Lucy/60-boltz-brain/swarm-memory/log/ /mnt/brains/swarm-memory/log/`, then copy `docs/*` back to `/mnt/brains/`.

## 2. Entry format (schema v1)

```json
{"v":1,"id":"<uuid>","device":"cachyos@cachyos-i30ltz","ts":"2026-09-16T09:28:08.123456789Z",
 "kind":"decision","key":"sync-transport","content":"…","tags":[],"meta":{},"deleted":false}
```

- **device** — OS installs are `<os-release ID>@<hostname>` (the OSes share hardware and may share a hostname). Phones are `phone-<model>-<android id prefix>`. Override with `SWARM_DEVICE_ID`.
- **kind** — `note`, `fact`, `decision`, `doc`, `claude_memory`, or any `[a-z][a-z0-9_]{0,31}`.
- **key** — entries with the same kind+key supersede each other (newest `ts` wins). Unkeyed entries are standalone notes.
- **deleted** — tombstone for a keyed entry.
- Validation is identical in Go (`memory/entry.go`) and Kotlin (`MemoryEntryEntity.fromJson`). Device ids can't contain `/`, so a pushed entry can't escape `log/`.

**Merge rule:** union by `id`, order by (`ts`, `id`). There are no conflicts to resolve, by construction.

## 3. What is in the memory

| Source | Kind / key | Direction |
|---|---|---|
| `/mnt/brains/{Lucy_Core_Prompt.md, Dr_Boltz_Core_Prompt.md, llcy_memory.md, lucille_personas_memory.json, memory.json, users.json}` | `doc` / filename | **One way**, files → log. A new entry is written only when content changes. Files stay authoritative where LucyServer already reads them. |
| `~/.claude/projects/-mnt-Lucy/memory/*.md` (Claude Code) | `claude_memory` / filename | **Both ways.** Local edit → new entry. Newer entry from another device → written to disk. Local delete → tombstone. Tombstone → local delete. Per-device hashes in `state/claude-<device>.json` separate "I changed it" from "someone else changed it". If both sides changed, local wins and the log keeps both versions. |
| People, phones, AIs | `note` / `fact` / `decision` | Written with `swarm-memory add`, the companion Memory tab, or `POST /api/memory/entries`. |

⚠️ `users.json`, `memory.json` and `llcy_memory.md` hold personal data (`memory.json` has two email addresses), and they are pushed to GitHub (`cledford955-maker/swarm-os-i30ltz`) — the user chose this on 2026-09-16. A scan found no passwords or API keys.

## 4. Transport

| Path | Port | Auth | Who |
|---|---|---|---|
| Tailscale → LucyServer main API | 5000 `/api/memory/*` | `X-Swarm-Auth` (loopback exempt, like all `/api`) | Phones anywhere with internet |
| LAN fallback → LucyServer sync-only listener | 8402 `/api/memory/*` only | Token always; any `Origin` header is refused | Phones on home Wi-Fi with Tailscale down |
| Phone ↔ phone | 8402 on each phone (`MemorySyncServer.kt`) | Same token rules | Gossip when LUCILLE is unreachable |

- **Discovery:** mDNS `_swarmcompanion._tcp`. LUCILLE advertises through avahi (`airootfs/etc/avahi/services/swarm-memory.service`), and phones register and browse with `NsdManager`.
- **Firewall** (`airootfs/etc/nftables.conf`): tcp 8402 from 10/8, 172.16/12, 192.168/16, fe80::/10, and udp 5353. Tailscale was already fully accepted.
- **Public token guard:** the LAN listener (LucyServer) and each phone's server + discovery **do not start while the token is the public fallback `swarm-token-2026`**. Tailscale sync on 5000 still works. To enable: put a real `SWARM_AUTH_TOKEN` in `/etc/swarm_os.env` (the installer generates one) and enter the same token in the companion's Remote PC settings.

## 5. Sync protocol

```
GET  /api/memory/sync?cursor=<opaque>  -> {"device","entries":[…],"cursor","more"}
POST /api/memory/sync {"entries":[…]}  -> {"accepted": n}      (always accepted; dedup by id)
```

- **Cursors instead of `since=<timestamp>`** (a deliberate change from v0.2.0): clocks on phones drift. LucyServer's cursor is the byte offset per device file, which is exact because the files are append-only. A phone's cursor is its Room `seq`. Cursors are opaque to the other side.
- Each side stores the peer's pull cursor and its own push cursor per peer. It pushes **everything** past the push cursor, including entries received from third devices, so the mesh converges by gossip.
- Phones page 500 entries (`more: true`). Pushes are batched 200 at a time.

## 6. Live editing — write lease

```
GET  /api/memory/lease
POST /api/memory/lease/acquire   {"device","force"}   force = explicit "Take over"
POST /api/memory/lease/heartbeat {"device"}           every 10 s
POST /api/memory/lease/release   {"device"}
GET  /api/memory/stream          SSE: event "entry", event "lease"
POST /api/memory/entries {"device","kind","key","content"}  -> 409 while another device is main
```

- TTL 30 s. A phone that locks or leaves range loses main automatically.
- The lease governs **live** writes only. Offline entries pushed later through `/sync` are always accepted; the append-only log makes that safe. The companion refuses a live write while it can see another device is main, and queues writes when LUCILLE is unreachable.
- The CLI writes the log directly and does not take the lease. It is a local, append-log writer like an offline phone.
- The stream picks up writes from other processes (e.g. the CLI) within 2 s.

## 7. Components

| Piece | Location |
|---|---|
| Log store, lease, importers, render, peer client, HTTP API + 11 tests | `30-source/LucyServer-go/memory/` |
| Server wiring (`/api/memory` on :5000, LAN listener on :8402) | `30-source/LucyServer-go/memory_wiring.go`, `main.go` |
| CLI `swarm-memory` (add, list, current, import-docs, claude, sync, render, tick, mirror, status) | `30-source/LucyServer-go/cmd/swarm-memory/` |
| Companion: Room table (migration 1→2, no data loss), sync engine, embedded server, NSD, JobScheduler job, Memory tab | `swarm_os-companion/app/src/main/java/com/example/data/memory/`, `ui/screens/MemoryScreen.kt` |
| SWARM OS: `swarm-memory-tick.timer` (5 min, User=swarm), avahi service, firewall, CLI staged to `/usr/local/bin` | `40-iso-profile/…/airootfs/`, build script step 3 |
| CachyOS dev host: `~/.local/bin/swarm-memory`, user `swarm-memory.timer` (5 min) | `~/.config/systemd/user/` |

**Background sync on phones:** a network callback triggers sync on reconnect (no polling timer). A persisted `JobScheduler` job runs at most every 15 min inside Doze maintenance windows. The embedded server only runs while the app process is alive, so phone-to-phone gossip is best effort by design; LUCILLE is the durable hub.

## 8. Not done yet

- **EndeavourOS:** install the CLI and timer there (`go build -o ~/.local/bin/swarm-memory ./cmd/swarm-memory` from LucyServer-go, then copy the two user units from CachyOS).
- **Phones:** install the new APK on all three, and set the real token in Remote PC to enable phone-to-phone sync.
- **Device verification:** not yet tested on real phones. Room migration, NSD on each phone model, and Doze job timing are unverified.
- **LUCILLE → phone pushes** need phone tailnet IPs in `peers.json`. Phones already pull from LUCILLE, so this only matters for LUCILLE-initiated sync.
- **Log compaction:** every change to `memory.json` or `users.json` stores a full copy (~220 KB each). Add compaction if the log grows past a few MB.
- **Encryption at rest** for the git copy of personal files: not in place (see §3).

## Changelog

- **1.0.0 — 2026-09-16:** First build. Resolves all six v0.2.0 open decisions: `ai-memory` layout = `/mnt/brains/swarm-memory`; schema v1 with version field; cursor protocol; lease TTL 30 s / heartbeat 10 s; phone queue = Room table; Doze strategy = network callback + JobScheduler. Adds the Claude memory two-way sync, git mirroring, and the public-token guard on LAN listeners.

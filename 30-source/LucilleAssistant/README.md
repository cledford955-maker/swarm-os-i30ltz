# Lucille Assistant v1.0.0

Lucille's personal-assistant side: a Go service on **:8403** plus a phone-first web app
(the purple-lightning UI in `web/`). Stdlib only — no dependencies.

## What she does (built)

| Job | Endpoint | Source |
|---|---|---|
| Daily brief + spoken headline | `GET /api/brief` | everything below, in parallel |
| Nudges: meds late, water behind pace, meal gap, short sleep, 90-min break, past 1 AM | `GET /api/nudges` | care log + sessions |
| Meds / water / meals / sleep | `GET /api/care`, `POST /api/care/{med,water,meal,sleep}` | `~/.local/share/lucille-assistant/care/<date>.json` |
| Project + gaming time | `GET /api/sessions`, `POST /api/sessions/{start,stop}` | `sessions.json` |
| Git status | `GET /api/git` | `git status` on configured repos |
| Local drives | `GET /api/drives` | `/proc/mounts` + statfs |
| Mail / calendar / Google Drive | `GET /api/{mail,calendar,gdrive}` | GoogleWorkspaceService :8399 |
| Shared memory read / add | `GET/POST /api/memory` | `/mnt/brains/swarm-memory/log`, `swarm-memory add` |
| Steam hours | `GET /api/gaming` | Steam Web API + logged gaming sessions |
| Steam sales + CD-key prices | `GET /api/deals`, `/api/deals/lookup?title=` | CheapShark (authorized key stores only) |
| Arch / distro / Linux / Linux-gaming news, politics filtered | `GET /api/news?tag=` | RSS: Arch, CachyOS, GamingOnLinux, Phoronix, DistroWatch, Steam |
| Build ideas | `GET /api/ideas` | Nemotron with git + memory + hours context; curated fallback |

## Build & run

```bash
cd /mnt/Lucy/30-source/LucilleAssistant && go build -o lucille-assistant .
```

```bash
bash -c 'set -a; . /mnt/Lucy/20-runtime/.env; set +a; ./lucille-assistant'
```

Open http://127.0.0.1:8403. First run writes `~/.config/lucille-assistant/config.json` —
**edit your real med names and times there**, plus repos, mounts, projects, water goal, wake/bed times.

Env: `LUCILLE_ASSISTANT_LISTEN` (`;`-separated), `LUCILLE_ASSISTANT_CONFIG`, `LUCILLE_ASSISTANT_DATA`,
`SWARM_AUTH_TOKEN`, `STEAM_API_KEY`, `STEAM_ID64`, `NVIDIA_API_KEY`.

## Phone

1. Run as a service: see `systemd/lucille-assistant.service` (listens on loopback + Tailscale 100.82.1.19).
2. Set a real `SWARM_AUTH_TOKEN` — without it, every non-loopback API call is refused.
3. On the phone (on the tailnet) open `http://100.82.1.19:8403/?token=YOUR_TOKEN` once — the token is saved — then *Add to Home screen*.

Next step: a native Lucille tab in `android_companion` that calls the same API.

## Artifact

`web/index.html` is also the published artifact. With no server reachable it shows clearly-labelled example data.

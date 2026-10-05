# SWARM Companion — setup
`2026-09-07 · v1.0.0`

The Companion does two different things over two different channels. Getting
them confused is what made the first attempt sync 1.25 GB.

| Feature | Screen | Channel | Needs |
|---|---|---|---|
| Coder Droid IDE | `CoderDroidScreen` | **local phone storage** | Syncthing |
| Remote terminal | `InteractiveTerminalScreen` | `ws://host:5000` | LucyServer + token |
| Remote commands | `RemotePcScreen` | `http://host:5000` | LucyServer + token |

Coder Droid uses an Android folder picker (`OpenDocumentTree`) and reads a
`File` tree from the phone. It never calls the server. That is why the project
must be synced.

## 1. Sync the workspace

Folder: `/run/media/i30ltz/LUCILLE/30-source`   ·   Syncthing id `swarm-source`

`30-source/.stignore` strips build output:

    1.25 GB / 6392 files   ->   40 MB / 466 files   (96.9% cut)

Excluded: `.dart_tool` (833 MB), `build` (151 MB), `bin` (95 MB), `obj`,
`.gradle`, `.idea`, `node_modules`, and all `*.iso *.apk *.zip *.qcow2 *.gguf`.
`.env` is excluded too — secrets never leave LUCILLE.

On the phone: Coder Droid -> folder picker -> the synced `30-source` folder.

Set this folder **Send Only** from LUCILLE unless you intend to edit on the
phone and push back. Receive-and-send means a phone can overwrite your source.

## 2. Start the server for the terminal screens

    /mnt/Lucy/70-scripts/serve_project_to_companion_v1.0.0_2026-09-07.sh

Prints host, port and the auth token.

> Corrected 2026-10-05: this previously read
> `./00-CURRENT/serve-to-companion.sh`, which does not exist —
> `00-CURRENT/` holds only symlinks. The token itself is generated on
> first run and kept at `~/Documents/.swarm_auth_token` (mode 600).
> The script exports it as `SWARM_AUTH_TOKEN`.
> Note the Lucille Assistant (Go, port 8403) is a *different* service and
> reads `SWARM_AUTH_TOKEN` from `/mnt/Lucy/20-runtime/.env` instead.

Then in the Companion:
Remote PC -> expand the node config -> set the IP, paste the token, SAVE.

## Companion changes made 2026-09-07

- **new** `data/config/SwarmConnection.kt` — SharedPreferences-backed host,
  port, auth token, project root. Single source of truth.
- `RemotePcScreen.kt` — host and token now come from `SwarmConnection`;
  added an auth-token field, a SAVE button, and a warning line when the
  connection is unusable.
- `InteractiveTerminalScreen.kt` — same; it had its own separate hardcoded IP.
- `AppRepository.kt` — the `/api/run_command` call used a hardcoded URL and
  **sent no auth header at all**, so it had been failing 401 regardless.

Removed from the app: the literal `X-Swarm-Auth: "swarm-token-2026"` that was
compiled into every build in two places.

Originals in `99-archive/superseded/*_2026-09-07_pre-config.kt`.

## NOT verified

Not compiled. No Android SDK or Gradle reachable from this session, and
`nuget.org` / the .NET installers are blocked too. Before trusting either side:

    cd 30-source/android_companion/swarm_os-companion && ./gradlew assembleDebug
    cd 30-source/LucyServer && dotnet build

## Still open

- Coder Droid has no server-backed file access. If you want the IDE to open
  files live from LUCILLE instead of a synced copy, that is a new feature —
  LucyServer already exposes `/api/fs` and `/api/code/files`, the app just
  never calls them.
- `/api/tts` remains exempt from auth.

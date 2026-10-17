# Coder Droid folder picker — root cause and fix
`2026-09-07 · v1.0.0 · app v6.2.20`

## The bug

Tapping the folder icon opened the system picker; choosing a folder returned to
an unchanged screen. Nothing was logged and nothing happened.

`CoderDroidScreen.kt`:

    val path = uri.path?.removePrefix("/tree/primary:") ?: return@let
    val root = File(Environment.getExternalStorageDirectory(), path)
    if (root.exists()) { open(root) }

Three faults, compounding:

1. **No storage permission existed.** The manifest declared only INTERNET,
   ACCESS_NETWORK_STATE, KILL_BACKGROUND_PROCESSES and USE_BIOMETRIC. With
   `targetSdk = 36`, scoped storage blocks every `java.io.File` read of shared
   storage, so `root.exists()` was **always false**.
2. **The if-body simply never ran**, and there was no else. Both failure paths
   (`?: return@let` and the failed `if`) were silent. That is the "just exits".
3. **The prefix strip only handled primary storage.** An SD card or USB volume
   yields `1A2B-3C4D:...`, which produced a nonsense path.

## The fix

**Manifest** — added `MANAGE_EXTERNAL_STORAGE`, plus `READ_EXTERNAL_STORAGE`
(maxSdk 32) and `WRITE_EXTERNAL_STORAGE` (maxSdk 28) for older devices, and
`requestLegacyExternalStorage` for API 29.

**New `ui/coderdroid/CdrStorage.kt`**
- `resolvePickedTree()` parses the tree Uri with `DocumentsContract.getTreeDocumentId`
  and handles `primary:` and volume-id forms correctly.
- Returns `Success` / `NeedsAllFilesAccess` / `Failed(reason)` — never silence.
- `takePersistableUriPermission` so the grant survives a restart.
- Remembers the workspace; `loadLastWorkspace()` reopens it next launch.
- `suggestedWorkspaces()` lists only folders verified to exist and be readable.

**`CoderDroidScreen.kt`**
- Permission is checked before the picker opens; if missing, the user is sent
  to the All-files settings page.
- A lifecycle observer re-checks on ON_RESUME and opens the pending folder as
  soon as the grant is given.
- A chooser dialog offers verified folders plus a BROWSE… escape hatch.
- A status banner shows the reason for every failure, with a GRANT shortcut.
- The last workspace reopens on launch, so the IDE never starts empty.

## Auth token removed from the app

`RemotePcScreen`, `InteractiveTerminalScreen` and `StoneUnlockScreen` each had
`X-Swarm-Auth: "swarm-token-2026"` compiled in. All three now read
`SwarmConnection.authToken` (SharedPreferences), set in Remote PC -> node config.
`AppRepository` sent no auth header at all; it does now.

## IMPORTANT: two companion projects exist

    /mnt/lucy/Luccile-v+/swarm_os-companion                   v6.2.20  55 kt  CURRENT
    /mnt/lucy/Luccile-v+/android_companion/swarm_os-companion v6.2.11  50 kt  stale

All fixes above went into the **v6.2.20** tree. `LUCILLE/30-source/android_companion`
holds a copy of the **stale v6.2.11** one — do not build or sync that as if it
were current. Decide which to keep and delete the other.

## Feature check

Screens receive real data (Room entities, `SystemStats`) as parameters from
MainActivity: Dashboard, SystemMonitor, TaskSync, Antivirus, AiLab, OsDeployment.
Network-backed: RemotePc, InteractiveTerminal, StoneUnlock, and now CoderDroid's
storage layer. No dead screens found.

## NOT verified

**Not compiled, not installed.** This sandbox has JDK 11 only (AGP needs 17+),
no Gradle, no Android SDK, no adb, and `dl.google.com`, `repo1.maven.org` and
`services.gradle.org` are all unreachable. Run on LUCILLE:

    ./70-scripts/build_and_deploy_companion_v1.0.0_2026-09-07.sh

It preflights adb/JDK/SDK, builds, checksums into `10-releases/`, installs on
every connected phone, and grants All-files access via `appops` where possible.

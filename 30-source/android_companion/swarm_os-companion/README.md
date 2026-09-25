# SWARM OS — Android Companion App

Kotlin/Jetpack Compose companion for SWARM OS. Connects to LucyServer (port 5000) and GamingAgent (port 8401) over Tailscale or LAN.

## Project Location

```
30-source/android_companion/swarm_os-companion/
```

## Build

```bash
cd /mnt/Lucy/30-source/android_companion/swarm_os-companion
./gradlew assembleDebug          # debug APK
./gradlew assembleRelease        # release APK (needs keystore)
```

Built APK lands at `app/build/outputs/apk/`.

## Key Screens

| Screen | What it does |
|---|---|
| Dashboard | Fleet overview, quick actions |
| Monitor | Per-device CPU/RAM/battery/ping; fleet pool stats |
| Dr. I30LTZ Avatar | Phone body diagram + telemetry + Boltz cheatsheet |
| Remote PC | Connect to SWARM OS terminal (SwarmConnection settings) |
| Coder Droid | Live shell over `/api/terminal/ws` |

## Connection Setup

Settings → Remote PC → enter SWARM OS IP (Tailscale preferred), port 5000, and `SWARM_AUTH_TOKEN` from `/etc/swarm_os.env` on the SWARM machine.

`SwarmConnection.kt` stores these in SharedPreferences.

## Auth Token

Default fallback: `swarm-token-2026`. Change it in `/etc/swarm_os.env` on SWARM and update here. See `FIRST_BOOT_CHECKLIST.md` §13.

## Before Deploying a New APK

Snapshot the installed SWARM OS root first (in case you're also pushing server-side changes):

```bash
# Desktop shortcut:
# /home/i30ltz/Desktop/swarm-snapshot.desktop  (right-click → Allow Launching)

# Or terminal:
sudo /mnt/Lucy/70-scripts/snapshot_before_update.sh pre-companion-apk
```

Rollback: reboot → GRUB → pick a **Snapshot** entry.

> **Keep desktop script current:** the `.desktop` calls `snapshot_before_update.sh`
> by absolute path. If the script moves, update the `Exec=` line in the `.desktop` file.

## Source of truth

`/mnt/Lucy/SWARM_AI_FEATURES.md` — Android Companion section.

# SWARM OS — Android Companion App  *(separate-project copy)*

> This directory is a separate-project mirror. The active source is:
> `30-source/android_companion/swarm_os-companion/`
> See that README for full docs.

Kotlin/Jetpack Compose companion for SWARM OS. Connects to LucyServer (port 5000) and GamingAgent (port 8401) over Tailscale or LAN.

## Build

```bash
cd /mnt/Lucy/30-source/android_companion/swarm_os-companion
./gradlew assembleDebug
```

## Before Deploying

Always snapshot first if you're also pushing server-side changes:

```bash
# Desktop shortcut:
# /home/i30ltz/Desktop/swarm-snapshot.desktop  (right-click → Allow Launching)

# Or terminal:
sudo /mnt/Lucy/70-scripts/snapshot_before_update.sh pre-companion-apk
```

Rollback: reboot → GRUB → pick a **Snapshot** entry.

> **Keep desktop script current:** the `.desktop` calls `snapshot_before_update.sh`
> by absolute path. Update its `Exec=` line if the script ever moves.

## Source of truth

`/mnt/Lucy/SWARM_AI_FEATURES.md`

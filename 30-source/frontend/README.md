# Swarm OS v5 — Honeycomb UI

## Overview
Flutter desktop frontend for Swarm OS agent management. Features a **honeycomb/wasp-nest** hex grid layout for agent cards with drag-and-drop rearrangement and floating resizable windows.

## Features
- 🐝 **Honeycomb Grid** — Agents displayed as hexagonal cards in a wasp-nest pattern
- 🔀 **Drag & Snap** — Drag cards to rearrange, auto-snaps to hex grid
- 📐 **Resizable Windows** — Float windows with 2-corner resize (bottom-left, bottom-right)
- 🎯 **Z-Order Management** — Click to focus, windows stack properly
- 📜 **Vertical Scroll** — Grid scrolls vertically for unlimited agents
- 🎨 **Dark Theme** — Deep dark UI with accent glow effects

## Architecture
```
lib/
├── core/           # Hex math, layout engine, theme
├── models/         # Data models (agents, windows, positions)
├── widgets/        # Reusable UI components (hex cards, grid, windows)
├── features/       # Feature screens (dashboard, agent details)
├── main.dart       # Entry point
└── app.dart        # App shell with window overlay
```

## Run
```bash
cd frontend
flutter pub get
flutter run -d linux   # or: -d macos / -d windows / -d chrome
```

## Before Deploying to the Installed System

Always snapshot first so you can roll back if the Flutter update breaks something:

```bash
# Option A — desktop shortcut (double-click)
# /home/i30ltz/Desktop/swarm-snapshot.desktop
# Right-click → Allow Launching if it opens as text on first use.

# Option B — terminal
sudo /mnt/Lucy/70-scripts/snapshot_before_update.sh pre-flutter-update
```

Then deploy the built bundle:

```bash
sudo cp -a /mnt/Lucy/30-source/frontend/build/linux/x64/release/bundle/. \
     /mnt/swarm/@/opt/swarm_os/swarm_flutter/
```

Rollback: reboot → GRUB menu → pick a **Snapshot** entry.

> **Keep desktop script current:** if `snapshot_before_update.sh` changes,
> the `.desktop` file at `/home/i30ltz/Desktop/swarm-snapshot.desktop` just
> calls that script by path — no edit needed. Only update the `.desktop` if
> you move the script.

## Controls
- **Click** card → Select agent
- **Double-click** card → Open detail window
- **Drag** card → Rearrange in honeycomb
- **Drag** window title bar → Move window
- **Drag** bottom corners → Resize window
- **Click** minimized tab → Restore window
```
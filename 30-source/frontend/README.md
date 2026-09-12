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

## Controls
- **Click** card → Select agent
- **Double-click** card → Open detail window
- **Drag** card → Rearrange in honeycomb
- **Drag** window title bar → Move window
- **Drag** bottom corners → Resize window
- **Click** minimized tab → Restore window
```
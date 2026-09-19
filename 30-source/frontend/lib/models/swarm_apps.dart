// ═══════════════════════════════════════════════════════════════
// Swarm OS — App Registry
//
// Single source of truth for every launchable app/tool/agent tile
// shown anywhere in the shell (hex desktop, left app drawer, hub
// grid). Previously these three surfaces each hardcoded their own
// duplicate app list, which is why icons drifted out of sync and
// went "missing" from one surface while still existing in another.
//
// Add a new tool/agent HERE ONCE — tag it with the categories that
// should surface it, and every consuming UI picks it up automatically.
// Set `mock: true` for placeholder tools that aren't wired up yet;
// consuming UIs may badge these as "SOON" instead of hiding them.
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import '../services/system_launcher.dart';

enum SwarmAppCategory { origin, system, gamingMedia, droid, forge }

class SwarmApp {
  final String id;
  final String name;
  final String description;
  final IconData icon;
  final Color color;
  // If set, tapping this tile launches a native process via SystemLauncher.
  final String? execCommand;
  // If set, tapping this tile navigates to this go_router path.
  final String? routePath;
  final Set<SwarmAppCategory> categories;
  final bool isFavorite;
  // Placeholder tool/agent idea not wired up to a real command/route yet.
  final bool mock;
  // Optional real artwork (asset path) shown clipped into the hex tile
  // behind its icon, instead of just a flat fill color. Added 2026-09-19 —
  // most tiles don't have one yet; those render exactly as before.
  final String? previewImage;

  const SwarmApp({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    required this.categories,
    this.description = '',
    this.execCommand,
    this.routePath,
    this.isFavorite = false,
    this.mock = false,
    this.previewImage,
  });
}

class SwarmAppRegistry {
  SwarmAppRegistry._();

  static const List<SwarmApp> all = [
    // ───────────── ORIGIN ─────────────
    SwarmApp(id: 'lucille', name: 'Lucille', icon: Icons.auto_awesome,
      color: Color(0xFFCE93D8), categories: {SwarmAppCategory.origin},
      routePath: '/lucille', previewImage: 'assets/wallpapers/lucille_swarm_core.jpg'),
    SwarmApp(id: 'forge', name: 'Forge', icon: Icons.construction,
      color: Color(0xFF9575CD), categories: {SwarmAppCategory.origin},
      routePath: '/forge', previewImage: 'assets/wallpapers/forge_ide_core.jpg'),
    SwarmApp(id: 'reference', name: 'Commands', icon: Icons.menu_book,
      color: Color(0xFF8EC4FF), categories: {SwarmAppCategory.origin},
      description: 'First-boot setup and copy-paste command reference',
      routePath: '/reference', isFavorite: true),
    SwarmApp(id: 'ide', name: 'Coder', icon: Icons.code,
      color: Color(0xFF64B5F6), categories: {SwarmAppCategory.origin},
      routePath: '/ide'),
    SwarmApp(id: 'claude_desktop', name: 'Claude', icon: Icons.psychology,
      color: Color(0xFFFF8A65), categories: {SwarmAppCategory.origin},
      execCommand: SystemLauncher.claudeDesktopCmd),
    SwarmApp(id: 'claude_code', name: 'CC', icon: Icons.terminal,
      color: Color(0xFF81C784), categories: {SwarmAppCategory.origin},
      execCommand: SystemLauncher.claudeCodeCmd),
    SwarmApp(id: 'memory', name: 'Memory', icon: Icons.psychology_alt,
      color: Color(0xFF4DB6AC), categories: {SwarmAppCategory.origin},
      routePath: '/memory'),
    SwarmApp(id: 'agents', name: 'AI Squad', icon: Icons.group,
      color: Color(0xFFBA68C8), categories: {SwarmAppCategory.origin},
      routePath: '/agents'),
    SwarmApp(id: 'vital', name: 'Vital', icon: Icons.monitor_heart,
      color: Color(0xFFEF9A9A), categories: {SwarmAppCategory.origin},
      routePath: '/vital'),

    // ───────────── SYSTEM ─────────────
    SwarmApp(id: 'terminal', name: 'Terminal', icon: Icons.terminal,
      color: Color(0xFF00D4FF), categories: {SwarmAppCategory.origin, SwarmAppCategory.system},
      description: 'High-performance GPU-accelerated shell',
      execCommand: SystemLauncher.terminalCmd, isFavorite: true),
    SwarmApp(id: 'grub_terminal', name: 'GRUB', icon: Icons.computer,
      color: Color(0xFFDA77F2), categories: {SwarmAppCategory.origin, SwarmAppCategory.system},
      description: 'GUI-first graphical terminal — toolbar, right-click, clickable links',
      routePath: '/grub', isFavorite: true),
    SwarmApp(id: 'file_explorer', name: 'Files', icon: Icons.folder_open,
      color: Color(0xFFF59E0B), categories: {SwarmAppCategory.origin, SwarmAppCategory.system},
      description: 'Drag-drop file manager — image viewer, Kate editor, video player',
      routePath: '/explorer', isFavorite: true),
    SwarmApp(id: 'browser', name: 'Browser', icon: Icons.public,
      color: Color(0xFF4FC3F7), categories: {SwarmAppCategory.origin, SwarmAppCategory.system},
      execCommand: SystemLauncher.browserCmd),
    SwarmApp(id: 'files', name: 'Files', icon: Icons.folder,
      color: Color(0xFFA1887F), categories: {SwarmAppCategory.system},
      description: 'Browse local drives, NVMe & partitions',
      execCommand: SystemLauncher.fileManagerCmd, isFavorite: true),
    SwarmApp(id: 'antigravity', name: 'Antigravity', icon: Icons.rocket_launch,
      color: Color(0xFFFFB74D), categories: {SwarmAppCategory.system},
      execCommand: SystemLauncher.antigravityIdeCmd),
    SwarmApp(id: 'sysmon', name: 'Monitor', icon: Icons.bar_chart,
      color: Color(0xFFFF7043), categories: {SwarmAppCategory.system},
      description: 'CPU, RAM, GPU & thermals monitor',
      execCommand: SystemLauncher.monitorCmd),
    SwarmApp(id: 'installer', name: 'Install', icon: Icons.install_desktop,
      color: Color(0xFFFFD54F), categories: {SwarmAppCategory.origin, SwarmAppCategory.system},
      description: 'Install SWARM OS to disk — graphical, no terminal',
      routePath: '/install'),
    SwarmApp(id: 'sysopt', name: 'SysOpt', icon: Icons.bolt,
      color: Color(0xFF4DD0E1), categories: {SwarmAppCategory.system},
      routePath: '/sysopt'),
    SwarmApp(id: 'mirror', name: 'Mirror', icon: Icons.screen_share,
      color: Color(0xFF80CBC4), categories: {SwarmAppCategory.system},
      routePath: '/mirror'),
    SwarmApp(id: 'settings', name: 'Settings', icon: Icons.settings,
      color: Color(0xFF78909C), categories: {SwarmAppCategory.system},
      routePath: '/settings'),
    SwarmApp(id: 'yay', name: 'Yay Package Center', icon: Icons.inventory_2,
      color: Color(0xFF78909C), categories: {SwarmAppCategory.system},
      description: 'Search & install Arch / AUR software',
      execCommand: 'yay'),

    // ───────────── GAMING & MEDIA ─────────────
    SwarmApp(id: 'gaming', name: 'Gamer', icon: Icons.sports_esports,
      // Was NVIDIA green — matched swarm-slint's Gaming tab before its
      // 2026-09-19 restyle to electric blue + black; matched here too now.
      color: Color(0xFF2979FF),
      categories: {SwarmAppCategory.gamingMedia, SwarmAppCategory.origin},
      description: 'GFN + Steam dashboard — AI game picks by Lucille',
      execCommand: SystemLauncher.gamingDashboardCmd,
      previewImage: 'assets/wallpapers/this_is_now_gaming.jpg'),
    SwarmApp(id: 'cinema', name: 'Cinema', icon: Icons.movie_filter,
      color: Color(0xFFF48FB1),
      categories: {SwarmAppCategory.gamingMedia, SwarmAppCategory.forge},
      description: 'Hardware-accelerated AI video player & production studio',
      routePath: '/cinema', isFavorite: true),
    SwarmApp(id: 'gitlens', name: 'GitLens', icon: Icons.hub,
      color: Color(0xFFFFD54F),
      categories: {SwarmAppCategory.gamingMedia, SwarmAppCategory.forge},
      description: 'Visual commit graph DAG, file history, blame & diff studio',
      routePath: '/gitlens', isFavorite: true),
    SwarmApp(id: 'diff', name: 'Diff', icon: Icons.difference,
      color: Color(0xFFDCE775), categories: {SwarmAppCategory.gamingMedia},
      routePath: '/diff'),
    SwarmApp(id: 'vms', name: 'VMs', icon: Icons.computer,
      color: Color(0xFF90A4AE), categories: {SwarmAppCategory.gamingMedia},
      routePath: '/vms'),
    SwarmApp(id: 'security', name: 'Security', icon: Icons.security,
      color: Color(0xFFEF5350), categories: {SwarmAppCategory.gamingMedia},
      routePath: '/security-audit'),
    SwarmApp(id: 'telemetry', name: 'Telemetry', icon: Icons.timeline,
      color: Color(0xFF7986CB), categories: {SwarmAppCategory.gamingMedia},
      routePath: '/telemetry'),
    SwarmApp(id: 'backend', name: 'Backend', icon: Icons.dns,
      color: Color(0xFF90A4AE), categories: {SwarmAppCategory.gamingMedia},
      routePath: '/backend'),

    // ───────────── DROID ─────────────
    SwarmApp(id: 'droid_companion', name: 'Droid Companion',
      icon: Icons.phone_android, color: Color(0xFF4ADE80),
      categories: {SwarmAppCategory.droid},
      description: 'Mobile telemetry and remote OS sync bridge',
      execCommand: 'swarm-droid-companion', isFavorite: true),
    SwarmApp(id: 'droid_apk_installer', name: 'APK Installer',
      icon: Icons.install_mobile, color: Color(0xFF4ADE80),
      categories: {SwarmAppCategory.droid},
      description: 'Sideload & manage Android packages',
      execCommand: 'adb install'),
    SwarmApp(id: 'droid_emulator', name: 'Waydroid Container',
      icon: Icons.smart_screen, color: Color(0xFF4ADE80),
      categories: {SwarmAppCategory.droid},
      description: 'Hardware-accelerated Android runtime',
      execCommand: 'waydroid session start', isFavorite: true),
    SwarmApp(id: 'droid_scrcpy', name: 'Screen Mirror (scrcpy)',
      icon: Icons.cast_connected, color: Color(0xFF4ADE80),
      categories: {SwarmAppCategory.droid},
      description: 'Ultra-low latency device mirroring',
      execCommand: 'scrcpy --stay-awake'),

    // ───────────── FORGE ─────────────
    SwarmApp(id: 'forge_docker', name: 'Docker Workbench',
      icon: Icons.view_in_ar, color: Color(0xFFFFA726),
      categories: {SwarmAppCategory.forge},
      description: 'Manage sandbox containers & images',
      execCommand: 'docker ps'),
    SwarmApp(id: 'forge_k3s', name: 'k3s Cluster Shell',
      icon: Icons.hub, color: Color(0xFFFFA726),
      categories: {SwarmAppCategory.forge},
      description: 'Lightweight Kubernetes cluster console',
      execCommand: 'kubectl get nodes'),
    SwarmApp(id: 'forge_build', name: 'Compiler & Toolchain',
      icon: Icons.build_circle, color: Color(0xFFFFA726),
      categories: {SwarmAppCategory.forge},
      description: 'Native C++20 / CMake build console',
      execCommand: 'cmake --version'),
    SwarmApp(id: 'forge_ide', name: 'Forge Code Studio',
      icon: Icons.code, color: Color(0xFFFFA726),
      categories: {SwarmAppCategory.forge},
      description: 'Antigravity developer IDE & agent suite',
      execCommand: 'code', isFavorite: true),

    // ───────────── MOCK IDEAS (not wired up — tap shows "coming soon") ─────────────
    SwarmApp(id: 'mock_taskmaster', name: 'Task Master', icon: Icons.checklist_rtl,
      color: Color(0xFF64DD17), categories: {SwarmAppCategory.origin},
      description: 'Agent that turns a goal into a tracked task list',
      mock: true),
    SwarmApp(id: 'mock_codesentry', name: 'Code Sentry', icon: Icons.shield_moon,
      color: Color(0xFFFF5252), categories: {SwarmAppCategory.system},
      description: 'Background agent that watches for regressions & flags them',
      mock: true),
    SwarmApp(id: 'mock_voicebridge', name: 'Voice Bridge', icon: Icons.record_voice_over,
      color: Color(0xFF40C4FF), categories: {SwarmAppCategory.origin},
      description: 'Push-to-talk voice HUD routed straight into Lucille',
      mock: true),
    SwarmApp(id: 'mock_swarmcast', name: 'SwarmCast', icon: Icons.podcasts,
      color: Color(0xFFB388FF), categories: {SwarmAppCategory.gamingMedia},
      description: 'Stream the desktop/gameplay straight to a companion device',
      mock: true),
  ];

  static List<SwarmApp> byCategory(SwarmAppCategory category) =>
      all.where((a) => a.categories.contains(category)).toList(growable: false);

  static SwarmApp? byId(String id) {
    for (final a in all) {
      if (a.id == id) return a;
    }
    return null;
  }
}

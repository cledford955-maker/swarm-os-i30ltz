import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/swarm_colors.dart';
import '../theme/swarm_text_styles.dart';
import '../services/system_launcher.dart';

class AppItem {
  final String id;
  final String name;
  final String description;
  final String category;
  final IconData icon;
  final String command;
  final Color accentColor;
  final bool isCore;

  const AppItem({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.icon,
    required this.command,
    required this.accentColor,
    this.isCore = false,
  });
}

class AppsPage extends ConsumerStatefulWidget {
  const AppsPage({super.key});

  @override
  ConsumerState<AppsPage> createState() => _AppsPageState();
}

class _AppsPageState extends ConsumerState<AppsPage> {
  String _selectedCategory = 'All';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _runningApps = {};
  List<AppItem> _discoveredApps = [];
  bool _scanning = false;

  final List<String> _categories = [
    'All',
    'AI & Dev',
    'Media & Studio',
    'System Tools',
    'Desktop & Kiosk',
  ];

  static const List<AppItem> _defaultApps = [
    AppItem(
      id: 'antigravity_ide',
      name: 'Antigravity IDE',
      description: 'Advanced Autonomous AI Coding Environment & Agentic Studio',
      category: 'AI & Dev',
      icon: Icons.code_rounded,
      command: 'antigravity || "/run/media/i30ltz/lucy-master/Antigravity-x64/antigravity" || code',
      accentColor: SwarmColors.accent,
      isCore: true,
    ),
    AppItem(
      id: 'android_studio',
      name: 'Android Studio',
      description: 'Official IDE for Android & Companion Mobile App Engineering',
      category: 'AI & Dev',
      icon: Icons.android_rounded,
      command: '/opt/android-studio/bin/studio.sh || android-studio || studio',
      accentColor: Color(0xFF3DDC84),
      isCore: true,
    ),
    AppItem(
      id: 'claude_desktop',
      name: 'Claude Desktop',
      description: 'Anthropic Claude Desktop AI Assistant & Workflow Agent',
      category: 'AI & Dev',
      icon: Icons.psychology_rounded,
      command: SystemLauncher.claudeDesktopCmd,
      accentColor: Color(0xFFD97706),
      isCore: true,
    ),
    AppItem(
      id: 'claude_code',
      name: 'Claude Code CLI',
      description: 'Terminal Agent for autonomous coding and shell refactoring',
      category: 'AI & Dev',
      icon: Icons.terminal_rounded,
      command: SystemLauncher.claudeCodeCmd,
      accentColor: Color(0xFFF59E0B),
      isCore: true,
    ),
    AppItem(
      id: 'lucille_core_daemon',
      name: 'Lucille Core Daemon',
      description: 'Native C++20 engine with epoll supervisor and vector memory',
      category: 'AI & Dev',
      icon: Icons.memory_rounded,
      command: 'alacritty -e /usr/bin/lucille-core || alacritty -e /run/media/i30ltz/lucy-master/Luccile-v+/lucille-core/build/lucille-core',
      accentColor: SwarmColors.accentCyan,
      isCore: true,
    ),
    AppItem(
      id: 'kdenlive',
      name: 'Kdenlive',
      description: 'Professional multi-track video editing and post-production studio',
      category: 'Media & Studio',
      icon: Icons.movie_creation_rounded,
      command: 'kdenlive',
      accentColor: Color(0xFF3B82F6),
    ),
    AppItem(
      id: 'haruna',
      name: 'Haruna Media Player',
      description: 'Modern hardware-accelerated video player with mpv backend',
      category: 'Media & Studio',
      icon: Icons.play_circle_filled_rounded,
      command: 'haruna',
      accentColor: Color(0xFFEC4899),
    ),
    AppItem(
      id: 'vlc',
      name: 'VLC Media Player',
      description: 'Universal media player and streaming server',
      category: 'Media & Studio',
      icon: Icons.videocam_rounded,
      command: 'vlc',
      accentColor: Color(0xFFF97316),
    ),
    AppItem(
      id: 'gamescope_session',
      name: 'Gamescope 1440p Session',
      description: 'Launch embedded Gamescope micro-compositor kiosk at 2560x1440@60Hz',
      category: 'Desktop & Kiosk',
      icon: Icons.sports_esports_rounded,
      command: '/usr/bin/swarm-session',
      accentColor: Color(0xFF10B981),
      isCore: true,
    ),
    AppItem(
      id: 'system_btop',
      name: 'Btop Resource Monitor',
      description: 'Real-time CPU/GPU/Disk/Network terminal performance dashboard',
      category: 'System Tools',
      icon: Icons.speed_rounded,
      command: 'alacritty -e btop || xterm -e btop',
      accentColor: Color(0xFF8B5CF6),
    ),
    AppItem(
      id: 'alacritty_terminal',
      name: 'Alacritty GPU Terminal',
      description: 'Fast, GPU-accelerated Wayland terminal emulator',
      category: 'System Tools',
      icon: Icons.laptop_windows_rounded,
      command: 'alacritty || foot || xterm',
      accentColor: Color(0xFF06B6D4),
    ),
    AppItem(
      id: 'file_manager',
      name: 'System File Manager',
      description: 'Explore workspace partitions, Btrfs subvolumes, and external drives',
      category: 'System Tools',
      icon: Icons.folder_copy_rounded,
      command: SystemLauncher.fileManagerCmd,
      accentColor: Color(0xFFEAB308),
    ),
    AppItem(
      id: 'web_browser',
      name: 'Web Browser',
      description: 'Fast web browsing with hardware WebGL acceleration',
      category: 'System Tools',
      icon: Icons.public_rounded,
      command: SystemLauncher.browserCmd,
      accentColor: Color(0xFF0EA5E9),
    ),
    AppItem(
      id: 'tailscale_manager',
      name: 'Tailscale Mesh Node',
      description: 'Manage WireGuard secure mesh connections and companion bridging',
      category: 'System Tools',
      icon: Icons.hub_rounded,
      command: 'alacritty -e tailscale status || tailscale-systray',
      accentColor: Color(0xFF6366F1),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _scanSystemApps();
  }

  Future<void> _scanSystemApps() async {
    setState(() => _scanning = true);
    final List<AppItem> discovered = List.from(_defaultApps);

    try {
      final appDir = Directory('/usr/share/applications');
      if (await appDir.exists()) {
        final entries = await appDir.list().toList();
        for (final entity in entries.take(30)) {
          if (entity is File && entity.path.endsWith('.desktop')) {
            final lines = await entity.readAsLines().catchError((_) => <String>[]);
            String name = '';
            String exec = '';
            String comment = '';
            bool noDisplay = false;

            for (final line in lines) {
              if (line.startsWith('Name=') && name.isEmpty) {
                name = line.substring(5).trim();
              } else if (line.startsWith('Exec=') && exec.isEmpty) {
                exec = line.substring(5).trim().split('%')[0].trim();
              } else if (line.startsWith('Comment=') && comment.isEmpty) {
                comment = line.substring(8).trim();
              } else if (line.startsWith('NoDisplay=true')) {
                noDisplay = true;
              }
            }

            if (!noDisplay && name.isNotEmpty && exec.isNotEmpty && !discovered.any((a) => a.name.toLowerCase() == name.toLowerCase())) {
              discovered.add(
                AppItem(
                  id: 'discovered_${name.toLowerCase().replaceAll(' ', '_')}',
                  name: name,
                  description: comment.isNotEmpty ? comment : 'System application installed in /usr/bin',
                  category: 'System Tools',
                  icon: Icons.apps_rounded,
                  command: exec,
                  accentColor: SwarmColors.accentMuted,
                ),
              );
            }
          }
        }
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        _discoveredApps = discovered;
        _scanning = false;
      });
    }
  }

  Future<void> _launchApp(AppItem app) async {
    setState(() {
      _runningApps.add(app.id);
    });

    final success = await SystemLauncher.launch(context, app.command, displayName: app.name);
    
    if (mounted) {
      Future.delayed(const Duration(seconds: 4), () {
        if (mounted) {
          setState(() {
            _runningApps.remove(app.id);
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _discoveredApps.where((app) {
      final matchesCategory = _selectedCategory == 'All' || app.category == _selectedCategory;
      final matchesSearch = _searchQuery.isEmpty ||
          app.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          app.description.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesCategory && matchesSearch;
    }).toList();

    return Scaffold(
      backgroundColor: SwarmColors.bgBase,
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: SwarmColors.accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: SwarmColors.accent.withValues(alpha: 0.3)),
                  ),
                  child: const Icon(Icons.grid_view_rounded, color: SwarmColors.accent, size: 28),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SWARM APPLICATION LAUNCHER',
                      style: SwarmTextStyles.headlineMedium.copyWith(
                        color: SwarmColors.textPrimary,
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Native Linux application executor & development runtime suite',
                      style: SwarmTextStyles.bodyMedium.copyWith(color: SwarmColors.textMuted),
                    ),
                  ],
                ),
                const Spacer(),
                IconButton(
                  onPressed: _scanSystemApps,
                  tooltip: 'Rescan /usr/share/applications',
                  icon: _scanning
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: SwarmColors.accent),
                        )
                      : const Icon(Icons.refresh_rounded, color: SwarmColors.textMuted),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Search Bar & Filter Chips
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Container(
                    decoration: BoxDecoration(
                      color: SwarmColors.bgElevated,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: SwarmColors.borderSubtle),
                    ),
                    child: TextField(
                      controller: _searchController,
                      style: const TextStyle(color: SwarmColors.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'Search apps, tools, and runtimes...',
                        hintStyle: const TextStyle(color: SwarmColors.textMuted, fontSize: 13),
                        prefixIcon: const Icon(Icons.search_rounded, color: SwarmColors.textMuted, size: 20),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, color: SwarmColors.textMuted, size: 16),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                      onChanged: (val) => setState(() => _searchQuery = val),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 5,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _categories.map((cat) {
                        final isSelected = _selectedCategory == cat;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: ChoiceChip(
                            label: Text(cat),
                            selected: isSelected,
                            onSelected: (_) => setState(() => _selectedCategory = cat),
                            selectedColor: SwarmColors.accent.withValues(alpha: 0.2),
                            backgroundColor: SwarmColors.bgElevated,
                            labelStyle: TextStyle(
                              color: isSelected ? SwarmColors.accent : SwarmColors.textMuted,
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                            side: BorderSide(
                              color: isSelected ? SwarmColors.accent : SwarmColors.borderSubtle,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // App Grid
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.search_off_rounded, color: SwarmColors.textMuted, size: 48),
                          const SizedBox(height: 12),
                          Text(
                            'No applications matched "$_searchQuery"',
                            style: const TextStyle(color: SwarmColors.textMuted),
                          ),
                        ],
                      ),
                    )
                  : GridView.builder(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 2.3,
                      ),
                      itemCount: filtered.length,
                      itemBuilder: (context, idx) {
                        final app = filtered[idx];
                        final isRunning = _runningApps.contains(app.id);

                        return Container(
                          decoration: BoxDecoration(
                            color: SwarmColors.bgElevated,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: app.isCore
                                  ? app.accentColor.withValues(alpha: 0.4)
                                  : SwarmColors.borderSubtle,
                              width: app.isCore ? 1.5 : 1,
                            ),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: () => _launchApp(app),
                              hoverColor: app.accentColor.withValues(alpha: 0.05),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 48,
                                      height: 48,
                                      decoration: BoxDecoration(
                                        color: app.accentColor.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: app.accentColor.withValues(alpha: 0.3)),
                                      ),
                                      child: Icon(app.icon, color: app.accentColor, size: 24),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  app.name,
                                                  style: const TextStyle(
                                                    color: SwarmColors.textPrimary,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 14,
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              if (app.isCore)
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: app.accentColor.withValues(alpha: 0.2),
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                  child: Text(
                                                    'CORE',
                                                    style: TextStyle(
                                                      color: app.accentColor,
                                                      fontSize: 9,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            app.description,
                                            style: const TextStyle(
                                              color: SwarmColors.textMuted,
                                              fontSize: 11,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: isRunning
                                            ? SwarmColors.statusHealthy.withValues(alpha: 0.2)
                                            : SwarmColors.bgBase,
                                      ),
                                      child: isRunning
                                          ? const Padding(
                                              padding: EdgeInsets.all(10.0),
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: SwarmColors.statusHealthy,
                                              ),
                                            )
                                          : const Icon(
                                              Icons.play_arrow_rounded,
                                              color: SwarmColors.textMuted,
                                              size: 20,
                                            ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

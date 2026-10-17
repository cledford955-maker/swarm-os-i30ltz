import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../hub/hub_page.dart';
import '../models/agent.dart';
import '../theme/swarm_colors.dart';
import '../services/system_launcher.dart';
import '../models/swarm_apps.dart';
import '../widgets/agent_avatar.dart';
import 'companion_bridge_dialog.dart';
import 'window_manager.dart';

// ── "THIS is NOW" palette ──────────────────────────────────────────
const _eBlue = Color(0xFF0088FF); // electric blue primary
const _drawerBg = Color(0xFF030810); // near-black with blue tint

class AppItem {
  final String id;
  final String name;
  final String description;
  final String command;
  final IconData icon;
  final Color color;
  final SwarmAppCategory category;
  bool isFavorite;

  AppItem({
    required this.id,
    required this.name,
    required this.description,
    required this.command,
    required this.icon,
    required this.color,
    required this.category,
    this.isFavorite = false,
  });

  // Maps the most-specific category for an app that may carry several tags.
  factory AppItem.fromRegistry(SwarmApp app) {
    final category = app.categories.contains(SwarmAppCategory.droid)
        ? SwarmAppCategory.droid
        : app.categories.contains(SwarmAppCategory.forge)
            ? SwarmAppCategory.forge
            : app.categories.contains(SwarmAppCategory.gamingMedia)
                ? SwarmAppCategory.gamingMedia
                : app.categories.contains(SwarmAppCategory.origin)
                    ? SwarmAppCategory.origin
                    : SwarmAppCategory.system;
    return AppItem(
      id: app.id,
      name: app.name,
      description: app.description,
      command: app.execCommand ?? app.routePath ?? '',
      icon: app.icon,
      color: app.color,
      category: category,
      isFavorite: app.isFavorite,
    );
  }
}

class LeftAppDrawer extends ConsumerStatefulWidget {
  final bool isOpen;
  final VoidCallback onClose;

  const LeftAppDrawer({
    super.key,
    required this.isOpen,
    required this.onClose,
  });

  @override
  ConsumerState<LeftAppDrawer> createState() => _LeftAppDrawerState();
}

class _LeftAppDrawerState extends ConsumerState<LeftAppDrawer> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // All categories — deduplicated by id so multi-tagged apps (browser, cinema…)
  // only appear once. Order: ORIGIN first (highest priority), then GAMING,
  // then SYS, DROID, FORGE.
  late final List<AppItem> _allApps = () {
    final seen = <String>{};
    return [
      ...SwarmAppRegistry.byCategory(SwarmAppCategory.origin),
      ...SwarmAppRegistry.byCategory(SwarmAppCategory.gamingMedia),
      ...SwarmAppRegistry.byCategory(SwarmAppCategory.system),
      ...SwarmAppRegistry.byCategory(SwarmAppCategory.droid),
      ...SwarmAppRegistry.byCategory(SwarmAppCategory.forge),
    ].where((a) => seen.add(a.id)).map(AppItem.fromRegistry).toList();
  }();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _launchApp(AppItem app) async {
    if (app.id == 'dr_boltz') {
      final agent = getAgent('dr_boltz');
      if (agent == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
                  Text('Dr. Boltz is not available in the agent registry.')),
        );
        return;
      }
      ref.read(windowProvider.notifier).openWindow(
            AppWindow(
              id: 'agent_${agent.id}',
              title: '${agent.name} · ${agent.role}',
              position: const Offset(100, 50),
              size: const Size(700, 500),
              content: AgentWindowContent(agent: agent),
            ),
          );
      Navigator.of(context).maybePop();
      widget.onClose();
      return;
    }
    // The package manager is already integrated into App Store, which can
    // search, install, and report results without hiding yay's CLI output.
    if (app.id == 'yay') {
      Navigator.of(context).maybePop();
      widget.onClose();
      if (mounted) context.go('/appstore');
      return;
    }
    if (app.id == 'droid_apk_installer') {
      await _promptAndInstallApk();
      return;
    }
    const terminalCommands = <String, String>{
      'droid_emulator': 'waydroid session start',
      'forge_docker': 'docker ps',
      'forge_k3s': 'kubectl get nodes',
      'forge_build': 'cmake --version',
    };
    final terminalCommand = terminalCommands[app.id];
    if (terminalCommand != null) {
      await SystemLauncher.launchTerminalCommand(
        context,
        terminalCommand,
        displayName: app.name,
      );
      return;
    }
    if (SwarmAppRegistry.byId(app.id)?.mock == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: _drawerBg,
          content: Text(
            '🔜 ${app.name} — coming soon',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }
    if (app.id == 'droid_companion') {
      Navigator.of(context).maybePop();
      CompanionResourcePoolDialog.show(context);
      return;
    }
    if (app.command.startsWith('/')) {
      Navigator.of(context).maybePop();
      widget.onClose();
      if (mounted) {
        context.go(app.command);
      }
      return;
    }
    await SystemLauncher.launch(context, app.command, displayName: app.name);
  }

  Future<void> _promptAndInstallApk() async {
    final pathController = TextEditingController();
    try {
      final path = await showDialog<String>(
        context: context,
        builder: (dialogContext) {
          var error = '';
          return StatefulBuilder(
            builder: (context, setDialogState) {
              Future<void> submit() async {
                final candidate = pathController.text.trim();
                if (!candidate.startsWith('/')) {
                  setDialogState(
                      () => error = 'Use the full absolute path to the APK.');
                  return;
                }
                if (!candidate.toLowerCase().endsWith('.apk')) {
                  setDialogState(
                      () => error = 'Choose a file whose name ends in .apk.');
                  return;
                }
                if (!await File(candidate).exists()) {
                  setDialogState(() =>
                      error = 'That file does not exist or is not readable.');
                  return;
                }
                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext, candidate);
                }
              }

              return AlertDialog(
                title: const Text('Install APK'),
                content: SizedBox(
                  width: 440,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                          'Enter the full path to an APK on this device.'),
                      const SizedBox(height: 12),
                      TextField(
                        controller: pathController,
                        autofocus: true,
                        decoration: const InputDecoration(
                          labelText: 'APK file path',
                          hintText: '/home/swarm/Downloads/app.apk',
                          border: OutlineInputBorder(),
                        ),
                        onSubmitted: (_) => submit(),
                      ),
                      if (error.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(error,
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.error)),
                      ],
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: submit,
                    child: const Text('Install'),
                  ),
                ],
              );
            },
          );
        },
      );
      if (path == null || !mounted) return;
      await SystemLauncher.launchTerminalCommand(
        context,
        'adb install ${SystemLauncher.shellQuote(path)}',
        displayName: 'APK Installer',
      );
    } finally {
      pathController.dispose();
    }
  }

  List<AppItem> get _filteredApps {
    if (_searchQuery.trim().isEmpty) return _allApps;
    final q = _searchQuery.toLowerCase();
    return _allApps.where((app) {
      return app.name.toLowerCase().contains(q) ||
          app.description.toLowerCase().contains(q) ||
          app.command.toLowerCase().contains(q);
    }).toList();
  }

  List<AppItem> get _favoriteApps =>
      _allApps.where((app) => app.isFavorite).toList();

  Widget _buildCategoryBadge(SwarmAppCategory category) {
    switch (category) {
      case SwarmAppCategory.origin:
        return _badge(Icons.grid_view_rounded, 'ORIGIN', _eBlue);
      case SwarmAppCategory.gamingMedia:
        return _badge(Icons.sports_esports, 'GAMING', const Color(0xFF76B900));
      case SwarmAppCategory.droid:
        return _badge(Icons.android, 'DROID', SwarmColors.statusOnline);
      case SwarmAppCategory.forge:
        return _badge(Icons.whatshot, 'FORGE', SwarmColors.statusBusy);
      case SwarmAppCategory.system:
        return _badge(Icons.memory, 'SYS', SwarmColors.agentCyan);
    }
  }

  Widget _badge(IconData icon, String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                  color: color),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      left: widget.isOpen ? 0 : -380,
      top: 48,
      bottom: 0,
      width: 380,
      child: Container(
        decoration: BoxDecoration(
          color: _drawerBg,
          image: const DecorationImage(
            image: AssetImage('assets/wallpapers/swarm_wasp_nest_v5.jpg'),
            fit: BoxFit.cover,
            opacity: 0.055,
          ),
          border: Border(
            right:
                BorderSide(color: _eBlue.withValues(alpha: 0.45), width: 1.5),
          ),
          boxShadow: [
            BoxShadow(
              color: _eBlue.withValues(alpha: 0.18),
              blurRadius: 20,
              offset: const Offset(4, 0),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.75),
              blurRadius: 28,
              offset: const Offset(10, 0),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header: THIS is NOW ──────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(16, 13, 8, 13),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                border: Border(
                  bottom: BorderSide(color: _eBlue.withValues(alpha: 0.4)),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: _eBlue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _eBlue.withValues(alpha: 0.5)),
                    ),
                    child: const Icon(Icons.grid_view_rounded,
                        color: _eBlue, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'THIS is NOW',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2.2,
                          color: _eBlue,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: _eBlue.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(3),
                          border:
                              Border.all(color: _eBlue.withValues(alpha: 0.4)),
                        ),
                        child: const Text(
                          'v1',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.5,
                            color: _eBlue,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.close,
                        color: Colors.white.withValues(alpha: 0.3), size: 18),
                    onPressed: widget.onClose,
                    tooltip: 'Close',
                  ),
                ],
              ),
            ),

            // ── Search ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                onChanged: (val) => setState(() => _searchQuery = val),
                decoration: InputDecoration(
                  hintText: 'Search apps, Gaming, Droid, Forge…',
                  hintStyle: TextStyle(
                      color: Colors.white.withValues(alpha: 0.3), fontSize: 13),
                  prefixIcon: Icon(Icons.search,
                      color: Colors.white.withValues(alpha: 0.3), size: 18),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear,
                              color: Colors.white.withValues(alpha: 0.3),
                              size: 16),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.04),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide:
                        BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: _eBlue),
                  ),
                ),
              ),
            ),

            // ── App List ─────────────────────────────────────────
            Expanded(
              child: ListView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                children: [
                  // Favorites row
                  if (_searchQuery.isEmpty && _favoriteApps.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8, top: 4),
                      child: Row(
                        children: [
                          Icon(Icons.star,
                              color: Colors.amber.withValues(alpha: 0.8),
                              size: 15),
                          const SizedBox(width: 6),
                          Text(
                            'FAVORITES',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                              color: Colors.white.withValues(alpha: 0.4),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      height: 84,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _favoriteApps.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 10),
                        itemBuilder: (context, idx) {
                          final app = _favoriteApps[idx];
                          return InkWell(
                            onTap: () => _launchApp(app),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              width: 80,
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.04),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                    color: app.color.withValues(alpha: 0.3)),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  AppIconOrb(
                                    icon: app.icon,
                                    color: app.color,
                                    size: 34,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    app.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    Divider(
                        color: Colors.white.withValues(alpha: 0.07), height: 1),
                    const SizedBox(height: 12),
                  ],

                  // Section heading
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      _searchQuery.isEmpty
                          ? 'ALL APPLICATIONS'
                          : 'RESULTS (${_filteredApps.length})',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                        color: Colors.white.withValues(alpha: 0.35),
                      ),
                    ),
                  ),

                  if (_filteredApps.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'No matching applications found',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.3),
                            fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                    ),

                  // App rows
                  ..._filteredApps.map((app) => Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.03),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.07)),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: ListTile(
                            dense: true,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 4),
                            leading: Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: app.color.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: app.color.withValues(alpha: 0.35)),
                              ),
                              child: Center(
                                child: AppIconOrb(
                                  icon: app.icon,
                                  color: app.color,
                                  size: 30,
                                ),
                              ),
                            ),
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    app.name,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                if (SwarmAppRegistry.byId(app.id)?.mock ==
                                    true) ...[
                                  Container(
                                    margin: const EdgeInsets.only(right: 6),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color:
                                          Colors.white.withValues(alpha: 0.06),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                          color: Colors.white
                                              .withValues(alpha: 0.2)),
                                    ),
                                    child: Text(
                                      'SOON',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.8,
                                        color:
                                            Colors.white.withValues(alpha: 0.5),
                                      ),
                                    ),
                                  ),
                                ],
                                _buildCategoryBadge(app.category),
                              ],
                            ),
                            subtitle: Text(
                              app.description,
                              style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.35),
                                  fontSize: 11),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(
                                    app.isFavorite
                                        ? Icons.star
                                        : Icons.star_border,
                                    color: app.isFavorite
                                        ? Colors.amber
                                        : Colors.white.withValues(alpha: 0.25),
                                    size: 18,
                                  ),
                                  onPressed: () {
                                    setState(
                                        () => app.isFavorite = !app.isFavorite);
                                  },
                                  tooltip: 'Toggle Favorite',
                                ),
                                IconButton(
                                  icon: const Icon(Icons.play_arrow,
                                      color: _eBlue, size: 20),
                                  onPressed: () => _launchApp(app),
                                  tooltip: 'Launch',
                                ),
                              ],
                            ),
                            onTap: () => _launchApp(app),
                          ),
                        ),
                      )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

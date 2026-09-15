import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/swarm_colors.dart';
import '../services/system_launcher.dart';
import '../models/swarm_apps.dart';
import 'companion_bridge_dialog.dart';

class AppItem {
  final String id;
  final String name;
  final String description;
  final String command;
  final IconData icon;
  final SwarmAppCategory category;
  bool isFavorite;

  AppItem({
    required this.id,
    required this.name,
    required this.description,
    required this.command,
    required this.icon,
    required this.category,
    this.isFavorite = false,
  });

  // Picks the drawer-relevant category (droid > forge > system) for an app
  // that may be tagged with more than one SwarmAppRegistry category.
  factory AppItem.fromRegistry(SwarmApp app) {
    final category = app.categories.contains(SwarmAppCategory.droid)
        ? SwarmAppCategory.droid
        : app.categories.contains(SwarmAppCategory.forge)
            ? SwarmAppCategory.forge
            : SwarmAppCategory.system;
    return AppItem(
      id: app.id,
      name: app.name,
      description: app.description,
      command: app.execCommand ?? app.routePath ?? '',
      icon: app.icon,
      category: category,
      isFavorite: app.isFavorite,
    );
  }
}

class LeftAppDrawer extends StatefulWidget {
  final bool isOpen;
  final VoidCallback onClose;

  const LeftAppDrawer({
    super.key,
    required this.isOpen,
    required this.onClose,
  });

  @override
  State<LeftAppDrawer> createState() => _LeftAppDrawerState();
}

class _LeftAppDrawerState extends State<LeftAppDrawer> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Drawn from SwarmAppRegistry (shared with the hex desktop and hub grid)
  // instead of a separate hardcoded list — previously this file, the hex
  // desktop, and the hub grid each kept their own drifting copy of the same
  // apps (Terminal, Claude, Files, Cinema, GitLens, ...).
  late final List<AppItem> _allApps = [
    ...SwarmAppRegistry.byCategory(SwarmAppCategory.droid),
    ...SwarmAppRegistry.byCategory(SwarmAppCategory.forge),
    ...SwarmAppRegistry.byCategory(SwarmAppCategory.system),
  ].map(AppItem.fromRegistry).toList();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _launchApp(AppItem app) async {
    if (SwarmAppRegistry.byId(app.id)?.mock == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: SwarmColors.bgElevated,
          content: Text(
            '🔧 ${app.name} — idea, not wired up yet',
            style: const TextStyle(color: SwarmColors.textPrimary, fontSize: 12),
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

  List<AppItem> get _filteredApps {
    if (_searchQuery.trim().isEmpty) return _allApps;
    final q = _searchQuery.toLowerCase();
    return _allApps.where((app) {
      return app.name.toLowerCase().contains(q) ||
          app.description.toLowerCase().contains(q) ||
          app.command.toLowerCase().contains(q);
    }).toList();
  }

  List<AppItem> get _favoriteApps {
    return _allApps.where((app) => app.isFavorite).toList();
  }

  Widget _buildCategoryBadge(SwarmAppCategory category) {
    switch (category) {
      case SwarmAppCategory.droid:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: SwarmColors.statusOnline.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: SwarmColors.statusOnline.withValues(alpha: 0.6)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.android, size: 12, color: SwarmColors.statusOnline),
              SizedBox(width: 4),
              Text(
                'DROID',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                  color: SwarmColors.statusOnline,
                ),
              ),
            ],
          ),
        );
      case SwarmAppCategory.forge:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: SwarmColors.statusBusy.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: SwarmColors.statusBusy.withValues(alpha: 0.6)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.whatshot, size: 12, color: SwarmColors.statusBusy),
              SizedBox(width: 4),
              Text(
                'FORGE',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                  color: SwarmColors.statusBusy,
                ),
              ),
            ],
          ),
        );
      case SwarmAppCategory.system:
      case SwarmAppCategory.origin:
      case SwarmAppCategory.gamingMedia:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: SwarmColors.agentCyan.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: SwarmColors.agentCyan.withValues(alpha: 0.6)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.memory, size: 12, color: SwarmColors.agentCyan),
              SizedBox(width: 4),
              Text(
                'SYS',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                  color: SwarmColors.agentCyan,
                ),
              ),
            ],
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      left: widget.isOpen ? 0 : -380,
      top: 48, // Below top bar
      bottom: 0,
      width: 380,
      child: Container(
        decoration: BoxDecoration(
          color: SwarmColors.bgSurface.withValues(alpha: 0.94),
          border: const Border(
            right: BorderSide(color: SwarmColors.border, width: 1.5),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.6),
              blurRadius: 24,
              offset: const Offset(8, 0),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drawer Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: SwarmColors.border)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: SwarmColors.accentSurface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: SwarmColors.accent.withValues(alpha: 0.4)),
                    ),
                    child: const Icon(Icons.apps, color: SwarmColors.accent, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'SWARM APPS',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                      color: SwarmColors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: SwarmColors.textMuted, size: 18),
                    onPressed: widget.onClose,
                    tooltip: 'Close App Drawer',
                  ),
                ],
              ),
            ),

            // Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: SwarmColors.textPrimary, fontSize: 13),
                onChanged: (val) => setState(() => _searchQuery = val),
                decoration: InputDecoration(
                  hintText: 'Search apps, Droid, Forge...',
                  hintStyle: const TextStyle(color: SwarmColors.textMuted, fontSize: 13),
                  prefixIcon: const Icon(Icons.search, color: SwarmColors.textMuted, size: 18),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: SwarmColors.textMuted, size: 16),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: SwarmColors.bgElevated,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: SwarmColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: SwarmColors.accent),
                  ),
                ),
              ),
            ),

            // Main Scrollable Area
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                children: [
                  // Favorites Section (Top)
                  if (_searchQuery.isEmpty && _favoriteApps.isNotEmpty) ...[
                    const Padding(
                      padding: EdgeInsets.only(bottom: 8, top: 4),
                      child: Row(
                        children: [
                          Icon(Icons.star, color: SwarmColors.statusIdle, size: 15),
                          SizedBox(width: 6),
                          Text(
                            'FAVORITES',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                              color: SwarmColors.textMuted,
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
                                color: SwarmColors.bgElevated,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: SwarmColors.border),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(app.icon, color: SwarmColors.accent, size: 26),
                                  const SizedBox(height: 6),
                                  Text(
                                    app.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: SwarmColors.textPrimary,
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
                    const Divider(color: SwarmColors.border, height: 1),
                    const SizedBox(height: 12),
                  ],

                  // Full Apps List Section
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      _searchQuery.isEmpty ? 'ALL APPLICATIONS' : 'SEARCH RESULTS (${_filteredApps.length})',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                        color: SwarmColors.textMuted,
                      ),
                    ),
                  ),

                  if (_filteredApps.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(24),
                      alignment: Alignment.center,
                      child: const Text(
                        'No matching applications found',
                        style: TextStyle(color: SwarmColors.textMuted, fontSize: 13),
                      ),
                    ),

                  ..._filteredApps.map((app) => Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: SwarmColors.bgElevated.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: SwarmColors.border),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: ListTile(
                            dense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            leading: Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: SwarmColors.bgSurface,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: SwarmColors.border),
                              ),
                              child: Icon(app.icon, color: SwarmColors.textPrimary, size: 20),
                            ),
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    app.name,
                                    style: const TextStyle(
                                      color: SwarmColors.textPrimary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                _buildCategoryBadge(app.category),
                              ],
                            ),
                            subtitle: Text(
                              app.description,
                              style: const TextStyle(color: SwarmColors.textMuted, fontSize: 11),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(
                                    app.isFavorite ? Icons.star : Icons.star_border,
                                    color: app.isFavorite ? SwarmColors.statusIdle : SwarmColors.textMuted,
                                    size: 18,
                                  ),
                                  onPressed: () {
                                    setState(() => app.isFavorite = !app.isFavorite);
                                  },
                                  tooltip: 'Toggle Favorite',
                                ),
                                IconButton(
                                  icon: const Icon(Icons.play_arrow, color: SwarmColors.accent, size: 20),
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

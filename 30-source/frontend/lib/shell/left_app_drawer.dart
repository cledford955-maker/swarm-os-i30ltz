import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/swarm_colors.dart';
import '../services/system_launcher.dart';
import '../services/launch_status.dart';
import '../models/swarm_apps.dart';
import '../widgets/agent_avatar.dart';
import 'companion_bridge_dialog.dart';

// ── "THIS is NOW" palette ──────────────────────────────────────────
const _eBlue    = Color(0xFF0088FF); // electric blue primary
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
    await SystemLauncher.launch(context, app.command, displayName: app.name, agentId: app.id);
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
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold,
              letterSpacing: 0.8, color: color),
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
            right: BorderSide(color: _eBlue.withValues(alpha: 0.45), width: 1.5),
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
                          border: Border.all(
                              color: _eBlue.withValues(alpha: 0.4)),
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
                    borderSide: BorderSide(
                        color: Colors.white.withValues(alpha: 0.1)),
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
                        separatorBuilder: (_, __) =>
                            const SizedBox(width: 10),
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
                            leading: _LaunchAuraIcon(
                              id: app.id,
                              icon: app.icon,
                              color: app.color,
                              size: 38,
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
                                      color: Colors.white.withValues(alpha: 0.06),
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
                                        color: Colors.white
                                            .withValues(alpha: 0.5),
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
                                        : Colors.white
                                            .withValues(alpha: 0.25),
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

// ── Per-icon launch-state aura ─────────────────────────────────────────────
// Wraps an AppIconOrb in a container whose border + glow tracks the tile's
// LaunchAuraState: blinking green while loading, solid green while running,
// red for 5 s when closed/failed.
class _LaunchAuraIcon extends StatefulWidget {
  const _LaunchAuraIcon({
    required this.id,
    required this.icon,
    required this.color,
    required this.size,
  });

  final String id;
  final IconData icon;
  final Color color;
  final double size;

  @override
  State<_LaunchAuraIcon> createState() => _LaunchAuraIconState();
}

class _LaunchAuraIconState extends State<_LaunchAuraIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _blink;

  @override
  void initState() {
    super.initState();
    _blink = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _blink.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<LaunchAuraState>(
      valueListenable: LaunchStatusRegistry.notifierFor(widget.id),
      builder: (_, aura, __) {
        return AnimatedBuilder(
          animation: _blink,
          builder: (_, __) {
            Color border = widget.color.withValues(alpha: 0.35);
            List<BoxShadow> glow = const [];

            if (aura == LaunchAuraState.loading) {
              // Blink green
              final alpha = 0.4 + _blink.value * 0.6;
              border = const Color(0xFF00FF88).withValues(alpha: alpha);
              glow = [BoxShadow(color: const Color(0xFF00FF88).withValues(alpha: alpha * 0.6), blurRadius: 10, spreadRadius: 1)];
            } else if (aura == LaunchAuraState.running) {
              border = const Color(0xFF00FF88).withValues(alpha: 0.7);
              glow = const [BoxShadow(color: Color(0x5500FF88), blurRadius: 8, spreadRadius: 1)];
            } else if (aura == LaunchAuraState.closed) {
              border = const Color(0xFFFF3333).withValues(alpha: 0.9);
              glow = const [BoxShadow(color: Color(0x88FF3333), blurRadius: 12, spreadRadius: 2)];
            }

            return Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                color: widget.color.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: border),
                boxShadow: glow,
              ),
              child: Center(
                child: AppIconOrb(icon: widget.icon, color: widget.color, size: widget.size - 8),
              ),
            );
          },
        );
      },
    );
  }
}

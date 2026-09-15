// ═══════════════════════════════════════════════════════════════
// Swarm OS — Infinite Circular Desktop
//
// One continuous vertical scroll through every space (ORIGIN, SYSTEM,
// GAMING & MEDIA, …user-added spaces). Scrolling past the last space
// loops seamlessly back to ORIGIN — the list has no end, it just keeps
// growing as spaces are added and wrapping around forever.
//
// • Scroll down through spaces; content repeats once you pass the end.
// • A "↻ FULL CIRCLE" divider marks each wrap back to ORIGIN.
// • Page 0 (ORIGIN) is clearly labelled ⭐ ORIGIN.
// • + button adds a new blank space; long-press to remove it.
// ═══════════════════════════════════════════════════════════════

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/hex_grid.dart';
import '../shell/window_manager.dart';
import '../services/system_launcher.dart';
import '../models/swarm_apps.dart';
import '../widgets/swarm_terminal.dart';
import '../widgets/companion_telemetry.dart';
import '../theme/swarm_colors.dart';

// ─── Thin transparent backing so the wasp-nest wallpaper shows through ───
const _t = Color(0x28000000);

class HexDesktopPage extends ConsumerStatefulWidget {
  const HexDesktopPage({super.key});

  @override
  ConsumerState<HexDesktopPage> createState() => _HexDesktopPageState();
}

class _HexDesktopPageState extends ConsumerState<HexDesktopPage> {
  late ScrollController _ctrl;
  // Each element is one desktop space. Index 0 = ORIGIN.
  late List<_DesktopSpace> _spaces;

  static const _kSpaces = 'hex_desktop_spaces';
  static const _kScrollOffset = 'hex_desktop_scroll_offset';

  // ────────────────────────────────────────────────────────────
  // Init / Persist
  // ────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _spaces = _buildInitialSpaces();
    _ctrl = ScrollController();
    HardwareKeyboard.instance.addHandler(_onKey);
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kSpaces);
      final offset = prefs.getDouble(_kScrollOffset) ?? 0;
      if (raw != null) {
        final List<dynamic> saved = jsonDecode(raw) as List<dynamic>;
        final rebuilt = <_DesktopSpace>[];
        final defaults = _buildInitialSpaces();
        for (int i = 0; i < saved.length; i++) {
          final name = saved[i]['name'] as String? ?? 'SPACE ${i + 1}';
          final agents = i < defaults.length ? defaults[i].agents : <HexAgent>[];
          rebuilt.add(_DesktopSpace(name: name, agents: agents));
        }
        if (rebuilt.isNotEmpty && mounted) {
          setState(() => _spaces = rebuilt);
        }
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_ctrl.hasClients && offset > 0) {
          _ctrl.jumpTo(offset.clamp(0, _ctrl.position.maxScrollExtent));
        }
      });
    } catch (_) {
      // Prefs unavailable — use defaults silently
    }
  }

  Future<void> _savePrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(
        _spaces.map((s) => {'name': s.name}).toList(),
      );
      await prefs.setString(_kSpaces, encoded);
      if (_ctrl.hasClients) {
        await prefs.setDouble(_kScrollOffset, _ctrl.offset);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    _ctrl.dispose();
    super.dispose();
  }

  // Meta+Tab → scroll to next space; Meta+Shift+Tab → previous space
  bool _onKey(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    if (!HardwareKeyboard.instance.isMetaPressed) return false;
    if (event.logicalKey != LogicalKeyboardKey.tab) return false;

    if (HardwareKeyboard.instance.isShiftPressed) {
      _scrollBy(-1);
    } else {
      _scrollBy(1);
    }
    return true; // consumed
  }

  void _scrollBy(int spaces) {
    if (!_ctrl.hasClients) return;
    final target = (_ctrl.offset + spaces * 520)
        .clamp(0.0, _ctrl.position.maxScrollExtent == 0
            ? double.infinity
            : double.infinity);
    _ctrl.animateTo(target < 0 ? 0 : target,
        duration: const Duration(milliseconds: 400), curve: Curves.easeOutCubic);
  }

  List<_DesktopSpace> _buildInitialSpaces() => [
    _DesktopSpace(name: 'ORIGIN', agents: _toHexAgents(SwarmAppCategory.origin)),
    _DesktopSpace(name: 'SYSTEM', agents: _toHexAgents(SwarmAppCategory.system)),
    _DesktopSpace(name: 'GAMING & MEDIA', agents: _toHexAgents(SwarmAppCategory.gamingMedia)),
  ];

  // ────────────────────────────────────────────────────────────
  // App definitions — pulled from the shared SwarmAppRegistry so this
  // page, the left app drawer, and the hub grid never drift out of sync.
  // ────────────────────────────────────────────────────────────

  List<HexAgent> _toHexAgents(SwarmAppCategory category) =>
      SwarmAppRegistry.byCategory(category).map(_toHexAgent).toList();

  HexAgent _toHexAgent(SwarmApp app) => HexAgent(
    id: app.id,
    name: app.name,
    icon: app.icon,
    color: app.color,
    bgColor: _t,
    execCommand: app.execCommand,
    routePath: app.routePath,
    mock: app.mock,
  );

  // ────────────────────────────────────────────────────────────
  // Actions
  // ────────────────────────────────────────────────────────────

  // Windows land centered in the middle gutter between the two icon rails,
  // not tucked in a corner behind them.
  Offset _centerWindowOffset(Size windowSize) {
    final screen = MediaQuery.of(context).size;
    return Offset(
      ((screen.width - windowSize.width) / 2).clamp(0, double.infinity),
      ((screen.height - windowSize.height) / 2).clamp(40, double.infinity),
    );
  }

  void _openAgent(HexAgent agent) {
    if (SwarmAppRegistry.byId(agent.id)?.mock == true) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: SwarmColors.bgElevated,
        content: Text('🔜 ${agent.name} — coming soon',
          style: const TextStyle(color: SwarmColors.textPrimary, fontSize: 12)),
        duration: const Duration(seconds: 2),
      ));
      return;
    }
    const windowSize = Size(620, 460);
    // These two stay in-app widgets rather than shelling out — an embedded
    // terminal/monitor works even before a terminal emulator is packaged.
    switch (agent.id) {
      case 'terminal':
        ref.read(windowProvider.notifier).openWindow(AppWindow(
          id: agent.id, title: agent.name,
          position: _centerWindowOffset(windowSize), size: windowSize,
          content: const SwarmTerminal(initialPanes: 1),
        ));
        return;
      case 'sysmon':
        ref.read(windowProvider.notifier).openWindow(AppWindow(
          id: agent.id, title: agent.name,
          position: _centerWindowOffset(windowSize), size: windowSize,
          content: const CompanionTelemetryPanel(),
        ));
        return;
    }
    if (agent.execCommand != null) {
      SystemLauncher.launch(context, agent.execCommand!, displayName: agent.name, agentId: agent.id);
      return;
    }
    if (agent.routePath != null) {
      context.go(agent.routePath!);
      return;
    }
    ref.read(windowProvider.notifier).openWindow(AppWindow(
      id: agent.id,
      title: agent.name,
      position: _centerWindowOffset(windowSize),
      size: windowSize,
      content: _placeholder(agent),
    ));
  }

  void _addSpace() {
    setState(() {
      _spaces.add(_DesktopSpace(name: 'SPACE ${_spaces.length + 1}', agents: []));
    });
    _savePrefs();
  }

  void _removeSpace(int index) {
    if (_spaces.length <= 1 || index == 0) return; // can't remove ORIGIN
    setState(() => _spaces.removeAt(index));
    _savePrefs();
  }

  // ────────────────────────────────────────────────────────────
  // Build
  // ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      NotificationListener<ScrollUpdateNotification>(
        onNotification: (n) {
          // Persist periodically rather than on every pixel of scroll.
          if ((n.metrics.pixels % 200) < 20) _savePrefs();
          return false;
        },
        child: ListView.builder(
          controller: _ctrl,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          // No itemCount — the list is intentionally endless. Each real
          // space repeats via `index % _spaces.length`, which is what makes
          // scrolling down forever loop back to ORIGIN instead of stopping.
          itemBuilder: (ctx, index) {
            final realIndex = index % _spaces.length;
            final isWrap = index > 0 && realIndex == 0;
            // A space with only a few icons is naturally short, so with few
            // spaces the endless loop was wrapping back to ORIGIN within a
            // single screen — "ORIGIN" repeating ~10x stacked on top of
            // itself instead of reading as one page per scroll. Force each
            // space to occupy at least one full viewport so scrolling always
            // moves meaningfully to the next space rather than looping in
            // place.
            final minHeight = MediaQuery.of(ctx).size.height -
                (isWrap ? 96 : 0); // divider eats a bit of the next one's slack
            return ConstrainedBox(
              constraints: BoxConstraints(minHeight: minHeight),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isWrap) _buildLoopDivider(),
                  _buildSpaceSection(realIndex),
                  const SizedBox(height: 28),
                ],
              ),
            );
          },
        ),
      ),

      // Add new space button (bottom-right)
      Positioned(
        right: 20,
        bottom: 24,
        child: _buildAddButton(),
      ),
    ]);
  }

  // ────────────────────────────────────────────────────────────
  // Space section
  // ────────────────────────────────────────────────────────────

  Widget _buildSpaceSection(int index) {
    final space = _spaces[index];
    // Icons run down two checkered columns hugging the left/right edges;
    // the middle stays clear as the landing zone for opened windows.
    // Interleaved so the checkerboard reads continuously top-to-bottom.
    final left = <HexAgent>[];
    final right = <HexAgent>[];
    for (int i = 0; i < space.agents.length; i++) {
      (i.isEven ? left : right).add(space.agents[i]);
    }

    return Stack(children: [
      Container(
        padding: const EdgeInsets.fromLTRB(0, 36, 0, 8),
        child: space.agents.isEmpty
            ? _buildEmptySpace()
            : IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 150,
                      child: HexGrid(
                        agents: left,
                        columns: 2,
                        rows: (left.length / 2).ceil().clamp(1, 40),
                        hexSize: 64,
                        onAgentOpen: _openAgent,
                        showSlotBackgrounds: false,
                      ),
                    ),
                    // Window landing zone — left empty on purpose.
                    const Expanded(child: SizedBox.shrink()),
                    SizedBox(
                      width: 150,
                      child: HexGrid(
                        agents: right,
                        columns: 2,
                        rows: (right.length / 2).ceil().clamp(1, 40),
                        hexSize: 64,
                        onAgentOpen: _openAgent,
                        showSlotBackgrounds: false,
                      ),
                    ),
                  ],
                ),
              ),
      ),

      // Space label badge (top-left)
      Positioned(
        top: 6,
        left: 0,
        child: index == 0 ? _originBadge() : _spaceBadge(space.name),
      ),

      // Remove button (top-right) — only for non-ORIGIN spaces
      if (index != 0)
        Positioned(
          top: 6,
          right: 0,
          child: GestureDetector(
            onTap: () => _removeSpace(index),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: Icon(Icons.close, color: Colors.white.withValues(alpha: 0.25), size: 14),
            ),
          ),
        ),
    ]);
  }

  Widget _buildEmptySpace() {
    return SizedBox(
      height: 160,
      child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.add_circle_outline,
          color: Colors.white.withValues(alpha: 0.1), size: 40),
        const SizedBox(height: 10),
        Text('Empty space', style: TextStyle(
          color: Colors.white.withValues(alpha: 0.15),
          fontSize: 13, letterSpacing: 1)),
      ])),
    );
  }

  // ────────────────────────────────────────────────────────────
  // Loop divider — shown each time the endless scroll wraps to ORIGIN
  // ────────────────────────────────────────────────────────────

  Widget _buildLoopDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Row(children: [
        Expanded(child: Divider(color: const Color(0xFF00D4FF).withValues(alpha: 0.25))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.loop_rounded, color: Color(0xFF00D4FF), size: 15),
            const SizedBox(width: 6),
            Text('FULL CIRCLE', style: TextStyle(
              color: const Color(0xFF00D4FF).withValues(alpha: 0.8),
              fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 3)),
          ]),
        ),
        Expanded(child: Divider(color: const Color(0xFF00D4FF).withValues(alpha: 0.25))),
      ]),
    );
  }

  // ────────────────────────────────────────────────────────────
  // Badges
  // ────────────────────────────────────────────────────────────

  Widget _originBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFFFD700).withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFFD700).withValues(alpha: 0.55), width: 1.2),
        boxShadow: [BoxShadow(
          color: const Color(0xFFFFD700).withValues(alpha: 0.18),
          blurRadius: 12,
        )],
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.star_rounded, color: Color(0xFFFFD700), size: 13),
        const SizedBox(width: 6),
        const Text(
          'ORIGIN',
          style: TextStyle(
            color: Color(0xFFFFD700),
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 2.5,
          ),
        ),
      ]),
    );
  }

  Widget _spaceBadge(String name) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF00D4FF).withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF00D4FF).withValues(alpha: 0.22)),
      ),
      child: Text(
        name,
        style: TextStyle(
          color: const Color(0xFF00D4FF).withValues(alpha: 0.55),
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 2,
        ),
      ),
    );
  }

  // ────────────────────────────────────────────────────────────
  // Add space button
  // ────────────────────────────────────────────────────────────

  Widget _buildAddButton() {
    return GestureDetector(
      onTap: _addSpace,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF00D4FF).withValues(alpha: 0.08),
          border: Border.all(color: const Color(0xFF00D4FF).withValues(alpha: 0.35)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF00D4FF).withValues(alpha: 0.20),
              blurRadius: 14,
            ),
          ],
        ),
        child: const Icon(Icons.add, color: Color(0xFF00D4FF), size: 22),
      ),
    );
  }

  // ────────────────────────────────────────────────────────────
  // Helpers
  // ────────────────────────────────────────────────────────────

  Widget _placeholder(HexAgent agent) {
    return Container(
      color: const Color(0xFF0A0A18),
      child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(agent.icon, color: agent.color.withValues(alpha: 0.25), size: 48),
        const SizedBox(height: 12),
        Text(agent.name, style: TextStyle(
          color: agent.color.withValues(alpha: 0.4), fontSize: 18)),
      ])),
    );
  }
}

// ─── Simple data model for a desktop space ───
class _DesktopSpace {
  final String name;
  final List<HexAgent> agents;
  _DesktopSpace({required this.name, required this.agents});
}

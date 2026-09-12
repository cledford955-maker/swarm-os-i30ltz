// ═══════════════════════════════════════════════════════════════
// Swarm OS — Infinite Circular Desktop
//
// Swipeable pages (desktops/spaces) arranged in a ring:
//   [ORIGIN] → [Space 2] → [Space 3] → … → [FULL CIRCLE] ↩ [ORIGIN]
//
// • Swipe right through spaces; grows as user adds new ones.
// • Last page = loop sentinel that auto-returns to ORIGIN (page 0).
// • Page 0 is clearly labelled ⭐ ORIGIN.
// • Bottom indicator: gold dot (origin), cyan dot (current), loop icon.
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
import '../widgets/swarm_terminal.dart';
import '../widgets/companion_telemetry.dart';

// ─── Thin transparent backing so the wasp-nest wallpaper shows through ───
const _t = Color(0x28000000);

class HexDesktopPage extends ConsumerStatefulWidget {
  const HexDesktopPage({super.key});

  @override
  ConsumerState<HexDesktopPage> createState() => _HexDesktopPageState();
}

class _HexDesktopPageState extends ConsumerState<HexDesktopPage> {
  late PageController _ctrl;
  // Each element is one desktop space.  Index 0 = ORIGIN.
  late List<_DesktopSpace> _spaces;
  int _currentPage = 0;

  static const _returnDelay = Duration(milliseconds: 700);
  static const _kSpaces = 'hex_desktop_spaces';
  static const _kLastPage = 'hex_desktop_last_page';

  // ────────────────────────────────────────────────────────────
  // Init / Persist
  // ────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _spaces = _buildInitialSpaces();
    _ctrl = PageController();
    HardwareKeyboard.instance.addHandler(_onKey);
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kSpaces);
      final lastPage = prefs.getInt(_kLastPage) ?? 0;
      if (raw != null) {
        final List<dynamic> saved = jsonDecode(raw) as List<dynamic>;
        // Rebuild spaces: initial 3 fixed app sets + any extra user spaces
        final rebuilt = <_DesktopSpace>[];
        final defaults = _buildInitialSpaces();
        for (int i = 0; i < saved.length; i++) {
          final name = saved[i]['name'] as String? ?? 'SPACE ${i + 1}';
          final agents = i < defaults.length ? defaults[i].agents : <HexAgent>[];
          rebuilt.add(_DesktopSpace(name: name, agents: agents));
        }
        if (rebuilt.isNotEmpty && mounted) {
          setState(() {
            _spaces = rebuilt;
            _currentPage = lastPage.clamp(0, rebuilt.length - 1);
          });
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_ctrl.hasClients) _ctrl.jumpToPage(_currentPage);
          });
        }
      }
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
      await prefs.setInt(_kLastPage, _currentPage.clamp(0, _spaces.length - 1));
    } catch (_) {}
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    _ctrl.dispose();
    super.dispose();
  }

  // Meta+Tab → next space; Meta+Shift+Tab → previous space
  bool _onKey(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    if (!HardwareKeyboard.instance.isMetaPressed) return false;
    if (event.logicalKey != LogicalKeyboardKey.tab) return false;

    if (HardwareKeyboard.instance.isShiftPressed) {
      _prevPage();
    } else {
      _nextPage();
    }
    return true; // consumed
  }

  void _nextPage() {
    final target =
        _currentPage >= _spaces.length - 1 ? 0 : _currentPage + 1;
    _ctrl.animateToPage(target,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic);
  }

  void _prevPage() {
    final target =
        _currentPage <= 0 ? _spaces.length - 1 : _currentPage - 1;
    _ctrl.animateToPage(target,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic);
  }

  List<_DesktopSpace> _buildInitialSpaces() => [
    _DesktopSpace(name: 'ORIGIN', agents: _coreApps()),
    _DesktopSpace(name: 'SYSTEM', agents: _systemApps()),
    _DesktopSpace(name: 'GAMING & MEDIA', agents: _mediaApps()),
  ];

  // ────────────────────────────────────────────────────────────
  // App definitions — split across three initial spaces
  // ────────────────────────────────────────────────────────────

  List<HexAgent> _coreApps() => [
    HexAgent(id: 'lucille', name: 'Lucille', icon: Icons.auto_awesome,
      color: const Color(0xFFCE93D8), bgColor: _t, routePath: '/lucille'),
    HexAgent(id: 'forge', name: 'Forge', icon: Icons.construction,
      color: const Color(0xFF9575CD), bgColor: _t, routePath: '/forge'),
    HexAgent(id: 'ide', name: 'Coder', icon: Icons.code,
      color: const Color(0xFF64B5F6), bgColor: _t, routePath: '/ide'),
    HexAgent(id: 'claude_desktop', name: 'Claude', icon: Icons.psychology,
      color: const Color(0xFFFF8A65), bgColor: _t,
      execCommand: SystemLauncher.claudeDesktopCmd),
    HexAgent(id: 'claude_code', name: 'CC', icon: Icons.terminal,
      color: const Color(0xFF81C784), bgColor: _t,
      execCommand: SystemLauncher.claudeCodeCmd),
    HexAgent(id: 'memory', name: 'Memory', icon: Icons.psychology_alt,
      color: const Color(0xFF4DB6AC), bgColor: _t, routePath: '/memory'),
    HexAgent(id: 'agents', name: 'AI Squad', icon: Icons.group,
      color: const Color(0xFFBA68C8), bgColor: _t, routePath: '/agents'),
    HexAgent(id: 'vital', name: 'Vital', icon: Icons.monitor_heart,
      color: const Color(0xFFEF9A9A), bgColor: _t, routePath: '/vital'),
  ];

  List<HexAgent> _systemApps() => [
    HexAgent(id: 'terminal', name: 'Terminal', icon: Icons.terminal,
      color: const Color(0xFF00D4FF), bgColor: _t),
    HexAgent(id: 'browser', name: 'Browser', icon: Icons.public,
      color: const Color(0xFF4FC3F7), bgColor: _t,
      execCommand: SystemLauncher.browserCmd),
    HexAgent(id: 'files', name: 'Files', icon: Icons.folder,
      color: const Color(0xFFA1887F), bgColor: _t,
      execCommand: SystemLauncher.fileManagerCmd),
    HexAgent(id: 'antigravity', name: 'Antigravity', icon: Icons.rocket_launch,
      color: const Color(0xFFFFB74D), bgColor: _t,
      execCommand: SystemLauncher.antigravityIdeCmd),
    HexAgent(id: 'sysmon', name: 'Monitor', icon: Icons.bar_chart,
      color: const Color(0xFFFF7043), bgColor: _t,
      execCommand: SystemLauncher.monitorCmd),
    HexAgent(id: 'installer', name: 'Install', icon: Icons.install_desktop,
      color: const Color(0xFFFFD54F), bgColor: _t,
      execCommand: SystemLauncher.installerCmd),
    HexAgent(id: 'sysopt', name: 'SysOpt', icon: Icons.bolt,
      color: const Color(0xFF4DD0E1), bgColor: _t, routePath: '/sysopt'),
    HexAgent(id: 'mirror', name: 'Mirror', icon: Icons.screen_share,
      color: const Color(0xFF80CBC4), bgColor: _t, routePath: '/mirror'),
    HexAgent(id: 'settings', name: 'Settings', icon: Icons.settings,
      color: const Color(0xFF78909C), bgColor: _t, routePath: '/settings'),
  ];

  List<HexAgent> _mediaApps() => [
    HexAgent(id: 'gaming', name: 'Gaming', icon: Icons.sports_esports,
      color: const Color(0xFF76B900), bgColor: _t, routePath: '/nvidia'),
    HexAgent(id: 'cinema', name: 'Cinema', icon: Icons.movie_filter,
      color: const Color(0xFFF48FB1), bgColor: _t, routePath: '/cinema'),
    HexAgent(id: 'gitlens', name: 'GitLens', icon: Icons.hub,
      color: const Color(0xFFFFD54F), bgColor: _t, routePath: '/gitlens'),
    HexAgent(id: 'diff', name: 'Diff', icon: Icons.difference,
      color: const Color(0xFFDCE775), bgColor: _t, routePath: '/diff'),
    HexAgent(id: 'vms', name: 'VMs', icon: Icons.computer,
      color: const Color(0xFF90A4AE), bgColor: _t, routePath: '/vms'),
    HexAgent(id: 'security', name: 'Security', icon: Icons.security,
      color: const Color(0xFFEF5350), bgColor: _t, routePath: '/security-audit'),
    HexAgent(id: 'telemetry', name: 'Telemetry', icon: Icons.timeline,
      color: const Color(0xFF7986CB), bgColor: _t, routePath: '/telemetry'),
    HexAgent(id: 'backend', name: 'Backend', icon: Icons.dns,
      color: const Color(0xFF90A4AE), bgColor: _t, routePath: '/backend'),
  ];

  // ────────────────────────────────────────────────────────────
  // Actions
  // ────────────────────────────────────────────────────────────

  void _openAgent(HexAgent agent) {
    if (agent.execCommand != null) {
      SystemLauncher.launch(context, agent.execCommand!, displayName: agent.name);
      return;
    }
    if (agent.routePath != null) {
      context.go(agent.routePath!);
      return;
    }
    Widget content;
    switch (agent.id) {
      case 'terminal':
        content = const SwarmTerminal(initialPanes: 1);
      case 'sysmon':
        content = const CompanionTelemetryPanel();
      default:
        content = _placeholder(agent);
    }
    ref.read(windowProvider.notifier).openWindow(AppWindow(
      id: agent.id,
      title: agent.name,
      position: const Offset(120, 80),
      size: const Size(620, 460),
      content: content,
    ));
  }

  void _addSpace() {
    setState(() {
      _spaces.add(_DesktopSpace(name: 'SPACE ${_spaces.length + 1}', agents: []));
    });
    _savePrefs();
    Future.microtask(() => _ctrl.animateToPage(
      _spaces.length - 1,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
    ));
  }

  void _removeSpace(int index) {
    if (_spaces.length <= 1 || index == 0) return; // can't remove ORIGIN
    setState(() {
      _spaces.removeAt(index);
      if (_currentPage >= _spaces.length) {
        _currentPage = _spaces.length - 1;
      }
    });
    _ctrl.jumpToPage(_currentPage);
    _savePrefs();
  }

  // ────────────────────────────────────────────────────────────
  // Page changed handler
  // ────────────────────────────────────────────────────────────

  void _onPageChanged(int page) {
    setState(() => _currentPage = page);
    // Save last-visited real page (not the sentinel)
    if (page < _spaces.length) _savePrefs();
    // Loop sentinel reached — bounce back to ORIGIN after a beat
    if (page == _spaces.length) {
      Future.delayed(_returnDelay, () {
        if (!mounted) return;
        _ctrl.animateToPage(0,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOutCubic);
      });
    }
  }

  // ────────────────────────────────────────────────────────────
  // Build
  // ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // itemCount = N real spaces + 1 loop-sentinel page
    return Stack(children: [
      PageView.builder(
        controller: _ctrl,
        itemCount: _spaces.length + 1,
        onPageChanged: _onPageChanged,
        itemBuilder: (ctx, index) {
          if (index == _spaces.length) return _buildLoopSentinel();
          return _buildSpacePage(index);
        },
      ),

      // Bottom page ring indicator
      Positioned(
        bottom: 12,
        left: 0,
        right: 0,
        child: _buildRingIndicator(),
      ),

      // Add new space button (bottom-right)
      Positioned(
        right: 20,
        bottom: 52,
        child: _buildAddButton(),
      ),
    ]);
  }

  // ────────────────────────────────────────────────────────────
  // Space page
  // ────────────────────────────────────────────────────────────

  Widget _buildSpacePage(int index) {
    final space = _spaces[index];
    return Stack(children: [
      // Space label badge (top-left)
      Positioned(
        top: 6,
        left: 16,
        child: index == 0 ? _originBadge() : _spaceBadge(index, space.name),
      ),

      // Scrollable hex icon grid
      SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 40, 16, 72),
        child: space.agents.isEmpty
            ? _buildEmptySpace(index)
            : HexGrid(
                agents: space.agents,
                columns: 8,
                rows: 4,
                hexSize: 64,
                onAgentOpen: _openAgent,
                showSlotBackgrounds: false,
              ),
      ),

      // Remove button (top-right) — only for non-ORIGIN spaces
      if (index != 0)
        Positioned(
          top: 6,
          right: 16,
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

  Widget _buildEmptySpace(int index) {
    return SizedBox(
      height: 300,
      child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.add_circle_outline,
          color: Colors.white.withValues(alpha: 0.1), size: 56),
        const SizedBox(height: 16),
        Text('Empty space', style: TextStyle(
          color: Colors.white.withValues(alpha: 0.15),
          fontSize: 14, letterSpacing: 1)),
        const SizedBox(height: 6),
        Text('Swipe right to see more desktops', style: TextStyle(
          color: Colors.white.withValues(alpha: 0.08),
          fontSize: 11, letterSpacing: 0.5)),
      ])),
    );
  }

  // ────────────────────────────────────────────────────────────
  // Loop sentinel
  // ────────────────────────────────────────────────────────────

  Widget _buildLoopSentinel() {
    return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      // Animated circular glow ring
      TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.6, end: 1.0),
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeInOut,
        builder: (_, v, child) => AnimatedScale(
          scale: v,
          duration: Duration.zero,
          child: child,
        ),
        child: Container(
          width: 130,
          height: 130,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFF00D4FF), width: 2),
            color: const Color(0xFF00D4FF).withValues(alpha: 0.06),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF00D4FF).withValues(alpha: 0.35),
                blurRadius: 40,
                spreadRadius: 8,
              ),
            ],
          ),
          child: const Icon(Icons.loop_rounded, color: Color(0xFF00D4FF), size: 64),
        ),
      ),
      const SizedBox(height: 28),
      const Text(
        'FULL CIRCLE',
        style: TextStyle(
          color: Color(0xFF00D4FF),
          fontSize: 24,
          fontWeight: FontWeight.w800,
          letterSpacing: 5,
        ),
      ),
      const SizedBox(height: 10),
      Text(
        'Returning to ORIGIN…',
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.35),
          fontSize: 13,
          letterSpacing: 1.5,
        ),
      ),
      const SizedBox(height: 32),
      // Preview of ORIGIN badge
      _originBadge(),
    ]));
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

  Widget _spaceBadge(int index, String name) {
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
  // Ring indicator (bottom)
  // ────────────────────────────────────────────────────────────

  Widget _buildRingIndicator() {
    final total = _spaces.length + 1; // real spaces + loop sentinel
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ...List.generate(total, (i) {
          final isLoop = i == _spaces.length;
          final isCurrent = _currentPage == i;
          final isOrigin = i == 0;

          if (isLoop) {
            // Loop sentinel dot — loop icon
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: AnimatedOpacity(
                opacity: isCurrent ? 1.0 : 0.35,
                duration: const Duration(milliseconds: 200),
                child: Icon(Icons.loop_rounded,
                  color: const Color(0xFF00D4FF), size: 14),
              ),
            );
          }

          return AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: isCurrent ? 22 : (isOrigin ? 10 : 7),
            height: isOrigin ? 10 : 7,
            decoration: BoxDecoration(
              color: isCurrent
                  ? (isOrigin ? const Color(0xFFFFD700) : const Color(0xFF00D4FF))
                  : isOrigin
                      ? const Color(0xFFFFD700).withValues(alpha: 0.55)
                      : Colors.white.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(12),
              boxShadow: isCurrent
                  ? [BoxShadow(
                      color: (isOrigin
                          ? const Color(0xFFFFD700)
                          : const Color(0xFF00D4FF)).withValues(alpha: 0.5),
                      blurRadius: 8,
                    )]
                  : [],
            ),
          );
        }),
      ],
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

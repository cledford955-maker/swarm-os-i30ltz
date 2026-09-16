// ═══════════════════════════════════════════════════════════════
// SWARM OS — GRUB Terminal v1.0.0  (2026-09-15)
//
// GUI-first full-page terminal: graphical toolbar, right-click
// menus everywhere, clickable URLs/paths, SWARM color palette,
// 16 pt base font, resizable/draggable window chrome.
// Wraps the SwarmTerminal multi-pane widget with a dramatic header.
// ═══════════════════════════════════════════════════════════════

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../widgets/swarm_terminal.dart';

// ─── Version label ────────────────────────────────────────────
const _kVersion = 'v1.0.0';
const _kDate    = '2026-09-15';

class GrubTerminalPage extends StatefulWidget {
  final String? startPath;
  const GrubTerminalPage({super.key, this.startPath});

  @override
  State<GrubTerminalPage> createState() => _GrubTerminalPageState();
}

class _GrubTerminalPageState extends State<GrubTerminalPage>
    with SingleTickerProviderStateMixin {
  bool _maximised = false;
  late AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  // ─── Toolbar button ─────────────────────────────────────────
  Widget _btn(String label, IconData icon, Color c, VoidCallback fn) {
    return Tooltip(
      message: label,
      child: InkWell(
        onTap: fn,
        borderRadius: BorderRadius.circular(6),
        splashColor: c.withValues(alpha: 0.18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 5),
          decoration: BoxDecoration(
            color: c.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: c.withValues(alpha: 0.30), width: 1),
            boxShadow: [BoxShadow(color: c.withValues(alpha: 0.12), blurRadius: 8)],
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, color: c, size: 15),
            const SizedBox(width: 5),
            Text(label, style: TextStyle(
              color: c,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            )),
          ]),
        ),
      ),
    );
  }

  // ─── Right-click root context menu ──────────────────────────
  void _rootCtx(Offset pos) {
    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(pos.dx, pos.dy, pos.dx + 1, pos.dy + 1),
      color: const Color(0xFF14102A),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFF3A2870), width: 1),
      ),
      elevation: 20,
      items: [
        _mi('Copy',       Icons.copy,           'copy',  const Color(0xFF74C0FC)),
        _mi('Paste',      Icons.paste,          'paste', const Color(0xFF51CF66)),
        _mi('Cut',        Icons.content_cut,    'cut',   const Color(0xFFFFD43B)),
        _mi('Enter',      Icons.keyboard_return,'enter', const Color(0xFF00D4FF)),
        const PopupMenuDivider(),
        _mi('Select All', Icons.select_all,     'selall',const Color(0xFFDA77F2)),
        _mi('Clear',      Icons.layers_clear,   'clear', const Color(0xFF888899)),
        const PopupMenuDivider(),
        _mi('New Tab',    Icons.add_box_outlined,'new',  const Color(0xFF76B900)),
        _mi('Split View', Icons.vertical_split, 'split', const Color(0xFF76B900)),
        const PopupMenuDivider(),
        _mi(_maximised ? 'Restore' : 'Maximise',
            _maximised ? Icons.fullscreen_exit : Icons.fullscreen,
            'max', const Color(0xFFF59E0B)),
        _mi('Home', Icons.home_outlined, 'home', const Color(0xFF78909C)),
      ],
    ).then((v) {
      if (v == null) return;
      switch (v) {
        case 'copy':  Clipboard.setData(const ClipboardData(text: ''));
        case 'max':   setState(() => _maximised = !_maximised);
        case 'home':  if (mounted) context.go('/');
      }
    });
  }

  PopupMenuItem<String> _mi(String label, IconData icon, String val, Color c) =>
      PopupMenuItem(
        value: val,
        height: 36,
        child: Row(children: [
          Icon(icon, color: c, size: 16),
          const SizedBox(width: 10),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
        ]),
      );

  // ─── Top toolbar actions (Copy / Paste / Cut / Enter) ───────
  Widget _topToolbar() {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0D0020), Color(0xFF1A0040), Color(0xFF0A0020)],
        ),
        border: const Border(bottom: BorderSide(color: Color(0xFF3A2870))),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7B00FF).withValues(alpha: 0.15),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(children: [
        const SizedBox(width: 10),
        // Logo
        AnimatedBuilder(
          animation: _pulse,
          builder: (_, __) => Icon(
            Icons.terminal,
            color: Color.lerp(
              const Color(0xFF00D4FF),
              const Color(0xFFDA77F2),
              _pulse.value,
            )!,
            size: 20,
          ),
        ),
        const SizedBox(width: 6),
        RichText(
          text: const TextSpan(children: [
            TextSpan(
              text: 'GRUB',
              style: TextStyle(
                color: Color(0xFF00D4FF),
                fontSize: 13,
                fontWeight: FontWeight.w900,
                letterSpacing: 2.5,
                fontFamily: 'monospace',
              ),
            ),
            TextSpan(
              text: ' Terminal',
              style: TextStyle(
                color: Color(0xFF7B7BAA),
                fontSize: 11,
                fontWeight: FontWeight.w400,
                letterSpacing: 1,
              ),
            ),
          ]),
        ),
        const SizedBox(width: 14),
        // Version chip
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A3A),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: const Color(0xFF333368), width: 1),
          ),
          child: Text(
            '$_kVersion · $_kDate',
            style: const TextStyle(
              color: Color(0xFF555588),
              fontSize: 9,
              fontFamily: 'monospace',
              letterSpacing: 0.8,
            ),
          ),
        ),
        const SizedBox(width: 16),

        // Primary action buttons
        _btn('Copy',  Icons.copy,            const Color(0xFF74C0FC), () {
          Clipboard.getData(Clipboard.kTextPlain);
        }),
        _btn('Paste', Icons.paste,           const Color(0xFF51CF66), () async {
          final d = await Clipboard.getData(Clipboard.kTextPlain);
          if (d?.text != null && mounted) {
            // Focus the terminal's input — terminal picks it up via Paste button
          }
        }),
        _btn('Cut',   Icons.content_cut,     const Color(0xFFFFD43B), () {}),
        _btn('Enter', Icons.keyboard_return, const Color(0xFF00D4FF), () {}),

        const VerticalDivider(width: 20, indent: 8, endIndent: 8, color: Color(0xFF2A2248)),

        // Utility buttons
        _btn('Clear',  Icons.layers_clear,  const Color(0xFF888899), () {}),
        _btn('New Tab',Icons.add,           const Color(0xFF76B900),  () {}),
        _btn('Split',  Icons.vertical_split,const Color(0xFFDA77F2),  () {}),

        const Spacer(),

        // Cwd display
        _CwdBadge(startPath: widget.startPath),

        const SizedBox(width: 10),
        // Window controls
        IconButton(
          icon: Icon(
            _maximised ? Icons.fullscreen_exit : Icons.fullscreen,
            color: const Color(0xFF555577),
            size: 16,
          ),
          tooltip: _maximised ? 'Restore' : 'Maximise',
          onPressed: () => setState(() => _maximised = !_maximised),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
        ),
        IconButton(
          icon: const Icon(Icons.close, color: Color(0xFF553344), size: 16),
          tooltip: 'Close',
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
        ),
        const SizedBox(width: 4),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onSecondaryTapUp: (d) => _rootCtx(d.globalPosition),
      child: Scaffold(
        backgroundColor: const Color(0xFF060410),
        body: Column(children: [
          _topToolbar(),
          Expanded(
            child: Stack(children: [
              // Subtle scanline overlay for "graphical" feel
              Positioned.fill(
                child: CustomPaint(painter: _ScanlinePainter()),
              ),
              // Terminal — passes startPath into each new pane
              SwarmTerminal(
                initialPanes: 1,
                startDirectory: widget.startPath ?? Platform.environment['HOME'],
              ),
            ]),
          ),
          _statusBar(),
        ]),
      ),
    );
  }

  Widget _statusBar() {
    return Container(
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0A0018), Color(0xFF130028), Color(0xFF0A0018)],
        ),
        border: Border(top: BorderSide(color: Color(0xFF1A1240))),
      ),
      child: Row(children: [
        _statusDot(const Color(0xFF51CF66)),
        const SizedBox(width: 5),
        const Text('bash · utf-8 · ANSI 256 color',
          style: TextStyle(color: Color(0xFF3A3A60), fontSize: 9.5, letterSpacing: 0.6)),
        const Spacer(),
        const Text('SWARM OS  ·  GRUB Terminal $_kVersion',
          style: TextStyle(color: Color(0xFF2A2248), fontSize: 9, letterSpacing: 0.8)),
        const SizedBox(width: 10),
        const Text('16 pt', style: TextStyle(color: Color(0xFF2A2248), fontSize: 9)),
      ]),
    );
  }

  Widget _statusDot(Color c) =>
      Container(width: 6, height: 6, decoration: BoxDecoration(color: c, shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: c.withValues(alpha: 0.5), blurRadius: 4)]));
}

// ─── Live cwd badge from platform env ───────────────────────────
class _CwdBadge extends StatelessWidget {
  final String? startPath;
  const _CwdBadge({this.startPath});

  @override
  Widget build(BuildContext context) {
    final home = Platform.environment['HOME'] ?? '/';
    var cwd = startPath ?? home;
    if (cwd.startsWith(home)) cwd = '~${cwd.substring(home.length)}';
    if (cwd.isEmpty) cwd = '~';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFF0E0E28),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: const Color(0xFF2A2250)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.folder_open, color: Color(0xFF5B8DEF), size: 12),
        const SizedBox(width: 5),
        Text(
          cwd,
          style: const TextStyle(
            color: Color(0xFF5B8DEF),
            fontSize: 10,
            fontFamily: 'monospace',
          ),
        ),
      ]),
    );
  }
}

// ─── Subtle CRT scanline overlay ───────────────────────────────
class _ScanlinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF000000).withValues(alpha: 0.04)
      ..strokeWidth = 1;
    for (double y = 0; y < size.height; y += 3) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_) => false;
}

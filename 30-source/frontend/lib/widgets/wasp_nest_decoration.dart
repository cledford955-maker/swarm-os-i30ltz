// ═══════════════════════════════════════════════════════════════
// SWARM OS — Wasp Nest Decoration
// Fills empty hex-grid slots (widgets/hex_grid.dart) between the app
// icons with a round metal wasp nest carrying a couple of small
// robotic wasps — a ticking red LED "eye" flash per wasp, offset out
// of phase, and a slow antenna twitch. Meant to read as watchful and
// a little threatening, reinforcing "the swarm" as a constant presence
// around the actual apps rather than empty dead space.
// ═══════════════════════════════════════════════════════════════

import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/swarm_colors.dart';
import 'swarm_motifs.dart';

class WaspNestDecoration extends StatefulWidget {
  final double size;
  // Slots repeat this widget many times across the grid — a stable seed
  // (e.g. the slot key's hash) keeps each nest's wasp placement fixed
  // across rebuilds instead of jittering on every repaint.
  final int seed;

  const WaspNestDecoration({super.key, required this.size, required this.seed});

  @override
  State<WaspNestDecoration> createState() => _WaspNestDecorationState();
}

class _WaspNestDecorationState extends State<WaspNestDecoration>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    // One continuous 0..1 sweep; the painter derives each wasp's own
    // tick timing from it via a phase offset, rather than juggling
    // several controllers for two small sprites.
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 4))
      ..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) => CustomPaint(
          size: Size.square(widget.size),
          painter: _WaspNestPainter(t: _ctrl.value, seed: widget.seed),
        ),
      ),
    );
  }
}

class _WaspNestPainter extends CustomPainter {
  final double t; // 0..1 looping clock
  final int seed;

  _WaspNestPainter({required this.t, required this.seed});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final r = size.shortestSide * 0.38; // nest sits well inside the hex cell, not filling it
    final rng = Random(seed);

    _paintNestBody(canvas, center, r);
    _paintHoneycombEtch(canvas, center, r);

    // Two wasps, placed at fixed-but-seeded points on the nest's rim,
    // ticking out of phase so the pair never flashes in sync.
    final angleA = rng.nextDouble() * 2 * pi;
    final angleB = angleA + pi * (0.55 + rng.nextDouble() * 0.4); // roughly opposite side
    _paintWasp(canvas, center, r, angle: angleA, phase: t);
    _paintWasp(canvas, center, r, angle: angleB, phase: (t + 0.5) % 1.0);
  }

  void _paintNestBody(Canvas canvas, Offset center, double r) {
    final metal = Paint()
      ..shader = const RadialGradient(
        colors: [
          Color(0xFF6A6E78),
          Color(0xFF33353D),
          Color(0xFF141519),
        ],
        stops: [0.0, 0.65, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: r));
    canvas.drawCircle(center, r, metal);

    final rim = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(1.0, r * 0.05)
      ..color = Colors.black.withValues(alpha: 0.6);
    canvas.drawCircle(center, r, rim);

    // Rivets around the rim — small dots, industrial/mechanical read.
    final rivet = Paint()..color = Colors.black.withValues(alpha: 0.55);
    const rivetCount = 8;
    for (var i = 0; i < rivetCount; i++) {
      final a = (i / rivetCount) * 2 * pi;
      final p = center + Offset(cos(a), sin(a)) * (r * 0.86);
      canvas.drawCircle(p, max(0.8, r * 0.035), rivet);
    }

    // Soft highlight, upper-left, to sell "round metal sphere" over flat disc.
    final highlight = Paint()
      ..shader = RadialGradient(
        colors: [Colors.white.withValues(alpha: 0.10), Colors.white.withValues(alpha: 0.0)],
      ).createShader(Rect.fromCircle(center: center - Offset(r * 0.35, r * 0.35), radius: r * 0.6));
    canvas.drawCircle(center - Offset(r * 0.35, r * 0.35), r * 0.6, highlight);
  }

  void _paintHoneycombEtch(Canvas canvas, Offset center, double r) {
    final etch = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(0.6, r * 0.025)
      ..color = SwarmColors.accent.withValues(alpha: 0.18);
    final cell = r * 0.32;
    final hexH = cell * 1.1547;
    for (var row = -1; row <= 1; row++) {
      for (var col = -1; col <= 1; col++) {
        final offsetX = (row.isOdd ? cell * 0.5 : 0.0);
        final p = center + Offset(col * cell + offsetX, row * hexH * 0.75);
        if ((p - center).distance > r * 0.72) continue; // stay inside the nest face
        _drawHexPath(canvas, p, cell * 0.42, etch);
      }
    }
  }

  void _drawHexPath(Canvas canvas, Offset c, double radius, Paint paint) {
    final path = Path();
    for (var i = 0; i < 6; i++) {
      final a = pi / 6 + i * pi / 3;
      final p = c + Offset(cos(a), sin(a)) * radius;
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  void _paintWasp(Canvas canvas, Offset nestCenter, double nestR,
      {required double angle, required double phase}) {
    final pos = nestCenter + Offset(cos(angle), sin(angle)) * (nestR * 0.72);
    final waspSize = nestR * 0.34;

    canvas.save();
    canvas.translate(pos.dx, pos.dy);
    canvas.rotate(angle + pi / 2); // orient roughly outward/along the rim
    paintMiniWasp(canvas, waspSize, phase);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _WaspNestPainter old) => old.t != t || old.seed != seed;
}

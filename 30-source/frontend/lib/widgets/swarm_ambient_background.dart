// ═══════════════════════════════════════════════════════════════
// SWARM OS — Ambient swarm layer
// A persistent, low-opacity drift of small robotic wasps behind all
// content — the hex desktop, every open window. The swarm should
// read as a constant presence around the whole shell, not something
// that only shows up in specific decorations.
// ═══════════════════════════════════════════════════════════════

import 'dart:math';
import 'package:flutter/material.dart';
import 'swarm_motifs.dart';

class SwarmAmbientBackground extends StatefulWidget {
  final int waspCount;
  // Kept low by default — this sits behind readable content across the
  // whole shell, so it needs to stay felt rather than seen.
  final double opacity;

  const SwarmAmbientBackground({super.key, this.waspCount = 16, this.opacity = 0.14});

  @override
  State<SwarmAmbientBackground> createState() => _SwarmAmbientBackgroundState();
}

class _SwarmAmbientBackgroundState extends State<SwarmAmbientBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    // Long, slow loop — this is ambient wandering, not the sharper 4s tick
    // cycle the nest wasps use.
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 90))
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
      child: Opacity(
        opacity: widget.opacity,
        child: LayoutBuilder(
          builder: (context, constraints) => AnimatedBuilder(
            animation: _ctrl,
            builder: (_, __) => CustomPaint(
              size: Size(constraints.maxWidth, constraints.maxHeight),
              painter: _SwarmDriftPainter(t: _ctrl.value, count: widget.waspCount),
            ),
          ),
        ),
      ),
    );
  }
}

class _SwarmDriftPainter extends CustomPainter {
  final double t; // 0..1 looping
  final int count;

  _SwarmDriftPainter({required this.t, required this.count});

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    final rng = Random(1337); // fixed seed — a stable formation, not reshuffling every rebuild

    for (var i = 0; i < count; i++) {
      // Each wasp gets its own slow Lissajous-ish wander path so the swarm
      // doesn't move as one rigid block, plus its own tick phase so the
      // eye-flashes stay scattered across the whole layer.
      final freqX = 0.6 + rng.nextDouble() * 0.9;
      final freqY = 0.5 + rng.nextDouble() * 0.8;
      final phaseX = rng.nextDouble() * 2 * pi;
      final phaseY = rng.nextDouble() * 2 * pi;
      final baseX = rng.nextDouble() * size.width;
      final baseY = rng.nextDouble() * size.height;
      final rangeX = size.width * (0.06 + rng.nextDouble() * 0.10);
      final rangeY = size.height * (0.05 + rng.nextDouble() * 0.08);
      final waspSize = 10.0 + rng.nextDouble() * 14.0;
      final tickPhase = (t + rng.nextDouble()) % 1.0;

      final angle = t * 2 * pi;
      final x = (baseX + sin(angle * freqX + phaseX) * rangeX) % size.width;
      final y = (baseY + cos(angle * freqY + phaseY) * rangeY) % size.height;
      final heading = atan2(
        cos(angle * freqY + phaseY) * freqY,
        cos(angle * freqX + phaseX) * freqX,
      );

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(heading);
      paintMiniWasp(canvas, waspSize, tickPhase);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _SwarmDriftPainter old) => old.t != t || old.count != count;
}

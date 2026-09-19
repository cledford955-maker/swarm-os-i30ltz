// ═══════════════════════════════════════════════════════════════
// SWARM OS — Tap/interaction burst
// A quick scatter of small wasps flying outward and fading from
// wherever the user just interacted — makes the swarm theme felt on
// every click, not just visible in static decoration. Call
// triggerSwarmBurst(context, globalPosition) from any existing
// onTap/onTapDown handler; it doesn't need the widget tree
// restructured around it.
// ═══════════════════════════════════════════════════════════════

import 'dart:math';
import 'package:flutter/material.dart';
import 'swarm_motifs.dart';

/// Drops a short-lived overlay burst of wasps at [globalPosition] and
/// removes itself when the animation finishes. Safe to call rapidly (each
/// call is an independent overlay entry) and safe to call from a context
/// with no Overlay above it (just does nothing).
void triggerSwarmBurst(BuildContext context, Offset globalPosition, {int waspCount = 5}) {
  final overlay = Overlay.maybeOf(context);
  if (overlay == null) return;

  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _SwarmBurst(
      origin: globalPosition,
      waspCount: waspCount,
      onComplete: () => entry.remove(),
    ),
  );
  overlay.insert(entry);
}

class _SwarmBurst extends StatefulWidget {
  final Offset origin;
  final int waspCount;
  final VoidCallback onComplete;

  const _SwarmBurst({required this.origin, required this.waspCount, required this.onComplete});

  @override
  State<_SwarmBurst> createState() => _SwarmBurstState();
}

class _SwarmBurstState extends State<_SwarmBurst> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final List<double> _angles;

  @override
  void initState() {
    super.initState();
    final rng = Random();
    _angles = List.generate(widget.waspCount, (_) => rng.nextDouble() * 2 * pi);
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 550))
      ..forward().whenComplete(widget.onComplete);
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
          size: MediaQuery.sizeOf(context),
          painter: _BurstPainter(origin: widget.origin, angles: _angles, t: _ctrl.value),
        ),
      ),
    );
  }
}

class _BurstPainter extends CustomPainter {
  final Offset origin;
  final List<double> angles;
  final double t; // 0..1, one-shot

  _BurstPainter({required this.origin, required this.angles, required this.t});

  @override
  void paint(Canvas canvas, Size size) {
    // Ease-out distance, linear fade-out over the back half of the burst.
    final dist = 60.0 * (1 - pow(1 - t, 2));
    final opacity = t < 0.5 ? 1.0 : (1 - (t - 0.5) / 0.5);
    if (opacity <= 0) return;

    for (final angle in angles) {
      final pos = origin + Offset(cos(angle), sin(angle)) * dist;
      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.rotate(angle + pi / 2);
      canvas.saveLayer(
        const Rect.fromLTWH(-30, -30, 60, 60),
        Paint()..color = Color.fromRGBO(255, 255, 255, opacity.clamp(0.0, 1.0)),
      );
      paintMiniWasp(canvas, 12, t);
      canvas.restore();
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _BurstPainter old) => old.t != t;
}

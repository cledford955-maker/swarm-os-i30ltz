// ═══════════════════════════════════════════════════════════════
// SWARM OS — Shared swarm motif primitives
// One robotic-wasp painter reused everywhere the "infested" theme
// shows up: nest decorations (wasp_nest_decoration.dart), the
// ambient background layer, window-chrome sentinels, and tap/hover
// burst effects — so the wasp itself stays visually consistent
// instead of four slightly-different drawings drifting apart.
// ═══════════════════════════════════════════════════════════════

import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/swarm_colors.dart';

/// Paints one small robotic wasp centered at the canvas origin, facing up
/// local-+Y. Callers translate/rotate the canvas to position and orient it
/// before calling. [size] is the wasp's overall body length. [tickPhase]
/// (0..1, looping) drives the leg twitch and the red-eye flash — see
/// [tickPulse] for the flash curve shared with callers that want to know
/// when a flash is happening (e.g. to trigger a sound or haptic later).
void paintMiniWasp(Canvas canvas, double size, double tickPhase) {
  final legTwitch = sin(tickPhase * 2 * pi) * 0.12;
  final legPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = max(0.6, size * 0.06)
    ..color = Colors.black87;
  for (final side in [-1, 1]) {
    for (var i = 0; i < 3; i++) {
      final base = Offset(side * size * 0.18, size * (0.15 * i - 0.15));
      final tip = base + Offset(side * size * (0.45 + legTwitch), size * 0.25);
      canvas.drawLine(base, tip, legPaint);
    }
  }

  final body = Paint()..color = const Color(0xFF2B2D33);
  final stripe = Paint()..color = const Color(0xFF9A7A00);
  canvas.drawOval(
      Rect.fromCenter(center: const Offset(0, -0.15), width: size * 0.55, height: size * 0.5), body);
  canvas.drawOval(
      Rect.fromCenter(center: Offset(0, size * 0.55), width: size * 0.65, height: size * 0.9), body);
  for (var i = 0; i < 3; i++) {
    final y = size * (0.2 + i * 0.28);
    canvas.drawRect(Rect.fromLTWH(-size * 0.3, y, size * 0.6, size * 0.09), stripe);
  }

  final wing = Paint()..color = Colors.white.withValues(alpha: 0.10);
  canvas.drawOval(Rect.fromCenter(center: Offset(-size * 0.35, -size * 0.05), width: size * 0.5, height: size * 0.22), wing);
  canvas.drawOval(Rect.fromCenter(center: Offset(size * 0.35, -size * 0.05), width: size * 0.5, height: size * 0.22), wing);

  final tick = tickPulse(tickPhase);
  if (tick > 0) {
    final eyeGlow = Paint()
      ..color = SwarmColors.statusCritical.withValues(alpha: 0.35 * tick)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, size * 0.3);
    canvas.drawCircle(const Offset(0, -0.15), size * 0.22, eyeGlow);
  }
  final eye = Paint()..color = Color.lerp(const Color(0xFF3A0000), SwarmColors.statusCritical, tick)!;
  canvas.drawCircle(const Offset(0, -0.15), size * 0.09, eye);
}

/// A brief sharp pulse near phase==0, decaying quickly — "ticking", not a
/// smooth sine breathe. Shared so every wasp in the app flashes the same way.
double tickPulse(double phase) {
  const flashWidth = 0.12;
  final p = phase % 1.0;
  if (p > flashWidth) return 0;
  return 1 - p / flashWidth;
}

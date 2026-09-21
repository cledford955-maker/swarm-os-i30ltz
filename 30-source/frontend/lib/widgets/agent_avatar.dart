// ═══════════════════════════════════════════════════════════════
// SWARM OS — 3-D Agent Avatars & App Icon Orbs (2026-09-19)
//
// Every agent in the swarm gets a glossy 3-D orb avatar: a radial-
// gradient sphere with rim light, specular highlight, drop shadow
// and a slow shimmer sweep, its light source angled uniquely per
// agent so no two orbs read exactly the same. Key agents get fully
// custom animated emblems painted live on top of the orb —
// Lucille's expanding neural hex rings, Apex's rotating code
// brackets, Droid's blinking antennae, Dr. Boltz's lightning, Dr.
// Vital's EKG tracer, Nexus's radar sweep, and more. All remaining
// agents render their Material glyph inside the orb.
//
// App tiles (SwarmApp / HexAgent / drawer rows) use AppIconOrb —
// the same 3-D sphere treatment wrapped around any IconData, so
// every app icon across the desktop, drawer and hub matches the
// agents' look.
// ═══════════════════════════════════════════════════════════════

import 'dart:math';
import 'package:flutter/material.dart';
import '../models/agent.dart';
import '../theme/swarm_colors.dart';

/// Paints one animated emblem centered on the canvas origin.
/// [r] is the emblem's working radius (fits inside the orb),
/// [t] is the looping 0..1 animation phase, [accent] the agent color.
typedef AgentEmblemPainter = void Function(
    Canvas canvas, double r, double t, Color accent);

// ═══════════════════════════════════════════════════════════════
// EMBLEM REGISTRY — which agents get a fully custom animated emblem
// ═══════════════════════════════════════════════════════════════

final Map<String, AgentEmblemPainter> kAgentEmblems = {
  'lucille': _lucilleCore,
  'apex': _apexBrackets,
  'droid': _droidAntennae,
  'ui_tandem': _tandemDualOrbit,
  'antigravity': _antigravityOrbit,
  'antigravity_ide': _ideElectron,
  'vital': _vitalEkg,
  'therapist_1': _heartPulse,
  'nexus': _nexusRadar,
  'librarian': _librarianBook,
  'streamer': _streamerSignal,
  'document_manager': _docFolder,
  'prompt': _promptTerminal,
  'hud': _hudScan,
  'companion': _companionRings,
  'nemo': _nemoSail,
  'hermes': _hermesWing,
  'gemini_notebook': _geminiSparkle,
  'gmail_agent': _gmailFly,
  'keepit_agent': _keepitBulb,
  'daily_briefs': _briefsDoubleBolt,
  'dr_boltz': _boltzBolt,
};

// ═══════════════════════════════════════════════════════════════
// AGENT AVATAR — 3-D orb + animated emblem for one agent
// ═══════════════════════════════════════════════════════════════

class AgentAvatar extends StatefulWidget {
  final String agentId;
  final double size;

  /// Offline / inactive agents render dimmed.
  final bool dimmed;

  const AgentAvatar({
    super.key,
    required this.agentId,
    required this.size,
    this.dimmed = false,
  });

  /// Renders the agent's animated orb when [agentId] belongs to a real
  /// swarm agent, otherwise falls back to a plain 3-D icon orb — used by
  /// generic desktop tiles (apps, mock tools) that only carry an IconData.
  static Widget maybeFor({
    required String agentId,
    required IconData icon,
    required Color color,
    required double size,
    bool dimmed = false,
  }) {
    if (getAgent(agentId) != null) {
      return AgentAvatar(agentId: agentId, size: size, dimmed: dimmed);
    }
    return AppIconOrb(icon: icon, color: color, size: size, dimmed: dimmed);
  }

  @override
  State<AgentAvatar> createState() => _AgentAvatarState();
}

class _AgentAvatarState extends State<AgentAvatar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final agent = getAgent(widget.agentId);
    final accent = agent?.accent ?? SwarmColors.accent;
    final emblem = kAgentEmblems[widget.agentId];
    final icon = agent?.icon ?? Icons.smart_toy;

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Opacity(
        opacity: widget.dimmed ? 0.35 : 1.0,
        child: RepaintBoundary(
          child: AnimatedBuilder(
            animation: _ctrl,
            builder: (_, __) => CustomPaint(
              painter: _OrbPainter(
                accent: accent,
                t: _ctrl.value,
                icon: emblem == null ? icon : null,
                emblem: emblem,
                lightAngle: _lightAngleFor(widget.agentId),
                halo: emblem != null,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// APP ICON ORB — the same 3-D sphere around any IconData
// ═══════════════════════════════════════════════════════════════

class AppIconOrb extends StatefulWidget {
  final IconData icon;
  final Color color;
  final double size;
  final bool dimmed;

  const AppIconOrb({
    super.key,
    required this.icon,
    required this.color,
    required this.size,
    this.dimmed = false,
  });

  @override
  State<AppIconOrb> createState() => _AppIconOrbState();
}

class _AppIconOrbState extends State<AppIconOrb>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    // Slower than the agent avatars — app icons shimmer gently
    // instead of performing.
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3800),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Opacity(
        opacity: widget.dimmed ? 0.4 : 1.0,
        child: RepaintBoundary(
          child: AnimatedBuilder(
            animation: _ctrl,
            builder: (_, __) => CustomPaint(
              painter: _OrbPainter(
                accent: widget.color,
                t: _ctrl.value,
                icon: widget.icon,
                lightAngle: _lightAngleFor('app_${widget.icon.codePoint}'),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// ORB PAINTER — the 3-D sphere itself
// ═══════════════════════════════════════════════════════════════

/// Unique light-source angle per id so every orb is lit slightly
/// differently — top-left-ish, varied within a 90° spread.
double _lightAngleFor(String id) {
  var h = 0;
  for (final code in id.codeUnits) {
    h = (h * 31 + code) & 0x7fffffff;
  }
  return -pi * 0.75 + (h % 100) / 100 * pi * 0.5;
}

class _OrbPainter extends CustomPainter {
  final Color accent;
  final double t;
  final IconData? icon;
  final AgentEmblemPainter? emblem;
  final double lightAngle;

  /// Pulsing halo behind the sphere — animated agents only.
  final bool halo;

  _OrbPainter({
    required this.accent,
    required this.t,
    this.icon,
    this.emblem,
    required this.lightAngle,
    this.halo = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    if (r <= 0) return;
    final rect = Offset.zero & size;

    // 0. Pulsing halo — the animated agents breathe light.
    if (halo) {
      final pulse = 0.5 + 0.5 * sin(t * 2 * pi);
      canvas.drawCircle(
        c,
        r * 0.9,
        Paint()
          ..color = accent.withValues(alpha: 0.16 + 0.16 * pulse)
          ..maskFilter = MaskFilter.blur(BlurStyle.outer, r * 0.30),
      );
    }

    // 1. Drop shadow — the orb sits ON the surface, not painted flat.
    canvas.drawCircle(
      c + Offset(0, r * 0.10),
      r * 0.88,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.38)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.16),
    );

    // 2. Sphere body — off-center radial gradient reads as a lit ball.
    final hsl = HSLColor.fromColor(accent);
    final lightC =
        hsl.withLightness((hsl.lightness + 0.28).clamp(0.0, 1.0)).toColor();
    final darkC =
        hsl.withLightness((hsl.lightness * 0.42).clamp(0.0, 0.30)).toColor();
    canvas.drawCircle(
      c,
      r * 0.86,
      Paint()
        ..shader = RadialGradient(
          center: Alignment(cos(lightAngle) * 0.45, sin(lightAngle) * 0.45),
          radius: 1.15,
          colors: [lightC, accent, darkC],
          stops: const [0.0, 0.55, 1.0],
        ).createShader(rect),
    );

    // 3. Rim light — reflected light on the far edge.
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r * 0.82),
      lightAngle + pi * 0.60,
      pi * 0.80,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.06
        ..strokeCap = StrokeCap.round
        ..color = lightC.withValues(alpha: 0.45),
    );

    // 4. Specular highlight — glossy reflection near the light.
    canvas.drawCircle(
      c + Offset(cos(lightAngle), sin(lightAngle)) * r * 0.42,
      r * 0.20,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.30)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.10),
    );

    // 5. Slow shimmer band sweeping across the sphere.
    canvas.save();
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: c, radius: r * 0.86)));
    canvas.translate(c.dx, c.dy);
    canvas.rotate(t * 2 * pi);
    canvas.drawRect(
      Rect.fromCenter(center: Offset.zero, width: r * 2.4, height: r * 0.22),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.05)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.09)
        ..blendMode = BlendMode.plus,
    );
    canvas.restore();

    // 6. Emblem or glyph, centered on the sphere.
    canvas.save();
    canvas.translate(c.dx, c.dy);
    final emblemFn = emblem;
    if (emblemFn != null) {
      emblemFn(canvas, r * 0.60, t, accent);
    } else if (icon != null) {
      // Soft glow puddle under the glyph.
      canvas.drawCircle(
        Offset.zero,
        r * 0.42,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.10)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.14),
      );
      final tp = TextPainter(
        text: TextSpan(
          text: String.fromCharCode(icon!.codePoint),
          style: TextStyle(
            fontFamily: icon!.fontFamily,
            fontSize: r * 0.95,
            color: Colors.white.withValues(alpha: 0.95),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _OrbPainter old) =>
      old.t != t ||
      old.accent != accent ||
      old.icon != icon ||
      old.emblem != emblem ||
      old.halo != halo;
}

// ═══════════════════════════════════════════════════════════════
// ANIMATED EMBLEMS — one per featured agent
// ═══════════════════════════════════════════════════════════════

/// LUCILLE — expanding neural hex rings around a pulsing core.
void _lucilleCore(Canvas canvas, double r, double t, Color accent) {
  for (var i = 0; i < 3; i++) {
    final phase = (t + i / 3) % 1.0;
    final ringR = r * (0.35 + 0.65 * phase);
    final path = Path();
    for (var k = 0; k < 6; k++) {
      final a = k * pi / 3 - pi / 2;
      final p = Offset(cos(a) * ringR, sin(a) * ringR);
      k == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    path.close();
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.09 * (1 - phase * 0.5)
        ..color = accent.withValues(alpha: (1 - phase) * 0.85),
    );
  }
  final corePulse = 0.5 + 0.5 * sin(t * 2 * pi);
  canvas.drawCircle(
    Offset.zero,
    r * 0.32,
    Paint()..color = accent.withValues(alpha: 0.25 + 0.20 * corePulse),
  );
  canvas.drawCircle(
    Offset.zero,
    r * (0.17 + 0.05 * corePulse),
    Paint()..color = Colors.white.withValues(alpha: 0.95),
  );
}

/// APEX — rotating code brackets < / >.
void _apexBrackets(Canvas canvas, double r, double t, Color accent) {
  canvas.save();
  canvas.rotate(t * 2 * pi);
  final stroke = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = r * 0.15
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..color = accent;
  // '<'
  canvas.drawLine(Offset(-r * 0.30, -r * 0.52), Offset(-r * 0.72, 0), stroke);
  canvas.drawLine(Offset(-r * 0.30, r * 0.52), Offset(-r * 0.72, 0), stroke);
  // '>'
  canvas.drawLine(Offset(r * 0.30, -r * 0.52), Offset(r * 0.72, 0), stroke);
  canvas.drawLine(Offset(r * 0.30, r * 0.52), Offset(r * 0.72, 0), stroke);
  // center slash
  canvas.drawLine(
    Offset(-r * 0.10, r * 0.58),
    Offset(r * 0.10, -r * 0.58),
    stroke..color = Colors.white,
  );
  canvas.restore();
}

/// DROID — Android dome with blinking eyes and pulsing antennae.
void _droidAntennae(Canvas canvas, double r, double t, Color accent) {
  final line = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = r * 0.13
    ..strokeCap = StrokeCap.round
    ..color = accent;
  // Head dome
  canvas.drawArc(
    Rect.fromCircle(center: Offset(0, r * 0.18), radius: r * 0.58),
    pi,
    pi,
    false,
    line,
  );
  // Eyes (occasional blink)
  final blink = sin(t * 2 * pi) > 0.75 ? 0.12 : 1.0;
  canvas.drawCircle(
    Offset(-r * 0.22, -r * 0.05),
    r * 0.10,
    Paint()..color = Colors.white.withValues(alpha: blink),
  );
  canvas.drawCircle(
    Offset(r * 0.22, -r * 0.05),
    r * 0.10,
    Paint()..color = Colors.white.withValues(alpha: blink),
  );
  // Antennae with pulsing tips
  for (final s in [-1, 1]) {
    canvas.drawLine(
      Offset(s * r * 0.30, -r * 0.38),
      Offset(s * r * 0.52, -r * 0.72),
      line,
    );
    final pulse = 0.5 + 0.5 * sin(t * 2 * pi + (s > 0 ? pi : 0));
    canvas.drawCircle(
      Offset(s * r * 0.55, -r * 0.78),
      r * (0.08 + 0.05 * pulse),
      Paint()..color = Colors.white.withValues(alpha: 0.45 + 0.55 * pulse),
    );
  }
}

/// UI TANDEM — two comets (Claude white + DeepSeek violet) sharing one orbit.
void _tandemDualOrbit(Canvas canvas, double r, double t, Color accent) {
  final a = t * 2 * pi;
  canvas.drawOval(
    Rect.fromCenter(center: Offset(0, r * 0.05), width: r * 1.9, height: r * 1.0),
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.045
      ..color = accent.withValues(alpha: 0.35),
  );
  canvas.drawCircle(
    Offset(0, r * 0.05),
    r * 0.22,
    Paint()..color = accent.withValues(alpha: 0.9),
  );
  const violet = Color(0xFFD500F9);
  for (var i = 0; i < 7; i++) {
    final aa = a - i * 0.10;
    canvas.drawCircle(
      Offset(cos(aa) * r * 0.95, r * 0.05 + sin(aa) * r * 0.5),
      r * (0.11 - i * 0.012),
      Paint()..color = Colors.white.withValues(alpha: (1 - i / 7) * 0.85),
    );
  }
  for (var i = 0; i < 7; i++) {
    final aa = a + pi - i * 0.10;
    canvas.drawCircle(
      Offset(cos(aa) * r * 0.95, r * 0.05 + sin(aa) * r * 0.5),
      r * (0.11 - i * 0.012),
      Paint()..color = violet.withValues(alpha: (1 - i / 7) * 0.85),
    );
  }
}

/// ANTIGRAVITY — a comet orbiting a planet on a tilted ellipse.
void _antigravityOrbit(Canvas canvas, double r, double t, Color accent) {
  final a = t * 2 * pi;
  canvas.drawOval(
    Rect.fromCenter(center: Offset(0, r * 0.1), width: r * 1.7, height: r * 0.9),
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.04
      ..color = accent.withValues(alpha: 0.30),
  );
  canvas.drawCircle(
    Offset(0, r * 0.1),
    r * 0.28,
    Paint()..color = accent.withValues(alpha: 0.9),
  );
  for (var i = 0; i < 8; i++) {
    final aa = a - i * 0.09;
    canvas.drawCircle(
      Offset(cos(aa) * r * 0.85, r * 0.1 + sin(aa) * r * 0.45),
      r * (0.12 - i * 0.012),
      Paint()..color = Colors.white.withValues(alpha: (1 - i / 8) * 0.8),
    );
  }
}

/// ANTIGRAVITY IDE — code block with an electron dot orbiting it.
void _ideElectron(Canvas canvas, double r, double t, Color accent) {
  final rect = Rect.fromCenter(center: Offset.zero, width: r * 1.3, height: r * 0.95);
  final rrect = RRect.fromRectAndRadius(rect, Radius.circular(r * 0.14));
  canvas.drawRRect(rrect, Paint()..color = Colors.black.withValues(alpha: 0.45));
  canvas.drawRRect(
    rrect,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.09
      ..color = accent,
  );
  final stroke = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = r * 0.10
    ..strokeCap = StrokeCap.round
    ..color = Colors.white;
  canvas.drawLine(Offset(-r * 0.30, -r * 0.16), Offset(-r * 0.10, 0), stroke);
  canvas.drawLine(Offset(-r * 0.30, r * 0.16), Offset(-r * 0.10, 0), stroke);
  canvas.drawLine(Offset(r * 0.02, 0), Offset(r * 0.28, 0), stroke);
  final a = t * 2 * pi;
  canvas.drawCircle(
    Offset(cos(a) * r * 0.95, sin(a) * r * 0.95),
    r * 0.12,
    Paint()..color = Colors.white,
  );
}

/// DR. VITAL — EKG trace with a bright tracer sweeping across.
void _vitalEkg(Canvas canvas, double r, double t, Color accent) {
  final path = Path()
    ..moveTo(-r, 0)
    ..lineTo(-r * 0.55, 0)
    ..lineTo(-r * 0.42, -r * 0.30)
    ..lineTo(-r * 0.25, r * 0.42)
    ..lineTo(-r * 0.08, -r * 0.12)
    ..lineTo(r * 0.10, 0)
    ..lineTo(r, 0);
  final base = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = r * 0.11
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..color = accent.withValues(alpha: 0.45);
  canvas.drawPath(path, base);
  final sweep = t % 1.0;
  final tx = -r + sweep * 2 * r;
  canvas.save();
  canvas.clipRect(Rect.fromCenter(center: Offset(tx, 0), width: r * 0.55, height: r * 2));
  canvas.drawPath(
    path,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.13
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = Colors.white,
  );
  canvas.restore();
}

/// DR. ELARA — a heart with a double-thump heartbeat.
void _heartPulse(Canvas canvas, double r, double t, Color accent) {
  final beat = _heartbeat(t);
  final scale = 1.0 + 0.16 * beat;
  final path = _heartPath(r * 0.85 * scale);
  if (beat > 0.25) {
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.25 * beat)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.25),
    );
  }
  canvas.drawPath(path, Paint()..color = accent.withValues(alpha: 0.95));
}

Path _heartPath(double r) {
  return Path()
    ..moveTo(0, r * 0.95)
    ..cubicTo(-r * 1.15, r * 0.30, -r * 0.95, -r * 0.65, 0, -r * 0.28)
    ..cubicTo(r * 0.95, -r * 0.65, r * 1.15, r * 0.30, 0, r * 0.95)
    ..close();
}

/// Two quick thumps per cycle, like a real heartbeat.
double _heartbeat(double t) {
  double thump(double center) {
    var d = (t - center) % 1.0;
    if (d < 0) d += 1.0;
    return exp(-d * d * 55);
  }

  return thump(0.08) + 0.6 * thump(0.38);
}

/// NEXUS — radar rings with a rotating sweep and a passing blip.
void _nexusRadar(Canvas canvas, double r, double t, Color accent) {
  for (final f in [0.45, 0.75, 1.0]) {
    canvas.drawCircle(
      Offset.zero,
      r * f,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.05
        ..color = accent.withValues(alpha: 0.30),
    );
  }
  final a = t * 2 * pi;
  for (var i = 0; i < 12; i++) {
    final aa = a - i * 0.10;
    canvas.drawLine(
      Offset.zero,
      Offset(cos(aa), sin(aa)) * r,
      Paint()
        ..strokeWidth = r * 0.07
        ..strokeCap = StrokeCap.round
        ..color = accent.withValues(alpha: (1 - i / 12) * 0.75),
    );
  }
  const blipA = -pi / 3;
  final blip = Offset(cos(blipA), sin(blipA)) * r * 0.6;
  final d = ((a - blipA) % (2 * pi)) / (2 * pi);
  canvas.drawCircle(
    blip,
    r * (0.08 + 0.10 * (1 - d)),
    Paint()..color = Colors.white.withValues(alpha: (1 - d) * 0.9),
  );
}

/// LIBRARIAN — an open book with a fluttering right page.
void _librarianBook(Canvas canvas, double r, double t, Color accent) {
  final flip = sin(t * 2 * pi);
  canvas.drawPath(
    Path()
      ..moveTo(0, -r * 0.45)
      ..lineTo(-r * 0.85, -r * 0.62)
      ..lineTo(-r * 0.85, r * 0.38)
      ..lineTo(0, r * 0.55)
      ..close(),
    Paint()..color = Colors.white.withValues(alpha: 0.85),
  );
  canvas.drawPath(
    Path()
      ..moveTo(0, -r * 0.45)
      ..lineTo(r * 0.85, -r * 0.62 - flip * r * 0.18)
      ..lineTo(r * 0.85, r * 0.38 - flip * r * 0.18)
      ..lineTo(0, r * 0.55)
      ..close(),
    Paint()..color = Colors.white.withValues(alpha: 0.65),
  );
  canvas.drawLine(
    Offset(0, -r * 0.45),
    Offset(0, r * 0.55),
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.08
      ..strokeCap = StrokeCap.round
      ..color = accent,
  );
}

/// STREAMER — signal arcs rising from a broadcast dot.
void _streamerSignal(Canvas canvas, double r, double t, Color accent) {
  canvas.drawCircle(
    Offset(0, r * 0.55),
    r * 0.16,
    Paint()..color = Colors.white,
  );
  for (var i = 0; i < 3; i++) {
    final phase = (t * 1.5 + i / 3) % 1.0;
    canvas.drawArc(
      Rect.fromCircle(center: Offset(0, r * 0.55), radius: r * (0.25 + phase * 0.75)),
      -pi * 0.78,
      pi * 0.56,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.09
        ..strokeCap = StrokeCap.round
        ..color = accent.withValues(alpha: (1 - phase) * 0.9),
    );
  }
}

/// DOCUMENT MANAGER — a file sliding up out of its folder.
void _docFolder(Canvas canvas, double r, double t, Color accent) {
  final slide = (0.5 + 0.5 * sin(t * 2 * pi)) * r * 0.25;
  // File (drawn first — the folder covers its lower half).
  final fileRect = Rect.fromCenter(
    center: Offset(r * 0.02, -r * 0.42 - slide),
    width: r * 0.6,
    height: r * 0.85,
  );
  canvas.drawRRect(
    RRect.fromRectAndRadius(fileRect, Radius.circular(r * 0.06)),
    Paint()..color = Colors.white.withValues(alpha: 0.92),
  );
  final line = Paint()
    ..strokeWidth = r * 0.05
    ..strokeCap = StrokeCap.round
    ..color = accent.withValues(alpha: 0.8);
  canvas.drawLine(
    Offset(fileRect.left + r * 0.12, fileRect.top + r * 0.22),
    Offset(fileRect.right - r * 0.12, fileRect.top + r * 0.22),
    line,
  );
  canvas.drawLine(
    Offset(fileRect.left + r * 0.12, fileRect.top + r * 0.38),
    Offset(fileRect.right - r * 0.20, fileRect.top + r * 0.38),
    line,
  );
  // Folder body.
  canvas.drawPath(
    Path()
      ..moveTo(-r * 0.9, -r * 0.35)
      ..lineTo(-r * 0.28, -r * 0.35)
      ..lineTo(-r * 0.12, -r * 0.15)
      ..lineTo(r * 0.9, -r * 0.15)
      ..lineTo(r * 0.9, r * 0.62)
      ..lineTo(-r * 0.9, r * 0.62)
      ..close(),
    Paint()..color = accent,
  );
}

/// PROMPT — terminal window with a blinking cursor.
void _promptTerminal(Canvas canvas, double r, double t, Color accent) {
  final rect = Rect.fromCenter(center: Offset.zero, width: r * 1.5, height: r * 1.1);
  final rrect = RRect.fromRectAndRadius(rect, Radius.circular(r * 0.16));
  canvas.drawRRect(rrect, Paint()..color = Colors.black.withValues(alpha: 0.5));
  canvas.drawRRect(
    rrect,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.09
      ..color = accent,
  );
  final stroke = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = r * 0.10
    ..strokeCap = StrokeCap.round
    ..color = Colors.white;
  canvas.drawLine(Offset(-r * 0.42, -r * 0.22), Offset(-r * 0.16, 0), stroke);
  canvas.drawLine(Offset(-r * 0.42, r * 0.22), Offset(-r * 0.16, 0), stroke);
  if ((t * 2) % 1.0 < 0.55) {
    canvas.drawRect(
      Rect.fromLTWH(r * 0.08, -r * 0.20, r * 0.16, r * 0.40),
      Paint()..color = Colors.white,
    );
  }
}

/// HUD — monitor with a scan line sweeping down the screen.
void _hudScan(Canvas canvas, double r, double t, Color accent) {
  final rect = Rect.fromCenter(center: Offset(0, -r * 0.12), width: r * 1.5, height: r * 1.0);
  final rrect = RRect.fromRectAndRadius(rect, Radius.circular(r * 0.14));
  canvas.drawRRect(rrect, Paint()..color = Colors.black.withValues(alpha: 0.5));
  canvas.drawRRect(
    rrect,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.09
      ..color = accent,
  );
  final leg = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = r * 0.09
    ..strokeCap = StrokeCap.round
    ..color = accent;
  canvas.drawLine(Offset(0, rect.bottom), Offset(0, rect.bottom + r * 0.22), leg);
  canvas.drawLine(
    Offset(-r * 0.28, rect.bottom + r * 0.22),
    Offset(r * 0.28, rect.bottom + r * 0.22),
    leg,
  );
  final y = rect.top + ((t * 1.3) % 1.0) * rect.height;
  canvas.drawLine(
    Offset(rect.left + r * 0.06, y),
    Offset(rect.right - r * 0.06, y),
    Paint()
      ..strokeWidth = r * 0.07
      ..color = Colors.white.withValues(alpha: 0.85),
  );
}

/// COMPANION — phone radiating rising signal rings.
void _companionRings(Canvas canvas, double r, double t, Color accent) {
  final rect = Rect.fromCenter(center: Offset(0, r * 0.18), width: r * 0.62, height: r * 1.05);
  final rrect = RRect.fromRectAndRadius(rect, Radius.circular(r * 0.14));
  canvas.drawRRect(rrect, Paint()..color = accent.withValues(alpha: 0.95));
  canvas.drawCircle(Offset(0, r * 0.55), r * 0.07, Paint()..color = Colors.white);
  for (var i = 0; i < 3; i++) {
    final phase = (t + i / 3) % 1.0;
    canvas.drawArc(
      Rect.fromCircle(
        center: Offset(0, rect.top - r * 0.05),
        radius: r * (0.18 + phase * 0.55),
      ),
      -pi * 0.78,
      pi * 0.56,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.08
        ..strokeCap = StrokeCap.round
        ..color = Colors.white.withValues(alpha: (1 - phase) * 0.85),
    );
  }
}

/// NEMO — sailboat rocking on animated waves.
void _nemoSail(Canvas canvas, double r, double t, Color accent) {
  final rock = sin(t * 2 * pi) * 0.10;
  canvas.save();
  canvas.rotate(rock);
  canvas.drawPath(
    Path()
      ..moveTo(-r * 0.75, r * 0.30)
      ..lineTo(r * 0.75, r * 0.30)
      ..quadraticBezierTo(r * 0.45, r * 0.85, 0, r * 0.85)
      ..quadraticBezierTo(-r * 0.45, r * 0.85, -r * 0.75, r * 0.30)
      ..close(),
    Paint()..color = accent.withValues(alpha: 0.95),
  );
  canvas.drawLine(
    Offset(0, r * 0.30),
    Offset(0, -r * 0.75),
    Paint()
      ..strokeWidth = r * 0.08
      ..strokeCap = StrokeCap.round
      ..color = Colors.white,
  );
  canvas.drawPath(
    Path()
      ..moveTo(r * 0.08, -r * 0.70)
      ..lineTo(r * 0.08, r * 0.18)
      ..lineTo(r * 0.68, r * 0.18)
      ..close(),
    Paint()..color = Colors.white.withValues(alpha: 0.9),
  );
  canvas.restore();
  final wave = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = r * 0.07
    ..strokeCap = StrokeCap.round
    ..color = accent.withValues(alpha: 0.7);
  for (var i = 0; i < 2; i++) {
    final y = r * (1.02 + i * 0.22);
    final dx = sin(t * 2 * pi + i) * r * 0.12;
    canvas.drawLine(Offset(-r * 0.55 + dx, y), Offset(-r * 0.15 + dx, y), wave);
    canvas.drawLine(Offset(r * 0.15 + dx, y), Offset(r * 0.55 + dx, y), wave);
  }
}

/// HERMES — caduceus staff with flapping wings.
void _hermesWing(Canvas canvas, double r, double t, Color accent) {
  final flap = sin(t * 2 * pi) * 0.30;
  canvas.drawLine(
    Offset(0, -r * 0.55),
    Offset(0, r * 0.9),
    Paint()
      ..strokeWidth = r * 0.10
      ..strokeCap = StrokeCap.round
      ..color = accent,
  );
  canvas.drawCircle(Offset(0, -r * 0.72), r * 0.16, Paint()..color = Colors.white);
  for (final s in [-1, 1]) {
    canvas.save();
    canvas.translate(0, -r * 0.25);
    canvas.rotate(s * flap);
    canvas.drawArc(
      Rect.fromCircle(center: Offset(s * r * 0.35, 0), radius: r * 0.55),
      s > 0 ? -pi * 0.45 : -pi * 0.55,
      pi * 0.5,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.09
        ..strokeCap = StrokeCap.round
        ..color = Colors.white.withValues(alpha: 0.85),
    );
    canvas.restore();
  }
}

/// GEMINI NOTEBOOK — rotating four-point sparkle with an orbiting mote.
void _geminiSparkle(Canvas canvas, double r, double t, Color accent) {
  canvas.save();
  canvas.rotate(t * 2 * pi);
  final path = Path();
  for (var i = 0; i < 8; i++) {
    final a = i * pi / 4 - pi / 2;
    final rad = i.isEven ? r : r * 0.26;
    final p = Offset(cos(a) * rad, sin(a) * rad);
    i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
  }
  path.close();
  canvas.drawPath(path, Paint()..color = accent.withValues(alpha: 0.95));
  canvas.restore();
  final a = -t * 4 * pi;
  canvas.drawCircle(
    Offset(cos(a) * r * 1.15, sin(a) * r * 1.15),
    r * 0.14,
    Paint()..color = Colors.white.withValues(alpha: 0.9),
  );
}

/// GMAIL SENTINEL — envelope flying with whoosh lines.
void _gmailFly(Canvas canvas, double r, double t, Color accent) {
  final rect = Rect.fromCenter(center: Offset(r * 0.15, 0), width: r * 1.15, height: r * 0.8);
  final rrect = RRect.fromRectAndRadius(rect, Radius.circular(r * 0.10));
  canvas.drawRRect(rrect, Paint()..color = accent.withValues(alpha: 0.95));
  final flap = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = r * 0.09
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..color = Colors.white;
  canvas.drawLine(
    rect.topLeft + Offset(r * 0.08, r * 0.06),
    Offset(rect.center.dx, rect.center.dy + r * 0.08),
    flap,
  );
  canvas.drawLine(
    rect.topRight + Offset(-r * 0.08, r * 0.06),
    Offset(rect.center.dx, rect.center.dy + r * 0.08),
    flap,
  );
  for (var i = 0; i < 3; i++) {
    final phase = (t + i / 3) % 1.0;
    final x = rect.left - r * 0.15 - phase * r * 0.55;
    canvas.drawLine(
      Offset(x, -r * 0.22 + i * r * 0.22),
      Offset(x, r * 0.02 + i * r * 0.22),
      Paint()
        ..strokeWidth = r * 0.08
        ..strokeCap = StrokeCap.round
        ..color = Colors.white.withValues(alpha: (1 - phase) * 0.8),
    );
  }
}

/// KEEPIT — lightbulb with flickering rays.
void _keepitBulb(Canvas canvas, double r, double t, Color accent) {
  for (var i = 0; i < 6; i++) {
    final a = -pi / 2 + (i - 2.5) * 0.42;
    final flick = 0.5 + 0.5 * sin(t * 4 * pi + i * 1.9);
    canvas.drawLine(
      Offset(cos(a) * r * 0.72, sin(a) * r * 0.72),
      Offset(cos(a) * r * (0.95 + 0.10 * flick), sin(a) * r * (0.95 + 0.10 * flick)),
      Paint()
        ..strokeWidth = r * 0.08
        ..strokeCap = StrokeCap.round
        ..color = Colors.white.withValues(alpha: 0.25 + 0.55 * flick),
    );
  }
  canvas.drawCircle(
    Offset(0, -r * 0.10),
    r * 0.52,
    Paint()..color = accent.withValues(alpha: 0.95),
  );
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(0, r * 0.55), width: r * 0.46, height: r * 0.34),
      Radius.circular(r * 0.07),
    ),
    Paint()..color = Colors.white.withValues(alpha: 0.85),
  );
}

/// DAILY BRIEFS — two bolts alternating charge.
void _briefsDoubleBolt(Canvas canvas, double r, double t, Color accent) {
  final flashA = ((t * 2) % 1.0) < 0.5 ? 1.0 : 0.35;
  final flashB = flashA == 1.0 ? 0.35 : 1.0;
  _bolt(canvas, Offset(-r * 0.42, 0), r * 0.62, accent, flashA);
  _bolt(canvas, Offset(r * 0.42, 0), r * 0.62, accent, flashB);
}

/// DR. BOLTZ — a single lightning bolt with a sharp periodic flash.
void _boltzBolt(Canvas canvas, double r, double t, Color accent) {
  final p = t % 1.0;
  final flash = p < 0.14 ? 1 - p / 0.14 : 0.0;
  _bolt(canvas, Offset.zero, r * 0.95, accent, 0.35 + 0.65 * flash);
}

void _bolt(Canvas canvas, Offset at, double s, Color accent, double flash) {
  canvas.save();
  canvas.translate(at.dx, at.dy);
  final path = Path()
    ..moveTo(s * 0.18, -s)
    ..lineTo(-s * 0.40, s * 0.12)
    ..lineTo(-s * 0.04, s * 0.12)
    ..lineTo(-s * 0.18, s)
    ..lineTo(s * 0.40, -s * 0.12)
    ..lineTo(s * 0.04, -s * 0.12)
    ..close();
  if (flash > 0.5) {
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.5)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.35),
    );
  }
  canvas.drawPath(
    path,
    Paint()..color = Color.lerp(accent.withValues(alpha: 0.55), Colors.white, flash)!,
  );
  canvas.restore();
}

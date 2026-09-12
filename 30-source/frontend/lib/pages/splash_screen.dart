import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../services/sound_service.dart';

/// Cinematic splash screen for SWARM_OS CARE.
///
/// Timeline (10s):
///  0.0-1.5  –  Electric blue 1999 Pontiac Firebird Trans Am WS6 LS1 revs at dusk
///  1.5-3.5  –  Aggressive slow-motion donut with thick tire smoke
///  3.5-5.0  –  Car straightens and accelerates away, tail lights glowing
///  3.2-5.8  – Fire burns across the screen
///  4.5-10   – Dissolves into a surreal 3D wasp nest with red wasps
class SplashScreen extends StatefulWidget {
  final VoidCallback? onFinished;
  const SplashScreen({super.key, this.onFinished});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _progress;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..forward().whenComplete(_oFinish);
    _progress = CurvedAnimation(parent: _controller, curve: Curves.linear);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      SoundService.instance.playSplashSound();
    });
  }

  void _oFinish() {
    SoundService.instance.stop();
    widget.onFinished?.call();
  }

  @override
  void dispose() {
    SoundService.instance.stop();
    _controller.dispose();
    super.dispose();
  }

  double _opacity(double t, double start, double end) {
    if (t <= start) return 0;
    if (t >= end) return 1;
    return (t - start) / (end - start);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedBuilder(
            animation: _progress,
            builder: (context, child) {
              final p = _progress.value;
              final carOpacity =
                  p < 0.5 ? 1.0 : (1.0 - (p - 0.5) / 0.1).clamp(0.0, 1.0);
              final titleOpacity = 1.0 - _opacity(p, 0.3, 0.48);
              final nestOpacity = _opacity(p, 0.45, 0.72);

              return Stack(
                fit: StackFit.expand,
                children: [
                  // Trans Am scene
                  Opacity(
                    opacity: carOpacity,
                    child: CustomPaint(
                      painter: TransAmScenePainter(progress: p),
                    ),
                  ),

                  // Wasp nest
                  Opacity(
                    opacity: nestOpacity,
                    child: CustomPaint(
                      painter: WaspNestPainter(progress: p),
                    ),
                  ),

                  // Fire burn-up
                  IgnorePointer(
                    child: CustomPaint(
                      painter: FirePainter(progress: p),
                    ),
                  ),

                  // Title
                  Opacity(
                    opacity: titleOpacity,
                    child: const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            size: 64,
                            color: Color(0xFF64DD45),
                          ),
                          SizedBox(height: 10),
                          Text(
                            'SWARM_OS CARE',
                            style: TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 5,
                              shadows: [
                                Shadow(
                                  color: Color(0xFFFF8800),
                                  blurRadius: 24,
                                  offset: Offset(0, 0),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

// ----------------------------------------------------------------------
// Trans Am scene painter
// ----------------------------------------------------------------------
class TransAmScenePainter extends CustomPainter {
  final double progress;
  TransAmScenePainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    _drawEnvironment(canvas, size);
    if (progress >= 0.5) return;

    if (progress < 0.15) {
      // Rev phase – car sits at dusk, vibrating with engine
      final p = progress / 0.15;
      final y = size.height * 0.66 + math.sin(p * math.pi * 8) * 5;
      final rot = math.sin(p * math.pi * 7) * 0.03;
      _drawCar(
        canvas,
        pos: Offset(size.width / 2, y),
        rotation: rot,
        scale: 1.7,
        tailLights: false,
        headLights: false,
      );
    } else if (progress < 0.35) {
      // Donut
      final p = (progress - 0.15) / 0.2;
      _drawDonut(canvas, size, p);
    } else {
      // Accelerate away
      final p = (progress - 0.35) / 0.15;
      _drawAccelerate(canvas, size, p);
    }
  }

  // ---------------------------------------------------------------
  void _drawEnvironment(Canvas canvas, Size size) {
    // Dusk sky
    final sky = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFF0A0A18),
          Color(0xFF1B102A),
          Color(0xFF3A2440),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height * 0.3));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height * 0.3), sky);

    // Asphalt lot
    final ground = Paint()..color = const Color(0xFF0E1012);
    canvas.drawRect(Rect.fromLTWH(0, size.height * 0.3, size.width, size.height * 0.7), ground);

    // Horizon glow
    final glow = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFF5A3A5A).withValues(alpha: 0.5),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, size.height * 0.28, size.width, size.height * 0.08));
    canvas.drawRect(
        Rect.fromLTWH(0, size.height * 0.28, size.width, size.height * 0.08), glow);

    // Street lamp glow
    final lampX = size.width * 0.08;
    final lampY = size.height * 0.3;
    canvas.drawLine(
      Offset(lampX, size.height * 0.46),
      Offset(lampX, lampY),
      Paint()
        ..color = const Color(0xFF202020)
        ..strokeWidth = 4,
    );
    canvas.drawCircle(Offset(lampX, lampY), 3, Paint()..color = Colors.amber);
    final lampGlow = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.amber.withValues(alpha: 0.22),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: Offset(lampX, lampY), radius: 70));
    canvas.drawCircle(Offset(lampX, lampY), 70, lampGlow);
  }

  // ---------------------------------------------------------------
  void _drawDonut(Canvas canvas, Size size, double p) {
    final center = Offset(size.width / 2, size.height * 0.62);
    final radius = size.width * 0.20;
    final ang = p * 2 * math.pi * 1.5;
    final pos = Offset(
      center.dx + math.cos(ang) * radius,
      center.dy + math.sin(ang) * radius * 0.7,
    );
    final heading = ang + math.pi / 2 + 0.45;

    // Rubber skid marks
    final skid = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = const Color(0xFF1A1A1A).withValues(alpha: 0.5 * math.sin(math.pi * p));
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - 18),
      -math.pi / 2,
      p * 2 * math.pi * 1.5,
      false,
      skid,
    );
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius + 18),
      -math.pi / 2,
      p * 2 * math.pi * 1.5,
      false,
      skid,
    );

    // Thick tire smoke
    _drawDonutSmoke(canvas, size, p);

    _drawCar(
      canvas,
      pos: pos,
      rotation: heading,
      scale: 1.5,
      tailLights: true,
      headLights: true,
    );
  }

  void _drawDonutSmoke(Canvas canvas, Size size, double p) {
    final center = Offset(size.width / 2, size.height * 0.62);
    final radius = size.width * 0.20;
    const count = 70;

    for (var i = 0; i < count; i++) {
      final seed = _frac(i * 127.1);
      final spawn = seed * 0.85;
      final age = p - spawn;
      if (age < 0 || age > 1.0) continue;

      final sa = spawn * 2 * math.pi * 1.5;
      final carPos = Offset(
        center.dx + math.cos(sa) * radius,
        center.dy + math.sin(sa) * radius * 0.7,
      );
      final heading = sa + math.pi / 2 + 0.45;

      final localX = (seed > 0.5 ? 1.0 : -1.0) * 20;
      const localY = 45.0;
      final cosH = math.cos(heading);
      final sinH = math.sin(heading);
      final world = Offset(
        carPos.dx + localX * cosH - localY * sinH,
        carPos.dy + localX * sinH + localY * cosH,
      );

      final vel = Offset(
        -math.sin(heading) + (seed * 2 - 1) * 0.6,
        math.cos(heading) + (seed * 2 - 1) * 0.6,
      ) * (14 + seed * 30);

      final pt = world + vel * age;
      final alpha = (1 - age) * 0.45;
      final rad = 5 + age * 26;
      canvas.drawCircle(
        pt,
        rad,
        Paint()..color = Colors.white.withValues(alpha: alpha),
      );
    }
  }

  void _drawAccelerate(Canvas canvas, Size size, double p) {
    final start = Offset(size.width / 2, size.height * 0.62);
    final end = Offset(size.width / 2, size.height * 0.10);
    final pos = Offset.lerp(start, end, p)!;
    final carScale = 1.5 - 1.2 * p;
    final rear = pos + Offset(0, 34 * carScale);

    // Smoke trail behind accelerating car
    for (var i = 0; i < 12; i++) {
      final t = i / 12;
      final y = rear.dy + t * 140 * (1 + p);
      final alpha = (1 - t) * 0.40 * (1 - p * 0.5);
      final rad = 6 + t * 30;
      canvas.drawCircle(
        Offset(rear.dx, y),
        rad,
        Paint()..color = Colors.white.withValues(alpha: alpha),
      );
    }

    // Rubber streaks leading to straight line
    final streakPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..color = Colors.black.withValues(alpha: 0.5 * (1 - p));
    canvas.drawLine(
      Offset(size.width / 2 - 30, start.dy),
      Offset(size.width / 2 - 30, pos.dy + 34),
      streakPaint,
    );
    canvas.drawLine(
      Offset(size.width / 2 + 30, start.dy),
      Offset(size.width / 2 + 30, pos.dy + 34),
      streakPaint,
    );

    _drawCar(
      canvas,
      pos: pos,
      rotation: 0,
      scale: carScale,
      tailLights: true,
      headLights: false,
    );
  }

  // ---------------------------------------------------------------
  void _drawCar(
    Canvas canvas, {
    required Offset pos,
    required double rotation,
    required double scale,
    required bool tailLights,
    required bool headLights,
  }) {
    canvas.save();
    canvas.translate(pos.dx, pos.dy);
    canvas.rotate(rotation);
    canvas.scale(scale);

    // Shadow
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(6, 10), width: 104, height: 158),
      Paint()..color = Colors.black.withValues(alpha: 0.55),
    );

    // Body – electric blue metallic
    final bodyPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFF2E86FF),
          Color(0xFF083F9E),
        ],
      ).createShader(Rect.fromCircle(center: Offset.zero, radius: 80));
    canvas.drawPath(_carBodyPath(), bodyPaint);

    // Hood highlight
    final hoodPaint = Paint()..color = const Color(0xFF174A9E).withValues(alpha: 0.6);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: const Offset(0, -52), width: 52, height: 38),
        const Radius.circular(4),
      ),
      hoodPaint,
    );

    // Ram-air nostrils
    final nostrilPaint = Paint()..color = const Color(0xFF061C3C);
    canvas.save();
    canvas.translate(-11, -50);
    canvas.rotate(0.15);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: 13, height: 30),
        const Radius.circular(3),
      ),
      nostrilPaint,
    );
    canvas.restore();
    canvas.save();
    canvas.translate(11, -50);
    canvas.rotate(-0.15);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: 13, height: 30),
        const Radius.circular(3),
      ),
      nostrilPaint,
    );
    canvas.restore();

    // Windshield
    final wind = Path()
      ..moveTo(-25, -28)
      ..lineTo(25, -28)
      ..lineTo(17, -9)
      ..lineTo(-17, -9)
      ..close();
    canvas.drawPath(wind, Paint()..color = const Color(0xFF0B1733).withValues(alpha: 0.92));

    // Roof
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: const Offset(0, 10), width: 36, height: 30),
        const Radius.circular(4),
      ),
      Paint()..color = const Color(0xFF123A6E),
    );

    // Rear window
    final rWind = Path()
      ..moveTo(-17, 28)
      ..lineTo(17, 28)
      ..lineTo(22, 42)
      ..lineTo(-22, 42)
      ..close();
    canvas.drawPath(rWind, Paint()..color = const Color(0xFF0B1733).withValues(alpha: 0.92));

    // WS6 spoiler
    final spoilerPaint = Paint()..color = const Color(0xFF111111);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: const Offset(0, 56), width: 92, height: 14),
        const Radius.circular(3),
      ),
      spoilerPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: const Offset(0, 49), width: 32, height: 8),
        const Radius.circular(3),
      ),
      spoilerPaint,
    );

    // Tail lights + glow
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: const Offset(0, 66), width: 42, height: 5),
        const Radius.circular(2),
      ),
      Paint()..color = Colors.red.shade600,
    );
    if (tailLights) {
      final glow = Paint()
        ..shader = RadialGradient(
          colors: [Colors.red.withValues(alpha: 0.85), Colors.transparent],
        ).createShader(Rect.fromCircle(center: const Offset(0, 66), radius: 38));
      canvas.drawCircle(const Offset(0, 66), 38, glow);
    }

    // Headlights
    if (headLights) {
      final hlPaint = Paint()..color = Colors.white.withValues(alpha: 0.85);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: const Offset(-16, -72), width: 16, height: 4),
          const Radius.circular(2),
        ),
        hlPaint,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: const Offset(16, -72), width: 16, height: 4),
          const Radius.circular(2),
        ),
        hlPaint,
      );
    }

    // Mirrors
    final mirrorPaint = Paint()..color = const Color(0xFF101010);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: const Offset(-34, -18), width: 6, height: 10),
        const Radius.circular(2),
      ),
      mirrorPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: const Offset(34, -18), width: 6, height: 10),
        const Radius.circular(2),
      ),
      mirrorPaint,
    );

    canvas.restore();
  }

  Path _carBodyPath() {
    final p = Path();
    p.moveTo(0, -80);
    p.quadraticBezierTo(28, -76, 42, -46);
    p.lineTo(37, -4);
    p.quadraticBezierTo(32, 24, 24, 36);
    p.quadraticBezierTo(29, 44, 34, 54);
    p.quadraticBezierTo(16, 66, 0, 74);
    p.quadraticBezierTo(-16, 66, -34, 54);
    p.quadraticBezierTo(-29, 44, -24, 36);
    p.quadraticBezierTo(-32, 24, -37, -4);
    p.lineTo(-42, -46);
    p.quadraticBezierTo(-28, -76, 0, -80);
    p.close();
    return p;
  }

  double _frac(double x) => x - x.floorToDouble();

  @override
  bool shouldRepaint(covariant TransAmScenePainter old) =>
      old.progress != progress;
}

// ----------------------------------------------------------------------
// Fire burn-up painter
// ----------------------------------------------------------------------
class FirePainter extends CustomPainter {
  final double progress;
  FirePainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width * 0.75;
    final intensity = _curve(progress, 0.28, 0.42, 0.55, 0.72);
    if (intensity <= 0) return;

    const count = 120;
    const golden = 2.399963;

    for (var i = 0; i < count; i++) {
      final h = _frac(i * 0.6180339887);
      final dist = h * maxRadius * intensity;
      final angle = i * golden + progress * 1.7;
      final x = center.dx + math.cos(angle) * dist;
      final y = center.dy + math.sin(angle) * dist;
      final flick = math.sin(progress * 45 + i * 3).abs() * 0.35 + 0.65;
      final alpha = (1 - dist / maxRadius) * intensity * flick * 0.9;
      const r = 255;
      final g = (80 + h * 120).clamp(0, 255).toInt();
      canvas.drawCircle(
        Offset(x, y),
        (2.5 + h * 3.5) * intensity,
        Paint()
          ..color = Color.fromRGBO(r, g, 0, alpha.clamp(0.0, 1.0))
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5),
      );
    }

    // Central glow
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.orange.withValues(alpha: (0.55 * intensity).clamp(0.0, 1.0)),
          Colors.deepOrange.withValues(alpha: (0.18 * intensity).clamp(0.0, 1.0)),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: maxRadius / 1.6));
    canvas.drawCircle(center, maxRadius / 1.6, glowPaint);
  }

  double _curve(double t, double a, double b, double c, double d) {
    if (t <= a || t >= d) return 0;
    if (t >= b && t <= c) return 1;
    if (t < b) return (t - a) / (b - a);
    return 1 - (t - c) / (d - c);
  }

  double _frac(double x) => x - x.floorToDouble();

  @override
  bool shouldRepaint(covariant FirePainter old) =>
      old.progress != progress;
}

// ----------------------------------------------------------------------
// Wasp nest painter – hexagon cells + red wasps
// ----------------------------------------------------------------------
class WaspNestPainter extends CustomPainter {
  final double progress;
  WaspNestPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    _drawNest(canvas, size);
    _drawWasps(canvas, size);
  }

  void _drawNest(Canvas canvas, Size size) {
    const cellRadius = 18.0;
    const dx = cellRadius * 1.5;
    final dy = cellRadius * math.sqrt(3);
    final cols = (size.width / dx).ceil() + 2;
    final rows = (size.height / dy).ceil() + 2;

    for (var row = 0; row < rows; row++) {
      for (var col = 0; col < cols; col++) {
        final offX = row.isEven ? 0.0 : dx / 2;
        final center = Offset(col * dx + offX, row * dy);
        if (center.dx > size.width + 20 || center.dx < -20) continue;
        if (center.dy > size.height + 20 || center.dy < -20) continue;

        final depth = _frac(row * 31 + col * 17);
        final base = HSLColor.fromAHSL(
          1,
          35 + depth * 25,
          0.5 + depth * 0.3,
          0.16 + depth * 0.12,
        ).toColor();

        final hex = _hexPath(center, cellRadius);
        canvas.drawPath(hex, Paint()..color = base);

        // Gloss
        final gloss = Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withValues(alpha: 0.10),
              Colors.black.withValues(alpha: 0.18),
            ],
          ).createShader(
            Rect.fromCircle(center: center, radius: cellRadius),
          );
        canvas.drawPath(hex, gloss);

        // Translucent larva
        if (_frac(row * 13 + col * 29) > 0.62) {
          final larvaPaint = Paint()
            ..color = Colors.amber.shade100.withValues(alpha: 0.45);
          final path = Path()
            ..arcTo(
              Rect.fromCircle(
                center: center.translate(-4, -4),
                radius: cellRadius * 0.45,
              ),
              0,
              math.pi * 1.4,
              false,
            );
          canvas.drawPath(path, larvaPaint);
        }
      }
    }
  }

  Path _hexPath(Offset center, double radius) {
    final path = Path();
    for (var i = 0; i < 6; i++) {
      final angle = math.pi / 3 * i - math.pi / 6;
      final x = center.dx + radius * math.cos(angle);
      final y = center.dy + radius * math.sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    return path;
  }

  void _drawWasps(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    const count = 12;

    for (var i = 0; i < count; i++) {
      final t = progress * 4.0 + i * 0.77;
      final x = center.dx +
          math.sin(t) * size.width * 0.30 +
          math.sin(i * 3.1 + progress * 5.5) * 14;
      final y = center.dy +
          math.cos(t * 1.31) * size.height * 0.26 +
          math.cos(i * 2.7 + progress * 4.1) * 14;
      final angle = math.atan2(center.dy - y, center.dx - x);
      final flap = math.sin(progress * 28 + i * 5).abs();
      _drawWasp(canvas, Offset(x, y), angle, flap);
    }
  }

  void _drawWasp(Canvas canvas, Offset pos, double angle, double wingFlap) {
    canvas.save();
    canvas.translate(pos.dx, pos.dy);
    canvas.rotate(angle);

    // Body – black
    final bodyPaint = Paint()..color = const Color(0xFF131313);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: 10, height: 16),
        const Radius.circular(5),
      ),
      bodyPaint,
    );

    // Red stripes
    final stripePaint = Paint()..color = const Color(0xFFE53935);
    canvas.drawRect(
      Rect.fromCenter(center: const Offset(0, -2), width: 10, height: 2),
      stripePaint,
    );
    canvas.drawRect(
      Rect.fromCenter(center: const Offset(0, 2), width: 10, height: 2),
      stripePaint,
    );

    // Head
    canvas.drawCircle(const Offset(0, -8), 3, bodyPaint);

    // Angry eyes
    final eyePaint = Paint()..color = Colors.white;
    canvas.drawCircle(const Offset(-1.5, -9.5), 1.0, eyePaint);
    canvas.drawCircle(const Offset(1.5, -9.5), 1.0, eyePaint);

    // Wings
    final wingPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.35 + wingFlap * 0.30);
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(-6, -3), width: 12, height: 6),
      wingPaint,
    );
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(6, -3), width: 12, height: 6),
      wingPaint,
    );

    canvas.restore();
  }

  double _frac(double x) => x - x.floorToDouble();

  @override
  bool shouldRepaint(covariant WaspNestPainter old) =>
      old.progress != progress;
}
// Garden mode foreground: blunts burning in an ashtray, smoke rising from the
// embers, plus a slow haze drifting up the whole screen.
//
// Each blunt takes a drag every ~9 s: the ember flares and a thicker plume
// rises for a couple of seconds, then it settles back to a thin curl.
//
// Smoke is a particle system drawn with one drawAtlas call per frame from a
// single soft puff sprite, which keeps it cheap on integrated graphics. The
// particle maths (SmokeSystem) is separate from the widget so it can be tested
// without a screen.

import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

// ─── Particle model ──────────────────────────────────────────────────────────

class SmokeEmitter {
  const SmokeEmitter(
    this.at, {
    this.rate = 10,
    this.spread = 0,
    this.size = 1,
    this.alpha = 1,
    this.rise = 1,
  });

  final Offset at;
  final double rate; // puffs per second
  final double spread; // puffs start up to this many px either side of [at]
  final double size; // scales puff size
  final double alpha; // scales puff opacity
  final double rise; // scales how fast it climbs
}

class SmokeParticle {
  const SmokeParticle({
    required this.born,
    required this.x,
    required this.y,
    required this.rise,
    required this.sway,
    required this.swayHz,
    required this.phase,
    required this.drift,
    required this.size0,
    required this.size1,
    required this.life,
    required this.alpha,
    required this.rot,
    required this.rotSpeed,
  });

  final double born, x, y;
  final double rise; // px/s
  final double sway, swayHz, phase; // side-to-side wander
  final double drift; // px/s of steady wind
  final double size0, size1; // diameter at birth / at death, px
  final double life; // seconds
  final double alpha; // peak opacity
  final double rot, rotSpeed;

  double progress(double now) => ((now - born) / life).clamp(0.0, 1.0);

  Offset positionAt(double now) {
    final age = now - born;
    final t = progress(now);
    final dy = rise * age * (1 - 0.35 * t); // slows as it thins out
    final dx = drift * age + sway * (0.25 + 1.2 * t) * sin(phase + swayHz * 2 * pi * age);
    return Offset(x + dx, y - dy);
  }

  double sizeAt(double now) => size0 + (size1 - size0) * sqrt(progress(now));

  /// Fades in over the first 7% of its life, then thins out to nothing.
  double alphaAt(double now) {
    final t = progress(now);
    return alpha * min(1.0, t / 0.07) * pow(1 - t, 1.5).toDouble();
  }

  double rotationAt(double now) => rot + rotSpeed * (now - born);
}

class SmokeSystem {
  SmokeSystem({Random? random, this.maxParticles = 360}) : _random = random ?? Random();

  final Random _random;
  final int maxParticles;
  final List<SmokeParticle> particles = [];
  final List<double> _owed = []; // fractional puffs carried between frames

  /// Seconds since the system started.
  double now = 0;

  /// Advance by [dt] seconds: age out finished puffs and spawn new ones from
  /// [emitters] at their own rates.
  void update(double dt, List<SmokeEmitter> emitters) {
    now += dt;
    particles.removeWhere((p) => now - p.born >= p.life);
    while (_owed.length < emitters.length) {
      _owed.add(0);
    }
    for (var i = 0; i < emitters.length; i++) {
      _owed[i] = min(_owed[i] + emitters[i].rate * dt, 3.0);
      while (_owed[i] >= 1 && particles.length < maxParticles) {
        _owed[i] -= 1;
        particles.add(_spawn(emitters[i]));
      }
    }
  }

  SmokeParticle _spawn(SmokeEmitter e) {
    final r = _random;
    double between(double a, double b) => a + r.nextDouble() * (b - a);
    return SmokeParticle(
      born: now,
      x: e.at.dx + between(-e.spread, e.spread),
      y: e.at.dy,
      rise: between(46, 84) * e.rise,
      sway: between(10, 26) * (0.6 + 0.4 * e.size),
      swayHz: between(0.16, 0.38),
      phase: between(0, 2 * pi),
      drift: between(-16, 2), // light breeze, mostly leftward — into the scene
      size0: between(16, 26) * e.size,
      size1: between(95, 150) * e.size,
      life: between(5.5, 8.5),
      alpha: between(0.30, 0.48) * e.alpha,
      rot: between(0, 2 * pi),
      rotSpeed: between(-0.35, 0.35),
    );
  }
}

// ─── Blunt layout ────────────────────────────────────────────────────────────

class _BluntSpec {
  const _BluntSpec(this.dx, this.dy, this.angle, this.length, this.thickness);
  final double dx, dy; // centre, as a fraction of tray width from the tray centre
  final double angle; // radians; negative tilts the lit end up
  final double length, thickness; // fractions of tray width
}

/// Where the ashtray and blunts sit for a given screen size: bottom right,
/// leaving the left for the strain card.
class GardenBluntLayout {
  GardenBluntLayout(Size size) {
    trayWidth = (size.width * 0.22).clamp(220.0, 380.0);
    tray = Rect.fromCenter(
      center: Offset(size.width - trayWidth * 0.62 - 28, size.height - trayWidth * 0.2 - 34),
      width: trayWidth,
      height: trayWidth * 0.26,
    );
  }

  static const _specs = [
    _BluntSpec(0.00, -0.125, -0.36, 0.80, 0.078), // back
    _BluntSpec(0.02, -0.050, -0.24, 0.86, 0.084),
    _BluntSpec(0.00, 0.025, -0.12, 0.74, 0.076), // front
  ];

  late final double trayWidth;
  late final Rect tray;

  int get count => _specs.length;

  Offset center(int i) =>
      tray.center + Offset(_specs[i].dx * trayWidth, _specs[i].dy * trayWidth);
  double angle(int i) => _specs[i].angle;
  double length(int i) => _specs[i].length * trayWidth;
  double thickness(int i) => _specs[i].thickness * trayWidth;

  /// The glowing end, in screen coordinates.
  Offset tip(int i) {
    final a = angle(i);
    return center(i) + Offset(cos(a), sin(a)) * (length(i) / 2);
  }

  /// 0..1 bump while blunt [i] is mid-drag; each blunt has its own rhythm.
  static double puff(int i, double now) {
    final cycle = 8.5 + i * 1.7;
    final phase = (now + i * 2.6) % cycle;
    return phase < 2.2 ? sin(pi * phase / 2.2) : 0;
  }

  static double ember(int i, double now) {
    final flicker = 0.10 * sin(now * 7.3 + i * 1.9) + 0.06 * sin(now * 13.1 + i);
    return (0.72 + flicker + 0.45 * puff(i, now)).clamp(0.2, 1.3);
  }
}

// ─── Widget ──────────────────────────────────────────────────────────────────

class GardenSmoke extends StatefulWidget {
  const GardenSmoke({super.key, this.accent = const Color(0xFF4CAF50)});

  /// Tints the smoke very slightly toward the current strain's colour.
  final Color accent;

  @override
  State<GardenSmoke> createState() => _GardenSmokeState();
}

class _GardenSmokeState extends State<GardenSmoke> with SingleTickerProviderStateMixin {
  final _system = SmokeSystem();
  final _frame = ValueNotifier<int>(0);
  late final Ticker _ticker;
  Duration _last = Duration.zero;
  Size _size = Size.zero;
  bool _warmed = false;
  ui.Image? _sprite;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick)..start();
    _makePuffSprite().then((img) {
      if (!mounted) {
        img.dispose();
        return;
      }
      setState(() => _sprite = img);
    });
  }

  @override
  void dispose() {
    _ticker.dispose();
    _frame.dispose();
    _sprite?.dispose();
    super.dispose();
  }

  /// One soft cloud-like blob (three overlapping, smoothly fading lobes), white,
  /// so it can be tinted per particle. Few, large lobes: many small ones read
  /// as speckle once the puff is scaled down.
  static Future<ui.Image> _makePuffSprite() {
    const s = 128.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, s, s));
    const lobes = [
      (Offset(s * 0.50, s * 0.50), s * 0.42),
      (Offset(s * 0.40, s * 0.57), s * 0.30),
      (Offset(s * 0.61, s * 0.43), s * 0.30),
    ];
    for (final (c, r) in lobes) {
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..shader = ui.Gradient.radial(
            c,
            r,
            [
              Colors.white.withValues(alpha: 0.50),
              Colors.white.withValues(alpha: 0.30),
              Colors.white.withValues(alpha: 0.10),
              Colors.white.withValues(alpha: 0),
            ],
            const [0, 0.35, 0.70, 1],
          ),
      );
    }
    return recorder.endRecording().toImage(s.toInt(), s.toInt());
  }

  List<SmokeEmitter> _emitters(GardenBluntLayout layout) {
    final now = _system.now;
    return [
      for (var i = 0; i < layout.count; i++)
        () {
          final p = GardenBluntLayout.puff(i, now);
          return SmokeEmitter(
            layout.tip(i),
            rate: 9 + 26 * p,
            spread: 3,
            size: 0.8 + 0.7 * p,
            alpha: 0.8 + 0.35 * p,
            rise: 1 + 0.15 * p,
          );
        }(),
      // Haze: big, faint, slow wisps welling up from below the whole screen.
      SmokeEmitter(
        Offset(_size.width / 2, _size.height + 30),
        rate: 1.1,
        spread: _size.width / 2,
        size: 3.0,
        alpha: 0.2,
        rise: 1.5,
      ),
    ];
  }

  void _tick(Duration elapsed) {
    final dt = ((elapsed - _last).inMicroseconds / 1e6).clamp(0.0, 0.1);
    _last = elapsed;
    if (_size.isEmpty) return;
    final layout = GardenBluntLayout(_size);
    if (!_warmed) {
      // Start with smoke already in the air instead of an empty screen.
      _warmed = true;
      for (var i = 0; i < 180; i++) {
        _system.update(1 / 30, _emitters(layout));
      }
    }
    _system.update(dt, _emitters(layout));
    _frame.value++;
  }

  @override
  Widget build(BuildContext context) {
    final tint = Color.lerp(const Color(0xFFDAD6E2), widget.accent, 0.10)!;
    return IgnorePointer(
      child: LayoutBuilder(builder: (_, constraints) {
        _size = constraints.biggest;
        return RepaintBoundary(
          child: CustomPaint(
            size: Size.infinite,
            painter: _GardenSmokePainter(
              system: _system,
              sprite: _sprite,
              tint: tint,
              repaint: _frame,
            ),
          ),
        );
      }),
    );
  }
}

// ─── Painter ─────────────────────────────────────────────────────────────────

class _GardenSmokePainter extends CustomPainter {
  _GardenSmokePainter({
    required this.system,
    required this.sprite,
    required this.tint,
    required Listenable repaint,
  }) : super(repaint: repaint);

  final SmokeSystem system;
  final ui.Image? sprite;
  final Color tint;

  static const _shadeColor = Color(0xFF14101C);

  @override
  void paint(Canvas canvas, Size size) {
    final layout = GardenBluntLayout(size);
    final now = system.now;

    _paintTray(canvas, layout);
    for (var i = 0; i < layout.count; i++) {
      _paintBlunt(canvas, layout, i, GardenBluntLayout.ember(i, now));
    }
    _paintSmoke(canvas, size, now);
  }

  void _paintSmoke(Canvas canvas, Size size, double now) {
    final img = sprite;
    if (img == null || system.particles.isEmpty) return;
    final n = system.particles.length;
    final transforms = List<RSTransform>.filled(n, RSTransform(1, 0, 0, 0), growable: false);
    final rects = List<Rect>.filled(n, Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()), growable: false);
    final colors = List<Color>.filled(n, tint, growable: false);
    final shade = List<Color>.filled(n, tint, growable: false);
    final half = img.width / 2;
    for (var i = 0; i < n; i++) {
      final p = system.particles[i];
      final pos = p.positionAt(now);
      final scale = p.sizeAt(now) / img.width;
      transforms[i] = RSTransform.fromComponents(
        rotation: p.rotationAt(now),
        scale: scale,
        anchorX: half,
        anchorY: half,
        translateX: pos.dx,
        translateY: pos.dy,
      );
      final a = p.alphaAt(now).clamp(0.0, 1.0);
      colors[i] = tint.withValues(alpha: a);
      shade[i] = _shadeColor.withValues(alpha: min(1.0, a * 1.0));
    }
    // A faint dark underlay first: pale smoke on a pale picture has no contrast
    // on its own, and on a dark picture the underlay disappears into it.
    canvas.drawAtlas(img, transforms, rects, shade, BlendMode.modulate, null, Paint());
    canvas.drawAtlas(img, transforms, rects, colors, BlendMode.modulate, null, Paint());
  }

  void _paintTray(Canvas canvas, GardenBluntLayout l) {
    final t = l.tray;
    // Soft shadow on whatever is behind.
    canvas.drawOval(
      t.shift(const Offset(0, 10)).inflate(6),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.38)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );
    // Dark smoked glass.
    canvas.drawOval(
      t,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF332A42), Color(0xFF0F0B16)],
        ).createShader(t),
    );
    canvas.drawOval(
      t,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.white.withValues(alpha: 0.24),
    );
    final inner = Rect.fromCenter(center: t.center.translate(0, -2), width: t.width * 0.82, height: t.height * 0.62);
    canvas.drawOval(inner, Paint()..color = const Color(0xFF0A070F));
    // A little ash.
    canvas.drawOval(
      Rect.fromCenter(center: inner.center.translate(inner.width * 0.18, inner.height * 0.12), width: inner.width * 0.26, height: inner.height * 0.34),
      Paint()..color = const Color(0xFF9E9AA6).withValues(alpha: 0.55),
    );
  }

  void _paintBlunt(Canvas canvas, GardenBluntLayout l, int i, double ember) {
    final len = l.length(i);
    final th = l.thickness(i);
    final rMouth = th * 0.42;
    final rBurn = th * 0.5;
    final ashLen = th * 0.9;
    final xAsh = len / 2 - ashLen;

    canvas.save();
    canvas.translate(l.center(i).dx, l.center(i).dy);
    canvas.rotate(l.angle(i));

    // Wrapped body: narrower at the mouth end, fuller toward the burn.
    final body = Path()
      ..moveTo(-len / 2 + rMouth, -rMouth)
      ..lineTo(xAsh, -rBurn)
      ..lineTo(xAsh, rBurn)
      ..lineTo(-len / 2 + rMouth, rMouth)
      ..arcToPoint(Offset(-len / 2 + rMouth, -rMouth), radius: Radius.circular(rMouth), clockwise: true)
      ..close();
    final bodyRect = Rect.fromLTRB(-len / 2, -rBurn, xAsh, rBurn);
    canvas.drawPath(
      body,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFA9763F), Color(0xFF6B4122), Color(0xFF2B190B)],
          stops: [0, 0.5, 1],
        ).createShader(bodyRect),
    );

    // Spiral of the leaf wrap, clipped to the body.
    canvas.save();
    canvas.clipPath(body);
    final seam = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(1.0, th * 0.05)
      ..color = Colors.black.withValues(alpha: 0.20);
    final glint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(1.0, th * 0.03)
      ..color = const Color(0xFFD9A869).withValues(alpha: 0.16);
    for (var x = -len / 2 - th; x < xAsh; x += th * 1.05) {
      canvas.drawLine(Offset(x, -rBurn), Offset(x + th * 0.95, rBurn), seam);
      canvas.drawLine(Offset(x + th * 0.42, -rBurn), Offset(x + th * 1.37, rBurn), glint);
    }
    canvas.restore();

    // Ash cone, then the glowing end face.
    final ash = RRect.fromRectAndRadius(
      Rect.fromLTRB(xAsh - 1, -rBurn * 0.94, len / 2, rBurn * 0.94),
      Radius.circular(th * 0.16),
    );
    canvas.drawRRect(
      ash,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFB9B6BF), Color(0xFF6C6973)],
        ).createShader(ash.outerRect),
    );
    final e = ember.clamp(0.0, 1.3);
    canvas.drawOval(
      Rect.fromCenter(center: Offset(len / 2, 0), width: th * 0.75, height: rBurn * 1.9),
      Paint()..color = Color.lerp(const Color(0xFFFF4A0A), const Color(0xFFFFD27A), (e - 0.5).clamp(0.0, 0.8) / 0.8)!,
    );

    // Glow around the ember (additive, so it also lights the smoke root).
    final glowR = th * (2.0 + 1.2 * e);
    canvas.drawCircle(
      Offset(len / 2, 0),
      glowR,
      Paint()
        ..blendMode = BlendMode.plus
        ..shader = ui.Gradient.radial(
          Offset(len / 2, 0),
          glowR,
          [
            const Color(0xFFFF7A18).withValues(alpha: (0.30 * e).clamp(0.0, 0.5)),
            const Color(0xFFFF7A18).withValues(alpha: 0),
          ],
        ),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_GardenSmokePainter old) => old.sprite != sprite || old.tint != tint;
}

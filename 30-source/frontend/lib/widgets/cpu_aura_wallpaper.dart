// ═══════════════════════════════════════════════════════════════
// Swarm OS — CPU Aura Wallpaper v1.2.0 (2026-10-12)
//
// A wallpaper with a soft light aura that pulses. The pulse rate follows CPU
// load: a slow ~3.2 s breath when idle, down to a ~0.45 s throb at 100 %.
// Every picture gets the screen-edge rim aura. The old bolt-glow overlays
// that were keyed pixel-perfectly to the fallen-soldier artwork are retired
// (boltGlows is accepted but treated as always false).
//
// [image] can change at runtime; the new picture crossfades in (RotatingWallpaper
// drives that from a folder of pictures).
//
// CPU is sampled once a second from /proc/stat (jiffy deltas). The pulse
// phase is integrated per frame, so a speed change never makes it jump.
// ═══════════════════════════════════════════════════════════════

import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'crossfade_image.dart';

// Bundled fallback shown on first frame and when the wallpaper folder is
// absent (live ISO / drive not mounted). Wild Thing leads every session.
const kDefaultWallpaper = 'assets/wallpapers/wild_thing.jpg';
// Keep old name so nothing else breaks if it references it.
const kFallenSoldierWallpaper = kDefaultWallpaper;

// Source image is 1408 x 768. Glow anchors are fractions of that image.
const _imageSize = Size(1408, 768);

class _Glow {
  final Offset at; // fraction of the image
  final Color color;
  final double radius; // fraction of the image height
  final double phase; // stagger so the bolts don't pulse in lockstep
  const _Glow(this.at, this.color, this.radius, this.phase);
}

const _glows = [
  _Glow(Offset(0.15, 0.40), Color(0xFFFF3A5C), 0.42, 0.00), // red bolt
  _Glow(Offset(0.33, 0.47), Color(0xFF3DFF9A), 0.36, 0.18), // green bolt
  _Glow(Offset(0.29, 0.52), Color(0xFF7A6BFF), 0.30, 0.33), // violet bolt
  _Glow(Offset(0.74, 0.43), Color(0xFF3FA9FF), 0.40, 0.52), // blue bolt
  _Glow(Offset(0.88, 0.36), Color(0xFFB45CFF), 0.40, 0.70), // purple bolt
  _Glow(Offset(0.56, 0.28), Color(0xFFFFFFFF), 0.34, 0.85), // eagle
];

class CpuAuraWallpaper extends StatefulWidget {
  const CpuAuraWallpaper({
    super.key,
    this.image = const AssetImage(kDefaultWallpaper),
    // boltGlows is accepted for backward compat but is always treated as
    // false — the glows were pixel-mapped to the old fallen-soldier art.
    this.boltGlows = false,
  });

  final ImageProvider image;
  // ignored — kept so call-sites don't need updating
  // ignore: unused_field
  final bool boltGlows;

  @override
  State<CpuAuraWallpaper> createState() => _CpuAuraWallpaperState();
}

class _CpuAuraWallpaperState extends State<CpuAuraWallpaper>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final _phase = ValueNotifier<double>(0);
  Duration _last = Duration.zero;

  // Smoothed 0..1 load; the target comes from /proc/stat once a second.
  double _load = 0;
  double _targetLoad = 0;
  int? _prevIdle, _prevTotal;
  bool _sampling = false;

  // Bolt glows permanently off — artwork-specific, retired with fallen-soldier.
  static const double _glow = 0.0;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick)..start();
  }

  Future<void> _sampleCpu() async {
    if (_sampling) return;
    _sampling = true;
    try {
      final line = (await File('/proc/stat').readAsLines()).first;
      final v = line.split(RegExp(r'\s+')).skip(1).map((s) => int.tryParse(s) ?? 0).toList();
      if (v.length >= 5) {
        final idle = v[3] + v[4]; // idle + iowait
        final total = v.fold<int>(0, (a, b) => a + b);
        if (_prevIdle != null && total > _prevTotal!) {
          final busy = 1 - (idle - _prevIdle!) / (total - _prevTotal!);
          _targetLoad = busy.clamp(0.0, 1.0);
        }
        _prevIdle = idle;
        _prevTotal = total;
      }
    } catch (_) {
      // No /proc (not Linux) — stay at the idle breath.
    } finally {
      _sampling = false;
    }
  }

  int _lastSampleSecond = -1;

  void _tick(Duration elapsed) {
    final dt = (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    if (elapsed.inSeconds != _lastSampleSecond) {
      _lastSampleSecond = elapsed.inSeconds;
      _sampleCpu();
    }
    // Ease toward the sampled load so the tempo glides instead of stepping.
    _load += (_targetLoad - _load) * math.min(1, dt * 2.5);
    // _glow is permanently 0 (bolt glows retired); no easing needed.
    final period = 3.2 - 2.75 * _load; // 3.2 s idle → 0.45 s flat out
    _phase.value = (_phase.value + dt / period) % 1.0;
  }

  @override
  void dispose() {
    _ticker.dispose();
    _phase.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(fit: StackFit.expand, children: [
      CrossfadeImage(
        image: widget.image,
        color: Colors.black.withValues(alpha: 0.18),
        colorBlendMode: BlendMode.darken,
      ),
      RepaintBoundary(
        child: CustomPaint(
          painter: _AuraPainter(_phase, () => _load, () => _glow),
        ),
      ),
    ]);
  }
}

class _AuraPainter extends CustomPainter {
  final ValueNotifier<double> phase;
  final double Function() load;
  final double Function() glow;
  _AuraPainter(this.phase, this.load, this.glow) : super(repaint: phase);

  @override
  void paint(Canvas canvas, Size size) {
    // Map image fractions onto the screen the same way BoxFit.cover crops.
    final scale = math.max(size.width / _imageSize.width, size.height / _imageSize.height);
    final drawn = _imageSize * scale;
    final origin = Offset((size.width - drawn.width) / 2, (size.height - drawn.height) / 2);
    final l = load();
    final boltStrength = glow();

    for (final g in _glows) {
      if (boltStrength < 0.01) break; // not the FALLEN SOLDIER picture
      // Smooth breath: 0..1 with a quick rise and slower fall.
      final t = (phase.value + g.phase) % 1.0;
      final wave = math.pow(math.sin(t * math.pi), 2).toDouble();
      final strength = (0.10 + 0.22 * wave) * (0.8 + 0.6 * l) * boltStrength;
      final center = origin + Offset(g.at.dx * drawn.width, g.at.dy * drawn.height);
      final radius = g.radius * drawn.height * (0.85 + 0.25 * wave);
      final paint = Paint()
        ..blendMode = BlendMode.plus
        ..shader = RadialGradient(colors: [
          g.color.withValues(alpha: strength.clamp(0.0, 0.6)),
          g.color.withValues(alpha: 0),
        ]).createShader(Rect.fromCircle(center: center, radius: radius));
      canvas.drawCircle(center, radius, paint);
    }

    // A faint rim of light around the whole screen that breathes with the
    // same tempo — the "aura" framing the desktop.
    final rim = math.pow(math.sin(phase.value * math.pi), 2).toDouble();
    final rimPaint = Paint()
      ..blendMode = BlendMode.plus
      ..shader = RadialGradient(
        radius: 0.95,
        colors: [
          Colors.transparent,
          Colors.transparent,
          const Color(0xFF9D5CFF).withValues(alpha: (0.05 + 0.12 * rim) * (0.8 + 0.6 * l)),
        ],
        stops: const [0, 0.62, 1],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, rimPaint);
  }

  @override
  bool shouldRepaint(covariant _AuraPainter old) => false;
}

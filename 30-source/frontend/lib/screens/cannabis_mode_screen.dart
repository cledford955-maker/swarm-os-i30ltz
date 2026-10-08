import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/swarm_text_styles.dart';
import '../services/garden_photos_service.dart';
import '../services/garden_backgrounds_service.dart';
import '../widgets/garden_backdrop.dart';
import '../widgets/garden_smoke.dart';

// Accent for a photo whose strain isn't in the table below (or has none).
const _plainAccent = Color(0xFF4CAF50);

// ── Strain database ───────────────────────────────────────────────────────────

const _strains = [
  ('Lucille OG',        'Indica',  'Euphoric · Relaxed · Creative',   Color(0xFF7B2D8B)),
  ('SWARM Sativa',      'Sativa',  'Energetic · Focused · Uplifted',  Color(0xFF1B8B2D)),
  ('Ghost Train Haze',  'Sativa',  'Cerebral · Electric · Giggly',    Color(0xFF00E5FF)),
  ('Purple Punch',      'Indica',  'Blissful · Sleepy · Berry',       Color(0xFF9C27B0)),
  ('Wedding Cake',      'Hybrid',  'Sweet · Euphoric · Relaxing',     Color(0xFFFF8F00)),
  ('Blue Dream',        'Hybrid',  'Balanced · Happy · Creative',     Color(0xFF2979FF)),
  ('Gorilla Glue #4',  'Hybrid',  'Heavy · Couch-lock · Potent',     Color(0xFF4CAF50)),
  ('Northern Lights',  'Indica',  'Sedating · Peaceful · Pine',      Color(0xFF00BCD4)),
  ('Sour Diesel',       'Sativa',  'Invigorating · Fast · Fuel',      Color(0xFFFFD600)),
  ('OG Kush',           'Hybrid',  'Classic · Earthy · Euphoric',     Color(0xFF8BC34A)),
  ('Pineapple Express', 'Hybrid',  'Tropical · Alert · Buzzy',        Color(0xFFFF6D00)),
  ('Zkittlez',          'Indica',  'Fruity · Calm · Colorful',        Color(0xFFE91E63)),
  ('Mac 1',             'Hybrid',  'Premium · Balanced · Creamy',     Color(0xFFB0BEC5)),
  ('Runtz',             'Hybrid',  'Candy · Giggly · Uplifting',      Color(0xFFFF4081)),
  ('Gelato',            'Hybrid',  'Dessert · Relaxed · Happy',       Color(0xFF7C4DFF)),
  ('Girl Scout Cookies','Hybrid',  'Creative · Warm · Full-body',     Color(0xFF795548)),
];

// ── Screen ────────────────────────────────────────────────────────────────────

class CannabisModeScreen extends StatefulWidget {
  const CannabisModeScreen({super.key, this.backgroundDirs, this.backgroundInterval});

  /// Where to look for background photos, and how long each stays up.
  /// Default to GardenBackgroundsService's folders and interval; tests override.
  final List<String>? backgroundDirs;
  final Duration? backgroundInterval;

  @override
  State<CannabisModeScreen> createState() => _CannabisModeScreenState();
}

class _CannabisModeScreenState extends State<CannabisModeScreen>
    with TickerProviderStateMixin {

  late AnimationController _lightController;  // drifting grow-lights
  late AnimationController _leafController;   // floating leaf animation
  late AnimationController _glowController;   // pulsing bud glow
  late AnimationController _spotController;   // spotlight sweep

  Timer? _strainTimer;
  int _strainIndex = 0;
  int _nextStrainIndex = 1;
  double _strainCrossFade = 1.0;   // 1 = fully showing _strainIndex

  final _rng = Random();

  // The photo on screen, or null while the painted grow-room is showing (no
  // photos on disk). With a photo up, the strain card follows the photo and
  // the 7-second strain rotation below stands down.
  GardenBackground? _photo;
  bool get _photoMode => _photo != null;

  @override
  void initState() {
    super.initState();
    _strainIndex = _rng.nextInt(_strains.length);
    _nextStrainIndex = (_strainIndex + 1) % _strains.length;

    _lightController = AnimationController(
      vsync: this, duration: const Duration(seconds: 8),
    )..repeat();

    _leafController = AnimationController(
      vsync: this, duration: const Duration(seconds: 12),
    )..repeat();

    _glowController = AnimationController(
      vsync: this, duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _spotController = AnimationController(
      vsync: this, duration: const Duration(seconds: 18),
    )..repeat();

    _scheduleStrainCycle();
  }

  @override
  void dispose() {
    _strainTimer?.cancel();
    _lightController.dispose();
    _leafController.dispose();
    _glowController.dispose();
    _spotController.dispose();
    super.dispose();
  }

  void _scheduleStrainCycle() {
    if (_photoMode) return;
    _strainTimer = Timer(const Duration(seconds: 7), _cycleStrain);
  }

  /// A new background photo appeared (or, with null, the photos are gone).
  void _onPhoto(GardenBackground? photo) {
    if (!mounted) return;
    final wasPhotoMode = _photoMode;
    if (photo == null && !wasPhotoMode) return;
    setState(() => _photo = photo);
    if (photo != null) {
      _strainTimer?.cancel();
    } else {
      _scheduleStrainCycle();
    }
  }

  /// The strain row shown on the card: the photo's own strain when it has one,
  /// otherwise (no photos) the rotating strain. A photo with no strain gets its
  /// caption, never an invented strain.
  (String, String, String, Color) get _shownStrain {
    final photo = _photo;
    if (photo == null) return _strains[_strainIndex];
    final name = photo.strain;
    if (name == null) return (photo.caption ?? 'Cannabis garden', 'Plant', '', _plainAccent);
    for (final s in _strains) {
      if (s.$1 == name) return s;
    }
    return (name, 'Cannabis', '', _plainAccent);
  }

  void _cycleStrain() {
    if (!mounted || _photoMode) return;
    setState(() { _strainCrossFade = 1.0; });

    // Fade out over 800 ms, then swap, fade back in
    Future.doWhile(() async {
      await Future.delayed(const Duration(milliseconds: 40));
      if (!mounted) return false;
      setState(() => _strainCrossFade -= 0.08);
      return _strainCrossFade > 0.05;
    }).then((_) {
      if (!mounted) return;
      setState(() {
        _strainIndex = _nextStrainIndex;
        _nextStrainIndex = (_strainIndex + 1) % _strains.length;
        _strainCrossFade = 0.05;
      });
      Future.doWhile(() async {
        await Future.delayed(const Duration(milliseconds: 40));
        if (!mounted) return false;
        setState(() => _strainCrossFade = (_strainCrossFade + 0.08).clamp(0, 1));
        return _strainCrossFade < 0.98;
      });
    });

    _scheduleStrainCycle();
  }

  @override
  Widget build(BuildContext context) {
    final strain = _shownStrain;
    final accent = strain.$4;
    final photo = _photo;
    const exitHint = 'Swipe up or press Esc to exit';
    final tag = photo == null ? 'LIVE STRAIN' : (photo.strain != null ? 'STRAIN' : 'GARDEN');
    final footnote = photo == null
        ? 'Strain rotates every 7 seconds  ·  $exitHint'
        : [if (photo.credit != null) photo.credit!, exitHint].join('  ·  ');

    return Scaffold(
      backgroundColor: const Color(0xFF050208),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Deep space background ─────────────────────────────────
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0.0, 0.3),
                radius: 1.4,
                colors: [
                  Color(0xFF0D0520),
                  Color(0xFF060310),
                  Color(0xFF020108),
                ],
              ),
            ),
          ),

          // ── Real photos: full-screen plants and buds, cycling. Paints
          //    nothing until the first photo is ready (or if there are none),
          //    and reports each photo so the card below can label it. ───────
          GardenBackdrop(
            loader: () => GardenBackgroundsService.load(
              widget.backgroundDirs ?? GardenBackgroundsService.dirs,
              knownStrains: _strains.map((s) => s.$1),
            ),
            interval: widget.backgroundInterval ?? GardenBackgroundsService.interval,
            onChanged: _onPhoto,
          ),

          // ── The painted grow-room, shown only while there is no photo.
          //    Its coloured beams would tint a real photograph. ──────────────
          if (!_photoMode) ...[
            // ── Grow-light ceiling beam ───────────────────────────────
            AnimatedBuilder(
              animation: _lightController,
              builder: (_, __) => CustomPaint(
                size: Size.infinite,
                painter: _GrowLightPainter(t: _lightController.value, accent: accent),
              ),
            ),

            // ── Spotlight sweep ───────────────────────────────────────
            AnimatedBuilder(
              animation: _spotController,
              builder: (_, __) => CustomPaint(
                size: Size.infinite,
                painter: _SpotlightPainter(t: _spotController.value, accent: accent),
              ),
            ),

            // ── Floating cannabis buds + leaves ───────────────────────
            AnimatedBuilder(
              animation: _leafController,
              builder: (_, __) => CustomPaint(
                size: Size.infinite,
                painter: _FloatingBudsPainter(t: _leafController.value, accent: accent),
              ),
            ),

            // ── Center bud: real photo when the strain has one on disk,
            //    procedural painter otherwise. Photos live at
            //    /opt/swarm_os/garden/<slug>.{jpg,jpeg,png,webp} and are
            //    resolved by GardenPhotosService.instance. The glow/accent
            //    ring stays under both paths so the animation reads the same.
            Center(
              child: SizedBox(
                width: 300, height: 300,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    AnimatedBuilder(
                      animation: _glowController,
                      builder: (_, __) => CustomPaint(
                        painter: _CenterBudPainter(
                          pulse: _glowController.value,
                          accent: accent,
                          drawBud: GardenPhotosService.instance.photoPathFor(strain.$1) == null,
                        ),
                      ),
                    ),
                    Builder(builder: (_) {
                      final path = GardenPhotosService.instance.photoPathFor(strain.$1);
                      if (path == null) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.all(28),
                        child: ClipOval(
                          child: Image.file(
                            File(path),
                            fit: BoxFit.cover,
                            // If the file suddenly disappears (btrfs snapshot
                            // rollback mid-render, unlikely but possible), fall
                            // back to the painter — never let a broken image
                            // widget crash the garden.
                            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
          ],

          // ── Blunts burning in an ashtray, smoke rising ────────────
          GardenSmoke(accent: accent),

          // ── Strain info card ──────────────────────────────────────
          Align(
            alignment: Alignment.bottomLeft,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 600),
                layoutBuilder: (current, previous) => Stack(
                  alignment: Alignment.bottomLeft,
                  children: [...previous, if (current != null) current],
                ),
                child: Opacity(
                  // Keyed by what it shows, so the label fades with its photo.
                  key: ValueKey('${photo?.path}|${strain.$1}'),
                  opacity: photo == null ? _strainCrossFade.clamp(0.0, 1.0) : 1.0,
                  child: _StrainCard(
                    strain: strain,
                    tag: tag,
                    caption: photo?.strain != null ? photo?.caption : null,
                    footnote: footnote,
                  ),
                ),
              ),
            ),
          ),

          // ── Top HUD ───────────────────────────────────────────────
          Positioned(
            top: 0, left: 0, right: 0,
            child: _TopHud(accent: accent, onExit: () => context.go('/')),
          ),
        ],
      ),
    );
  }
}

// ── Strain info card ──────────────────────────────────────────────────────────

class _StrainCard extends StatelessWidget {
  final (String, String, String, Color) strain;
  final String tag;
  final String? caption;
  final String footnote;
  const _StrainCard({
    required this.strain,
    this.tag = 'LIVE STRAIN',
    this.caption,
    this.footnote = 'Strain rotates every 7 seconds  ·  Swipe up or press Esc to exit',
  });

  @override
  Widget build(BuildContext context) {
    final (name, type, effects, accent) = strain;
    return Container(
      margin: const EdgeInsets.fromLTRB(32, 0, 32, 40),
      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 22),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: 0.55), width: 1.5),
        boxShadow: [
          BoxShadow(color: accent.withValues(alpha: 0.22), blurRadius: 40, spreadRadius: 2),
          BoxShadow(color: Colors.black.withValues(alpha: 0.8), blurRadius: 20),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: accent.withValues(alpha: 0.55), width: 1),
                ),
                child: Text(type.toUpperCase(),
                    style: TextStyle(color: accent, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.8)),
              ),
              const SizedBox(width: 12),
              Container(width: 6, height: 6, decoration: BoxDecoration(color: accent, shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: accent, blurRadius: 6)])),
              const SizedBox(width: 8),
              Text(tag, style: TextStyle(color: accent.withValues(alpha: 0.7), fontSize: 10, letterSpacing: 2)),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            name,
            style: SwarmTextStyles.title.copyWith(
              color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold,
              shadows: [Shadow(color: accent.withValues(alpha: 0.8), blurRadius: 16)],
            ),
          ),
          if (caption != null) ...[
            const SizedBox(height: 4),
            Text(caption!, style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13)),
          ],
          const SizedBox(height: 6),
          if (effects.isNotEmpty)
          Row(
            children: effects.split(' · ').map((e) => Container(
              margin: const EdgeInsets.only(right: 10),
              child: Row(children: [
                Container(width: 5, height: 5, decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.8), shape: BoxShape.circle)),
                const SizedBox(width: 5),
                Text(e, style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 13)),
              ]),
            )).toList(),
          ),
          const SizedBox(height: 10),
          Container(height: 1, color: accent.withValues(alpha: 0.2)),
          const SizedBox(height: 10),
          Text(footnote,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: 10, letterSpacing: 1.2)),
        ],
      ),
    );
  }
}

// ── Top HUD ───────────────────────────────────────────────────────────────────

class _TopHud extends StatelessWidget {
  final Color accent;
  final VoidCallback onExit;
  const _TopHud({required this.accent, required this.onExit});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(28, 18, 28, 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [Colors.black.withValues(alpha: 0.75), Colors.transparent],
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF1B5E20).withValues(alpha: 0.6),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF4CAF50).withValues(alpha: 0.7), width: 1.5),
            ),
            child: const Text('🌿', style: TextStyle(fontSize: 18)),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('LUCILLE GARDEN', style: TextStyle(
                  color: accent, fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 2.2,
                  shadows: [Shadow(color: accent, blurRadius: 8)])),
              Text('PRIVATE MODE ACTIVE', style: TextStyle(color: Colors.white.withValues(alpha: 0.45), fontSize: 10, letterSpacing: 1.5)),
            ],
          ),
          const Spacer(),
          InkWell(
            onTap: onExit,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
              ),
              child: Text('EXIT GARDEN', style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7), fontSize: 11, letterSpacing: 1.4)),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// PAINTERS
// ═══════════════════════════════════════════════════════════════════════════════

/// LED grow-light beam array from the ceiling
class _GrowLightPainter extends CustomPainter {
  final double t;
  final Color accent;
  _GrowLightPainter({required this.t, required this.accent});

  @override
  void paint(Canvas canvas, Size size) {
    final colors = [
      const Color(0xFFAA00FF),   // deep purple (HPS/LED)
      const Color(0xFFFF1744),   // red (flowering spectrum)
      const Color(0xFF00E676),   // green
      const Color(0xFF2979FF),   // blue (veg spectrum)
      accent,
    ];

    for (int i = 0; i < 5; i++) {
      final xFrac = (i + 0.5) / 5;
      final drift = sin(t * pi * 2 + i * 1.3) * 0.04;
      final cx = size.width * (xFrac + drift);

      final paint = Paint()
        ..shader = RadialGradient(
          center: const Alignment(0, -1),
          radius: 1.8,
          colors: [colors[i].withValues(alpha: 0.22), colors[i].withValues(alpha: 0.0)],
        ).createShader(Rect.fromCenter(center: Offset(cx, 0), width: size.width * 0.5, height: size.height));

      canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
    }

    // Ceiling bar
    final barPaint = Paint()
      ..shader = LinearGradient(
        colors: colors.map((c) => c.withValues(alpha: 0.55)).toList(),
      ).createShader(Rect.fromLTWH(0, 0, size.width, 4));
    canvas.drawRect(const Rect.fromLTWH(0, 0, double.infinity, 4), barPaint);
  }

  @override bool shouldRepaint(_GrowLightPainter old) => old.t != t || old.accent != accent;
}

/// Drifting spotlight beam
class _SpotlightPainter extends CustomPainter {
  final double t;
  final Color accent;
  _SpotlightPainter({required this.t, required this.accent});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width * (0.3 + sin(t * pi * 2) * 0.35);
    final cy = size.height * 0.5;

    final paint = Paint()
      ..shader = RadialGradient(
        colors: [accent.withValues(alpha: 0.09), Colors.transparent],
        radius: 0.6,
      ).createShader(Rect.fromCenter(center: Offset(cx, cy), width: 500, height: 500));

    canvas.drawCircle(Offset(cx, cy), 250, paint);
  }

  @override bool shouldRepaint(_SpotlightPainter old) => old.t != t || old.accent != accent;
}

/// Floating buds and five-leaf silhouettes
class _FloatingBudsPainter extends CustomPainter {
  final double t;
  final Color accent;
  _FloatingBudsPainter({required this.t, required this.accent});

  @override
  void paint(Canvas canvas, Size size) {
    final rng = Random(42);
    const count = 18;

    for (int i = 0; i < count; i++) {
      final baseX = rng.nextDouble() * size.width;
      final baseY = rng.nextDouble() * size.height;
      final speed = 0.04 + rng.nextDouble() * 0.06;
      final phase = rng.nextDouble() * pi * 2;
      final scale = 0.4 + rng.nextDouble() * 0.6;

      final x = baseX + sin(t * pi * 2 * speed + phase) * 18;
      final y = baseY + cos(t * pi * 2 * speed * 0.7 + phase) * 14;
      final rot = t * pi * 0.3 * (rng.nextDouble() - 0.5) + phase;

      final alpha = (0.12 + 0.12 * sin(t * pi * 2 + phase)).clamp(0.0, 1.0);

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(rot);
      canvas.scale(scale);

      if (i % 3 == 0) {
        // Draw bud cluster
        _drawBudCluster(canvas, accent.withValues(alpha: alpha));
      } else {
        // Draw five-leaf cannabis silhouette
        _drawLeafFan(canvas, accent.withValues(alpha: alpha));
      }

      canvas.restore();
    }
  }

  void _drawBudCluster(Canvas canvas, Color color) {
    final p = Paint()..color = color..style = PaintingStyle.fill;
    final glow = Paint()..color = color.withValues(alpha: color.a * 0.4)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    // 5 overlapping circles = bud cluster
    const offsets = [Offset(0,0), Offset(8,-10), Offset(-8,-10), Offset(10,4), Offset(-10,4)];
    for (final o in offsets) {
      canvas.drawCircle(o, 10, glow);
      canvas.drawCircle(o, 6, p);
    }
  }

  void _drawLeafFan(Canvas canvas, Color color) {
    final p = Paint()..color = color..style = PaintingStyle.fill;
    const leafCount = 5;
    for (int l = 0; l < leafCount; l++) {
      final angle = (l / leafCount) * pi * 2 - pi / 2;
      final len = l == 0 ? 22.0 : 16.0;
      canvas.save();
      canvas.rotate(angle);
      final path = Path()
        ..moveTo(0, 0)
        ..cubicTo(-5, -len * 0.4, -3, -len * 0.8, 0, -len)
        ..cubicTo(3, -len * 0.8, 5, -len * 0.4, 0, 0);
      canvas.drawPath(path, p);
      canvas.restore();
    }
    // Stem
    canvas.drawRect(Rect.fromCenter(center: const Offset(0, 4), width: 2, height: 8), p);
  }

  @override bool shouldRepaint(_FloatingBudsPainter old) => old.t != t || old.accent != accent;
}

/// Central featured bud with glow rings
class _CenterBudPainter extends CustomPainter {
  final double pulse;
  final Color accent;
  /// When false, only the glow rings behind the bud are drawn (the caller is
  /// overlaying a real photo instead of the procedural bud/leaves/sparkles).
  final bool drawBud;
  _CenterBudPainter({required this.pulse, required this.accent, this.drawBud = true});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    // Outer glow rings — always drawn, they're the ambient light around the
    // bud regardless of whether a real photo is overlaid on top.
    for (int r = 3; r >= 0; r--) {
      final radius = 60.0 + r * 22 + pulse * 14;
      final alpha = (0.04 + (3 - r) * 0.025 - pulse * 0.01).clamp(0.0, 1.0);
      canvas.drawCircle(
        Offset(cx, cy), radius,
        Paint()..color = accent.withValues(alpha: alpha)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 22),
      );
    }

    if (!drawBud) return;

    // Main bud: large cluster
    final clusters = [
      Offset(cx, cy - 10),
      Offset(cx - 22, cy + 5),
      Offset(cx + 22, cy + 5),
      Offset(cx, cy + 22),
      Offset(cx - 14, cy - 26),
      Offset(cx + 14, cy - 26),
    ];
    for (final c in clusters) {
      final r = 22.0 + pulse * 3;
      canvas.drawCircle(c, r + 8,
          Paint()..color = accent.withValues(alpha: 0.12)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12));
      canvas.drawCircle(c, r,
          Paint()..color = Color.lerp(const Color(0xFF1B4820), accent, 0.35 + pulse * 0.15)!
              ..style = PaintingStyle.fill);
    }

    // Trichome sparkles
    final rng = Random(7);
    final sparkPaint = Paint()..color = Colors.white.withValues(alpha: 0.6 + pulse * 0.3);
    for (int i = 0; i < 16; i++) {
      final angle = (i / 16) * pi * 2;
      final dist = 28 + rng.nextDouble() * 16;
      final sx = cx + cos(angle + pulse * 0.4) * dist;
      final sy = cy + sin(angle + pulse * 0.4) * dist;
      canvas.drawCircle(Offset(sx, sy), 1.2 + rng.nextDouble(), sparkPaint);
    }

    // Five-leaf fan behind the bud
    canvas.save();
    canvas.translate(cx, cy + 50);
    final leafP = Paint()..color = const Color(0xFF2E7D32).withValues(alpha: 0.55);
    const leafCount = 5;
    for (int l = 0; l < leafCount; l++) {
      final angle = (l / leafCount) * pi * 2 - pi / 2;
      final len = l == 0 ? 70.0 : 52.0;
      canvas.save();
      canvas.rotate(angle);
      final path = Path()
        ..moveTo(0, 0)
        ..cubicTo(-12, -len * 0.35, -8, -len * 0.75, 0, -len)
        ..cubicTo(8, -len * 0.75, 12, -len * 0.35, 0, 0);
      canvas.drawPath(path, leafP);
      canvas.restore();
    }
    canvas.restore();
  }

  @override bool shouldRepaint(_CenterBudPainter old) =>
      old.pulse != pulse || old.accent != accent || old.drawBud != drawBud;
}

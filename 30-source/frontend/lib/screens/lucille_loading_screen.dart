import 'dart:math';
import 'package:flutter/material.dart';

/// Screen 2: Cockpit Telemetry Loading Screen
/// Tachometer red needle climbs 1,000 → 6,500 RPM as modules load.
/// Burning asphalt progress bar + LS1 telemetry status log.
/// Holographic wasp nest honeycomb grid pulses behind cockpit glass.
class LucilleLoadingScreen extends StatefulWidget {
  final double progress;     // 0.0 → 1.0
  final String? statusMessage;
  final bool indeterminate;
  final VoidCallback? onComplete;

  const LucilleLoadingScreen({
    super.key,
    this.progress = 0.0,
    this.statusMessage,
    this.indeterminate = true,
    this.onComplete,
  });

  @override
  State<LucilleLoadingScreen> createState() => _LucilleLoadingScreenState();
}

class _LucilleLoadingScreenState extends State<LucilleLoadingScreen>
    with TickerProviderStateMixin {

  late AnimationController _idleController;     // V8 idle cam shake
  late AnimationController _pulseController;    // glow pulse
  late AnimationController _smokeController;    // burnout smoke time
  late AnimationController _progressController; // indeterminate slide
  late AnimationController _needleController;   // tach needle smooth

  late Animation<double> _idleAnim;
  late Animation<double> _pulseAnim;
  late Animation<double> _needleAnim;

  final Random _rng = Random(42);
  final List<_BarSmoke> _barSmoke = [];
  int _logIndex = 0;

  static const List<String> _telemetryLog = [
    'FIRING LS1 INJECTORS...',
    'SPOOLING TURBO PROTOCOLS...',
    'SHREDDING REAR TIRES: 6,200 RPM...',
    'SYNCHRONIZING CYBER-WASP HIVE...',
    'LUCILLE CORE ONLINE.',
  ];

  static const Color _highlight   = Color(0xFF00E5FF);
  static const Color _asphalt     = Color(0xFF060610);
  static const Color _waspGold    = Color(0xFFFFCC00);

  @override
  void initState() {
    super.initState();

    // Deep, choppy V8 idle lope shake
    _idleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 130),
    )..repeat(reverse: true);
    _idleAnim = Tween<double>(begin: -0.9, end: 0.9).animate(
      CurvedAnimation(parent: _idleController, curve: Curves.easeInOut),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _smokeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    )..repeat();

    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    );
    if (widget.indeterminate) _progressController.repeat();

    _needleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _needleAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _needleController, curve: Curves.easeOut),
    );

    if (!widget.indeterminate) {
      _needleController.animateTo(widget.progress);
    }

    for (int i = 0; i < 35; i++) {
      _barSmoke.add(_BarSmoke.random(_rng));
    }
  }

  @override
  void didUpdateWidget(covariant LucilleLoadingScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.indeterminate && oldWidget.progress != widget.progress) {
      _needleController.animateTo(widget.progress,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOut);
      final idx = (widget.progress * (_telemetryLog.length - 1))
          .floor()
          .clamp(0, _telemetryLog.length - 1);
      if (idx != _logIndex) setState(() => _logIndex = idx);
    }
  }

  @override
  void dispose() {
    _idleController.dispose();
    _pulseController.dispose();
    _smokeController.dispose();
    _progressController.dispose();
    _needleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: _asphalt,
      body: AnimatedBuilder(
        animation: Listenable.merge([
          _idleController,
          _pulseController,
          _smokeController,
          _progressController,
          _needleController,
        ]),
        builder: (context, _) {
          final displayProgress = widget.indeterminate
              ? _progressController.value
              : _needleAnim.value;

          return Transform.translate(
            offset: Offset(0, _idleAnim.value),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // L0: 1440p Realistic Trans-Am WS6 visible through windshield
                Opacity(
                  opacity: 0.32,
                  child: Image.asset(
                    'assets/splash/transam_1440p.jpg',
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Image.asset(
                      'assets/transam_1440p.jpg',
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),
                ),

                // L0b: Honeycomb hex grid HUD overlay
                CustomPaint(
                  painter: _HexGridBgPainter(pulse: _pulseAnim.value),
                  size: size,
                ),

                // L1: Cockpit glass overlay
                Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(0, -0.25),
                      radius: 1.2,
                      colors: [
                        const Color(0xFF0A102A).withValues(alpha: 0.75),
                        _asphalt.withValues(alpha: 0.94),
                      ],
                    ),
                  ),
                ),

                // L2: Gauge cluster
                _buildGaugeCluster(size, displayProgress),

                // L3: Bottom progress + telemetry
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: _buildProgressSection(size, displayProgress),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildGaugeCluster(Size size, double progress) {
    final rpmVal = (1000 + progress * 5500).toInt();
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(height: size.height * 0.04),

        // Central tachometer
        CustomPaint(
          painter: _TachometerPainter(
            progress: progress,
            pulseValue: _pulseAnim.value,
            rpmValue: rpmVal,
          ),
          size: Size(size.width * 0.56, size.width * 0.56),
        ),

        const SizedBox(height: 20),

        // Side gauges
        Padding(
          padding: EdgeInsets.symmetric(horizontal: size.width * 0.07),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              CustomPaint(
                painter: _SideGaugePainter(
                  label: 'BOOST',
                  unit: 'PSI',
                  maxVal: 14.7,
                  progress: (progress * 1.1).clamp(0.0, 1.0),
                  color: _waspGold,
                  pulseValue: _pulseAnim.value,
                ),
                size: Size(size.width * 0.28, size.width * 0.28),
              ),
              CustomPaint(
                painter: _SideGaugePainter(
                  label: 'FUEL PSI',
                  unit: 'PSI',
                  maxVal: 58.0,
                  progress: (0.20 + progress * 0.60).clamp(0.0, 1.0),
                  color: _highlight,
                  pulseValue: _pulseAnim.value,
                  warnAbove: 0.88,
                ),
                size: Size(size.width * 0.28, size.width * 0.28),
              ),
            ],
          ),
        ),

        const SizedBox(height: 22),
        _buildTelemetryLog(size),
      ],
    );
  }

  Widget _buildTelemetryLog(Size size) {
    final msg = widget.statusMessage ?? _telemetryLog[_logIndex];
    return Container(
      margin: EdgeInsets.symmetric(horizontal: size.width * 0.07),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFF04040E).withValues(alpha: 0.88),
        border: Border.all(color: _highlight.withValues(alpha: 0.22), width: 1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          // Blinking cursor
          AnimatedBuilder(
            animation: _pulseController,
            builder: (_, __) => Container(
              width: 7,
              height: 13,
              margin: const EdgeInsets.only(right: 10),
              color: _highlight.withValues(alpha: _pulseAnim.value),
            ),
          ),
          Expanded(
            child: Text(
              msg,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 2.0,
                color: Color(0xFF00E5FF),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressSection(Size size, double progress) {
    return Container(
      padding: const EdgeInsets.fromLTRB(32, 18, 32, 32),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            _asphalt.withValues(alpha: 0.95),
            _asphalt,
          ],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Burning asphalt progress bar
          SizedBox(
            height: 10,
            child: CustomPaint(
              painter: _BurningAsphaltBarPainter(
                progress: widget.indeterminate ? null : progress,
                smokeT: _smokeController.value,
                pulseValue: _pulseAnim.value,
                particles: _barSmoke,
              ),
              size: Size(size.width - 64, 10),
            ),
          ),
          const SizedBox(height: 10),
          if (!widget.indeterminate)
            Text(
              '${(progress * 100).toInt()}%',
              style: TextStyle(
                color: _highlight.withValues(alpha: 0.6),
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 5,
              ),
            ),
          const SizedBox(height: 6),
          Text(
            'SWARM OS v5 β',
            style: TextStyle(
              color: _highlight.withValues(alpha: 0.18),
              fontSize: 9,
              letterSpacing: 3,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// PAINTER: Honeycomb hex grid background
// ═══════════════════════════════════════════════════════════════
class _HexGridBgPainter extends CustomPainter {
  final double pulse;
  const _HexGridBgPainter({required this.pulse});

  @override
  void paint(Canvas canvas, Size size) {
    const s = 55.0;
    final h = s * sqrt(3) / 2;
    final paint = Paint()
      ..color = const Color(0xFF00E5FF).withValues(alpha: 0.026 * pulse)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;
    for (double y = -s; y < size.height + s; y += h * 2) {
      for (double x = -s; x < size.width + s; x += s * 1.5) {
        _hex(canvas, x, y, s * 0.48, paint);
        _hex(canvas, x + s * 0.75, y + h, s * 0.48, paint);
      }
    }
  }

  void _hex(Canvas canvas, double cx, double cy, double r, Paint p) {
    final path = Path();
    for (int i = 0; i < 6; i++) {
      final a = i * 60 * pi / 180;
      if (i == 0) {
        path.moveTo(cx + r * cos(a), cy + r * sin(a));
      } else {
        path.lineTo(cx + r * cos(a), cy + r * sin(a));
      }
    }
    path.close();
    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(covariant _HexGridBgPainter old) => old.pulse != pulse;
}

// ═══════════════════════════════════════════════════════════════
// PAINTER: Central tachometer — 1,000 → 6,500 RPM
// ═══════════════════════════════════════════════════════════════
class _TachometerPainter extends CustomPainter {
  final double progress;
  final double pulseValue;
  final int rpmValue;

  // 270° sweep, start at 135° from 3 o'clock
  static const double _startAngle = 135.0 * pi / 180;
  static const double _sweep      = 270.0 * pi / 180;

  const _TachometerPainter({
    required this.progress,
    required this.pulseValue,
    required this.rpmValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final outerR = size.width * 0.47;
    final arcR   = outerR - 10;

    // Background disc
    canvas.drawCircle(Offset(cx, cy), outerR,
      Paint()..color = const Color(0xFF070710));

    // Outer ring
    canvas.drawCircle(Offset(cx, cy), outerR,
      Paint()
        ..color = const Color(0xFF00E5FF).withValues(alpha: 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5);
    canvas.drawCircle(Offset(cx, cy), outerR,
      Paint()
        ..color = const Color(0xFF00E5FF).withValues(alpha: 0.25 * pulseValue)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..maskFilter = MaskFilter.blur(BlurStyle.outer, 7 * pulseValue));

    // Color zones on arc
    _arc(canvas, cx, cy, arcR, 7, _startAngle,
      _sweep * 0.615, const Color(0xFF0077DD).withValues(alpha: 0.65));
    _arc(canvas, cx, cy, arcR, 7, _startAngle + _sweep * 0.615,
      _sweep * 0.23, const Color(0xFFFF8800).withValues(alpha: 0.70));
    _arc(canvas, cx, cy, arcR, 7, _startAngle + _sweep * 0.845,
      _sweep * 0.155, const Color(0xFFFF1111).withValues(alpha: 0.85));

    // Tick marks + RPM labels
    for (int i = 0; i <= 65; i++) {
      final frac  = i / 65.0;
      final angle = _startAngle + _sweep * frac;
      final major = i % 10 == 0;
      final mid   = i % 5 == 0;
      final tickOuter = outerR - 2;
      final tickInner = outerR - (major ? 18 : mid ? 13 : 8);
      final color = i >= 55 ? const Color(0xFFFF2222)
                  : i >= 40 ? const Color(0xFFFF8800)
                  : const Color(0xFF88BBDD);

      canvas.drawLine(
        Offset(cx + tickOuter * cos(angle), cy + tickOuter * sin(angle)),
        Offset(cx + tickInner * cos(angle), cy + tickInner * sin(angle)),
        Paint()
          ..color = color.withValues(alpha: major ? 1.0 : 0.55)
          ..strokeWidth = major ? 2.5 : 1.0);

      if (major) {
        final lr = outerR - 30;
        _centerText(canvas,
          cx + lr * cos(angle), cy + lr * sin(angle),
          '${i ~/ 10}', 11,
          color.withValues(alpha: 0.85));
      }
    }

    // "×100 RPM" sub-label
    _centerText(canvas, cx, cy + outerR * 0.30, '×100 RPM', 9,
      const Color(0xFF557799));

    // Needle
    final needleAngle = _startAngle + _sweep * progress;
    final needleR = outerR - 16;

    canvas.drawLine(Offset(cx, cy),
      Offset(cx + needleR * cos(needleAngle), cy + needleR * sin(needleAngle)),
      Paint()
        ..color = const Color(0xFFFF1111).withValues(alpha: 0.45 * pulseValue)
        ..strokeWidth = 9
        ..strokeCap = StrokeCap.round
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 9 * pulseValue));
    canvas.drawLine(Offset(cx, cy),
      Offset(cx + needleR * cos(needleAngle), cy + needleR * sin(needleAngle)),
      Paint()
        ..color = const Color(0xFFFF1111)
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round);
    // Counterweight
    canvas.drawLine(Offset(cx, cy),
      Offset(cx - needleR * 0.14 * cos(needleAngle), cy - needleR * 0.14 * sin(needleAngle)),
      Paint()
        ..color = const Color(0xFFBB1111)
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round);

    // Hub
    canvas.drawCircle(Offset(cx, cy), 10,
      Paint()..color = const Color(0xFF333344));
    canvas.drawCircle(Offset(cx, cy), 10,
      Paint()
        ..color = const Color(0xFF00E5FF).withValues(alpha: 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5);

    // Digital RPM readout
    _centerText(canvas, cx, cy + outerR * 0.52,
      '$rpmValue', 20, const Color(0xFF00E5FF));
    _centerText(canvas, cx, cy + outerR * 0.67,
      'RPM', 9, const Color(0xFF00E5FF).withValues(alpha: 0.6));
  }

  void _arc(Canvas canvas, double cx, double cy, double r, double sw,
            double start, double sweep, Color color) {
    canvas.drawArc(
      Rect.fromCenter(center: Offset(cx, cy), width: r * 2, height: r * 2),
      start, sweep, false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = sw);
  }

  void _centerText(Canvas canvas, double x, double y, String text,
                   double fontSize, Color color) {
    final tp = TextPainter(
      text: TextSpan(text: text,
        style: TextStyle(color: color, fontSize: fontSize,
          fontWeight: FontWeight.w700, letterSpacing: 1.5)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(x - tp.width / 2, y - tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant _TachometerPainter old) =>
      old.progress != progress ||
      old.pulseValue != pulseValue ||
      old.rpmValue != rpmValue;
}

// ═══════════════════════════════════════════════════════════════
// PAINTER: Side gauge (Boost / Fuel Pressure)
// ═══════════════════════════════════════════════════════════════
class _SideGaugePainter extends CustomPainter {
  final String label;
  final String unit;
  final double maxVal;
  final double progress;
  final Color color;
  final double pulseValue;
  final double warnAbove;

  static const double _startAngle = 135.0 * pi / 180;
  static const double _sweep      = 270.0 * pi / 180;

  const _SideGaugePainter({
    required this.label, required this.unit, required this.maxVal,
    required this.progress, required this.color, required this.pulseValue,
    this.warnAbove = 1.1,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r  = size.width * 0.44;

    canvas.drawCircle(Offset(cx, cy), r,
      Paint()..color = const Color(0xFF080812));
    canvas.drawCircle(Offset(cx, cy), r,
      Paint()
        ..color = color.withValues(alpha: 0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5);

    // Track
    canvas.drawArc(
      Rect.fromCenter(center: Offset(cx, cy), width: (r - 7) * 2, height: (r - 7) * 2),
      _startAngle, _sweep, false,
      Paint()
        ..color = const Color(0xFF141428)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6);

    // Fill
    final fillColor = progress > warnAbove ? const Color(0xFFFF3300) : color;
    canvas.drawArc(
      Rect.fromCenter(center: Offset(cx, cy), width: (r - 7) * 2, height: (r - 7) * 2),
      _startAngle, _sweep * progress, false,
      Paint()
        ..color = fillColor.withValues(alpha: 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6);

    // Needle
    final na = _startAngle + _sweep * progress;
    canvas.drawLine(Offset(cx, cy),
      Offset(cx + (r - 14) * cos(na), cy + (r - 14) * sin(na)),
      Paint()
        ..color = fillColor
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round);

    canvas.drawCircle(Offset(cx, cy), 5,
      Paint()..color = const Color(0xFF333344));

    // Value
    final val = maxVal * progress;
    _text(canvas, cx, cy - 5,
      val.toStringAsFixed(1), 13, fillColor);
    _text(canvas, cx, cy + 10,
      unit, 7, color.withValues(alpha: 0.5));
    _text(canvas, cx, cy + r * 0.58,
      label, 7, color.withValues(alpha: 0.7));
  }

  void _text(Canvas canvas, double x, double y, String s,
             double sz, Color c) {
    final tp = TextPainter(
      text: TextSpan(text: s,
        style: TextStyle(color: c, fontSize: sz,
          fontWeight: FontWeight.w700, letterSpacing: 1.5)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(x - tp.width / 2, y - tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant _SideGaugePainter old) => true;
}

// ═══════════════════════════════════════════════════════════════
// PAINTER: Burning asphalt progress bar
// ═══════════════════════════════════════════════════════════════
class _BurningAsphaltBarPainter extends CustomPainter {
  final double? progress; // null = indeterminate
  final double smokeT;
  final double pulseValue;
  final List<_BarSmoke> particles;

  const _BurningAsphaltBarPainter({
    required this.progress,
    required this.smokeT,
    required this.pulseValue,
    required this.particles,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rr = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      const Radius.circular(5));

    // Asphalt track
    canvas.drawRRect(rr, Paint()..color = const Color(0xFF0A0A14));

    // Tread mark texture on track
    final markPaint = Paint()
      ..color = const Color(0xFF0F0F1E)
      ..strokeWidth = 3;
    for (int i = 0; i < 10; i++) {
      final x = size.width * i / 10;
      canvas.drawLine(Offset(x, 0), Offset(x + size.width * 0.04, size.height), markPaint);
    }

    if (progress != null) {
      final fw = size.width * progress!;

      // Burnout fill: dark asphalt → char → orange fire at tip
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, 0, fw, size.height),
          const Radius.circular(5)),
        Paint()
          ..shader = const LinearGradient(
            colors: [
              Color(0xFF0E0E1A),
              Color(0xFF2A1000),
              Color(0xFF662200),
              Color(0xFFFF6600),
            ],
            stops: [0.0, 0.45, 0.78, 1.0],
          ).createShader(Rect.fromLTWH(0, 0, fw, size.height)));

      // Leading fire glow
      if (fw > 6) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(fw - 10, 0, 10, size.height),
            const Radius.circular(3)),
          Paint()
            ..color = const Color(0xFFFF5500).withValues(alpha: 0.75 * pulseValue)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, 10 * pulseValue));

        // Rising smoke from leading edge
        for (final p in particles) {
          final phase = (smokeT + p.phase) % 1.0;
          final px = fw - p.xOff * size.width * 0.06;
          final py = size.height / 2 - phase * size.height * 2.8 * p.rise;
          if (py < -size.height * 2) continue;
          canvas.drawCircle(Offset(px, py), p.size * (1 + phase),
            Paint()
              ..color = const Color(0xFF888899)
                  .withValues(alpha: ((1 - phase) * p.opacity * 0.45).clamp(0.0, 1.0))
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
        }
      }
    } else {
      // Indeterminate: burning streak slides across
      final sw = size.width * 0.38;
      final sx = ((smokeT * 1.5 % 1.38) - 0.38) * size.width;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(sx, 0, sw, size.height),
          const Radius.circular(5)),
        Paint()
          ..shader = LinearGradient(
            colors: [
              Colors.transparent,
              const Color(0xFF2A1000).withValues(alpha: 0.8),
              const Color(0xFFFF5500),
              const Color(0xFFFF8800).withValues(alpha: 0.85),
              Colors.transparent,
            ],
            stops: const [0.0, 0.25, 0.58, 0.82, 1.0],
          ).createShader(Rect.fromLTWH(sx, 0, sw, size.height)));
    }
  }

  @override
  bool shouldRepaint(covariant _BurningAsphaltBarPainter old) => true;
}

// ═══════════════════════════════════════════════════════════════
// DATA CLASS
// ═══════════════════════════════════════════════════════════════

class _BarSmoke {
  final double phase, xOff, size, opacity, rise;

  const _BarSmoke({
    required this.phase, required this.xOff,
    required this.size, required this.opacity, required this.rise,
  });

  factory _BarSmoke.random(Random rng) => _BarSmoke(
    phase: rng.nextDouble(),
    xOff: rng.nextDouble(),
    size: 2.0 + rng.nextDouble() * 5.0,
    opacity: 0.30 + rng.nextDouble() * 0.70,
    rise: 0.30 + rng.nextDouble() * 0.70,
  );
}

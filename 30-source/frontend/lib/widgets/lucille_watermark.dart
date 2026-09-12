import 'dart:math';
import 'package:flutter/material.dart';

/// ═══════════════════════════════════════════════════════════════
/// LUCILLE WATERMARK
/// ═══════════════════════════════════════════════════════════════
/// Reusable watermark with Trans-Am silhouette + hex logo + wasp.
/// Drop this ANYWHERE in the app for branding.
/// ═══════════════════════════════════════════════════════════════
class LucilleWatermark extends StatelessWidget {
  final double opacity;
  final double size;
  final WatermarkStyle style;

  const LucilleWatermark({
    super.key,
    this.opacity = 0.06,
    this.size = 200,
    this.style = WatermarkStyle.transAm,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: _WatermarkPainter(
          opacity: opacity,
          style: style,
        ),
        size: Size(size, size * 0.6),
      ),
    );
  }
}

enum WatermarkStyle {
  transAm,    // 1999 Trans-Am silhouette
  hexLogo,    // Hex with wasp
  combined,   // Both
  text,       // Just "SWARM OS" text
}

/// Full-screen watermark overlay — use in a Stack
class LucilleWatermarkOverlay extends StatefulWidget {
  final double opacity;
  final WatermarkStyle style;

  const LucilleWatermarkOverlay({
    super.key,
    this.opacity = 0.04,
    this.style = WatermarkStyle.combined,
  });

  @override
  State<LucilleWatermarkOverlay> createState() =>
      _LucilleWatermarkOverlayState();
}

class _LucilleWatermarkOverlayState extends State<LucilleWatermarkOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (context, _) {
          return CustomPaint(
            painter: _FullScreenWatermarkPainter(
              opacity: widget.opacity * _pulse.value,
              style: widget.style,
            ),
            size: MediaQuery.of(context).size,
          );
        },
      ),
    );
  }
}

/// Corner watermark — sits in a corner
class LucilleCornerWatermark extends StatelessWidget {
  final double opacity;

  const LucilleCornerWatermark({super.key, this.opacity = 0.15});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CustomPaint(
              painter: _MiniHexPainter(opacity: opacity),
              size: const Size(18, 18),
            ),
            const SizedBox(width: 6),
            Text(
              'SWARM OS',
              style: TextStyle(
                color: const Color(0xFF00BFFF).withValues(alpha: opacity),
                fontSize: 8,
                fontWeight: FontWeight.w600,
                letterSpacing: 3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// PAINTERS
// ═══════════════════════════════════════════════════════════════

class _WatermarkPainter extends CustomPainter {
  final double opacity;
  final WatermarkStyle style;

  _WatermarkPainter({required this.opacity, required this.style});

  @override
  void paint(Canvas canvas, Size size) {
    switch (style) {
      case WatermarkStyle.transAm:
        _drawTransAm(canvas, size, opacity);
        break;
      case WatermarkStyle.hexLogo:
        _drawHexLogo(canvas, size, opacity);
        break;
      case WatermarkStyle.combined:
        _drawTransAm(canvas, size, opacity);
        _drawHexLogo(canvas, Size(size.width * 0.25, size.width * 0.25), opacity * 0.8);
        break;
      case WatermarkStyle.text:
        break;
    }
  }

  void _drawTransAm(Canvas canvas, Size size, double op) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final carW = size.width * 0.9;
    final carH = carW * 0.25;

    final bodyPath = Path();
    bodyPath.moveTo(cx - carW * 0.5, cy + carH * 0.3);
    bodyPath.lineTo(cx - carW * 0.48, cy + carH * 0.1);
    bodyPath.lineTo(cx - carW * 0.45, cy - carH * 0.05);
    bodyPath.lineTo(cx - carW * 0.35, cy - carH * 0.15);
    bodyPath.lineTo(cx - carW * 0.2, cy - carH * 0.25);
    bodyPath.lineTo(cx - carW * 0.1, cy - carH * 0.5);
    bodyPath.lineTo(cx + carW * 0.05, cy - carH * 0.52);
    bodyPath.lineTo(cx + carW * 0.2, cy - carH * 0.35);
    bodyPath.lineTo(cx + carW * 0.35, cy - carH * 0.3);
    bodyPath.lineTo(cx + carW * 0.42, cy - carH * 0.35);
    bodyPath.lineTo(cx + carW * 0.45, cy - carH * 0.25);
    bodyPath.lineTo(cx + carW * 0.48, cy - carH * 0.05);
    bodyPath.lineTo(cx + carW * 0.5, cy + carH * 0.1);
    bodyPath.lineTo(cx + carW * 0.48, cy + carH * 0.3);
    bodyPath.close();

    canvas.drawPath(
      bodyPath,
      Paint()
        ..color = const Color(0xFF00BFFF).withValues(alpha: op)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    canvas.drawPath(
      bodyPath,
      Paint()..color = const Color(0xFF00BFFF).withValues(alpha: op * 0.2),
    );
  }

  void _drawHexLogo(Canvas canvas, Size size, double op) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = min(size.width, size.height) / 2 - 2;

    final path = Path();
    for (int i = 0; i < 6; i++) {
      final angle = (60.0 * i - 30) * pi / 180;
      final x = cx + r * cos(angle);
      final y = cy + r * sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();

    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFF00BFFF).withValues(alpha: op)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(covariant _WatermarkPainter old) =>
      old.opacity != opacity || old.style != style;
}

class _FullScreenWatermarkPainter extends CustomPainter {
  final double opacity;
  final WatermarkStyle style;

  _FullScreenWatermarkPainter({required this.opacity, required this.style});

  @override
  void paint(Canvas canvas, Size size) {
    // Trans-Am in center
    if (style == WatermarkStyle.transAm || style == WatermarkStyle.combined) {
      final cx = size.width / 2;
      final cy = size.height / 2;
      final carW = size.width * 0.35;
      final carH = carW * 0.25;

      final bodyPath = Path();
      bodyPath.moveTo(cx - carW * 0.5, cy + carH * 0.3);
      bodyPath.lineTo(cx - carW * 0.48, cy + carH * 0.1);
      bodyPath.lineTo(cx - carW * 0.45, cy - carH * 0.05);
      bodyPath.lineTo(cx - carW * 0.35, cy - carH * 0.15);
      bodyPath.lineTo(cx - carW * 0.2, cy - carH * 0.25);
      bodyPath.lineTo(cx - carW * 0.1, cy - carH * 0.5);
      bodyPath.lineTo(cx + carW * 0.05, cy - carH * 0.52);
      bodyPath.lineTo(cx + carW * 0.2, cy - carH * 0.35);
      bodyPath.lineTo(cx + carW * 0.35, cy - carH * 0.3);
      bodyPath.lineTo(cx + carW * 0.42, cy - carH * 0.35);
      bodyPath.lineTo(cx + carW * 0.45, cy - carH * 0.25);
      bodyPath.lineTo(cx + carW * 0.48, cy - carH * 0.05);
      bodyPath.lineTo(cx + carW * 0.5, cy + carH * 0.1);
      bodyPath.lineTo(cx + carW * 0.48, cy + carH * 0.3);
      bodyPath.close();

      canvas.drawPath(
        bodyPath,
        Paint()
          ..color = const Color(0xFF00BFFF).withValues(alpha: opacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }

    // Hex logo in corner
    if (style == WatermarkStyle.hexLogo || style == WatermarkStyle.combined) {
      final hx = size.width - 40;
      const hy = 40.0;
      const r = 16.0;

      final path = Path();
      for (int i = 0; i < 6; i++) {
        final angle = (60.0 * i - 30) * pi / 180;
        final x = hx + r * cos(angle);
        final y = hy + r * sin(angle);
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      path.close();

      canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0xFF00BFFF).withValues(alpha: opacity * 2)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _FullScreenWatermarkPainter old) =>
      old.opacity != opacity;
}

class _MiniHexPainter extends CustomPainter {
  final double opacity;

  _MiniHexPainter({required this.opacity});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width / 2 - 1;

    final path = Path();
    for (int i = 0; i < 6; i++) {
      final angle = (60.0 * i - 30) * pi / 180;
      final x = cx + r * cos(angle);
      final y = cy + r * sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();

    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFF00BFFF).withValues(alpha: opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(covariant _MiniHexPainter old) => old.opacity != opacity;
}
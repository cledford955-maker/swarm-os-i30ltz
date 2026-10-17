import 'dart:math';
import 'package:flutter/material.dart';

/// Clips a widget into a flat-top hexagon shape.
class HexagonClipper extends CustomClipper<Path> {
  final bool flatTop;

  HexagonClipper({this.flatTop = true});

  @override
  Path getClip(Size size) {
    return hexagonPath(size, flatTop: flatTop);
  }

  @override
  bool shouldReclip(covariant HexagonClipper oldClipper) =>
      oldClipper.flatTop != flatTop;

  /// Builds a hexagon path that fills the given [size].
  static Path hexagonPath(Size size, {bool flatTop = true}) {
    final path = Path();
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final cy = h / 2;

    if (flatTop) {
      final rx = w / 2;
      final ry = h / 2;
      for (int i = 0; i < 6; i++) {
        final angleDeg = 60.0 * i;
        final angleRad = angleDeg * pi / 180.0;
        final x = cx + rx * cos(angleRad);
        final y = cy + ry * sin(angleRad);
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
    } else {
      final rx = w / 2;
      final ry = h / 2;
      for (int i = 0; i < 6; i++) {
        final angleDeg = 60.0 * i - 30.0;
        final angleRad = angleDeg * pi / 180.0;
        final x = cx + rx * cos(angleRad);
        final y = cy + ry * sin(angleRad);
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
    }

    path.close();
    return path;
  }

  static double get flatTopAspect => 2.0 / sqrt(3);
  static double get pointyTopAspect => sqrt(3) / 2.0;

  /// Given a flat-top hex width, returns correct height.
  static double heightForWidth(double width) => width * sqrt(3) / 2.0;

  /// Given a flat-top hex height, returns correct width.
  static double widthForHeight(double height) => height * 2.0 / sqrt(3);
}

/// A widget that clips its child into a hexagon with optional glowing border.
class HexagonWidget extends StatelessWidget {
  final Widget child;
  final double width;
  final double height;
  final bool flatTop;
  final Color borderColor;
  final double borderWidth;
  final Color? glowColor;
  final double glowRadius;

  const HexagonWidget({
    super.key,
    required this.child,
    required this.width,
    required this.height,
    this.flatTop = true,
    this.borderColor = const Color(0xFF00FFFF),
    this.borderWidth = 1.5,
    this.glowColor,
    this.glowRadius = 8.0,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(
        painter: _HexBorderPainter(
          flatTop: flatTop,
          borderColor: borderColor,
          borderWidth: borderWidth,
          glowColor: glowColor ?? borderColor.withValues(alpha: 0.4),
          glowRadius: glowRadius,
        ),
        child: ClipPath(
          clipper: HexagonClipper(flatTop: flatTop),
          child: child,
        ),
      ),
    );
  }
}

class _HexBorderPainter extends CustomPainter {
  final bool flatTop;
  final Color borderColor;
  final double borderWidth;
  final Color glowColor;
  final double glowRadius;

  _HexBorderPainter({
    required this.flatTop,
    required this.borderColor,
    required this.borderWidth,
    required this.glowColor,
    required this.glowRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final path = HexagonClipper.hexagonPath(size, flatTop: flatTop);

    if (glowRadius > 0) {
      final glowPaint = Paint()
        ..color = glowColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = borderWidth + glowRadius
        ..maskFilter = MaskFilter.blur(BlurStyle.outer, glowRadius);
      canvas.drawPath(path, glowPaint);
    }

    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth;
    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _HexBorderPainter old) =>
      old.borderColor != borderColor ||
      old.borderWidth != borderWidth ||
      old.glowColor != glowColor ||
      old.glowRadius != glowRadius;
}
import 'package:flutter/material.dart';
import 'dart:math';

/// Generates a flat-top hexagon path centered in [size].
Path hexPath(Size size, {double inset = 0}) {
  final path = Path();
  final cx = size.width / 2;
  final cy = size.height / 2;
  final r = min(size.width, size.height) / 2 - inset;
  for (int i = 0; i < 6; i++) {
    final angle = (60.0 * i - 30.0) * pi / 180.0;
    final x = cx + r * cos(angle);
    final y = cy + r * sin(angle);
    i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
  }
  path.close();
  return path;
}

/// Clips child to hexagon shape.
class HexClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) => hexPath(size);
  @override
  bool shouldReclip(covariant CustomClipper<Path> old) => false;
}

/// Paints a hexagon outline or fill.
class HexPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final bool filled;
  final Color? glowColor;

  HexPainter({
    this.color = Colors.cyanAccent,
    this.strokeWidth = 1.5,
    this.filled = false,
    this.glowColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final path = hexPath(size, inset: strokeWidth / 2);

    if (filled) {
      canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.fill,
      );
    }

    // Glow
    if (glowColor != null) {
      canvas.drawPath(
        path,
        Paint()
          ..color = glowColor!
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth + 4
          ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 8),
      );
    }

    // Stroke
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth,
    );
  }

  @override
  bool shouldRepaint(covariant HexPainter old) =>
      old.color != color || old.strokeWidth != strokeWidth || old.filled != filled;
}
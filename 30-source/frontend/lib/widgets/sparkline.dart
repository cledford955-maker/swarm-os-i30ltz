import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/swarm_colors.dart';

/// A tiny sparkline chart widget for inline data visualization.
class Sparkline extends StatelessWidget {
  final List<double> data;
  final double height;
  final double width;
  final Color? color;
  final bool filled;

  const Sparkline({
    super.key,
    required this.data,
    this.height = 24,
    this.width = 60,
    this.color,
    this.filled = true,
  });

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return SizedBox(width: width, height: height);
    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(
        painter: _SparklinePainter(
          data: data,
          lineColor: color ?? SwarmColors.accent,
          filled: filled,
        ),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final List<double> data;
  final Color lineColor;
  final bool filled;

  _SparklinePainter({
    required this.data,
    required this.lineColor,
    required this.filled,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.length < 2) return;

    final minVal = data.reduce(math.min);
    final maxVal = data.reduce(math.max);
    final range = maxVal - minVal;
    final effectiveRange = range == 0 ? 1.0 : range;

    final stepX = size.width / (data.length - 1);
    final points = <Offset>[];
    for (var i = 0; i < data.length; i++) {
      final normalised = (data[i] - minVal) / effectiveRange;
      points.add(Offset(i * stepX, size.height * (1 - normalised)));
    }

    // Line
    final linePaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeJoin = StrokeJoin.round;

    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }
    canvas.drawPath(path, linePaint);

    // Fill
    if (filled) {
      final fillPath = Path.from(path)
        ..lineTo(points.last.dx, size.height)
        ..lineTo(points.first.dx, size.height)
        ..close();

      final fillPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            lineColor.withValues(alpha: 0.25),
            lineColor.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
        ..style = PaintingStyle.fill;

      canvas.drawPath(fillPath, fillPaint);
    }
  }

  @override
  bool shouldRepaint(_SparklinePainter old) =>
      old.data != data || old.lineColor != lineColor;
}

import 'package:flutter/material.dart';
import '../theme/swarm_colors.dart';

/// A tiny horizontal bar chart visualization.
class MiniBar extends StatelessWidget {
  final double value; // 0.0 to 1.0
  final Color? color;
  final double height;
  final double width;

  const MiniBar({
    super.key,
    required this.value,
    this.color,
    this.height = 4,
    this.width = 40,
  });

  @override
  Widget build(BuildContext context) {
    final barColor = color ?? SwarmColors.accent;
    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(
        painter: _MiniBarPainter(
          value: value.clamp(0.0, 1.0),
          color: barColor,
          trackColor: SwarmColors.bgSurface,
        ),
      ),
    );
  }
}

class _MiniBarPainter extends CustomPainter {
  final double value;
  final Color color;
  final Color trackColor;

  _MiniBarPainter({
    required this.value,
    required this.color,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.fill;
    final barPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final radius = Radius.circular(size.height / 2);

    // Track
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, radius),
      trackPaint,
    );
    // Filled portion
    if (value > 0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, 0, size.width * value, size.height),
          radius,
        ),
        barPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_MiniBarPainter old) =>
      old.value != value || old.color != color;
}

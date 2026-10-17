import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/swarm_colors.dart';
import '../theme/swarm_text_styles.dart';

/// Circular progress ring with percentage label.
class ProgressRing extends StatelessWidget {
  final double value; // 0.0 to 1.0
  final double size;
  final Color? color;
  final bool showLabel;
  final double strokeWidth;

  const ProgressRing({
    super.key,
    required this.value,
    this.size = 56,
    this.color,
    this.showLabel = true,
    this.strokeWidth = 4,
  });

  @override
  Widget build(BuildContext context) {
    final ringColor = color ?? SwarmColors.accent;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(size, size),
            painter: _RingPainter(
              value: value.clamp(0.0, 1.0),
              color: ringColor,
              trackColor: SwarmColors.bgSurface,
              strokeWidth: strokeWidth,
            ),
          ),
          if (showLabel)
            Text(
              '${(value * 100).round()}%',
              style: SwarmTextStyles.labelSmall.copyWith(
                color: ringColor,
                fontWeight: FontWeight.w700,
              ),
            ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double value;
  final Color color;
  final Color trackColor;
  final double strokeWidth;

  _RingPainter({
    required this.value,
    required this.color,
    required this.trackColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    canvas.drawArc(
      rect, -math.pi / 2, 2 * math.pi, false,
      Paint()
        ..color = trackColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth,
    );

    if (value > 0) {
      canvas.drawArc(
        rect, -math.pi / 2, 2 * math.pi * value, false,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.value != value || old.color != color;
}

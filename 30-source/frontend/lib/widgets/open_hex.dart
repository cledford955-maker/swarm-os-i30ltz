import 'package:flutter/material.dart';
import 'hexagon_painter.dart';

/// An empty/open hexagon placeholder between agent cards.
class OpenHex extends StatelessWidget {
  final double size;
  final Color color;

  const OpenHex({
    super.key,
    this.size = 120,
    this.color = const Color(0x14FFFFFF),
  });

  @override
  Widget build(BuildContext context) {
    final h = size * 1.1547;
    return SizedBox(
      width: size,
      height: h,
      child: CustomPaint(
        size: Size(size, h),
        painter: HexPainter(
          color: color,
          strokeWidth: 0.8,
          filled: false,
        ),
      ),
    );
  }
}
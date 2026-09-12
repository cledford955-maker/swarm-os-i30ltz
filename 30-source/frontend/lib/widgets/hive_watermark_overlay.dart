import 'package:flutter/material.dart';
import '../theme/swarm_colors.dart';

/// Full-screen non-intrusive watermark overlay
/// Stamping 'I320K3-N-I30LTZ' and 'WELCOME TO THE HIVE!!!' across all views
class HiveWatermarkOverlay extends StatelessWidget {
  const HiveWatermarkOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          // 1. Repeating Diagonal Matrix Watermark
          Positioned.fill(
            child: CustomPaint(
              painter: _WatermarkGridPainter(),
            ),
          ),

          // 2. High-Tech Corner Watermark Badge (Bottom Right)
          Positioned(
            right: 16,
            bottom: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: SwarmColors.accent.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: SwarmColors.accent,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'I320K3-N-I30LTZ // WELCOME TO THE HIVE',
                    style: TextStyle(
                      color: SwarmColors.accent,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 3. High-Tech Corner Watermark Badge (Top Right below TopBar)
          const Positioned(
            right: 20,
            top: 56,
            child: Opacity(
              opacity: 0.25,
              child: Text(
                'AUTH_SIG: I320K3-N-I30LTZ',
                style: TextStyle(
                  color: SwarmColors.accentCyan,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2.0,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Large background ambient typography: "WELCOME TO THE HIVE!!!"
class HiveBackgroundWelcome extends StatelessWidget {
  const HiveBackgroundWelcome({super.key});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'WELCOME TO THE HIVE!!!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 72,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 6,
                  color: SwarmColors.accent.withValues(alpha: 0.05),
                  shadows: [
                    Shadow(
                      color: SwarmColors.accent.withValues(alpha: 0.12),
                      blurRadius: 30,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'I320K3-N-I30LTZ · SWARM OS · CYBERNETIC MESH',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 8,
                  fontFamily: 'monospace',
                  color: SwarmColors.agentPurple.withValues(alpha: 0.04),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WatermarkGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const text = 'I320K3-N-I30LTZ';
    const textStyle = TextStyle(
      color: Color(0x1276B900), // ~7% opacity NVIDIA Green
      fontSize: 14,
      fontWeight: FontWeight.bold,
      letterSpacing: 2.0,
      fontFamily: 'monospace',
    );

    const textSpan = TextSpan(text: text, style: textStyle);
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    )..layout();

    final stepX = textPainter.width + 120;
    final stepY = textPainter.height + 90;

    canvas.save();
    canvas.rotate(-0.35); // ~20 degree tilt

    // Draw repeating rows and columns
    for (double x = -size.width; x < size.width * 2; x += stepX) {
      for (double y = -size.height; y < size.height * 2; y += stepY) {
        textPainter.paint(canvas, Offset(x, y));
      }
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

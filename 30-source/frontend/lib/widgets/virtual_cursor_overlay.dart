import 'package:flutter/material.dart';
import '../services/gamepad_service.dart';
import '../theme/swarm_colors.dart';

class VirtualCursorOverlay extends StatelessWidget {
  const VirtualCursorOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: GamepadService(),
      builder: (context, _) {
        final service = GamepadService();
        service.updateScreenSize(MediaQuery.of(context).size);

        if (!service.isVirtualCursorActive) {
          return const SizedBox.shrink();
        }

        final pos = service.cursorPosition;

        return Stack(
          children: [
            // Cursor Crosshair
            Positioned(
              left: pos.dx - 16,
              top: pos.dy - 16,
              child: IgnorePointer(
                child: SizedBox(
                  width: 32,
                  height: 32,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Outer pulsing ring
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: SwarmColors.accent.withValues(alpha: 0.8),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: SwarmColors.accent.withValues(alpha: 0.5),
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                      ),
                      // Center dot
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: SwarmColors.textPrimary,
                        ),
                      ),
                      // Crosshairs
                      Container(width: 1.5, height: 32, color: SwarmColors.accent.withValues(alpha: 0.4)),
                      Container(width: 32, height: 1.5, color: SwarmColors.accent.withValues(alpha: 0.4)),
                    ],
                  ),
                ),
              ),
            ),

            // On-screen Gamepad HUD Indicator
            Positioned(
              bottom: 24,
              left: 0,
              right: 0,
              child: Center(
                child: IgnorePointer(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: SwarmColors.bgSurface.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: SwarmColors.accent.withValues(alpha: 0.6)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.6),
                          blurRadius: 16,
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.sports_esports, color: SwarmColors.accent, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'CONTROLLER MOUSE: LT [Hold]  •  Right Stick [Aim]  •  RT [Click]  •  RB [Right-Click]',
                          style: TextStyle(
                            color: SwarmColors.textPrimary,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

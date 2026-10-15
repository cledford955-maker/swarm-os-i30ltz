// ═══════════════════════════════════════════════════════════════
// Swarm OS — Floating whole-shell zoom control
// Small persistent -/reset/+ pill, bottom-left, on every screen.
// Also responds to Ctrl+= / Ctrl+- / Ctrl+0 anywhere in the app.
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/ui_scale_service.dart';
import '../theme/swarm_colors.dart';
import '../shell/desktop_geometry.dart';

class UiZoomControl extends StatelessWidget {
  const UiZoomControl({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<UiScaleService>(
      builder: (context, ui, _) {
        return Positioned(
          left: 12,
          // Clear the static taskbar at the bottom of the screen.
          bottom: 12 + DesktopGeometry.taskbarHeight,
          child: Material(
            color: Colors.transparent,
            child: SafeArea(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                decoration: BoxDecoration(
                  color: SwarmColors.bgElevated.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  _btn(Icons.remove, ui.scale > UiScaleService.min ? ui.zoomOut : null),
                  GestureDetector(
                    onTap: ui.reset,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Text(
                        '${(ui.scale * 100).round()}%',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  _btn(Icons.add, ui.scale < UiScaleService.max ? ui.zoomIn : null),
                ]),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _btn(IconData icon, VoidCallback? onTap) {
    // Semantics, not Tooltip: this control is built in MaterialApp.builder,
    // above the Navigator, so there is no Overlay for a Tooltip to use.
    // A Tooltip here threw "No Overlay widget found", which a release build
    // paints as a full-screen light-grey error box (the "white overlay").
    return Semantics(
      button: true,
      label: icon == Icons.add ? 'Zoom in (Ctrl+=)' : 'Zoom out (Ctrl+-)',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          child: Icon(icon,
            size: 15,
            color: onTap != null
                ? Colors.white.withValues(alpha: 0.8)
                : Colors.white.withValues(alpha: 0.2)),
        ),
      ),
    );
  }
}

/// Scales every screen in the shell uniformly (icons, text, layout — not
/// just fonts), keeping hit-testing correct. Content is laid out against a
/// shrunk/grown "virtual" screen size and then stretched back to the real
/// one via Transform.scale.
///
/// Always wraps, even at 1.0, so the widget tree keeps the same shape when
/// the scale crosses 100% — otherwise the Router below is torn down and
/// rebuilt on that step.
class WholeShellZoom extends StatelessWidget {
  final double scale;
  final Widget child;
  const WholeShellZoom({super.key, required this.scale, required this.child});

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final virtualSize = mq.size / scale;
    return MediaQuery(
      data: mq.copyWith(size: virtualSize),
      child: ClipRect(
        child: OverflowBox(
          alignment: Alignment.topLeft,
          minWidth: virtualSize.width,
          maxWidth: virtualSize.width,
          minHeight: virtualSize.height,
          maxHeight: virtualSize.height,
          child: Transform.scale(
            scale: scale,
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: virtualSize.width,
              height: virtualSize.height,
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

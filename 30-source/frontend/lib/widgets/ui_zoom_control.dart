// ═══════════════════════════════════════════════════════════════
// Swarm OS — Floating whole-shell zoom control
// Small persistent -/reset/+ pill, bottom-left, on every screen.
// Also responds to Ctrl+= / Ctrl+- / Ctrl+0 anywhere in the app.
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/ui_scale_service.dart';
import '../theme/swarm_colors.dart';

class UiZoomControl extends StatelessWidget {
  const UiZoomControl({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<UiScaleService>(
      builder: (context, ui, _) {
        return Positioned(
          left: 12,
          bottom: 12,
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
    return Tooltip(
      message: icon == Icons.add ? 'Zoom in (Ctrl+=)' : 'Zoom out (Ctrl+-)',
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

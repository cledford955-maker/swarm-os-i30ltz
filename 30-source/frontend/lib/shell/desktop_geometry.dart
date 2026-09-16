// ═══════════════════════════════════════════════════════════════
// Swarm OS — Desktop geometry (2026-09-16)
//
// One place that knows where the desktop icon rails are, so the icon grid
// and the window manager agree. Each side of the screen, from the edge in:
//   1 free column · 2 staggered icon columns
// New windows open centered in the zone between the two rails.
// ═══════════════════════════════════════════════════════════════

import 'dart:math' as math;
import 'package:flutter/widgets.dart';

class DesktopGeometry {
  DesktopGeometry._();

  /// Shell size in logical (zoomed) pixels — updated by SwarmShell on layout.
  static Size screen = const Size(1440, 900);

  static const double topBarHeight = 44;
  static const double _gap = 16;

  /// One icon cell. Scales with screen width, within readable bounds.
  static double get cell => (screen.width * 0.045).clamp(72.0, 96.0);

  /// Width of one side rail: the free column plus two icon columns.
  static double get railWidth => cell * 3;

  /// Where windows live: between the rails, below the top bar.
  static Rect get windowZone => Rect.fromLTRB(
        railWidth + _gap,
        topBarHeight + _gap,
        math.max(railWidth + _gap + 320, screen.width - railWidth - _gap),
        math.max(topBarHeight + _gap + 240, screen.height - _gap),
      );

  /// Center a new window in the zone, shrinking it to fit. [stackIndex]
  /// cascades each additional window a little so they don't hide each other.
  static Rect place(Size wanted, int stackIndex) {
    final zone = windowZone;
    final size = Size(math.min(wanted.width, zone.width), math.min(wanted.height, zone.height));
    final step = 28.0 * (stackIndex % 6);
    final left = (zone.left + (zone.width - size.width) / 2 + step)
        .clamp(zone.left, zone.right - size.width);
    final top = (zone.top + (zone.height - size.height) / 2 + step)
        .clamp(zone.top, zone.bottom - size.height);
    return Offset(left, top) & size;
  }
}

// ═══════════════════════════════════════════════════════════════
// Swarm OS — Whole-shell UI zoom
//
// A single scale factor applied to the entire Flutter shell (every
// screen, not just one widget) via a Transform.scale wrapper around
// the router's child in main.dart. Persisted per-user so it survives
// restarts.
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Wraps another [TextScaler] and guarantees the scaled result is never
/// smaller than [minSize] logical pixels, no matter how small the widget's
/// declared font size is. SWARM OS text styles run 10-14px by design; at
/// "100%" (no extra OS/accessibility scaling) nothing should render below
/// a readable floor.
class MinimumFontSizeTextScaler extends TextScaler {
  const MinimumFontSizeTextScaler(this.base, {this.minSize = 16});

  final TextScaler base;
  final double minSize;

  @override
  double scale(double fontSize) {
    final scaled = base.scale(fontSize);
    return scaled < minSize ? minSize : scaled;
  }

  @override
  // ignore: deprecated_member_use
  double get textScaleFactor => base.textScaleFactor;

  @override
  bool operator ==(Object other) =>
      other is MinimumFontSizeTextScaler &&
      other.base == base &&
      other.minSize == minSize;

  @override
  int get hashCode => Object.hash(base, minSize);
}

class UiScaleService extends ChangeNotifier {
  // v2 (2026-09-16): default raised to 1.3 — new key so a scale saved under
  // the old 1.0 default doesn't keep the desktop zoomed out.
  static const _key = 'swarm_ui_scale_v2';
  static const double min = 0.75;
  static const double max = 1.75;
  static const double step = 0.1;
  static const double defaultScale = 1.3;

  double _scale = defaultScale;
  double get scale => _scale;

  UiScaleService() {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getDouble(_key);
      if (saved != null) {
        _scale = saved.clamp(min, max);
        notifyListeners();
      }
    } catch (_) {
      // Prefs unavailable — stay at the default
    }
  }

  void zoomIn() => _setScale(_scale + step);
  void zoomOut() => _setScale(_scale - step);
  void reset() => _setScale(defaultScale);

  void _setScale(double value) {
    final clamped = value.clamp(min, max);
    if (clamped == _scale) return;
    _scale = clamped;
    notifyListeners();
    SharedPreferences.getInstance()
        .then((p) => p.setDouble(_key, _scale))
        .catchError((_) => false);
  }
}

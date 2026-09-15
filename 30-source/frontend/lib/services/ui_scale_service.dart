// ═══════════════════════════════════════════════════════════════
// Swarm OS — Whole-shell UI zoom
//
// A single scale factor applied to the entire Flutter shell (every
// screen, not just one widget) via a Transform.scale wrapper around
// the router's child in main.dart. Persisted per-user so it survives
// restarts.
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UiScaleService extends ChangeNotifier {
  static const _key = 'swarm_ui_scale';
  static const double min = 0.75;
  static const double max = 1.75;
  static const double step = 0.1;

  double _scale = 1.0;
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
      // Prefs unavailable — stay at default 1.0
    }
  }

  void zoomIn() => _setScale(_scale + step);
  void zoomOut() => _setScale(_scale - step);
  void reset() => _setScale(1.0);

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

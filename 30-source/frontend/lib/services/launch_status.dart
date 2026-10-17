import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';

/// Per-tile launch lifecycle, driving the hex icon status aura:
/// blinking green while starting, solid green while running, one red
/// flash when the app closes (or fails to start at all).
enum LaunchAuraState { idle, loading, running, closed }

/// Global registry keyed by agent/tile id. Global rather than owned by any
/// one widget because launches are fire-and-forget native processes with
/// no natural owning widget, and the same tile id can be driven from
/// either an external process launch or an in-app window's lifecycle.
class LaunchStatusRegistry {
  LaunchStatusRegistry._();

  static final Map<String, ValueNotifier<LaunchAuraState>> _states = {};
  static final Map<String, Timer> _pollers = {};

  static ValueNotifier<LaunchAuraState> notifierFor(String id) =>
      _states.putIfAbsent(id, () => ValueNotifier(LaunchAuraState.idle));

  static void setLoading(String id) {
    _pollers.remove(id)?.cancel();
    notifierFor(id).value = LaunchAuraState.loading;
  }

  static void setRunning(String id) {
    notifierFor(id).value = LaunchAuraState.running;
  }

  static void setIdle(String id) {
    _pollers.remove(id)?.cancel();
    notifierFor(id).value = LaunchAuraState.idle;
  }

  // One red flash, then auto-reverts to idle so the aura doesn't linger.
  static void setClosed(String id) {
    _pollers.remove(id)?.cancel();
    notifierFor(id).value = LaunchAuraState.closed;
    Timer(const Duration(milliseconds: 650), () {
      if (notifierFor(id).value == LaunchAuraState.closed) {
        notifierFor(id).value = LaunchAuraState.idle;
      }
    });
  }

  /// Polls a liveness marker file on disk until it disappears, then reports
  /// the tile as closed. Needed for externally launched *detached* native
  /// processes — once detached, Dart can no longer observe their real exit
  /// code, so liveness is tracked via a file the shell wrapper removes the
  /// moment the launched command's subshell exits.
  static void watchMarkerFile(String id, String markerPath,
      {Duration interval = const Duration(milliseconds: 1200)}) {
    _pollers.remove(id)?.cancel();
    _pollers[id] = Timer.periodic(interval, (timer) async {
      final exists = await File(markerPath).exists();
      if (!exists) {
        timer.cancel();
        _pollers.remove(id);
        setClosed(id);
      }
    });
  }
}

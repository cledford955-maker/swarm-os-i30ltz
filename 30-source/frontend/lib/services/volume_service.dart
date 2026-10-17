// ═══════════════════════════════════════════════════════════════
// Swarm OS — Real system volume (2026-10-15)
//
// The top-bar volume button used to be a bare IconButton with an empty
// onPressed. This talks to the real audio stack: PipeWire's `wpctl`
// first (that's what SWARM OS actually runs — see the old tooltip,
// "PipeWire Audio"), falling back to `pactl` (PulseAudio compat) so the
// control still does something useful on a system without wpctl.
// ═══════════════════════════════════════════════════════════════

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';

class VolumeService extends ChangeNotifier {
  static const _sink = '@DEFAULT_AUDIO_SINK@';
  static const _pactlSink = '@DEFAULT_SINK@';

  double _volume = 0.5; // 0.0 - 1.0 (can exceed 1.0 on some sinks)
  bool _muted = false;
  bool _available = false;
  String? _error;
  Timer? _poll;

  double get volume => _volume;
  bool get muted => _muted;
  bool get available => _available;
  String? get error => _error;

  VolumeService() {
    refresh();
    _poll = Timer.periodic(const Duration(seconds: 4), (_) => refresh());
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> refresh() async {
    if (await _refreshViaWpctl()) return;
    if (await _refreshViaPactl()) return;
    _available = false;
    _error = 'No PipeWire (wpctl) or PulseAudio (pactl) found';
    notifyListeners();
  }

  Future<bool> _refreshViaWpctl() async {
    try {
      final r = await Process.run('wpctl', const ['get-volume', _sink]);
      if (r.exitCode != 0) return false;
      final out = (r.stdout as String).trim();
      final match = RegExp(r'[\d.]+').firstMatch(out);
      if (match != null) _volume = double.tryParse(match.group(0)!) ?? _volume;
      _muted = out.contains('[MUTED]');
      _available = true;
      _error = null;
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _refreshViaPactl() async {
    try {
      final r = await Process.run('pactl', const ['get-sink-volume', _pactlSink]);
      if (r.exitCode != 0) return false;
      final match = RegExp(r'(\d+)%').firstMatch(r.stdout as String);
      if (match != null) _volume = int.parse(match.group(1)!) / 100.0;
      final m = await Process.run('pactl', const ['get-sink-mute', _pactlSink]);
      _muted = (m.stdout as String).contains('yes');
      _available = true;
      _error = null;
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> setVolume(double v) async {
    final clamped = v.clamp(0.0, 1.0);
    _volume = clamped;
    notifyListeners();
    try {
      final r = await Process.run(
          'wpctl', ['set-volume', _sink, clamped.toStringAsFixed(2)]);
      if (r.exitCode == 0) return;
    } catch (_) {}
    try {
      await Process.run(
          'pactl', ['set-sink-volume', _pactlSink, '${(clamped * 100).round()}%']);
    } catch (_) {}
  }

  Future<void> toggleMute() async {
    _muted = !_muted;
    notifyListeners();
    try {
      final r = await Process.run('wpctl', const ['set-mute', _sink, 'toggle']);
      if (r.exitCode == 0) return;
    } catch (_) {}
    try {
      await Process.run('pactl', const ['set-sink-mute', _pactlSink, 'toggle']);
    } catch (_) {}
  }
}

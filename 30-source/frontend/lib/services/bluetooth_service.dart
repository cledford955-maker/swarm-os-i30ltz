// ═══════════════════════════════════════════════════════════════
// Swarm OS — Real Bluetooth control (2026-10-15)
//
// The top-bar Bluetooth button used to be a bare IconButton with an
// empty onPressed. This drives `bluetoothctl` non-interactively (each
// call below is a complete, self-contained invocation — no persistent
// interactive session is kept open) to report power state, list
// paired/connected devices, scan, and connect/disconnect.
// ═══════════════════════════════════════════════════════════════

import 'dart:io';
import 'package:flutter/foundation.dart';

class BluetoothDevice {
  final String mac;
  final String name;
  final bool paired;
  final bool connected;
  const BluetoothDevice({
    required this.mac,
    required this.name,
    this.paired = false,
    this.connected = false,
  });
}

class BluetoothService extends ChangeNotifier {
  bool _available = false;
  bool _powered = false;
  bool _scanning = false;
  String? _error;
  List<BluetoothDevice> _devices = const [];

  bool get available => _available;
  bool get powered => _powered;
  bool get scanning => _scanning;
  String? get error => _error;
  List<BluetoothDevice> get devices => _devices;

  BluetoothService() {
    refreshStatus();
  }

  Future<void> refreshStatus() async {
    try {
      final show = await Process.run('bluetoothctl', const ['show']);
      if (show.exitCode != 0) {
        _available = false;
        _error = 'bluetoothctl not available on this system';
        notifyListeners();
        return;
      }
      _available = true;
      _error = null;
      _powered = (show.stdout as String).contains('Powered: yes');
      await _refreshDevices();
    } catch (e) {
      _available = false;
      _error = 'Bluetooth control unavailable: $e';
      notifyListeners();
    }
  }

  Future<void> _refreshDevices() async {
    try {
      final paired = await Process.run('bluetoothctl', const ['devices', 'Paired']);
      final connected = await Process.run('bluetoothctl', const ['devices', 'Connected']);
      final connectedMacs = _macsIn(connected.stdout as String? ?? '');
      final list = <BluetoothDevice>[];
      for (final line in (paired.stdout as String? ?? '').split('\n')) {
        final m = RegExp(r'Device ([0-9A-Fa-f:]{17}) (.+)').firstMatch(line.trim());
        if (m == null) continue;
        final mac = m.group(1)!;
        list.add(BluetoothDevice(
          mac: mac,
          name: m.group(2)!.trim(),
          paired: true,
          connected: connectedMacs.contains(mac),
        ));
      }
      _devices = list;
    } catch (_) {
      // Keep whatever device list we already had.
    }
    notifyListeners();
  }

  Set<String> _macsIn(String out) {
    final set = <String>{};
    for (final line in out.split('\n')) {
      final m = RegExp(r'Device ([0-9A-Fa-f:]{17})').firstMatch(line.trim());
      if (m != null) set.add(m.group(1)!);
    }
    return set;
  }

  Future<void> setPowered(bool on) async {
    _powered = on;
    notifyListeners();
    try {
      await Process.run('bluetoothctl', ['power', on ? 'on' : 'off']);
    } catch (_) {}
    await refreshStatus();
  }

  /// Scans for nearby devices for [timeout], then refreshes the list.
  /// `bluetoothctl --timeout Ns scan on` runs the scan and returns on its
  /// own — no need to separately stop it.
  Future<void> scan({Duration timeout = const Duration(seconds: 6)}) async {
    if (_scanning || !_powered) return;
    _scanning = true;
    notifyListeners();
    try {
      await Process.run(
          'bluetoothctl', ['--timeout', '${timeout.inSeconds}', 'scan', 'on']);
    } catch (_) {}
    _scanning = false;
    await _refreshDevices();
  }

  Future<void> connect(String mac) async {
    try {
      await Process.run('bluetoothctl', ['connect', mac]);
    } catch (_) {}
    await _refreshDevices();
  }

  Future<void> disconnect(String mac) async {
    try {
      await Process.run('bluetoothctl', ['disconnect', mac]);
    } catch (_) {}
    await _refreshDevices();
  }
}

import 'dart:convert';
import 'dart:io' hide Platform;
import '../platform/platform.dart';
import 'dart:async';

import 'package:http/http.dart' as http;
import 'swarm_config.dart';

/// Real system telemetry via dart:io — replaces the Tauri Rust commands.
/// Reads /proc/ and runs lightweight system commands for live metrics.
class TelemetryService {
  /// Get available RAM in GB.
  Future<double> getAvailableRam() async {
    try {
      final contents = await File('/proc/meminfo').readAsString();
      for (final line in contents.split('\n')) {
        if (line.startsWith('MemAvailable:')) {
          final kb = int.parse(line.split(RegExp(r'\s+'))[1]);
          return kb / (1024 * 1024);
        }
      }
    } catch (_) {}
    return 0;
  }

  /// Get total RAM in GB.
  Future<double> getTotalRam() async {
    try {
      final contents = await File('/proc/meminfo').readAsString();
      for (final line in contents.split('\n')) {
        if (line.startsWith('MemTotal:')) {
          final kb = int.parse(line.split(RegExp(r'\s+'))[1]);
          return kb / (1024 * 1024);
        }
      }
    } catch (_) {}
    return 0;
  }

  /// Get CPU usage percentage (average across all cores).
  Future<double> getCpuUsage() async {
    try {
      final stat1 = await _readCpuStat();
      await Future<void>.delayed(const Duration(milliseconds: 250));
      final stat2 = await _readCpuStat();

      final idle = stat2.idle - stat1.idle;
      final total = stat2.total - stat1.total;
      if (total == 0) return 0;
      return ((total - idle) / total) * 100;
    } catch (_) {
      return 0;
    }
  }

  /// Get CPU temperature in Celsius (if thermal zone available).
  Future<double> getCpuTemp() async {
    try {
      final temp = await File('/sys/class/thermal/thermal_zone0/temp')
          .readAsString();
      return int.parse(temp.trim()) / 1000.0;
    } catch (_) {
      return 0;
    }
  }

  /// Get hostname.
  Future<String> getHostname() async {
    try {
      return (await File('/etc/hostname').readAsString()).trim();
    } catch (_) {
      return Platform.localHostname;
    }
  }

  /// Get kernel version.
  Future<String> getKernel() async {
    try {
      final result = await Process.run('uname', ['-r']);
      return (result.stdout as String).trim();
    } catch (_) {
      return 'unknown';
    }
  }

  /// Get system uptime as a Duration.
  Future<Duration> getUptime() async {
    try {
      final contents = await File('/proc/uptime').readAsString();
      final seconds = double.parse(contents.split(' ').first);
      return Duration(seconds: seconds.toInt());
    } catch (_) {
      return Duration.zero;
    }
  }

  /// List running processes (top-level info).
  Future<List<ProcessInfo>> getProcesses() async {
    try {
      final result = await Process.run(
        'ps',
        ['aux', '--sort=-pcpu'],
      );
      final lines = (result.stdout as String).split('\n');
      if (lines.length < 2) return [];
      return lines
          .skip(1)
          .where((l) => l.trim().isNotEmpty)
          .take(20)
          .map((line) {
        final parts = line.split(RegExp(r'\s+'));
        if (parts.length < 11) return null;
        return ProcessInfo(
          user: parts[0],
          pid: int.tryParse(parts[1]) ?? 0,
          cpu: double.tryParse(parts[2]) ?? 0,
          mem: double.tryParse(parts[3]) ?? 0,
          command: parts.sublist(10).join(' '),
        );
      })
          .whereType<ProcessInfo>()
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Get full mesh summary for connected Tailscale / companion nodes
  Future<Map<String, dynamic>> getMeshSummary() async {
    final hostname = await getHostname();
    final cpu = await getCpuUsage();
    final ramUsed = await getTotalRam() - await getAvailableRam();
    final ramTotal = await getTotalRam();

    final devices = <Map<String, dynamic>>[
      {
        'device_id': 'workstation-local',
        'hostname': '$hostname (SWARM OS)',
        'device_type': 'desktop',
        'online': true,
        'ip': await _tailscaleIp(),
        'platform': 'Arch Linux',
        'telemetry': {
          'cpu_percent': cpu,
          'ram_percent': ramTotal > 0 ? (ramUsed / ramTotal) * 100 : 0,
          'ram_used_gb': ramUsed,
          'ram_total_gb': ramTotal,
        },
      },
    ];

    // Fetch real companion connections from LucyServer's /api/companion/status.
    try {
      final uri = Uri.parse('${SwarmConfig.httpBase}/api/companion/status');
      final resp = await http.get(uri, headers: SwarmConfig.authHeaders)
          .timeout(const Duration(seconds: 3));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final companions = data['companions'] as List? ?? [];
        for (final c in companions) {
          devices.add({
            'device_id': c['device_id'] ?? 'unknown',
            'hostname': c['device_name'] ?? 'Companion',
            'device_type': 'phone',
            'online': true,
            'ip': '',
            'platform': 'Android',
            'telemetry': {},
          });
        }
      }
    } catch (_) {}

    return {
      'mesh_name': 'SWARM Tailscale Mesh',
      'active_node_count': devices.where((d) => d['online'] == true).length,
      'devices': devices,
    };
  }

  /// Get detailed telemetry for a specific device in the mesh.
  /// For the local workstation: real /proc data. For companions: we only
  /// know they're connected (no remote telemetry endpoint yet).
  Future<Map<String, dynamic>?> getDeviceTelemetry(String id) async {
    if (id != 'workstation-local') {
      return {
        'device_id': id,
        'hostname': id,
        'device_type': 'phone',
        'online': true,
        'platform': 'Android',
        'telemetry': {},
      };
    }

    final cpu = await getCpuUsage();
    final temp = await getCpuTemp();
    final ramTotal = await getTotalRam();
    final ramUsed = ramTotal - await getAvailableRam();

    final disks = <Map<String, dynamic>>[];
    try {
      final result = await Process.run('df', ['-BG', '--output=target,fstype,size,used,pcent', '/']);
      for (final line in (result.stdout as String).split('\n').skip(1)) {
        final parts = line.trim().split(RegExp(r'\s+'));
        if (parts.length >= 5) {
          disks.add({
            'mountpoint': parts[0],
            'fstype': parts[1],
            'total_gb': double.tryParse(parts[2].replaceAll('G', '')) ?? 0,
            'used_gb': double.tryParse(parts[3].replaceAll('G', '')) ?? 0,
            'percent': double.tryParse(parts[4].replaceAll('%', '')) ?? 0,
          });
        }
      }
    } catch (_) {}

    return {
      'device_id': id,
      'hostname': await getHostname(),
      'device_type': 'desktop',
      'online': true,
      'ip': await _tailscaleIp(),
      'platform': 'Arch Linux',
      'telemetry': {
        'cpu_percent': cpu,
        'percent_total': cpu,
        'cpu': {
          'percent_total': cpu,
          'temp_c': temp,
          'physical_cores': Platform.numberOfProcessors,
          'logical_cores': Platform.numberOfProcessors,
        },
        'memory': {
          'ram_percent': ramTotal > 0 ? (ramUsed / ramTotal) * 100 : 0,
          'ram_used_gb': double.parse(ramUsed.toStringAsFixed(1)),
          'ram_total_gb': double.parse(ramTotal.toStringAsFixed(1)),
        },
        'ram_percent': ramTotal > 0 ? (ramUsed / ramTotal) * 100 : 0,
        'disk': disks,
      },
    };
  }

  /// Scan network by re-fetching the mesh summary (real companion connections).
  Future<List<Map<String, dynamic>>> scanNetwork() async {
    final mesh = await getMeshSummary();
    return (mesh['devices'] as List? ?? []).cast<Map<String, dynamic>>();
  }

  /// Shared clipboard retrieval via LucyServer's /api/clipboard.
  Future<String> getSharedClipboard() async {
    try {
      final result = await Process.run('bash', ['-c', 'wl-paste 2>/dev/null || xclip -selection clipboard -o 2>/dev/null || echo ""']);
      return (result.stdout as String).trim();
    } catch (_) {
      return '';
    }
  }

  /// Shared file list — returns files in the Lucille sync directory if it exists.
  Future<List<dynamic>> getSharedFiles() async {
    try {
      final dir = Directory('/tmp/lucille_sync');
      if (!await dir.exists()) return [];
      return await dir.list().map((e) => {
        'filename': e.path.split('/').last,
        'from_device': 'local',
      }).toList();
    } catch (_) {
      return [];
    }
  }

  /// Send mesh alert notification (placeholder — needs real push infrastructure).
  Future<bool> sendNotification(String targetId, String title, String body, [String senderId = '']) async {
    return false;
  }

  // ─── Internal ─────────────────────────────────────────────────────────

  Future<String> _tailscaleIp() async {
    try {
      final result = await Process.run('tailscale', ['ip', '-4']);
      final ip = (result.stdout as String).trim();
      if (ip.isNotEmpty && result.exitCode == 0) return ip;
    } catch (_) {}
    return '';
  }

  Future<_CpuStat> _readCpuStat() async {
    final contents = await File('/proc/stat').readAsString();
    final firstLine = contents.split('\n').first;
    final parts = firstLine.split(RegExp(r'\s+'));
    // cpu user nice system idle iowait irq softirq steal
    final values = parts.sublist(1).map((s) => int.tryParse(s) ?? 0).toList();
    final idle = values.length > 3 ? values[3] : 0;
    final total = values.fold<int>(0, (a, b) => a + b);
    return _CpuStat(idle: idle, total: total);
  }
}

class _CpuStat {
  final int idle;
  final int total;
  const _CpuStat({required this.idle, required this.total});
}

class ProcessInfo {
  final String user;
  final int pid;
  final double cpu;
  final double mem;
  final String command;
  const ProcessInfo({
    required this.user,
    required this.pid,
    required this.cpu,
    required this.mem,
    required this.command,
  });
}

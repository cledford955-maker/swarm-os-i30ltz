import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/telemetry_service.dart';
import 'sentinel_providers.dart';

/// Snapshot of system telemetry.
class TelemetrySnapshot {
  final double cpuPercent;
  final double cpuTempC;
  final double ramUsedGb;
  final double ramTotalGb;
  final String kernel;
  final String hostname;
  final Duration uptime;
  final List<ProcessInfo> topProcesses;

  const TelemetrySnapshot({
    required this.cpuPercent,
    required this.cpuTempC,
    required this.ramUsedGb,
    required this.ramTotalGb,
    required this.kernel,
    required this.hostname,
    required this.uptime,
    required this.topProcesses,
  });

  double get ramPercent => ramTotalGb > 0 ? (ramUsedGb / ramTotalGb) * 100 : 0;
  String get uptimeFormatted {
    final h = uptime.inHours;
    final m = uptime.inMinutes.remainder(60);
    return '${h}h ${m}m';
  }

  static const TelemetrySnapshot empty = TelemetrySnapshot(
    cpuPercent: 0,
    cpuTempC: 0,
    ramUsedGb: 0,
    ramTotalGb: 0,
    kernel: '...',
    hostname: 'SWARM-OS',
    uptime: Duration.zero,
    topProcesses: [],
  );
}

/// Streams live telemetry at a configurable interval.
class TelemetryNotifier extends AsyncNotifier<TelemetrySnapshot> {
  Timer? _timer;
  static const _interval = Duration(seconds: 3);

  @override
  Future<TelemetrySnapshot> build() async {
    ref.onDispose(() => _timer?.cancel());
    _startPolling();
    return _fetch();
  }

  void _startPolling() {
    _timer?.cancel();
    _timer = Timer.periodic(_interval, (_) async {
      state = await AsyncValue.guard(_fetch);
    });
  }

  Future<TelemetrySnapshot> _fetch() async {
    final svc = ref.read(telemetryServiceProvider);
    final cpu = await svc.getCpuUsage();
    final temp = await svc.getCpuTemp();
    final availRam = await svc.getAvailableRam();
    final totalRam = await svc.getTotalRam();
    final hostname = await svc.getHostname();
    final kernel = await svc.getKernel();
    final uptime = await svc.getUptime();
    final processes = await svc.getProcesses();

    return TelemetrySnapshot(
      cpuPercent: cpu,
      cpuTempC: temp,
      ramUsedGb: totalRam - availRam,
      ramTotalGb: totalRam,
      hostname: hostname,
      kernel: kernel,
      uptime: uptime,
      topProcesses: processes,
    );
  }
}

final telemetryProvider = AsyncNotifierProvider<TelemetryNotifier, TelemetrySnapshot>(
  TelemetryNotifier.new,
);

// ─── Sentinel Agent Status Providers ──────────────────────────────────────────

/// Tracks live status of sentinel agents from the backend via SSE.
/// Updates whenever the SSE stream emits a 'status' event.
class AgentStatusNotifier extends StateNotifier<Map<String, String>> {
  final Ref _ref;
  AgentStatusNotifier(this._ref) : super({}) {
    _subscribe();
  }

  void _subscribe() {
    _ref.listen<AsyncValue>(sseEventsProvider, (_, next) {
      next.whenData((event) {
        if (event.type == 'agent_status') {
          final data = event.data as Map<String, dynamic>? ?? {};
          final id = data['id']?.toString() ?? '';
          final status = data['status']?.toString() ?? 'offline';
          if (id.isNotEmpty) {
            state = {...state, id: status};
          }
        }
      });
    });
  }
}

final agentStatusProvider = StateNotifierProvider<AgentStatusNotifier, Map<String, String>>(
  (ref) => AgentStatusNotifier(ref),
);

// ─── SSE Log Stream ────────────────────────────────────────────────────────────

/// Accumulated terminal log lines from the SSE stream.
class TerminalLogNotifier extends StateNotifier<List<String>> {
  final Ref _ref;
  TerminalLogNotifier(this._ref) : super([]) {
    _subscribe();
  }

  void _subscribe() {
    _ref.listen<AsyncValue>(sseEventsProvider, (_, next) {
      next.whenData((event) {
        if (event.type == 'log' || event.type == 'status') {
          final line = event.data?.toString() ?? '';
          if (line.isNotEmpty) {
            state = [...state.length > 199 ? state.sublist(state.length - 199) : state, line]; // Keep last 200 lines
          }
        }
      });
    });
  }

    void addLog(String line) {
    if (line.isNotEmpty) {
      state = [...state.length > 199 ? state.sublist(state.length - 199) : state, line];
    }
  }

  void clear() => state = [];
}

final terminalLogProvider = StateNotifierProvider<TerminalLogNotifier, List<String>>(
  (ref) => TerminalLogNotifier(ref),
);

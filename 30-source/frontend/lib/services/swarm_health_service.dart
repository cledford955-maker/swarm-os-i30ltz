import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'swarm_config.dart';

/// Parsed response from LucyServer's GET /api/health.
///
/// The Go handler returns:
///   { status, version, build_date, uptime_seconds,
///     lucy_mount_gb_used, lucy_mount_gb_total,
///     services: { lucy_server, gaming_agent, google_workspace } }
class SwarmHealthSnapshot {
  final String status; // "ok" | "degraded"
  final String version;
  final String buildDate;
  final int uptimeSeconds;
  final double diskUsedGb;
  final double diskTotalGb;
  final Map<String, String> services; // name → "ok" | error string
  final DateTime fetchedAt;

  const SwarmHealthSnapshot({
    required this.status,
    required this.version,
    required this.buildDate,
    required this.uptimeSeconds,
    required this.diskUsedGb,
    required this.diskTotalGb,
    required this.services,
    required this.fetchedAt,
  });

  double get diskPercent =>
      diskTotalGb > 0 ? (diskUsedGb / diskTotalGb) * 100 : 0;

  double get diskFreeGb => diskTotalGb - diskUsedGb;

  Duration get uptime => Duration(seconds: uptimeSeconds);

  String get uptimeFormatted {
    final d = uptime.inDays;
    final h = uptime.inHours.remainder(24);
    final m = uptime.inMinutes.remainder(60);
    if (d > 0) return '${d}d ${h}h';
    return '${h}h ${m}m';
  }

  bool get isOk => status == 'ok';

  bool serviceOk(String name) => services[name] == 'ok';

  /// True when this snapshot is older than [maxAge], or was never fetched.
  bool isStale([Duration maxAge = const Duration(seconds: 60)]) =>
      status == 'unknown' || DateTime.now().difference(fetchedAt) > maxAge;

  static final SwarmHealthSnapshot empty = SwarmHealthSnapshot(
    status: 'unknown',
    version: '…',
    buildDate: '',
    uptimeSeconds: 0,
    diskUsedGb: 0,
    diskTotalGb: 0,
    services: const {},
    fetchedAt: DateTime.utc(1970),
  );

  factory SwarmHealthSnapshot.fromJson(Map<String, dynamic> json) {
    final rawDyn = json['services'] as Map? ?? {};
    final raw = rawDyn.cast<String, dynamic>();
    return SwarmHealthSnapshot(
      status: json['status'] as String? ?? 'unknown',
      version: json['version'] as String? ?? '?',
      buildDate: json['build_date'] as String? ?? '',
      uptimeSeconds: (json['uptime_seconds'] as num?)?.toInt() ?? 0,
      diskUsedGb: (json['lucy_mount_gb_used'] as num?)?.toDouble() ?? 0,
      diskTotalGb: (json['lucy_mount_gb_total'] as num?)?.toDouble() ?? 0,
      services: raw.map((k, v) => MapEntry(k, v.toString())),
      fetchedAt: DateTime.now(),
    );
  }
}

/// Polls LucyServer's /api/health at a configurable interval.
///
/// Exposes a stream of [SwarmHealthSnapshot]. When the server is unreachable
/// the stream emits [SwarmHealthSnapshot.empty] so consumers can show an
/// "offline" state rather than stale numbers.
class SwarmHealthService {
  final String baseUrl;
  final Duration interval;

  Timer? _timer;
  final _controller = StreamController<SwarmHealthSnapshot>.broadcast();
  SwarmHealthSnapshot _last = SwarmHealthSnapshot.empty;

  SwarmHealthService({
    String? baseUrl,
    this.interval = const Duration(seconds: 10),
  }) : baseUrl = baseUrl ?? SwarmConfig.httpBase;

  SwarmHealthSnapshot get latest => _last;

  Stream<SwarmHealthSnapshot> get snapshots => _controller.stream;

  void start() {
    _poll(); // immediate first fetch
    _timer?.cancel();
    _timer = Timer.periodic(interval, (_) => _poll());
  }

  Future<void> _poll() async {
    try {
      final uri = Uri.parse('$baseUrl/api/health');
      final response = await http.get(uri, headers: SwarmConfig.authHeaders)
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        _last = SwarmHealthSnapshot.fromJson(json);
      } else {
        _last = SwarmHealthSnapshot.empty;
      }
    } catch (_) {
      _last = SwarmHealthSnapshot.empty;
    }
    if (!_controller.isClosed) _controller.add(_last);
  }

  void dispose() {
    _timer?.cancel();
    _controller.close();
  }
}

import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'swarm_config.dart';

/// Metadata for a single published ISO returned by /api/updates/check.
class SwarmIsoRelease {
  final String filename;
  final String version;
  final String path;
  final int sizeBytes;
  final String sha256;
  final DateTime? modTime;

  const SwarmIsoRelease({
    required this.filename,
    required this.version,
    required this.path,
    required this.sizeBytes,
    required this.sha256,
    required this.modTime,
  });

  factory SwarmIsoRelease.fromJson(Map<String, dynamic> json) {
    final rawTime = json['mod_time'] as String? ?? '';
    return SwarmIsoRelease(
      filename: json['filename'] as String? ?? '',
      version: json['version'] as String? ?? '',
      path: json['path'] as String? ?? '',
      sizeBytes: (json['size_bytes'] as num?)?.toInt() ?? 0,
      sha256: json['sha256'] as String? ?? '',
      modTime: rawTime.isEmpty ? null : DateTime.tryParse(rawTime),
    );
  }

  /// GiB rounded to one decimal.
  double get sizeGb => sizeBytes / (1 << 30);
}

/// Snapshot returned by /api/updates/check.
class SwarmUpdateSnapshot {
  final String currentVersion;
  final String? latestVersion;
  final bool updateAvailable;
  final SwarmIsoRelease? latestIso;
  final DateTime fetchedAt;

  const SwarmUpdateSnapshot({
    required this.currentVersion,
    required this.latestVersion,
    required this.updateAvailable,
    required this.latestIso,
    required this.fetchedAt,
  });

  static final SwarmUpdateSnapshot empty = SwarmUpdateSnapshot(
    currentVersion: '?',
    latestVersion: null,
    updateAvailable: false,
    latestIso: null,
    fetchedAt: DateTime.utc(1970),
  );

  factory SwarmUpdateSnapshot.fromJson(Map<String, dynamic> json) {
    final iso = json['latest_iso'];
    return SwarmUpdateSnapshot(
      currentVersion: json['current_version'] as String? ?? '?',
      latestVersion: json['latest_version'] as String?,
      updateAvailable: json['update_available'] as bool? ?? false,
      latestIso: iso == null
          ? null
          : SwarmIsoRelease.fromJson((iso as Map).cast<String, dynamic>()),
      fetchedAt: DateTime.now(),
    );
  }
}

/// Polls LucyServer's /api/updates/check at a slow interval (every 15 min by
/// default — a new ISO is a rare event, no need to hit it every 10 s the way
/// health does).
class SwarmUpdateService {
  final String baseUrl;
  final Duration interval;

  Timer? _timer;
  final _controller = StreamController<SwarmUpdateSnapshot>.broadcast();
  SwarmUpdateSnapshot _last = SwarmUpdateSnapshot.empty;

  SwarmUpdateService({
    String? baseUrl,
    this.interval = const Duration(minutes: 15),
  }) : baseUrl = baseUrl ?? SwarmConfig.httpBase;

  SwarmUpdateSnapshot get latest => _last;
  Stream<SwarmUpdateSnapshot> get snapshots => _controller.stream;

  void start() {
    unawaited(_poll());
    _timer?.cancel();
    _timer = Timer.periodic(interval, (_) => _poll());
  }

  Future<SwarmUpdateSnapshot> refresh() async {
    await _poll();
    return _last;
  }

  Future<void> _poll() async {
    try {
      final uri = Uri.parse('$baseUrl/api/updates/check');
      final response = await http
          .get(uri, headers: SwarmConfig.authHeaders)
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        _last = SwarmUpdateSnapshot.fromJson(json);
      } else {
        _last = SwarmUpdateSnapshot.empty;
      }
    } catch (_) {
      _last = SwarmUpdateSnapshot.empty;
    }
    if (!_controller.isClosed) _controller.add(_last);
  }

  void dispose() {
    _timer?.cancel();
    _controller.close();
  }
}

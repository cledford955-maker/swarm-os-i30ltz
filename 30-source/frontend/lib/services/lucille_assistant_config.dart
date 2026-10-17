import '../platform/platform.dart';

/// Where the Flutter shell finds Lucille Assistant — the Go service that
/// holds Team Brief/threads/games/swarm-dispatch logic (source:
/// /mnt/lucillebuild, API in main.go/threads.go/games.go). Separate
/// service from LucyServer (SwarmConfig, port 5000): this is Lucille's own
/// brain, meant to be "one backend, every client a thin UI over it."
///
/// Defaults to loopback :8403 — Lucille Assistant's auth middleware treats
/// any loopback caller as the main PC user with no token needed, so the
/// common case (this service running on the same machine as the shell)
/// needs zero credential handling.
class LucilleAssistantConfig {
  static const _fallbackHost = '127.0.0.1';
  static const _fallbackPort = 8403;

  static String get host =>
      Platform.environment['LUCILLE_HOST'] ?? _fallbackHost;

  static int get port =>
      int.tryParse(Platform.environment['LUCILLE_PORT'] ?? '') ?? _fallbackPort;

  static String get httpBase => 'http://$host:$port';

  /// Only set when reaching Lucille Assistant over the network (e.g. a
  /// paired-device token over Tailscale) — loopback needs none.
  static String? get token => Platform.environment['LUCILLE_ASSISTANT_TOKEN'];

  static Map<String, String> get headers => {
        'Content-Type': 'application/json',
        if (token != null && token!.isNotEmpty) 'X-Swarm-Auth': token!,
      };
}

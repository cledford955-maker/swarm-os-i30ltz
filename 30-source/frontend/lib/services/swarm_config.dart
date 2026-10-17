import 'dart:io' hide Platform;
import '../platform/platform.dart';

/// Single source of truth for how the Flutter shell contacts LucyServer.
///
/// Reads SWARM_AUTH_TOKEN from the process environment — baked into the
/// ISO via /etc/swarm_os.env (EnvironmentFile on all swarm services) so the
/// shell inherits it on boot.  Falls back to the shared literal so a fresh
/// install that hasn't set a custom token still works.
class SwarmConfig {
  // Web demo build (--dart-define=MOCK=true): no real token is ever compiled in.
  static const _demo = bool.fromEnvironment('MOCK');
  static const _fallbackToken = _demo ? 'demo' : 'swarm-token-2026';
  static const _fallbackHost = '127.0.0.1';
  static const _fallbackPort = 5000;

  static String get authToken =>
      Platform.environment['SWARM_AUTH_TOKEN'] ?? _fallbackToken;

  static String get lucyHost =>
      Platform.environment['LUCY_HOST'] ?? _fallbackHost;

  static int get lucyPort =>
      int.tryParse(Platform.environment['LUCY_PORT'] ?? '') ?? _fallbackPort;

  static String get httpBase => 'http://$lucyHost:$lucyPort';

  static Map<String, String> get authHeaders => {
        'Content-Type': 'application/json',
        'X-Swarm-Auth': authToken,
      };
}

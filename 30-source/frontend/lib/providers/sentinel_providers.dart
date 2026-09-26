import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/sentinel_client.dart';
import '../services/sentinel_sse.dart';
import '../services/ai_client.dart';
import '../services/telemetry_service.dart';
import '../services/swarm_health_service.dart';
import '../services/swarm_update_service.dart';

/// Singleton providers for backend services.
// Defaults to the Flutter shell's own project root — the app Lucille/Forge/
// Droid are actually running inside and whose persona directory-mapping
// (lib/widgets/, lib/pages/, ...) only makes sense relative to it — rather
// than the prior '/home' default. _getProjectContext() in agent_chat.dart
// explicitly blanks out '/home' and '/', so with that default the agents had
// NO directory context at all unless the user had already browsed to one via
// the vault browser. Not the whole /mnt/Lucy drive: several of its top-level
// dirs are orphaned/legacy (see CLAUDE.md) and would just add noise/risk to
// the 250-file listing this drives.
final projectDirectoryProvider = StateProvider<String>((ref) => '/mnt/Lucy/30-source/frontend');

final sentinelClientProvider = Provider<SentinelClient>((ref) {
  final client = SentinelClient();
  ref.onDispose(client.dispose);
  return client;
});

final sentinelSseProvider = Provider<SentinelSseClient>((ref) {
  final sse = SentinelSseClient();
  sse.connect();
  ref.onDispose(sse.dispose);
  return sse;
});

final sseEventsProvider = StreamProvider<SseEvent>((ref) {
  final sse = ref.watch(sentinelSseProvider);
  return sse.events;
});

final aiClientProvider = Provider<AiClient>((ref) {
  final client = AiClient();
  ref.onDispose(client.dispose);
  return client;
});

final telemetryServiceProvider = Provider<TelemetryService>((ref) {
  return TelemetryService();
});

final openRouterBalanceProvider = FutureProvider<String>((ref) async {
  final aiClient = ref.watch(aiClientProvider);
  return aiClient.fetchOpenRouterBalance();
});

// ─── Backend Health (LucyServer /api/health) ──────────────────────────────────

final swarmHealthServiceProvider = Provider<SwarmHealthService>((ref) {
  final svc = SwarmHealthService();
  svc.start();
  ref.onDispose(svc.dispose);
  return svc;
});

/// Streams live backend health snapshots from LucyServer's /api/health.
/// Consumers get an "offline" [SwarmHealthSnapshot.empty] when the server
/// is unreachable — never stale data.
final swarmHealthProvider = StreamProvider<SwarmHealthSnapshot>((ref) {
  final svc = ref.watch(swarmHealthServiceProvider);
  return svc.snapshots;
});

// ─── OTA Update Check (LucyServer /api/updates/check) ─────────────────────────

final swarmUpdateServiceProvider = Provider<SwarmUpdateService>((ref) {
  final svc = SwarmUpdateService();
  svc.start();
  ref.onDispose(svc.dispose);
  return svc;
});

/// Emits an [SwarmUpdateSnapshot] every 15 minutes (and once at startup).
/// The banner in the top bar reads from this to show "Update v6.2.75 available".
final swarmUpdateProvider = StreamProvider<SwarmUpdateSnapshot>((ref) {
  final svc = ref.watch(swarmUpdateServiceProvider);
  return svc.snapshots;
});

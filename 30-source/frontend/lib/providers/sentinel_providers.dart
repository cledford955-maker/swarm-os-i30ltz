import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/sentinel_client.dart';
import '../services/sentinel_sse.dart';
import '../services/ai_client.dart';
import '../services/telemetry_service.dart';

/// Singleton providers for backend services.
final projectDirectoryProvider = StateProvider<String>((ref) => '/home');

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

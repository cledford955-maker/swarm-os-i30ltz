import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../services/live_model_catalog_service.dart';
import '../services/skill_router.dart';
import '../services/nvidia_voice_service.dart';
import '../services/nvidia_rag_service.dart';
import '../services/nvidia_image_service.dart';
import '../services/nvidia_cuopt_service.dart';
import '../services/physics_ai_service.dart';
import '../services/nim_skill_telemetry.dart';
import 'sentinel_providers.dart';

/// Live model catalog singleton. Notifies listeners when the catalog refreshes.
final liveModelCatalogProvider = ChangeNotifierProvider<LiveModelCatalogService>((ref) {
  final service = LiveModelCatalogService();
  service.ensureLoaded();
  ref.onDispose(() {});
  return service;
});

/// Last-run latency and routing state for the NVIDIA dashboard. The store is
/// intentionally memory-only and never captures prompts or generated data.
final nimSkillTelemetryProvider = ChangeNotifierProvider<NimSkillTelemetry>((ref) {
  return NimSkillTelemetry();
});

/// Provider for the skill router. Depends on the live catalog and the
/// existing [aiClientProvider] so chat skills reuse the same HTTP client
/// and API-key resolution path as the rest of the app.
final skillRouterProvider = Provider<SkillRouter>((ref) {
  final catalog = ref.watch(liveModelCatalogProvider);
  final aiClient = ref.watch(aiClientProvider);
  final telemetry = ref.watch(nimSkillTelemetryProvider);
  return SkillRouter(
    catalog: catalog,
    aiClient: aiClient,
    httpClient: http.Client(),
    telemetry: telemetry,
  );
});

/// Typed NVIDIA voice service facade (Parakeet STT + Riva TTS).
final nvidiaVoiceServiceProvider = Provider<NvidiaVoiceService>((ref) {
  final router = ref.watch(skillRouterProvider);
  return NvidiaVoiceService(router);
});

/// Typed NVIDIA RAG service facade (embeddings + rerank).
final nvidiaRagServiceProvider = Provider<NvidiaRagService>((ref) {
  final router = ref.watch(skillRouterProvider);
  return NvidiaRagService(router);
});

/// Typed NVIDIA image generation service facade (SDXL Turbo).
final nvidiaImageServiceProvider = Provider<NvidiaImageService>((ref) {
  final router = ref.watch(skillRouterProvider);
  return NvidiaImageService(router);
});

/// Typed NVIDIA cuOpt optimization service facade.
final nvidiaCuOptServiceProvider = Provider<NvidiaCuOptService>((ref) {
  final router = ref.watch(skillRouterProvider);
  return NvidiaCuOptService(router);
});

/// Typed NVIDIA physics AI service facade (Cosmos + Omniverse).
final physicsAiServiceProvider = Provider<PhysicsAiService>((ref) {
  final router = ref.watch(skillRouterProvider);
  return PhysicsAiService(router);
});

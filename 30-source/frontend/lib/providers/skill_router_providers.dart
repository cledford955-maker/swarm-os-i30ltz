import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../services/live_model_catalog_service.dart';
import '../services/skill_router.dart';
import 'sentinel_providers.dart';

/// Live model catalog singleton. Notifies listeners when the catalog refreshes.
final liveModelCatalogProvider = ChangeNotifierProvider<LiveModelCatalogService>((ref) {
  final service = LiveModelCatalogService();
  service.ensureLoaded();
  ref.onDispose(() {});
  return service;
});

/// Provider for the skill router. Depends on the live catalog and the
/// existing [aiClientProvider] so chat skills reuse the same HTTP client
/// and API-key resolution path as the rest of the app.
final skillRouterProvider = Provider<SkillRouter>((ref) {
  final catalog = ref.watch(liveModelCatalogProvider);
  final aiClient = ref.watch(aiClientProvider);
  return SkillRouter(
    catalog: catalog,
    aiClient: aiClient,
    httpClient: http.Client(),
  );
});

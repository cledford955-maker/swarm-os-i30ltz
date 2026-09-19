import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// A model as OpenRouter's own /api/v1/models actually reports it right now —
/// not a hand-typed guess. If it's in here, it exists; if OpenRouter drops or
/// renames it, it silently disappears from here on the next refresh instead
/// of lingering as a dead entry a user can still pick.
class LiveModel {
  final String id;
  final String name;
  final String description;
  final int? contextLength;
  final double? promptPricePerToken;
  final double? completionPricePerToken;
  final List<String> inputModalities;
  final List<String> outputModalities;

  const LiveModel({
    required this.id,
    required this.name,
    required this.description,
    this.contextLength,
    this.promptPricePerToken,
    this.completionPricePerToken,
    this.inputModalities = const [],
    this.outputModalities = const [],
  });

  factory LiveModel.fromJson(Map<String, dynamic> json) {
    final pricing = json['pricing'] as Map<String, dynamic>? ?? const {};
    final arch = json['architecture'] as Map<String, dynamic>? ?? const {};
    double? parsePrice(dynamic v) {
      if (v == null) return null;
      return double.tryParse(v.toString());
    }
    return LiveModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? json['id'] as String? ?? '',
      description: json['description'] as String? ?? '',
      contextLength: json['context_length'] as int?,
      promptPricePerToken: parsePrice(pricing['prompt']),
      completionPricePerToken: parsePrice(pricing['completion']),
      inputModalities: (arch['input_modalities'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
      outputModalities: (arch['output_modalities'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
    );
  }

  bool get isNvidiaFree => id.startsWith('nvidia/') && id.endsWith(':free');
  bool get isFree => id.endsWith(':free') || (promptPricePerToken == 0 && completionPricePerToken == 0);

  /// "$X.XX / 1M" from the real per-token prompt price — matches the display
  /// convention the rest of the catalog (SwarmModel.pricePer1M) already uses.
  String get pricePer1MDisplay {
    if (isFree) return 'FREE';
    if (promptPricePerToken == null) return '—';
    final per1M = promptPricePerToken! * 1000000;
    if (per1M < 0.01) return '\$${per1M.toStringAsFixed(4)} / 1M';
    return '\$${per1M.toStringAsFixed(2)} / 1M';
  }

  String get contextDisplay {
    if (contextLength == null) return '—';
    if (contextLength! >= 1000000) return '${(contextLength! / 1000000).toStringAsFixed(1)}M';
    if (contextLength! >= 1000) return '${(contextLength! / 1000).round()}K';
    return '$contextLength';
  }
}

/// OpenRouter's own real category filter values (confirmed against a live
/// 400 validation error on 2026-09-19 — these are the only values the API
/// actually accepts, not a guessed list).
const List<String> kOpenRouterCategories = [
  'programming',
  'roleplay',
  'marketing',
  'marketing/seo',
  'technology',
  'science',
  'translation',
  'legal',
  'finance',
  'health',
  'trivia',
  'academia',
];

/// Fetches and caches OpenRouter's live model catalog. This is the ground
/// truth for "does this model actually exist right now" — the static
/// SwarmModel catalog in models/swarm.dart is hand-maintained and has been
/// found to contain entries that don't exist on the real API (wrong provider
/// slugs, retired model generations). Nothing here can go stale in that way:
/// it either reflects what OpenRouter reports right now, or it's empty
/// pending a fetch.
class LiveModelCatalogService extends ChangeNotifier {
  static const String _baseUrl = 'https://openrouter.ai/api/v1';
  static const String _cacheKey = 'live_model_catalog_cache_v1';
  static const Duration _cacheTtl = Duration(minutes: 30);

  List<LiveModel> _all = [];
  DateTime? _fetchedAt;
  bool _loading = false;
  String? _error;
  final Map<String, List<LiveModel>> _categoryCache = {};

  List<LiveModel> get all => _all;
  DateTime? get fetchedAt => _fetchedAt;
  bool get loading => _loading;
  String? get error => _error;
  bool get hasData => _all.isNotEmpty;

  /// id -> LiveModel, for O(1) "does this exist" checks.
  late Map<String, LiveModel> _byId = {};
  LiveModel? byId(String id) => _byId[id];
  bool exists(String id) => _byId.containsKey(id);

  List<LiveModel> get nvidiaNimFree =>
      _all.where((m) => m.isNvidiaFree).toList()
        ..sort((a, b) => a.name.compareTo(b.name));

  Future<void> ensureLoaded() async {
    if (hasData && _fetchedAt != null && DateTime.now().difference(_fetchedAt!) < _cacheTtl) {
      return;
    }
    await refresh();
  }

  Future<void> refresh() async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final resp = await http.get(Uri.parse('$_baseUrl/models')).timeout(const Duration(seconds: 15));
      if (resp.statusCode != 200) {
        _error = 'HTTP ${resp.statusCode}';
        await _loadFromCacheIfEmpty();
        _loading = false;
        notifyListeners();
        return;
      }
      final json = jsonDecode(resp.body) as Map<String, dynamic>;
      final list = (json['data'] as List<dynamic>? ?? [])
          .map((e) => LiveModel.fromJson(e as Map<String, dynamic>))
          .where((m) => m.id.isNotEmpty)
          .toList();
      _all = list;
      _byId = {for (final m in list) m.id: m};
      _fetchedAt = DateTime.now();
      _categoryCache.clear();
      unawaited(_saveToCache());
    } catch (e) {
      _error = e.toString();
      await _loadFromCacheIfEmpty();
    }

    _loading = false;
    notifyListeners();
  }

  /// Live-ranked models for one of OpenRouter's real categories (e.g.
  /// 'programming' for coding). OpenRouter caps this at ~20 per category —
  /// there is no server-side "top 100" for a single category; this is
  /// OpenRouter's own ranking, not ours.
  Future<List<LiveModel>> fetchCategory(String category) async {
    if (_categoryCache.containsKey(category)) return _categoryCache[category]!;
    try {
      final resp = await http
          .get(Uri.parse('$_baseUrl/models?category=${Uri.encodeComponent(category)}'))
          .timeout(const Duration(seconds: 15));
      if (resp.statusCode != 200) return [];
      final json = jsonDecode(resp.body) as Map<String, dynamic>;
      final list = (json['data'] as List<dynamic>? ?? [])
          .map((e) => LiveModel.fromJson(e as Map<String, dynamic>))
          .toList();
      _categoryCache[category] = list;
      return list;
    } catch (_) {
      return [];
    }
  }

  /// Broader "coding-relevant" set beyond the ~20 OpenRouter ranks under
  /// 'programming' — every live model whose id/name/description reads as
  /// coding-focused, capped at 100. Real entries only (drawn from the same
  /// live fetch), just not OpenRouter's own popularity ranking.
  List<LiveModel> topCodingModels({int limit = 100}) {
    const codeWords = ['code', 'coder', 'coding', 'program', 'dev', 'swe'];
    final matches = _all.where((m) {
      final hay = '${m.id} ${m.name} ${m.description}'.toLowerCase();
      return codeWords.any(hay.contains);
    }).toList();
    matches.sort((a, b) => (a.promptPricePerToken ?? 0).compareTo(b.promptPricePerToken ?? 0));
    return matches.take(limit).toList();
  }

  Future<void> _saveToCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final payload = {
        'fetchedAt': _fetchedAt?.toIso8601String(),
        'models': _all
            .map((m) => {
                  'id': m.id,
                  'name': m.name,
                  'description': m.description,
                  'context_length': m.contextLength,
                  'pricing': {
                    'prompt': m.promptPricePerToken?.toString(),
                    'completion': m.completionPricePerToken?.toString(),
                  },
                  'architecture': {
                    'input_modalities': m.inputModalities,
                    'output_modalities': m.outputModalities,
                  },
                })
            .toList(),
      };
      await prefs.setString(_cacheKey, jsonEncode(payload));
    } catch (_) {}
  }

  Future<void> _loadFromCacheIfEmpty() async {
    if (hasData) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);
      if (raw == null) return;
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final list = (json['models'] as List<dynamic>? ?? [])
          .map((e) => LiveModel.fromJson(e as Map<String, dynamic>))
          .toList();
      _all = list;
      _byId = {for (final m in list) m.id: m};
      final fa = json['fetchedAt'] as String?;
      if (fa != null) _fetchedAt = DateTime.tryParse(fa);
    } catch (_) {}
  }
}

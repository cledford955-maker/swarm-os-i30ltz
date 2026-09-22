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

  // Not const: _paidTwinExists is set by LiveModelCatalogService after the
  // whole catalog loads (a :free variant only counts as "on sale" relative
  // to its paid twin, which can't be known from one JSON record alone).
  LiveModel({
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

  /// "$X.XX / 1M" from the real per-token completion (output) price — the
  /// number that actually dominates agent-loop costs, since coding agents
  /// emit far more tokens than they read.
  String get outputPricePer1MDisplay {
    if (isFree) return 'FREE';
    if (completionPricePerToken == null) return '—';
    final per1M = completionPricePerToken! * 1000000;
    if (per1M < 0.01) return '\$${per1M.toStringAsFixed(4)} / 1M';
    return '\$${per1M.toStringAsFixed(2)} / 1M';
  }

  /// Blended 3:1 input:output cost per 1M — the standard approximation for
  /// agentic coding traffic. This is the number the "$2 ceiling" check uses.
  double get blendedPricePer1M {
    if (isFree) return 0;
    final p = promptPricePerToken ?? 0;
    final c = completionPricePerToken ?? 0;
    return (p * 3 + c) / 4 * 1000000;
  }

  String get blendedPriceDisplay {
    if (isFree) return 'FREE';
    final v = blendedPricePer1M;
    if (v < 0.01) return '\$${v.toStringAsFixed(4)} / 1M';
    return '\$${v.toStringAsFixed(2)} / 1M';
  }

  /// The base id without OpenRouter's `:free` / `:batch` variant suffix.
  String get baseId {
    for (final suffix in [':free', ':batch']) {
      if (id.endsWith(suffix)) return id.substring(0, id.length - suffix.length);
    }
    return id;
  }

  /// True when this exact id is a discounted variant of a pricier base model
  /// (a `:free` twin of a paid model = 100% off; a `:batch` variant = ~50%
  /// off OpenRouter's documented batch discount). Only meaningful once the
  /// whole catalog is loaded — computed by LiveModelCatalogService.
  bool get isDiscountedVariant => id.endsWith(':free') && _paidTwinExists ||
      id.endsWith(':batch');
  bool _paidTwinExists = false;
  set hasPaidTwin(bool v) => _paidTwinExists = v;

  /// Discount percentage vs the paid base twin, when detectable.
  int? get discountPercent {
    if (id.endsWith(':free') && _paidTwinExists) return 100;
    if (id.endsWith(':batch')) return 50; // OpenRouter's documented batch rate
    return null;
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

  /// The current-generation flagship families the top swarm is built from.
  /// Anything in these families that exists live shows up in the TOP filter.
  static const _flagshipFamilies = [
    'moonshotai/kimi-k2.6', 'moonshotai/kimi-k3',
    'qwen/qwen3.6', 'qwen/qwen3-max',
    'z-ai/glm-5.3', 'z-ai/glm-5.2',
    'deepseek/deepseek-v4', 'deepseek/deepseek-r2',
    'nvidia/nemotron-3',
  ];

  /// Live flagship models from the top families, ranked cheapest-blended
  /// first. This is the "top models" list — current generation only, no
  /// retired generations, no $5+/1M premium tier unless it's in a family
  /// the user explicitly asked for.
  List<LiveModel> topFlagshipModels({int limit = 50}) {
    final matches = _all.where((m) =>
        _flagshipFamilies.any(m.baseId.startsWith) &&
        !m.id.endsWith(':batch')).toList();
    matches.sort((a, b) => a.blendedPricePer1M.compareTo(b.blendedPricePer1M));
    return matches.take(limit).toList();
  }

  /// Live models on "sale" — discounted variants of pricier base models:
  /// `:free` twins of paid models (100% off) and `:batch` variants (~50%
  /// off). Detected from the live catalog itself, not hand-maintained.
  List<LiveModel> get onSaleModels => _all.where((m) => m.isDiscountedVariant).toList()
        ..sort((a, b) => (b.discountPercent ?? 0).compareTo(a.discountPercent ?? 0));

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
      _markDiscountedVariants();
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

  /// Flags `:free` variants that have a paid base twin on the catalog right
  /// now — those are the genuine "100% OFF" sale entries. A `:free` with no
  /// paid twin is just a permanently-free model, not a sale.
  void _markDiscountedVariants() {
    for (final m in _all) {
      if (m.id.endsWith(':free')) {
        m.hasPaidTwin = _byId.containsKey(m.baseId) &&
            (_byId[m.baseId]!.promptPricePerToken ?? 0) > 0;
      }
    }
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
      _markDiscountedVariants();
      final fa = json['fetchedAt'] as String?;
      if (fa != null) _fetchedAt = DateTime.tryParse(fa);
    } catch (_) {}
  }
}

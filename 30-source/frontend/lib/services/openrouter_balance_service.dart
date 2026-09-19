import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class OpenRouterBalance {
  final double usage;
  final double? limit;
  final String? label;
  final bool isFreeTier;

  OpenRouterBalance({
    required this.usage,
    this.limit,
    this.label,
    this.isFreeTier = false,
  });

  double get remaining => (limit != null) ? (limit! - usage) : double.infinity;
  bool get hasLimit => limit != null && limit! > 0;

  String get displayUsage => '\$${usage.toStringAsFixed(4)}';
  String get displayRemaining =>
      hasLimit ? '\$${remaining.toStringAsFixed(4)}' : '∞';
  String get displayLimit =>
      hasLimit ? '\$${limit!.toStringAsFixed(2)}' : 'unlimited';
}

class OpenRouterBalanceService extends ChangeNotifier {
  static const String _apiKeyPref = 'openrouter_api_key';
  static const String _baseUrl = 'https://openrouter.ai/api/v1';
  static const Duration _pollInterval = Duration(seconds: 60);

  String? _apiKey;
  OpenRouterBalance? _balance;
  bool _loading = false;
  String? _error;
  Timer? _pollTimer;

  OpenRouterBalance? get balance => _balance;
  bool get loading => _loading;
  String? get error => _error;
  bool get hasKey => _apiKey != null && _apiKey!.isNotEmpty;

  OpenRouterBalanceService() {
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    // This widget's own 'openrouter_api_key' pref used to be the only place
    // checked here — completely disconnected from the real 'OPENROUTER_API_KEY'
    // every other part of the app (Settings, AiClient) reads, so the balance
    // chip showed "no key" by default even with a working key configured.
    // Same resolution chain as SettingsPage._resolveKey now.
    _apiKey = prefs.getString(_apiKeyPref) ?? _resolveSharedKey(prefs);
    if (hasKey) {
      await fetchBalance();
      _startPolling();
    }
  }

  String? _resolveSharedKey(SharedPreferences prefs) {
    final prefVal = prefs.getString('OPENROUTER_API_KEY');
    if (prefVal != null && prefVal.trim().isNotEmpty) return prefVal.trim();

    // /run/media/i30ltz/lucy-master/ is the read-only reference mirror, not a
    // real source of a live key — kept last for old-install compatibility,
    // not first.
    const envPaths = [
      '/etc/swarm_os.env',
      './.env',
      '../.env',
      '/root/.env',
      '/usr/local/bin/swarm_os/.env',
      '/run/media/i30ltz/lucy-master/.env',
    ];
    for (final p in envPaths) {
      final f = File(p);
      if (!f.existsSync()) continue;
      try {
        for (final line in f.readAsLinesSync()) {
          final trimmed = line.trim();
          if (trimmed.startsWith('OPENROUTER_API_KEY=')) {
            return trimmed.substring('OPENROUTER_API_KEY='.length).trim().replaceAll('"', '').replaceAll("'", '');
          }
        }
      } catch (_) {}
    }
    return Platform.environment['OPENROUTER_API_KEY'];
  }

  Future<void> setApiKey(String key) async {
    _apiKey = key.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_apiKeyPref, _apiKey!);
    _error = null;
    notifyListeners();
    await fetchBalance();
    _startPolling();
  }

  Future<void> clearApiKey() async {
    _apiKey = null;
    _balance = null;
    _error = null;
    _pollTimer?.cancel();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_apiKeyPref);
    notifyListeners();
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(_pollInterval, (_) => fetchBalance());
  }

  Future<void> fetchBalance() async {
    if (!hasKey) return;

    _loading = true;
    notifyListeners();

    try {
      final resp = await http.get(
        Uri.parse('$_baseUrl/auth/key'),
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (resp.statusCode == 200) {
        final json = jsonDecode(resp.body);
        final data = json['data'] ?? {};
        _balance = OpenRouterBalance(
          usage: (data['usage'] ?? 0).toDouble(),
          limit: data['limit'] != null ? (data['limit']).toDouble() : null,
          label: data['label'],
          isFreeTier: data['is_free_tier'] ?? false,
        );
        _error = null;
      } else if (resp.statusCode == 401) {
        _error = 'Invalid API key';
        _balance = null;
      } else {
        _error = 'HTTP ${resp.statusCode}';
      }
    } catch (e) {
      _error = e.toString();
    }

    _loading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }
}
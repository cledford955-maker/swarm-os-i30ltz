import 'dart:async';
import 'dart:convert';
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
    _apiKey = prefs.getString(_apiKeyPref);
    if (hasKey) {
      await fetchBalance();
      _startPolling();
    }
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
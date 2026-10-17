import 'dart:convert';
import 'package:http/http.dart' as http;
import 'lucille_assistant_config.dart';
import '../models/lucille_brief.dart';
import '../models/lucille_game.dart';

/// Thin HTTP client for Lucille Assistant's API (Team Brief, threads,
/// games). One function per endpoint, no caching — the providers layer
/// decides when to refetch.
class LucilleAssistantClient {
  final String _base = LucilleAssistantConfig.httpBase;
  Map<String, String> get _headers => LucilleAssistantConfig.headers;

  Uri _u(String path, [Map<String, String>? query]) =>
      Uri.parse('$_base$path').replace(queryParameters: query);

  Future<TeamBrief> fetchArtifact() async {
    final r = await http.get(_u('/api/artifact'), headers: _headers)
        .timeout(const Duration(seconds: 8));
    if (r.statusCode != 200) throw Exception('artifact: HTTP ${r.statusCode}');
    return TeamBrief.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  Future<ThreadMsg> postThread({
    required String anchor,
    required String text,
    String quote = '',
  }) async {
    final r = await http
        .post(_u('/api/threads/post'), headers: _headers,
            body: jsonEncode({'anchor': anchor, 'text': text, 'quote': quote}))
        .timeout(const Duration(seconds: 8));
    final body = jsonDecode(r.body) as Map<String, dynamic>;
    if (r.statusCode != 200 || body['ok'] != true) {
      throw Exception(body['error'] ?? 'post failed (HTTP ${r.statusCode})');
    }
    return ThreadMsg.fromJson(body['message'] as Map<String, dynamic>);
  }

  /// who: "lucille" | "boltz" | "claude" | "auto". Returns at once; the
  /// reply lands in the thread a few seconds later — call fetchArtifact()
  /// again (or poll) to see it.
  Future<void> askThread({required String anchor, required String who}) async {
    final r = await http
        .post(_u('/api/threads/ask'), headers: _headers,
            body: jsonEncode({'anchor': anchor, 'who': who}))
        .timeout(const Duration(seconds: 8));
    final body = jsonDecode(r.body) as Map<String, dynamic>;
    if (r.statusCode != 200 || body['ok'] != true) {
      throw Exception(body['error'] ?? 'ask failed (HTTP ${r.statusCode})');
    }
  }

  Future<List<SteamHit>> searchGames(String q) async {
    final r = await http
        .get(_u('/api/game/search', {'q': q}), headers: _headers)
        .timeout(const Duration(seconds: 15));
    final body = jsonDecode(r.body) as Map<String, dynamic>;
    if (r.statusCode != 200 || body['ok'] != true) {
      throw Exception(body['error'] ?? 'search failed (HTTP ${r.statusCode})');
    }
    return ((body['results'] as List?) ?? [])
        .map((e) => SteamHit.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<GameCard> fetchGame({int appId = 0, String title = ''}) async {
    final r = await http
        .get(_u('/api/game', {
          if (appId > 0) 'appid': '$appId',
          if (title.isNotEmpty) 'title': title,
        }), headers: _headers)
        .timeout(const Duration(seconds: 25));
    final body = jsonDecode(r.body) as Map<String, dynamic>;
    if (r.statusCode != 200 || body['ok'] != true) {
      throw Exception(body['error'] ?? 'game failed (HTTP ${r.statusCode})');
    }
    return GameCard.fromJson(body['game'] as Map<String, dynamic>);
  }

  Future<List<GameMark>> fetchGameMarks() async {
    final r = await http.get(_u('/api/games/marks'), headers: _headers)
        .timeout(const Duration(seconds: 8));
    final body = jsonDecode(r.body) as Map<String, dynamic>;
    if (r.statusCode != 200 || body['ok'] != true) {
      throw Exception(body['error'] ?? 'marks failed (HTTP ${r.statusCode})');
    }
    return ((body['games'] as List?) ?? [])
        .map((e) => GameMark.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> setGameMark({
    required int appId,
    required String name,
    String image = '',
    String? like, // "like" | "dislike" | "" | null (leave as-is)
    bool? wish, // null (leave as-is)
  }) async {
    final r = await http
        .post(_u('/api/games/mark'), headers: _headers,
            body: jsonEncode({
              'appid': appId,
              'name': name,
              'image': image,
              if (like != null) 'like': like,
              if (wish != null) 'wish': wish,
            }))
        .timeout(const Duration(seconds: 8));
    if (r.statusCode != 200) {
      final body = jsonDecode(r.body) as Map<String, dynamic>;
      throw Exception(body['error'] ?? 'mark failed (HTTP ${r.statusCode})');
    }
  }
}

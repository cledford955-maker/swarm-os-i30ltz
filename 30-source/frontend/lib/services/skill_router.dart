import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/agent.dart';
import 'ai_client.dart';
import 'live_model_catalog_service.dart';
import 'nim_skill_telemetry.dart';
import '../skills/nvidia_nim_skill.dart';

/// Exception thrown when a skill cannot be routed or executed.
class SkillRouterException implements Exception {
  final String message;
  SkillRouterException(this.message);
  @override
  String toString() => 'SkillRouterException: $message';
}

/// Routes agent skill requests to concrete NVIDIA NIM / OpenRouter endpoints.
///
/// The router is provider-agnostic: pass in the live catalog service and an
/// [AiClient] instance. It validates model availability against the live
/// OpenRouter catalog before invoking anything, so dead model IDs fail fast
/// instead of producing cryptic 404s.
class SkillRouter {
  final LiveModelCatalogService _catalog;
  final AiClient _aiClient;
  final http.Client _httpClient;
  final Future<String?> Function() _apiKeyResolver;
  final NimSkillTelemetry? _telemetry;

  SkillRouter({
    required LiveModelCatalogService catalog,
    required AiClient aiClient,
    http.Client? httpClient,
    Future<String?> Function()? apiKeyResolver,
    NimSkillTelemetry? telemetry,
  })  : _catalog = catalog,
        _aiClient = aiClient,
        _httpClient = httpClient ?? http.Client(),
        _apiKeyResolver = apiKeyResolver ?? _defaultApiKeyResolver,
        _telemetry = telemetry;

  static Future<String?> _defaultApiKeyResolver() async {
    // Prefer environment-style lookup first; fallback to SharedPreferences.
    // The actual app stores the key in SharedPreferences via settings.
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      return prefs.getString('OPENROUTER_API_KEY');
    } catch (_) {
      return null;
    }
  }

  /// Resolve a skill to a live model ID, validating against the catalog.
  Future<String> resolveModelId(NimSkill skill, {String? overrideModelId}) async {
    await _catalog.ensureLoaded();
    return skill.resolveModelId(
      overrideModelId: overrideModelId,
      isAvailable: (id) => _catalog.exists(id),
    );
  }

  /// Execute a skill for the given agent.
  ///
  /// [inputs] must match the skill's input schema. The exact shape depends on
  /// [NimSkill.modality]:
  /// - chat / structuredChat: `{'prompt': String}`
  /// - speechToText: `{'audio': File}`
  /// - textToSpeech: `{'text': String, 'voice': String?}`
  /// - embeddings: `{'inputs': List<String>}`
  /// - rerank: `{'query': String, 'documents': List<String>}`
  /// - image: `{'prompt': String, 'size': String?}`
  Future<Map<String, dynamic>> execute({
    required Agent agent,
    required NimSkill skill,
    required Map<String, dynamic> inputs,
    String? overrideModelId,
  }) async {
    final modelId = await resolveModelId(skill, overrideModelId: overrideModelId);
    final stopwatch = Stopwatch()..start();
    final usedFallback = modelId != skill.defaultModelId;
    final liveModel = _catalog.byId(modelId);
    final usedPaidRoute = liveModel != null
        ? !liveModel.isFree
        : !modelId.endsWith(':free');

    try {
      late final Map<String, dynamic> result;
      switch (skill.modality) {
        case NimSkillModality.chat:
        case NimSkillModality.structuredChat:
          result = await _executeChat(skill, modelId, inputs, agent);
        case NimSkillModality.speechToText:
          result = await _executeSpeechToText(skill, modelId, inputs);
        case NimSkillModality.textToSpeech:
          result = await _executeTextToSpeech(skill, modelId, inputs);
        case NimSkillModality.embeddings:
          result = await _executeEmbeddings(skill, modelId, inputs);
        case NimSkillModality.rerank:
          result = await _executeRerank(skill, modelId, inputs);
        case NimSkillModality.image:
          result = await _executeImage(skill, modelId, inputs);
      }
      stopwatch.stop();
      _recordRun(
        skill: skill,
        modelId: modelId,
        latency: stopwatch.elapsed,
        succeeded: true,
        usedFallback: usedFallback,
        usedPaidRoute: usedPaidRoute,
      );
      return result;
    } catch (error) {
      stopwatch.stop();
      _recordRun(
        skill: skill,
        modelId: modelId,
        latency: stopwatch.elapsed,
        succeeded: false,
        usedFallback: usedFallback,
        usedPaidRoute: usedPaidRoute,
        error: error.toString(),
      );
      rethrow;
    }
  }

  void _recordRun({
    required NimSkill skill,
    required String modelId,
    required Duration latency,
    required bool succeeded,
    required bool usedFallback,
    required bool usedPaidRoute,
    String? error,
  }) {
    _telemetry?.record(NimSkillRunRecord(
      skillId: skill.id,
      modelId: modelId,
      completedAt: DateTime.now(),
      latency: latency,
      succeeded: succeeded,
      usedFallback: usedFallback,
      usedPaidRoute: usedPaidRoute,
      error: error,
    ));
  }

  Future<String> _apiKey() async {
    final key = await _apiKeyResolver();
    if (key == null || key.isEmpty) {
      throw SkillRouterException('OPENROUTER_API_KEY not configured');
    }
    return key;
  }

  Map<String, String> _headers(String apiKey) => {
        'Authorization': 'Bearer $apiKey',
        'HTTP-Referer': 'https://swarmos.dev',
        'X-Title': 'SWARM OS',
      };

  Future<Map<String, dynamic>> _executeChat(
    NimSkill skill,
    String modelId,
    Map<String, dynamic> inputs,
    Agent agent,
  ) async {
    final prompt = inputs['prompt'] as String? ??
        inputs['context'] as String? ??
        inputs['usdSnippet'] as String? ??
        '';
    if (prompt.isEmpty) {
      throw SkillRouterException('Skill ${skill.id} requires a prompt/context input');
    }

    final buffer = StringBuffer();
    await _aiClient.streamChat(
      model: modelId,
      systemPrompt: agent.persona.isNotEmpty
          ? '${agent.persona}\n\nYou are invoking the "${skill.name}" NVIDIA skill. Respond concisely and accurately.'
          : 'You are invoking the "${skill.name}" NVIDIA skill. Respond concisely and accurately.',
      previousMessages: [
        {'role': 'user', 'content': prompt},
      ],
      onToken: buffer.write,
    );

    return {'response': buffer.toString()};
  }

  Future<Map<String, dynamic>> _executeSpeechToText(
    NimSkill skill,
    String modelId,
    Map<String, dynamic> inputs,
  ) async {
    final audio = inputs['audio'];
    if (audio is! File) {
      throw SkillRouterException('Skill ${skill.id} requires an audio File input');
    }
    if (!audio.existsSync()) {
      throw SkillRouterException('Audio file does not exist: ${audio.path}');
    }

    final apiKey = await _apiKey();
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('https://openrouter.ai/api/v1/audio/transcriptions'),
    );
    request.headers.addAll(_headers(apiKey));
    request.fields['model'] = modelId;
    final lang = inputs['language'] as String? ?? 'en';
    if (lang.isNotEmpty) request.fields['language'] = lang;
    request.files.add(await http.MultipartFile.fromPath('file', audio.path));

    final response = await _httpClient.send(request);
    final body = await response.stream.transform(utf8.decoder).join();
    if (response.statusCode != 200) {
      throw SkillRouterException('STT failed: HTTP ${response.statusCode} — $body');
    }
    final json = jsonDecode(body) as Map<String, dynamic>;
    return {'text': json['text'] as String? ?? ''};
  }

  Future<Map<String, dynamic>> _executeTextToSpeech(
    NimSkill skill,
    String modelId,
    Map<String, dynamic> inputs,
  ) async {
    final text = inputs['text'] as String? ?? '';
    if (text.isEmpty) {
      throw SkillRouterException('Skill ${skill.id} requires a text input');
    }

    final apiKey = await _apiKey();
    final response = await _httpClient.post(
      Uri.parse('https://openrouter.ai/api/v1/audio/speech'),
      headers: {
        ..._headers(apiKey),
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': modelId,
        'input': text,
        'voice': inputs['voice'] as String? ?? 'default',
      }),
    );

    if (response.statusCode != 200) {
      throw SkillRouterException('TTS failed: HTTP ${response.statusCode} — ${response.body}');
    }

    final tempDir = await getTemporaryDirectory();
    final outFile = File('${tempDir.path}/swarm_tts_${_timestamp()}.mp3');
    await outFile.writeAsBytes(response.bodyBytes);
    return {'audio': outFile.path};
  }

  Future<Map<String, dynamic>> _executeEmbeddings(
    NimSkill skill,
    String modelId,
    Map<String, dynamic> inputs,
  ) async {
    final raw = inputs['inputs'];
    final List<String> chunks = (raw is List)
        ? raw.whereType<String>().toList()
        : [raw.toString()];
    if (chunks.isEmpty) {
      throw SkillRouterException('Skill ${skill.id} requires a non-empty inputs list');
    }

    final apiKey = await _apiKey();
    final response = await _httpClient.post(
      Uri.parse('https://openrouter.ai/api/v1/embeddings'),
      headers: {
        ..._headers(apiKey),
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': modelId,
        'input': chunks,
      }),
    );

    if (response.statusCode != 200) {
      throw SkillRouterException('Embeddings failed: HTTP ${response.statusCode} — ${response.body}');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final data = json['data'] as List<dynamic>? ?? [];
    final vectors = data
        .map((e) => (e as Map<String, dynamic>)['embedding'] as List<dynamic>?)
        .whereType<List<dynamic>>()
        .map((v) => v.map((n) => (n as num).toDouble()).toList())
        .toList();
    return {'embeddings': vectors};
  }

  Future<Map<String, dynamic>> _executeRerank(
    NimSkill skill,
    String modelId,
    Map<String, dynamic> inputs,
  ) async {
    final query = inputs['query'] as String? ?? '';
    final docs = inputs['documents'];
    final List<String> documents =
        (docs is List) ? docs.whereType<String>().toList() : [docs.toString()];
    if (query.isEmpty || documents.isEmpty) {
      throw SkillRouterException('Skill ${skill.id} requires query and documents');
    }

    final apiKey = await _apiKey();
    final response = await _httpClient.post(
      Uri.parse('https://openrouter.ai/api/v1/rerank'),
      headers: {
        ..._headers(apiKey),
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': modelId,
        'query': query,
        'documents': documents,
      }),
    );

    if (response.statusCode != 200) {
      throw SkillRouterException('Rerank failed: HTTP ${response.statusCode} — ${response.body}');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final results = json['results'] as List<dynamic>? ?? [];
    final rankings = results
        .map((e) => e as Map<String, dynamic>)
        .map((e) => {
              'index': e['index'] as int? ?? 0,
              'score': (e['relevance_score'] as num?)?.toDouble() ??
                  (e['score'] as num?)?.toDouble() ??
                  0.0,
            })
        .toList();
    return {'rankings': rankings};
  }

  Future<Map<String, dynamic>> _executeImage(
    NimSkill skill,
    String modelId,
    Map<String, dynamic> inputs,
  ) async {
    final prompt = inputs['prompt'] as String? ?? '';
    if (prompt.isEmpty) {
      throw SkillRouterException('Skill ${skill.id} requires a prompt');
    }

    final apiKey = await _apiKey();
    final response = await _httpClient.post(
      Uri.parse('https://openrouter.ai/api/v1/images/generations'),
      headers: {
        ..._headers(apiKey),
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': modelId,
        'prompt': prompt,
        'size': inputs['size'] as String? ?? '512x512',
      }),
    );

    if (response.statusCode != 200) {
      throw SkillRouterException('Image generation failed: HTTP ${response.statusCode} — ${response.body}');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final data = json['data'] as List<dynamic>? ?? [];
    final url = data.isNotEmpty ? (data.first as Map<String, dynamic>)['url'] as String? : null;
    return {'image': url ?? ''};
  }

  String _timestamp() => DateTime.now().millisecondsSinceEpoch.toString();
}

import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/swarm.dart';

/// Direct HTTP client for AI providers.
/// Replaces the Vercel AI SDK — talks to OpenRouter, Ollama, etc. directly.
class AiClient {
  final http.Client _client;

  AiClient() : _client = http.Client();

  // ─── Ollama (local) ───────────────────────────────────────────────────

  /// Streams a chat completion from a local Ollama model.
  Stream<String> chatOllama({
    required String model,
    required List<Map<String, String>> messages,
    String baseUrl = 'http://localhost:11434',
  }) async* {
    final request = http.Request(
      'POST',
      Uri.parse('$baseUrl/api/chat'),
    );
    request.headers['Content-Type'] = 'application/json';
    request.body = jsonEncode({
      'model': model,
      'messages': messages,
      'stream': true,
      'stop': ['I am an AI', 'I am not a doctor', 'As an AI', 'seek professional help', 'I cannot provide medical advice'],
    });

    final response = await _client.send(request);
    await for (final chunk in response.stream.transform(utf8.decoder)) {
      for (final line in chunk.split('\n')) {
        if (line.trim().isEmpty) continue;
        try {
          final json = jsonDecode(line) as Map<String, dynamic>;
          final content =
              (json['message'] as Map<String, dynamic>?)?['content'] as String?;
          if (content != null && content.isNotEmpty) {
            yield content;
          }
        } catch (_) {}
      }
    }
  }

  // ─── OpenRouter ───────────────────────────────────────────────────────

  /// Streams a chat completion from OpenRouter with automatic fallback for free endpoints.
  Stream<String> chatOpenRouter({
    required String model,
    required List<Map<String, String>> messages,
    required String apiKey,
  }) async* {
    http.Request buildRequest(String targetModel) {
      final req = http.Request(
        'POST',
        Uri.parse('https://openrouter.ai/api/v1/chat/completions'),
      );
      req.headers.addAll({
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
        'HTTP-Referer': 'https://swarmos.dev',
        'X-Title': 'SWARM OS',
      });
      req.body = jsonEncode({
        'model': targetModel,
        'messages': messages,
        'stream': true,
      });
      return req;
    }

    http.StreamedResponse response;
    try {
      response = await _client.send(buildRequest(model));
      
      // If server returns an error (500, 502, 503, 404, 429)
      if (response.statusCode != 200) {
        final errorBody = await response.stream.transform(utf8.decoder).join();
        
        // 1. Try stripping :free if free endpoint failed
        if (model.endsWith(':free')) {
          final fallbackModel = model.replaceAll(':free', '');
          final fallbackResponse = await _client.send(buildRequest(fallbackModel));
          if (fallbackResponse.statusCode == 200) {
            response = fallbackResponse;
          } else {
            // 2. Fall back to OpenRouter AutoRouter
            final autoReq = buildRequest('openrouter/auto');
            final autoRes = await _client.send(autoReq);
            if (autoRes.statusCode == 200) {
              response = autoRes;
            } else {
              throw Exception('OpenRouter API error ${response.statusCode}: $errorBody');
            }
          }
        } else if (model != 'openrouter/auto') {
          // Fall back to AutoRouter for general 500 / provider errors
          final autoReq = buildRequest('openrouter/auto');
          final autoRes = await _client.send(autoReq);
          if (autoRes.statusCode == 200) {
            response = autoRes;
          } else {
            throw Exception('OpenRouter API error ${response.statusCode}: $errorBody');
          }
        } else {
          throw Exception('OpenRouter API error ${response.statusCode}: $errorBody');
        }
      }
    } catch (e) {
      if (model != 'openrouter/auto' && !e.toString().contains('auto failed')) {
        yield* chatOpenRouter(model: 'openrouter/auto', messages: messages, apiKey: apiKey);
        return;
      }
      rethrow;
    }

    await for (final chunk in response.stream.transform(utf8.decoder)) {
      for (final line in chunk.split('\n')) {
        if (!line.startsWith('data: ')) continue;
        final data = line.substring(6).trim();
        if (data == '[DONE]') return;
        try {
          final json = jsonDecode(data) as Map<String, dynamic>;
          final delta = ((json['choices'] as List<dynamic>?)?.firstOrNull
                  as Map<String, dynamic>?)?['delta']
              as Map<String, dynamic>?;
          final content = delta?['content'] as String?;
          if (content != null && content.isNotEmpty) yield content;
        } catch (_) {}
      }
    }
  }

  // ─── Google Gemini ────────────────────────────────────────────────────

  /// Non-streaming chat with Google Gemini API.
  Future<String> chatGemini({
    required String model,
    required List<Map<String, String>> messages,
    required String apiKey,
  }) async {
    final contents = messages.map((m) => {
          'role': m['role'] == 'assistant' ? 'model' : 'user',
          'parts': [
            {'text': m['content']}
          ],
        }).toList();

    final resp = await _client.post(
      Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'contents': contents}),
    );

    if (resp.statusCode != 200) {
      throw Exception('Gemini API error: ${resp.statusCode} ${resp.body}');
    }

    final json = jsonDecode(resp.body) as Map<String, dynamic>;
    final candidates = json['candidates'] as List<dynamic>?;
    if (candidates == null || candidates.isEmpty) {
      throw Exception('No response from Gemini');
    }
    final parts = (candidates.first as Map<String, dynamic>)['content']
        ['parts'] as List<dynamic>;
    return parts.map((p) => p['text'] as String).join();
  }

  /// Unified streaming chat — routes to Ollama for local models, OpenRouter for cloud.
  /// [onToken] is called with each text chunk as it arrives.
  Future<void> streamChat({
    required String model,
    required String systemPrompt,
    required List<Map<String, String>> previousMessages,
    required void Function(String token) onToken,
    String? openRouterApiKey,
  }) async {
    if (openRouterApiKey == null || openRouterApiKey.isEmpty) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      openRouterApiKey = prefs.getString('OPENROUTER_API_KEY');
    }

    if (openRouterApiKey == null || openRouterApiKey.isEmpty) {
      throw Exception('OpenRouter API key is required. Make sure it is set in your settings.');
    }

    final messages = [
      if (systemPrompt.isNotEmpty) {'role': 'system', 'content': systemPrompt},
      ...previousMessages,
    ];

    // Default to default-coding-swarm's first model if the model string is
    // generic — derived from the swarm config itself (2026-09-19) so this
    // can't drift out of sync with it the way a hardcoded literal did before.
    String resolvedModel = (model == 'lucy' || model.isEmpty)
        ? swarms['default-coding-swarm']!.models.first.id
        : model;

    // Check if user requested AutoRouter
    if (resolvedModel.toLowerCase() == 'autorouter' ||
        resolvedModel.toLowerCase() == 'auto' ||
        resolvedModel == 'autorouter-swarm') {
      resolvedModel = 'openrouter/auto';
    }

    // Check if the provided string is a Swarm ID instead of a model ID.
    // If it is, use the first model in that swarm config.
    if (swarms.containsKey(resolvedModel)) {
      final swarmConfig = swarms[resolvedModel]!;
      if (swarmConfig.models.isNotEmpty) {
        resolvedModel = swarmConfig.models.first.id;
      }
    } else if (resolvedModel.startsWith('custom-')) {
      final customList = await loadCustomSwarms();
      final customSwarm = customList.where((s) => s.id == resolvedModel).firstOrNull;
      if (customSwarm != null && customSwarm.models.isNotEmpty) {
        resolvedModel = customSwarm.models.first.id;
      }
    }

    await for (final token in chatOpenRouter(
      model: resolvedModel,
      messages: messages,
      apiKey: openRouterApiKey,
    )) {
      onToken(token);
    }
  }

  /// Fetches the OpenRouter account balance/usage.
  Future<String> fetchOpenRouterBalance() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final apiKey = prefs.getString('OPENROUTER_API_KEY');
    
    if (apiKey == null || apiKey.isEmpty) {
      return 'No Key';
    }

    try {
      final request = http.Request(
        'GET',
        Uri.parse('https://openrouter.ai/api/v1/credits'),
      );
      request.headers.addAll({
        'Authorization': 'Bearer $apiKey',
      });
      final response = await _client.send(request);
      final body = await response.stream.transform(utf8.decoder).join();
      
      if (response.statusCode == 200) {
        final json = jsonDecode(body) as Map<String, dynamic>;
        final data = json['data'] as Map<String, dynamic>?;
        if (data != null) {
          final totalCredits = data['total_credits'] as num? ?? 0.0;
          final totalUsage = data['total_usage'] as num? ?? 0.0;
          final remaining = (totalCredits - totalUsage).toStringAsFixed(4);
          return '\$$remaining';
        }
      }

      // Fallback
      final fallbackReq = http.Request('GET', Uri.parse('https://openrouter.ai/api/v1/auth/key'));
      fallbackReq.headers.addAll({'Authorization': 'Bearer $apiKey'});
      final fallbackRes = await _client.send(fallbackReq);
      final fallbackBody = await fallbackRes.stream.transform(utf8.decoder).join();
      if (fallbackRes.statusCode == 200) {
        final json = jsonDecode(fallbackBody) as Map<String, dynamic>;
        final data = json['data'] as Map<String, dynamic>?;
        if (data != null) {
          final usage = data['usage'] as num? ?? 0.0;
          final limit = data['limit'] as num?;
          if (limit != null) {
             final remaining = (limit - usage).toStringAsFixed(4);
             return '\$$remaining';
          }
          return '\$${usage.toStringAsFixed(4)} used';
        }
      }
      return 'Error fetching';
    } catch (e) {
      return 'Offline';
    }
  }

  /// Summarizes a chat history using Nemotron Lightning (free).
  Future<String> summarizeHistory(List<Map<String, String>> history) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final apiKey = prefs.getString('OPENROUTER_API_KEY');
    
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('OpenRouter API key is required to summarize.');
    }

    final prompt = 'Please summarize the following conversation history. '
        'Focus strictly on the core technical context, the project state, what the user is trying to accomplish, and any important decisions made. '
        'Keep the summary dense, concise, and highly actionable for an AI agent to read and immediately understand the state of the project. '
        'Conversation History:\n\n'
        '${history.map((m) => '${m['role']?.toUpperCase()}: ${m['content']}').join('\n\n')}';

    final request = http.Request(
      'POST',
      Uri.parse('https://openrouter.ai/api/v1/chat/completions'),
    );
    request.headers.addAll({
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $apiKey',
      'HTTP-Referer': 'https://swarmos.dev',
      'X-Title': 'SWARM OS Summarizer',
    });
    request.body = jsonEncode({
      'model': 'nvidia/llama-3.1-nemotron-70b-instruct:free',
      'messages': [{'role': 'user', 'content': prompt}],
    });

    final response = await _client.send(request);
    final body = await response.stream.transform(utf8.decoder).join();
    
    if (response.statusCode != 200) {
      throw Exception('OpenRouter API error ${response.statusCode}: $body');
    }

    try {
      final json = jsonDecode(body) as Map<String, dynamic>;
      final content = json['choices']?[0]?['message']?['content'] as String?;
      if (content == null || content.isEmpty) {
        throw Exception('Empty summary response.');
      }
      return content;
    } catch (e) {
      throw Exception('Failed to parse summary: $e');
    }
  }

  // ─── OpenRouter Video Generation ────────────────────────────────────────

  /// Submits an asynchronous video generation job to OpenRouter.
  Future<Map<String, dynamic>> submitVideoJob({
    required String model,
    required String prompt,
    String? resolution,
    String? aspectRatio,
    int? duration,
    bool? generateAudio,
    String? openRouterApiKey,
  }) async {
    String? apiKey = openRouterApiKey;
    if (apiKey == null || apiKey.isEmpty) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      apiKey = prefs.getString('OPENROUTER_API_KEY');
    }
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('OpenRouter API key is required for video generation.');
    }

    final bodyData = <String, dynamic>{
      'model': model,
      'prompt': prompt,
      if (resolution != null) 'resolution': resolution,
      if (aspectRatio != null) 'aspect_ratio': aspectRatio,
      if (duration != null) 'duration': duration,
      if (generateAudio != null) 'generate_audio': generateAudio,
    };

    final resp = await _client.post(
      Uri.parse('https://openrouter.ai/api/v1/videos'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
        'HTTP-Referer': 'https://swarmos.dev',
        'X-Title': 'SWARM OS Video Studio',
      },
      body: jsonEncode(bodyData),
    );

    if (resp.statusCode != 200 && resp.statusCode != 201 && resp.statusCode != 202) {
      throw Exception('OpenRouter Video Job submission failed: ${resp.statusCode} ${resp.body}');
    }

    return jsonDecode(resp.body) as Map<String, dynamic>;
  }

  /// Polls the status of an asynchronous OpenRouter video generation job.
  Future<Map<String, dynamic>> pollVideoJobStatus({
    required String jobId,
    String? openRouterApiKey,
  }) async {
    String? apiKey = openRouterApiKey;
    if (apiKey == null || apiKey.isEmpty) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      apiKey = prefs.getString('OPENROUTER_API_KEY');
    }
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('OpenRouter API key is required to check video status.');
    }

    final resp = await _client.get(
      Uri.parse('https://openrouter.ai/api/v1/videos/$jobId'),
      headers: {
        'Authorization': 'Bearer $apiKey',
        'HTTP-Referer': 'https://swarmos.dev',
        'X-Title': 'SWARM OS Video Studio',
      },
    );

    if (resp.statusCode != 200) {
      throw Exception('OpenRouter Video Status check failed: ${resp.statusCode} ${resp.body}');
    }

    return jsonDecode(resp.body) as Map<String, dynamic>;
  }

  void dispose() => _client.close();
}

import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'swarm_config.dart';

class LucyServerClient {
  final String baseUrl;

  LucyServerClient({String? baseUrl}) : baseUrl = baseUrl ?? SwarmConfig.httpBase;

  Stream<String> streamLucyChat({
    required String modelId,
    required List<Map<String, String>> messages,
    bool autoRoute = false,
  }) async* {
    final request = http.Request('POST', Uri.parse('$baseUrl/lucy'));
    SwarmConfig.authHeaders.forEach((k, v) => request.headers[k] = v);
    request.body = jsonEncode({
      'ModelId': modelId,
      'Messages': messages.map((m) => {
        'Role': m['role'],
        'Content': m['content'],
      }).toList(),
      'AutoRoute': autoRoute,
    });

    final client = http.Client();
    try {
      final response = await client.send(request);

      if (response.statusCode != 200) {
        final errBody = await response.stream.transform(utf8.decoder).join();
        throw Exception('LucyServer error: ${response.statusCode} - $errBody');
      }

      final stream = response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter());

      await for (final line in stream) {
        if (line.startsWith('data: ')) {
          final data = line.substring(6);
          if (data == '[DONE]') return;
          
          if (data.startsWith('[ERROR]')) {
             throw Exception(data.replaceAll('\\n', '\n'));
          }
          
          // Unescape newlines that C# escaped
          yield data.replaceAll('\\n', '\n');
        }
      }
    } finally {
      client.close();
    }
  }
}

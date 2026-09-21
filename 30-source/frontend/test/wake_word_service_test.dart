import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:swarm_flutter/services/lucille_voice_service.dart';
import 'package:swarm_flutter/services/wake_word_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    final voice = LucilleVoiceService();
    if (!voice.isMuted) voice.toggleMute();
  });

  test(
      'spoken chat uses GamingAgent, retains context and dispatches media safely',
      () async {
    final service = WakeWordService();
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      expect(request.url.host, '127.0.0.1');
      expect(request.url.port, 8401);
      if (request.url.path == '/api/media/control') {
        expect(jsonDecode(request.body), {'action': 'pause'});
        return http.Response('{"ok":true}', 200);
      }
      expect(request.url.path, '/api/lucille/chat');
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      final messages = body['messages'] as List;
      if (requests.length == 1) {
        expect(messages, [
          {'role': 'user', 'content': 'hello'}
        ]);
        return http.Response(
            '{"reply":"Hello!","sessionId":"voice-test"}', 200);
      }
      expect(body['sessionId'], 'voice-test');
      expect(messages.length, 3);
      expect(messages[1]['content'], 'Hello!');
      return http.Response(
          jsonEncode({
            'reply': 'Paused.\nACTION: media_pause',
            'sessionId': 'voice-test'
          }),
          200);
    });
    await http.runWithClient(() async {
      await service.handleSpokenPrompt('hello');
      expect(service.lastLucilleResponse, 'Hello!');
      await service.handleSpokenPrompt('pause my music');
    }, () => client);
    expect(service.lastLucilleResponse, 'Paused.');
    expect(service.isProcessing, isFalse);
    expect(requests.length, 3);
  });

  test('provider failure and unsupported actions release processing state',
      () async {
    final service = WakeWordService();
    for (final response in [
      http.Response('{"error":"provider unavailable"}', 200),
      http.Response(
          jsonEncode({'reply': 'No.\nACTION: arbitrary_shell rm'}), 200),
      http.Response('unavailable', 503),
    ]) {
      await http.runWithClient(() => service.handleSpokenPrompt('test failure'),
          () => MockClient((_) async => response));
      expect(service.isProcessing, isFalse);
    }
  });
}

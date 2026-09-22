import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'lucille_voice_service.dart';

class WakeWordService extends ChangeNotifier {
  static final WakeWordService _instance = WakeWordService._internal();
  factory WakeWordService() => _instance;
  WakeWordService._internal();

  bool _isListening = false;
  bool get isListening => _isListening;

  bool _isProcessing = false;
  bool get isProcessing => _isProcessing;

  String _lastSpokenPrompt = '';
  String get lastSpokenPrompt => _lastSpokenPrompt;

  String _lastLucilleResponse = '';
  String get lastLucilleResponse => _lastLucilleResponse;

  Timer? _micPollingTimer;
  Process? _recordingProcess;
  String? _sessionId;
  bool _polling = false;
  final List<Map<String, String>> _conversation = [];
  static String get _runtimePath =>
      '${Platform.environment['XDG_RUNTIME_DIR'] ?? '/run/user/${Process.runSync('id', [
                '-u'
              ]).stdout.toString().trim()}'}/lucille-wake';

  Future<void> _process(Future<void> Function() action) async {
    if (_isProcessing) return;
    _isProcessing = true;
    notifyListeners();
    final busy = File('$_runtimePath/busy');
    try {
      // This lives under the login user's private runtime directory.
      await busy.parent.create(recursive: true);
      await Process.run('chmod', ['700', busy.parent.path]);
      await busy.writeAsString('');
      await action();
    } finally {
      try {
        if (await busy.exists()) await busy.delete();
      } finally {
        _isProcessing = false;
        notifyListeners();
      }
    }
  }

  void startListening() {
    if (_isListening) return;
    _isListening = true;
    notifyListeners();

    // Start background audio monitoring
    _startMicWatcher();
  }

  void stopListening() {
    _isListening = false;
    _micPollingTimer?.cancel();
    _recordingProcess?.kill();
    _recordingProcess = null;
    notifyListeners();
  }

  /// Trigger Lucille immediately (via "Hey Lucy" voice command, hotkey, or HUD click)
  Future<void> triggerWakeWord() async {
    await _process(() async {
      final voiceService = LucilleVoiceService();
      await voiceService.speak(voiceService.getRandomAcknowledgment());
      await _recordAndProcessUserSpeech();
    });
  }

  Future<void> _startMicWatcher() async {
    // Periodically checks if continuous listener script is running or mic trigger event happens
    _micPollingTimer =
        Timer.periodic(const Duration(milliseconds: 250), (_) async {
      if (!_isListening || _isProcessing || _polling) return;
      _polling = true;
      try {
        final wakeFlag = File('$_runtimePath/wake.flag');
        if (await wakeFlag.exists()) {
          final prompt = await wakeFlag.readAsString();
          await wakeFlag.delete();
          if (prompt.trim().isNotEmpty) {
            await handleSpokenPrompt(prompt.trim());
          } else {
            await triggerWakeWord();
          }
        }
      } catch (e) {
        if (kDebugMode) print('Wake event failed: $e');
      } finally {
        _polling = false;
      }
    });
  }

  Future<void> _recordAndProcessUserSpeech() async {
    final wavPath = '$_runtimePath/input.wav';

    try {
      // Record 4 seconds of audio from default microphone using arecord
      _recordingProcess = await Process.start('arecord', [
        '-d',
        '4',
        '-f',
        'cd',
        '-t',
        'wav',
        '-q',
        wavPath,
      ]);

      await _recordingProcess?.exitCode;

      final wavFile = File(wavPath);
      if (await wavFile.exists() && await wavFile.length() > 2000) {
        // Transcribe speech using OpenRouter or local Whisper
        final text = await _transcribeAudio(wavFile);
        if (text.isNotEmpty) {
          _lastSpokenPrompt = text;
          notifyListeners();
          await _askLucilleAI(text);
        } else {
          await LucilleVoiceService()
              .speak("I didn't quite catch that, hun. Tell me again?");
        }
      }
    } catch (e) {
      if (kDebugMode) print('Audio record error: $e');
    } finally {
      try {
        if (await File(wavPath).exists()) {
          await File(wavPath).delete();
        }
      } catch (_) {}
    }
  }

  Future<String> _transcribeAudio(File audioFile) async {
    // 1. Try Groq Whisper (Ultra-fast Whisper-Large-v3-Turbo)
    try {
      String groqKey = await _resolveKey('GROQ_API_KEY');
      if (groqKey.isEmpty) groqKey = await _resolveKey('GROQ_KEY');

      if (groqKey.isNotEmpty) {
        final request = http.MultipartRequest(
          'POST',
          Uri.parse('https://api.groq.com/openai/v1/audio/transcriptions'),
        );
        request.headers['Authorization'] = 'Bearer $groqKey';
        request.fields['model'] = 'whisper-large-v3-turbo';
        request.fields['response_format'] = 'json';
        request.files
            .add(await http.MultipartFile.fromPath('file', audioFile.path));

        final streamedResponse =
            await request.send().timeout(const Duration(seconds: 10));
        final response = await http.Response.fromStream(streamedResponse);

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final text = (data['text'] ?? '').toString().trim();
          if (text.isNotEmpty) return text;
        }
      }
    } catch (e) {
      if (kDebugMode) print('Groq transcription error: $e');
    }

    // 2. Try OpenAI Whisper (whisper-1)
    try {
      String openAiKey = await _resolveKey('OPENAI_API_KEY');
      if (openAiKey.isEmpty) openAiKey = await _resolveKey('OPENAI_KEY');

      if (openAiKey.isNotEmpty) {
        final request = http.MultipartRequest(
          'POST',
          Uri.parse('https://api.openai.com/v1/audio/transcriptions'),
        );
        request.headers['Authorization'] = 'Bearer $openAiKey';
        request.fields['model'] = 'whisper-1';
        request.files
            .add(await http.MultipartFile.fromPath('file', audioFile.path));

        final streamedResponse =
            await request.send().timeout(const Duration(seconds: 10));
        final response = await http.Response.fromStream(streamedResponse);

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final text = (data['text'] ?? '').toString().trim();
          if (text.isNotEmpty) return text;
        }
      }
    } catch (e) {
      if (kDebugMode) print('OpenAI transcription error: $e');
    }

    // 3. Try Gemini Multimodal Audio Transcription
    try {
      String geminiKey = await _resolveKey('GEMINI_API_KEY');
      if (geminiKey.isEmpty) geminiKey = await _resolveKey('GEMINI_KEY');

      if (geminiKey.isNotEmpty) {
        final bytes = await audioFile.readAsBytes();
        final base64Audio = base64Encode(bytes);
        final uri = Uri.parse(
            'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=$geminiKey');
        final res = await http
            .post(
              uri,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'contents': [
                  {
                    'parts': [
                      {
                        'inline_data': {
                          'mime_type': 'audio/wav',
                          'data': base64Audio,
                        }
                      },
                      {
                        'text':
                            'Transcribe the spoken speech in this audio accurately. Return ONLY the transcribed text, nothing else.'
                      }
                    ]
                  }
                ]
              }),
            )
            .timeout(const Duration(seconds: 12));

        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          final text =
              (data['candidates']?[0]?['content']?['parts']?[0]?['text'] ?? '')
                  .toString()
                  .trim();
          if (text.isNotEmpty) return text;
        }
      }
    } catch (e) {
      if (kDebugMode) print('Gemini transcription error: $e');
    }

    return '';
  }

  Future<void> handleSpokenPrompt(String prompt) async {
    await _process(() async {
      _lastSpokenPrompt = prompt;
      notifyListeners();
      await _askLucilleAI(prompt);
    });
  }

  /// Matches spoken requests to summon/dismiss the gaming overlay (e.g.
  /// "open the overlay", "hide overlay", "bring up the overlay") so they're
  /// handled locally via the same toggle script the Shift+Tab hotkey uses
  /// (see labwc/rc.xml + airootfs/usr/local/bin/swarm-overlay-toggle.sh),
  /// instead of being sent to the AI as a chat prompt.
  static final RegExp _overlayIntentRe = RegExp(
      r'\b(open|show|close|hide|toggle|bring up|pull up)\b.*\boverlay\b',
      caseSensitive: false);

  bool _isOverlayIntent(String prompt) => _overlayIntentRe.hasMatch(prompt);

  Future<void> _toggleOverlay(String prompt) async {
    const scriptPath = '/usr/local/bin/swarm-overlay-toggle.sh';
    try {
      final action =
          RegExp(r'\b(close|hide)\b', caseSensitive: false).hasMatch(prompt)
              ? 'hide'
              : RegExp(r'\btoggle\b', caseSensitive: false).hasMatch(prompt)
                  ? 'toggle'
                  : 'show';
      final result = await Process.run(scriptPath, [action]);
      if (result.exitCode == 0) {
        await LucilleVoiceService().speak('There you go, hun.');
      } else {
        if (kDebugMode) {
          print(
              'swarm-overlay-toggle.sh exited ${result.exitCode}: ${result.stderr}');
        }
        await LucilleVoiceService()
            .speak("Hmm, the overlay didn't want to cooperate.");
      }
    } catch (e) {
      if (kDebugMode) print('swarm-overlay-toggle.sh error: $e');
      await LucilleVoiceService()
          .speak("I can't reach the overlay from here, hun.");
    }
  }

  Future<void> _askLucilleAI(String prompt) async {
    if (_isOverlayIntent(prompt)) {
      await _toggleOverlay(prompt);
      return;
    }
    try {
      final res = await http
          .post(
            Uri.parse('http://127.0.0.1:8401/api/lucille/chat'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'messages': [
                ..._conversation,
                {'role': 'user', 'content': prompt}
              ],
              if (_sessionId != null) 'sessionId': _sessionId,
            }),
          )
          .timeout(const Duration(seconds: 125));
      if (res.statusCode != 200) {
        throw HttpException('GamingAgent: ${res.statusCode}');
      }
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if ((data['error'] ?? '').toString().isNotEmpty) {
        throw StateError(data['error'].toString());
      }
      _sessionId = data['sessionId'] as String?;
      final reply = (data['reply'] ?? '').toString();
      final directive =
          RegExp(r'(?:^|\n)ACTION:\s*(\S+)(?:[ \t]+([^\n]+))?\s*$')
              .firstMatch(reply);
      if (directive != null) {
        await _dispatchAction(
            directive.group(1)!, directive.group(2)?.trim() ?? '');
      }
      _conversation.addAll([
        {'role': 'user', 'content': prompt},
        {'role': 'assistant', 'content': reply},
      ]);
      if (_conversation.length > 12) _conversation.removeRange(0, 2);
      // Action directives are handled above and are never read aloud.
      final responseText = (data['reply'] ?? '')
          .toString()
          .split('\n')
          .where((line) => !line.trimLeft().startsWith('ACTION:'))
          .join('\n')
          .trim();
      if (responseText.isEmpty) {
        throw StateError('Lucille returned an empty reply');
      }

      _lastLucilleResponse = responseText;
      notifyListeners();

      // Speak response out loud through the seductive TTS engine
      await LucilleVoiceService().speak(responseText);
    } catch (e) {
      if (kDebugMode) print('Lucille AI error: $e');
      await LucilleVoiceService().speak(
        "I heard you, sweetie, but my cloud link flickered. I'm still right here with you.",
      );
    }
  }

  Future<void> _dispatchAction(String verb, String argument) async {
    const mediaActions = {
      'media_play': 'play',
      'media_pause': 'pause',
      'media_play_pause': 'play-pause',
      'media_next': 'next',
      'media_previous': 'previous',
      'media_stop': 'stop',
    };
    if (mediaActions.containsKey(verb)) {
      final response = await http
          .post(
            Uri.parse('http://127.0.0.1:8401/api/media/control'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'action': mediaActions[verb]}),
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) throw StateError('Media control failed');
      return;
    }
    if (verb == 'open_browser' && argument.isNotEmpty) {
      final uri = Uri.tryParse(argument);
      if (uri != null &&
          uri.hasScheme &&
          !['http', 'https'].contains(uri.scheme)) {
        throw StateError('Unsupported browser URL');
      }
      final url = uri != null && uri.hasScheme && uri.host.isNotEmpty
          ? uri.toString()
          : Uri.https('www.google.com', '/search', {'q': argument}).toString();
      await Process.start(
          '/opt/swarm_os/swarm-overlay/swarm-overlay', ['browser', url],
          mode: ProcessStartMode.detached);
      return;
    }
    if (verb == 'open_app') {
      final candidates = switch (argument) {
        'chrome' => ['google-chrome-stable', 'google-chrome', 'chromium'],
        'opera-gx' => ['opera-gx', 'opera'],
        _ => <String>[],
      };
      for (final executable in candidates) {
        try {
          await Process.start(executable, [], mode: ProcessStartMode.detached);
          return;
        } on ProcessException {/* Try the next installed browser. */}
      }
    }
    throw StateError('Action unavailable: $verb');
  }

  Future<String> _resolveKey(String keyName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final prefVal = prefs.getString(keyName);
      if (prefVal != null && prefVal.trim().isNotEmpty) return prefVal.trim();
    } catch (_) {}

    final envPaths = [
      '/etc/swarm_os.env',
      '/root/.env',
      '/usr/local/bin/swarm_os/.env',
      '/run/media/i30ltz/lucy-master/.env',
      './.env',
      '../.env',
      '${Platform.environment['HOME']}/.env',
    ];
    for (final p in envPaths) {
      final f = File(p);
      if (f.existsSync()) {
        try {
          for (final line in f.readAsLinesSync()) {
            final trimmed = line.trim();
            if (trimmed.startsWith('$keyName=')) {
              return trimmed
                  .substring('$keyName='.length)
                  .trim()
                  .replaceAll('"', '')
                  .replaceAll("'", '');
            }
          }
        } catch (_) {}
      }
    }
    return Platform.environment[keyName] ?? '';
  }
}

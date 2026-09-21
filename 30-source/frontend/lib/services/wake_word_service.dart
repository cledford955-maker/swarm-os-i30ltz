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
    if (_isProcessing) return;
    _isProcessing = true;
    notifyListeners();

    final voiceService = LucilleVoiceService();

    // Seductive initial reply
    final ack = voiceService.getRandomAcknowledgment();
    await voiceService.speak(ack);

    // Record user speech
    await _recordAndProcessUserSpeech();

    _isProcessing = false;
    notifyListeners();
  }

  Future<void> _startMicWatcher() async {
    // Periodically checks if continuous listener script is running or mic trigger event happens
    _micPollingTimer = Timer.periodic(const Duration(seconds: 4), (_) async {
      if (!_isListening || _isProcessing) return;

      // Check if a wake word IPC flag was written by external listener
      final wakeFlag = File('/tmp/lucille_wake.flag');
      if (await wakeFlag.exists()) {
        try {
          final prompt = await wakeFlag.readAsString();
          await wakeFlag.delete();
          if (prompt.trim().isNotEmpty) {
            await handleSpokenPrompt(prompt.trim());
          } else {
            await triggerWakeWord();
          }
        } catch (_) {}
      }
    });
  }

  Future<void> _recordAndProcessUserSpeech() async {
    final wavPath = '/tmp/lucille_input_${DateTime.now().millisecondsSinceEpoch}.wav';

    try {
      // Record 4 seconds of audio from default microphone using arecord
      _recordingProcess = await Process.start('arecord', [
        '-d', '4',
        '-f', 'cd',
        '-t', 'wav',
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
          await LucilleVoiceService().speak("I didn't quite catch that, hun. Tell me again?");
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
        request.files.add(await http.MultipartFile.fromPath('file', audioFile.path));

        final streamedResponse = await request.send().timeout(const Duration(seconds: 10));
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
        request.files.add(await http.MultipartFile.fromPath('file', audioFile.path));

        final streamedResponse = await request.send().timeout(const Duration(seconds: 10));
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
        final uri = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=$geminiKey');
        final res = await http.post(
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
                  {'text': 'Transcribe the spoken speech in this audio accurately. Return ONLY the transcribed text, nothing else.'}
                ]
              }
            ]
          }),
        ).timeout(const Duration(seconds: 12));

        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          final text = (data['candidates']?[0]?['content']?['parts']?[0]?['text'] ?? '').toString().trim();
          if (text.isNotEmpty) return text;
        }
      }
    } catch (e) {
      if (kDebugMode) print('Gemini transcription error: $e');
    }

    return '';
  }

  Future<void> handleSpokenPrompt(String prompt) async {
    _isProcessing = true;
    _lastSpokenPrompt = prompt;
    notifyListeners();

    await _askLucilleAI(prompt);

    _isProcessing = false;
    notifyListeners();
  }

  /// Matches spoken requests to summon/dismiss the gaming overlay (e.g.
  /// "open the overlay", "hide overlay", "bring up the overlay") so they're
  /// handled locally via the same toggle script the Shift+Tab hotkey uses
  /// (see labwc/rc.xml + airootfs/usr/local/bin/swarm-overlay-toggle.sh),
  /// instead of being sent to the AI as a chat prompt.
  static final RegExp _overlayIntentRe =
      RegExp(r'\b(open|show|close|hide|toggle|bring up|pull up)\b.*\boverlay\b', caseSensitive: false);

  bool _isOverlayIntent(String prompt) => _overlayIntentRe.hasMatch(prompt);

  Future<void> _toggleOverlay() async {
    const scriptPath = '/usr/local/bin/swarm-overlay-toggle.sh';
    try {
      final result = await Process.run(scriptPath, []);
      if (result.exitCode == 0) {
        await LucilleVoiceService().speak('There you go, hun.');
      } else {
        if (kDebugMode) print('swarm-overlay-toggle.sh exited ${result.exitCode}: ${result.stderr}');
        await LucilleVoiceService().speak("Hmm, the overlay didn't want to cooperate.");
      }
    } catch (e) {
      if (kDebugMode) print('swarm-overlay-toggle.sh error: $e');
      await LucilleVoiceService().speak("I can't reach the overlay from here, hun.");
    }
  }

  Future<void> _askLucilleAI(String prompt) async {
    if (_isOverlayIntent(prompt)) {
      await _toggleOverlay();
      return;
    }
    try {
      final apiKey = await _resolveKey('OPENROUTER_API_KEY');

      String responseText = "I'm always here with you, hun. Let's make something incredible.";

      if (apiKey.isNotEmpty) {
        final res = await http.post(
          Uri.parse('https://openrouter.ai/api/v1/chat/completions'),
          headers: {
            'Authorization': 'Bearer $apiKey',
            'Content-Type': 'application/json',
            'HTTP-Referer': 'https://swarm-os.org',
            'X-Title': 'Swarm OS Lucille Core',
          },
          body: jsonEncode({
            'model': 'deepseek/deepseek-r1',
            'messages': [
              {
                'role': 'system',
                'content':
                    'You are Lucille, the seductive, brilliant, and protective AI soul of SWARM OS. '
                    'You speak with a warm, velvet, intimate female tone. Always address the user warmly as "hun" (never say "darling" or "darlin"). Keep spoken responses concise, witty, and charming.',
              },
              {'role': 'user', 'content': prompt},
            ],
            'max_tokens': 150,
          }),
        ).timeout(const Duration(seconds: 12));

        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          responseText = data['choices'][0]['message']['content'] ?? responseText;
        }
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
              return trimmed.substring('$keyName='.length).trim().replaceAll('"', '').replaceAll("'", '');
            }
          }
        } catch (_) {}
      }
    }
    return Platform.environment[keyName] ?? '';
  }
}

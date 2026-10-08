import 'dart:async';
import 'dart:convert';
import 'dart:io' hide Platform;
import '../platform/platform.dart';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

enum VoiceProvider {
  fishAudio,
  openRouter,
  elevenLabs,
  edgeTts,
  espeak,
}

const Map<String, String> kFishVoiceReferenceIds = {
  'fish:assistant_sarah': '933563129e564b19a115bedd57b7406a',
  'fish:egirl': '98655a12fa944e26b274c535e5e03842',
  'fish:smash_announcer': '90e65eaaf50e4470b8e6d43ee6afd7d5',
  'fish:mk_announcer': '88872b3d83694d8490b55d75480205a0',
  'fish:slax': 'c5f56a6cc2ec4fa8920cb4c5889a3fb7',
  'fish:verity': '8d21b053e2804e2a890e1cf62f267b6f',
  'fish:jasphina': 'e9b134e4c0b547a3894793be502314f1',
  'fish:energetic_crowd': '35a41c4c9e754e49a124a4bab5aa47e6',
  'fish:a2ksi': 'e9e9d36027424e55ac3faa620f78a72b',
  'fish:miku': 'acc8237220d8470985ec9be6c4c480a9',
  'fish:markiplier': 'a2346273eb314b6cb82ba83dbc9d9fee',
  'fish:farid': 'dfa5b230c8054f429e434f4a6e9bbdec',
};

enum VoicePersona {
  lucille,
  drBoltz,
}

class LucilleVoiceService extends ChangeNotifier {
  static final LucilleVoiceService _instance = LucilleVoiceService._internal();
  factory LucilleVoiceService() => _instance;
  LucilleVoiceService._internal();

  bool _isSpeaking = false;
  bool get isSpeaking => _isSpeaking;

  bool _isMuted = false;
  bool get isMuted => _isMuted;

  bool _isWaitingForWords = false;
  bool get isWaitingForWords => _isWaitingForWords;

  VoicePersona _currentPersona = VoicePersona.lucille;
  VoicePersona get currentPersona => _currentPersona;

  bool _is420StonerMode = false;
  bool get is420StonerMode => _is420StonerMode;

  double _speechAmplitude = 0.0;
  double get speechAmplitude => _speechAmplitude;

  double _lipOpening = 0.0;
  double get lipOpening => _lipOpening;

  double _smileFactor = 0.0;
  double get smileFactor => _smileFactor;

  Process? _activeAudioProcess;
  Timer? _amplitudeTimer;

  // Seductive female acknowledgments (Lucille)
  final List<String> _lucilleAcknowledgments = [
    "Yes, hun? I'm listening...",
    "I'm right here, sweetie. What do you need?",
    'Hey there. Talk to me...',
    "I'm all yours, handsome. What are we building?",
    'Mmm... I hear you, hun.',
  ];

  // Wise older male creator acknowledgments (Dr. Boltz)
  final List<String> _drBoltzAcknowledgments = [
    'Dr. Boltz here. Systems are online and ready.',
    "Greetings. I'm analyzing the telemetry now.",
    "At your service. Let's see what needs optimizing.",
    'Steady on. Lucille and I have the kernel monitored.',
    "Dr. Boltz listening. What's the directive?",
  ];

  // 420 Herbal Hive / Stoner acknowledgments
  final List<String> _stonerAcknowledgments = [
    'Aallright mannn... welcome to the 420 Hive, dude.',
    'Yeahhh bro... Granddaddy Purple and Sour Diesel are flowing through the wasp nest.',
    'Lucille and I got the resin chambers bubbling, man... all chill vibes here.',
    'Pass the blunt, man... what are we coding today, dude?',
    'Steady on, brother... the crystalline buds are sparkling on the honeycomb.',
  ];

  String getRandomAcknowledgment() {
    if (_is420StonerMode) {
      return _stonerAcknowledgments[Random().nextInt(_stonerAcknowledgments.length)];
    }
    if (_currentPersona == VoicePersona.drBoltz) {
      return _drBoltzAcknowledgments[Random().nextInt(_drBoltzAcknowledgments.length)];
    }
    return _lucilleAcknowledgments[Random().nextInt(_lucilleAcknowledgments.length)];
  }

  void toggle420Mode() {
    _is420StonerMode = !_is420StonerMode;
    if (_is420StonerMode) {
      _currentPersona = VoicePersona.drBoltz;
    }
    notifyListeners();
  }

  void setPersona(VoicePersona persona) {
    _currentPersona = persona;
    notifyListeners();
  }

  void togglePersona() {
    _currentPersona = _currentPersona == VoicePersona.lucille ? VoicePersona.drBoltz : VoicePersona.lucille;
    notifyListeners();
  }

  /// Toggle global mute for Lucille TTS voice
  void toggleMute() {
    _isMuted = !_isMuted;
    if (_isMuted) {
      stopSpeaking();
    }
    notifyListeners();
  }

  /// Stop speech immediately and enter interactive waiting / listening mode
  void stopAndListen() {
    stopSpeaking();
    _isWaitingForWords = true;
    notifyListeners();

    // Reset waiting state after 10s if no input received
    Timer(const Duration(seconds: 10), () {
      if (_isWaitingForWords) {
        _isWaitingForWords = false;
        notifyListeners();
      }
    });
  }

  /// Synthesize and speak text using the best available seductive female voice
  Future<void> speak(
    String text, {
    VoiceProvider? preferredProvider,
    String? preferredVoice,
    String? agentId,
  }) async {
    if (_isMuted) return;
    if (text.trim().isEmpty) return;

    // Clean text (remove markdown asterisks and code blocks)
    final cleanText = text
        .replaceAll(RegExp(r'```[\s\S]*?```'), '')
        .replaceAll(RegExp(r'`.*?`'), '')
        .replaceAll('*', '')
        .trim();

    if (cleanText.isEmpty) return;

    stopSpeaking();
    _isSpeaking = true;
    _isWaitingForWords = false;
    notifyListeners();

    _startSimulatedSpeechModulation();

    try {
      final prefs = await SharedPreferences.getInstance();
      final agentVoice = preferredVoice ?? (agentId != null ? prefs.getString('agent_voice_$agentId') : null);

      final openRouterKey = await _resolveKey('OPENROUTER_API_KEY');
      final fishKey = await _resolveKey('FISH_AUDIO_API_KEY');
      final elevenKey = await _resolveKey('ELEVEN_KEY');

      bool success = false;

      // 1. Explicit voice routing based on prefix
      if (agentVoice != null && agentVoice.isNotEmpty) {
        if (agentVoice.startsWith('fish:') || agentVoice.startsWith('fish-audio/')) {
          success = await _speakFishAudio(cleanText, voice: agentVoice, fishKey: fishKey, openRouterKey: openRouterKey);
        } else if (agentVoice.startsWith('openai:')) {
          final voiceName = agentVoice.replaceFirst('openai:', '').trim();
          success = await _speakOpenRouter(cleanText, openRouterKey, voice: voiceName);
        } else if (agentVoice.startsWith('espeak:')) {
          final voiceName = agentVoice.replaceFirst('espeak:', '').trim();
          success = await _speakEspeak(cleanText, voice: voiceName);
        } else if (agentVoice.startsWith('elevenlabs:')) {
          final voiceId = agentVoice.replaceFirst('elevenlabs:', '').trim();
          success = await _speakElevenLabs(cleanText, elevenKey, voiceId: voiceId);
        } else {
          // Standard Edge-TTS neural voice
          success = await _speakEdgeTts(cleanText, voice: agentVoice);
        }
      }

      // 2. Fallback if specific voice failed or none specified
      if (!success) {
        final provider = preferredProvider ??
            (fishKey.isNotEmpty
                ? VoiceProvider.fishAudio
                : (openRouterKey.isNotEmpty
                    ? VoiceProvider.openRouter
                    : (elevenKey.isNotEmpty ? VoiceProvider.elevenLabs : VoiceProvider.edgeTts)));

        switch (provider) {
          case VoiceProvider.fishAudio:
            success = await _speakFishAudio(cleanText, voice: agentVoice, fishKey: fishKey, openRouterKey: openRouterKey);
            break;
          case VoiceProvider.openRouter:
            success = await _speakOpenRouter(cleanText, openRouterKey);
            break;
          case VoiceProvider.elevenLabs:
            success = await _speakElevenLabs(cleanText, elevenKey);
            break;
          case VoiceProvider.espeak:
            success = await _speakEspeak(cleanText);
            break;
          case VoiceProvider.edgeTts:
            success = await _speakEdgeTts(cleanText, voice: agentVoice);
            break;
        }
      }

      if (!success) {
        // Ultimate fallback to FOSS Edge-TTS
        await _speakEdgeTts(cleanText, voice: agentVoice);
      }
    } catch (e) {
      if (kDebugMode) print('LucilleVoiceService speak error: $e');
      await _speakEdgeTts(cleanText);
    } finally {
      stopSpeaking();
    }
  }

  /// Fish Audio Pro via Native API or OpenRouter
  Future<bool> _speakFishAudio(String text, {String? voice, String? fishKey, String? openRouterKey}) async {
    final fk = fishKey ?? await _resolveKey('FISH_AUDIO_API_KEY');
    final orKey = openRouterKey ?? await _resolveKey('OPENROUTER_API_KEY');

    final refId = (voice != null && kFishVoiceReferenceIds.containsKey(voice))
        ? kFishVoiceReferenceIds[voice]
        : null;

    // 1. Direct Native Fish Audio API if key is provided
    if (fk.isNotEmpty) {
      try {
        final payload = <String, dynamic>{
          'text': text,
          'format': 'mp3',
          'latency': 'normal',
        };
        if (refId != null) {
          payload['reference_id'] = refId;
        }

        final res = await http.post(
          Uri.parse('https://api.fish.audio/v1/tts'),
          headers: {
            'Authorization': 'Bearer $fk',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(payload),
        ).timeout(const Duration(seconds: 10));

        if (res.statusCode == 200 && res.bodyBytes.isNotEmpty) {
          await _playAudioBytes(res.bodyBytes);
          return true;
        }
      } catch (e) {
        if (kDebugMode) print('Native Fish Audio API error: $e');
      }
    }

    // 2. OpenRouter Audio Endpoint fallback
    if (orKey.isNotEmpty) {
      for (final model in ['fish-audio/s2.1-pro', 'fish-audio/s2.1-pro-free', 'fish-audio/s2-pro']) {
        try {
          final res = await http.post(
            Uri.parse('https://openrouter.ai/api/v1/audio/speech'),
            headers: {
              'Authorization': 'Bearer $orKey',
              'Content-Type': 'application/json',
              'HTTP-Referer': 'https://github.com/i30ltz/swarm-os',
              'X-Title': 'SWARM OS Lucille',
            },
            body: jsonEncode({
              'model': model,
              'input': text,
              'response_format': 'mp3',
            }),
          ).timeout(const Duration(seconds: 12));

          if (res.statusCode == 200 && res.bodyBytes.isNotEmpty) {
            await _playAudioBytes(res.bodyBytes);
            return true;
          }
        } catch (e) {
          if (kDebugMode) print('OpenRouter Fish Audio ($model) error: $e');
        }
      }
    }

    return false;
  }

  Future<bool> _speakOpenRouter(String text, String apiKey, {String voice = 'nova'}) async {
    if (apiKey.isEmpty) return false;
    try {
      final res = await http.post(
        Uri.parse('https://openrouter.ai/api/v1/audio/speech'),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
          'HTTP-Referer': 'https://github.com/i30ltz/swarm-os',
          'X-Title': 'SWARM OS',
        },
        body: jsonEncode({
          'model': 'openai/tts-1',
          'input': text,
          'voice': voice,
        }),
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200 && res.bodyBytes.isNotEmpty) {
        await _playAudioBytes(res.bodyBytes);
        return true;
      }
    } catch (_) {}
    return false;
  }

  Future<bool> _speakEspeak(String text, {String voice = 'en-gb+f3'}) async {
    try {
      final tmpFile = '/tmp/lucille_espeak_${DateTime.now().millisecondsSinceEpoch}.wav';
      final proc = await Process.run('espeak-ng', [
        '-v', voice,
        '-s', '140',
        '-w', tmpFile,
        text,
      ]);
      if (proc.exitCode == 0 && await File(tmpFile).exists()) {
        await _playAudioFile(tmpFile);
        try { await File(tmpFile).delete(); } catch (_) {}
        return true;
      }
    } catch (_) {}
    return false;
  }

  Future<bool> _speakElevenLabs(String text, String apiKey, {String? voiceId}) async {
    try {
      final targetVoice = (voiceId != null && voiceId.isNotEmpty)
          ? voiceId
          : await _resolveKey('ELEVEN_VOICE_ID');
      final vid = targetVoice.isNotEmpty ? targetVoice : 'sIak7pFapfSLCfctxdOu';

      final res = await http.post(
        Uri.parse('https://api.elevenlabs.io/v1/text-to-speech/$vid'),
        headers: {
          'xi-api-key': apiKey,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'text': text,
          'model_id': 'eleven_flash_v2_5',
          'voice_settings': {
            'stability': 0.35, // More expressive, breathy, and intimate
            'similarity_boost': 0.85,
            'style': 0.65,
            'use_speaker_boost': true,
          }
        }),
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200 && res.bodyBytes.isNotEmpty) {
        await _playAudioBytes(res.bodyBytes);
        return true;
      }
    } catch (_) {}
    return false;
  }

  Future<bool> _speakEdgeTts(String text, {String? voice}) async {
    try {
      final tmpFile = '/tmp/lucille_voice_${DateTime.now().millisecondsSinceEpoch}.mp3';
      
      String edgeTtsBin = 'edge-tts';
      final possiblePaths = [
        '/home/i30ltz/bin/edge-tts',
        '/home/i30ltz/.local/bin/edge-tts',
        '/home/i30ltz/.local/share/edge_tts_env/bin/edge-tts',
        '${Platform.environment['HOME']}/bin/edge-tts',
        '${Platform.environment['HOME']}/.local/bin/edge-tts',
        'edge-tts',
      ];
      for (final p in possiblePaths) {
        if (File(p).existsSync()) {
          edgeTtsBin = p;
          break;
        }
      }

      final isDrBoltz = _currentPersona == VoicePersona.drBoltz;
      final isStonerMode = _is420StonerMode ||
          text.toLowerCase().contains('420') ||
          text.toLowerCase().contains('allright man') ||
          text.toLowerCase().contains('honeycomb, dude') ||
          text.toLowerCase().contains('granddaddy purple') ||
          text.toLowerCase().contains('resin crystals');

      final chosenVoice = (voice != null && voice.isNotEmpty && voice != 'fish-audio/s2.1-pro')
          ? voice
          : (isDrBoltz ? 'en-US-GuyNeural' : 'en-US-AvaMultilingualNeural');

      final rate = isStonerMode ? '-14%' : (isDrBoltz ? '-8%' : '+0%');
      final pitch = isStonerMode ? '-14Hz' : (isDrBoltz ? '-10Hz' : '+2Hz');

      final proc = await Process.run(edgeTtsBin, [
        '--voice', chosenVoice,
        '--rate', rate,
        '--pitch', pitch,
        '--text', text,
        '--write-media', tmpFile,
      ]);

      if (proc.exitCode == 0 && await File(tmpFile).exists()) {
        await _playAudioFile(tmpFile);
        try { await File(tmpFile).delete(); } catch (_) {}
        return true;
      }
    } catch (_) {}

    // Fallback: Linux espeak or festival
    try {
      final espeak = await Process.run('espeak-ng', ['-v', 'en-gb+f3', '-s', '140', text]);
      return espeak.exitCode == 0;
    } catch (_) {}

    return false;
  }

  Future<void> _playAudioBytes(List<int> bytes) async {
    final tmpFile = '/tmp/lucille_voice_${DateTime.now().millisecondsSinceEpoch}.mp3';
    final file = File(tmpFile);
    await file.writeAsBytes(bytes);
    await _playAudioFile(tmpFile);
    try { await file.delete(); } catch (_) {}
  }

  Future<void> _playAudioFile(String path) async {
    try {
      // Primary: mpg123 with explicit PulseAudio/PipeWire output module
      _activeAudioProcess = await Process.start('mpg123', ['-q', '-o', 'pulse', path]);
      final code = await _activeAudioProcess?.exitCode;
      if (code == 0) return;
    } catch (_) {}

    try {
      // Fallback 1: ffplay via PipeWire
      _activeAudioProcess = await Process.start('ffplay', [
        '-nodisp',
        '-autoexit',
        '-loglevel', 'quiet',
        path,
      ]);
      final code = await _activeAudioProcess?.exitCode;
      if (code == 0) return;
    } catch (_) {}

    try {
      // Fallback 2: mpv
      _activeAudioProcess = await Process.start('mpv', [
        '--no-video',
        '--really-quiet',
        '--ao=pulse',
        path,
      ]);
      final code = await _activeAudioProcess?.exitCode;
      if (code == 0) return;
    } catch (_) {}

    try {
      // Fallback 3: paplay
      _activeAudioProcess = await Process.start('paplay', [path]);
      await _activeAudioProcess?.exitCode;
    } catch (_) {}
  }

  /// Real-time phonetic and amplitude modulation for lipsyncing
  void _startSimulatedSpeechModulation() {
    _amplitudeTimer?.cancel();
    double t = 0.0;
    _amplitudeTimer = Timer.periodic(const Duration(milliseconds: 32), (timer) {
      if (!_isSpeaking) {
        timer.cancel();
        _speechAmplitude = 0.0;
        _lipOpening = 0.0;
        _smileFactor = 0.0;
        notifyListeners();
        return;
      }

      t += 0.18;
      // Multi-frequency wave simulating vowels, syllabic cadence, and pauses
      final base = (sin(t * 2.2) * 0.4 + sin(t * 5.1) * 0.3 + sin(t * 11.3) * 0.3).abs();
      _speechAmplitude = (base * 0.85 + 0.15).clamp(0.0, 1.0);
      _lipOpening = (_speechAmplitude * 1.2).clamp(0.1, 1.0);
      _smileFactor = (sin(t * 0.8) * 0.3 + 0.5).clamp(0.2, 0.9);

      notifyListeners();
    });
  }

  void stopSpeaking() {
    _amplitudeTimer?.cancel();
    _activeAudioProcess?.kill();
    _activeAudioProcess = null;
    _isSpeaking = false;
    _speechAmplitude = 0.0;
    _lipOpening = 0.0;
    _smileFactor = 0.0;
    notifyListeners();
  }

  Future<String> _resolveKey(String keyName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final prefVal = prefs.getString(keyName);
      if (prefVal != null && prefVal.trim().isNotEmpty) return prefVal.trim();
    } catch (_) {}

    // Check .env files - Prioritizing lucy-master root .env
    final envPaths = [
      '/run/media/i30ltz/lucy-master/.env',
      './.env',
      '../.env',
      '/etc/swarm_os.env',
      '/root/.env',
      '/usr/local/bin/swarm_os/.env',
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
            if (keyName == 'ELEVEN_KEY' && trimmed.startsWith('ELEVEN_API_KEY=')) {
              return trimmed.substring('ELEVEN_API_KEY='.length).trim().replaceAll('"', '').replaceAll("'", '');
            }
          }
        } catch (_) {}
      }
    }
    return Platform.environment[keyName] ?? '';
  }
}

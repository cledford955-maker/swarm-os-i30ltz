import 'dart:io';
import '../models/agent.dart';
import '../skills/nvidia_nim_skill.dart';
import 'skill_router.dart';

/// Typed facade over [SkillRouter] for NVIDIA voice skills.
///
/// Keeps callers (e.g. Dr. Vital, Echo) decoupled from raw skill IDs and
/// input-map plumbing. All methods validate inputs and return typed results.
class NvidiaVoiceService {
  final SkillRouter _router;

  const NvidiaVoiceService(this._router);

  /// Transcribe an audio file using the NVIDIA Parakeet CTC NIM.
  ///
  /// [language] is an optional hint such as `en` or `es`.
  /// Returns the transcribed text.
  Future<String> transcribe({
    required Agent agent,
    required File audio,
    String? language,
  }) async {
    final skill = NvidiaNimSkillRegistry.byId('nvidia.stt')!;
    final result = await _router.execute(
      agent: agent,
      skill: skill,
      inputs: {
        'audio': audio,
        if (language != null && language.isNotEmpty) 'language': language,
      },
    );
    return result['text'] as String? ?? '';
  }

  /// Synthesize text to speech using the NVIDIA Riva FastPitch NIM.
  ///
  /// Returns the absolute path to the generated MP3 file.
  Future<String> speak({
    required Agent agent,
    required String text,
    String voice = 'default',
  }) async {
    if (text.trim().isEmpty) {
      throw ArgumentError('TTS text must not be empty');
    }
    final skill = NvidiaNimSkillRegistry.byId('nvidia.tts')!;
    final result = await _router.execute(
      agent: agent,
      skill: skill,
      inputs: {'text': text, 'voice': voice},
    );
    return result['audio'] as String? ?? '';
  }

  /// Convenience: transcribe with the default agent (`echo`) if none is given.
  Future<String> transcribeWithDefaultAgent(File audio, {String? language}) {
    final agent = getAgent('agent_21') ?? agents.first;
    return transcribe(agent: agent, audio: audio, language: language);
  }

  /// Convenience: speak with the default agent (`vital`) if none is given.
  Future<String> speakWithDefaultAgent(String text, {String voice = 'default'}) {
    final agent = getAgent('vital') ?? agents.first;
    return speak(agent: agent, text: text, voice: voice);
  }
}

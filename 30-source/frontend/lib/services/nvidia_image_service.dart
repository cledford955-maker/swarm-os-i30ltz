import 'package:flutter/foundation.dart';
import '../models/agent.dart';
import '../skills/nvidia_nim_skill.dart';
import 'skill_router.dart';

/// Result of an NVIDIA SDXL Turbo image generation call.
@immutable
class GeneratedImage {
  /// Remote URL or local file path to the generated image.
  final String url;

  /// Prompt that produced the image.
  final String prompt;

  /// Requested image size.
  final String size;

  const GeneratedImage({
    required this.url,
    required this.prompt,
    required this.size,
  });

  bool get hasUrl => url.isNotEmpty;
}

/// Typed facade over [SkillRouter] for NVIDIA image generation.
class NvidiaImageService {
  final SkillRouter _router;

  const NvidiaImageService(this._router);

  /// Generate an image from [prompt] using the NVIDIA SDXL Turbo NIM.
  ///
  /// [size] defaults to `512x512`.
  Future<GeneratedImage> generate({
    required Agent agent,
    required String prompt,
    String size = '512x512',
  }) async {
    if (prompt.trim().isEmpty) {
      throw ArgumentError('Image prompt must not be empty');
    }
    final skill = NvidiaNimSkillRegistry.byId('nvidia.image')!;
    final result = await _router.execute(
      agent: agent,
      skill: skill,
      inputs: {'prompt': prompt, 'size': size},
    );
    return GeneratedImage(
      url: result['image'] as String? ?? '',
      prompt: prompt,
      size: size,
    );
  }

  /// Convenience: generate with the default visual agent (`ui_tandem`).
  Future<GeneratedImage> generateWithDefaultAgent(
    String prompt, {
    String size = '512x512',
  }) {
    final agent = getAgent('ui_tandem') ?? agents.first;
    return generate(agent: agent, prompt: prompt, size: size);
  }
}

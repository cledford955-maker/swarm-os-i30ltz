import 'package:flutter/foundation.dart';
import '../models/agent.dart';
import '../skills/nvidia_nim_skill.dart';
import 'skill_router.dart';

/// Result of a Cosmos world-model reasoning call.
@immutable
class WorldModelReasoning {
  final String response;

  const WorldModelReasoning({required this.response});
}

/// Result of an Omniverse USD asset reasoning call.
@immutable
class UsdReasoning {
  final String response;

  const UsdReasoning({required this.response});
}

/// Typed facade over [SkillRouter] for NVIDIA physical-AI and 3D reasoning.
///
/// Covers:
/// - Cosmos Nemotron world-model reasoning
/// - Omniverse USD asset reasoning
class PhysicsAiService {
  final SkillRouter _router;

  const PhysicsAiService(this._router);

  /// Reason about a physical scenario using NVIDIA Cosmos Nemotron.
  Future<WorldModelReasoning> reasonAboutPhysics({
    required Agent agent,
    required String scenario,
  }) async {
    if (scenario.trim().isEmpty) {
      throw ArgumentError('Physics scenario must not be empty');
    }
    final skill = NvidiaNimSkillRegistry.byId('nvidia.cosmos')!;
    final result = await _router.execute(
      agent: agent,
      skill: skill,
      inputs: {'prompt': scenario},
    );
    return WorldModelReasoning(response: result['response'] as String? ?? '');
  }

  /// Reason about a USD snippet or 3D pipeline using NVIDIA Omniverse.
  Future<UsdReasoning> reasonAboutUsd({
    required Agent agent,
    required String usdSnippet,
  }) async {
    if (usdSnippet.trim().isEmpty) {
      throw ArgumentError('USD snippet must not be empty');
    }
    final skill = NvidiaNimSkillRegistry.byId('nvidia.omniverse')!;
    final result = await _router.execute(
      agent: agent,
      skill: skill,
      inputs: {'usdSnippet': usdSnippet},
    );
    return UsdReasoning(response: result['response'] as String? ?? '');
  }

  /// Convenience: physics reasoning with the default agent (`antigravity`).
  Future<WorldModelReasoning> reasonAboutPhysicsWithDefaultAgent(String scenario) {
    final agent = getAgent('antigravity') ?? agents.first;
    return reasonAboutPhysics(agent: agent, scenario: scenario);
  }

  /// Convenience: USD reasoning with the default agent (`antigravity`).
  Future<UsdReasoning> reasonAboutUsdWithDefaultAgent(String usdSnippet) {
    final agent = getAgent('antigravity') ?? agents.first;
    return reasonAboutUsd(agent: agent, usdSnippet: usdSnippet);
  }
}

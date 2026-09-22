import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/agent.dart';
import '../skills/nvidia_nim_skill.dart';
import 'skill_router.dart';

/// Result of an NVIDIA cuOpt optimization run.
@immutable
class CuOptSolution {
  /// Raw JSON solution returned by the model.
  final Map<String, dynamic> raw;

  /// Human-readable summary, if the model produced one.
  final String? summary;

  const CuOptSolution({required this.raw, this.summary});

  /// Convenience accessor for the optimized assignment/routing plan.
  Map<String, dynamic>? get plan => raw['solution'] as Map<String, dynamic>?;
}

/// Typed facade over [SkillRouter] for NVIDIA cuOpt combinatorial optimization.
///
/// cuOpt is exposed as a structured-chat skill because the free NIM endpoint
/// expects a problem description and returns JSON. This facade wraps that
/// in a typed API for scheduling, routing, and resource allocation.
class NvidiaCuOptService {
  final SkillRouter _router;

  const NvidiaCuOptService(this._router);

  /// Solve a combinatorial optimization problem described by [problem].
  ///
  /// [problem] can be any JSON-serializable structure: cost matrix,
  /// constraints, demands, capacities, time windows, etc.
  ///
  /// Returns the parsed solution map and an optional summary string.
  Future<CuOptSolution> solve({
    required Agent agent,
    required Map<String, dynamic> problem,
  }) async {
    if (problem.isEmpty) {
      throw ArgumentError('cuOpt problem must not be empty');
    }
    final skill = NvidiaNimSkillRegistry.byId('nvidia.cuopt')!;
    final result = await _router.execute(
      agent: agent,
      skill: skill,
      inputs: {'problem': problem},
    );
    final raw = result['solution'];
    Map<String, dynamic> parsed;
    if (raw is Map<String, dynamic>) {
      parsed = raw;
    } else if (raw is String) {
      try {
        parsed = jsonDecode(raw) as Map<String, dynamic>;
      } catch (_) {
        parsed = {'raw': raw};
      }
    } else {
      parsed = {'raw': raw};
    }
    return CuOptSolution(
      raw: parsed,
      summary: result['summary'] as String?,
    );
  }

  /// Convenience: solve with the default planning agent (`antigravity`).
  Future<CuOptSolution> solveWithDefaultAgent(Map<String, dynamic> problem) {
    final agent = getAgent('antigravity') ?? agents.first;
    return solve(agent: agent, problem: problem);
  }
}

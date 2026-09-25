import 'package:flutter/foundation.dart';

/// One completed NVIDIA-skill invocation as observed by [SkillRouter].
@immutable
class NimSkillRunRecord {
  final String skillId;
  final String modelId;
  final DateTime completedAt;
  final Duration latency;
  final bool succeeded;
  final bool usedFallback;
  final bool usedPaidRoute;
  final String? error;

  const NimSkillRunRecord({
    required this.skillId,
    required this.modelId,
    required this.completedAt,
    required this.latency,
    required this.succeeded,
    required this.usedFallback,
    required this.usedPaidRoute,
    this.error,
  });
}

/// In-memory operational telemetry for the NVIDIA dashboard.
///
/// This deliberately records no prompts, audio, generated content, or API
/// keys. It keeps only the most recent routing result for each skill.
class NimSkillTelemetry extends ChangeNotifier {
  final Map<String, NimSkillRunRecord> _latestBySkill = {};

  NimSkillRunRecord? forSkill(String skillId) => _latestBySkill[skillId];

  NimSkillRunRecord? get mostRecent {
    if (_latestBySkill.isEmpty) return null;
    return _latestBySkill.values.reduce(
      (a, b) => a.completedAt.isAfter(b.completedAt) ? a : b,
    );
  }

  void record(NimSkillRunRecord run) {
    _latestBySkill[run.skillId] = run;
    notifyListeners();
  }
}

import 'package:flutter_test/flutter_test.dart';
import 'package:swarm_flutter/services/nim_skill_telemetry.dart';

void main() {
  test('stores only the latest run for each skill and finds most recent', () {
    final telemetry = NimSkillTelemetry();
    var notifications = 0;
    telemetry.addListener(() => notifications++);

    telemetry.record(NimSkillRunRecord(
      skillId: 'nvidia.tts',
      modelId: 'nvidia/riva:free',
      completedAt: DateTime.utc(2026, 9, 25, 10),
      latency: const Duration(milliseconds: 800),
      succeeded: true,
      usedFallback: false,
      usedPaidRoute: false,
    ));
    telemetry.record(NimSkillRunRecord(
      skillId: 'nvidia.image',
      modelId: 'paid/image-model',
      completedAt: DateTime.utc(2026, 9, 25, 10, 1),
      latency: const Duration(seconds: 3),
      succeeded: false,
      usedFallback: true,
      usedPaidRoute: true,
      error: 'HTTP 429',
    ));

    expect(notifications, 2);
    expect(telemetry.forSkill('nvidia.tts')?.latency.inMilliseconds, 800);
    expect(telemetry.forSkill('nvidia.image')?.usedPaidRoute, isTrue);
    expect(telemetry.mostRecent?.skillId, 'nvidia.image');
    expect(telemetry.mostRecent?.error, 'HTTP 429');
  });

  test('replaces an older record for the same skill', () {
    final telemetry = NimSkillTelemetry();
    final first = NimSkillRunRecord(
      skillId: 'nvidia.rerank',
      modelId: 'first',
      completedAt: DateTime.utc(2026, 9, 25, 10),
      latency: const Duration(seconds: 2),
      succeeded: false,
      usedFallback: false,
      usedPaidRoute: false,
    );
    final second = NimSkillRunRecord(
      skillId: 'nvidia.rerank',
      modelId: 'second',
      completedAt: DateTime.utc(2026, 9, 25, 10, 2),
      latency: const Duration(milliseconds: 400),
      succeeded: true,
      usedFallback: true,
      usedPaidRoute: false,
    );

    telemetry.record(first);
    telemetry.record(second);

    expect(telemetry.forSkill('nvidia.rerank'), same(second));
    expect(telemetry.mostRecent, same(second));
  });
}

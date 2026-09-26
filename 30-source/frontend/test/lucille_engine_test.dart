import 'package:flutter_test/flutter_test.dart';
import 'package:swarm_flutter/services/lucille_engine_service.dart';

void main() {
  group('LucilleEngineStatus', () {
    test('fromJson parses a running engine response', () {
      final json = {
        'status': 'running',
        'user': 'swarm',
        'uid': 1001,
        'p_cores': 6,
        'e_cores': 8,
        'total_ram_mb': 16384,
        'cgroup_memory_high_mb': 12288,
        'soul_sha256': 'abc123def456',
        'active_processes': 3,
      };
      final s = LucilleEngineStatus.fromJson(json);
      expect(s.running, isTrue);
      expect(s.user, 'swarm');
      expect(s.uid, 1001);
      expect(s.pCores, 6);
      expect(s.eCores, 8);
      expect(s.totalRamMb, 16384);
      expect(s.cgroupMemoryHighMb, 12288);
      expect(s.soulSha256, 'abc123def456');
      expect(s.activeProcesses, 3);
    });

    test('fromJson handles offline/non-running status', () {
      final json = {'status': 'stopped'};
      final s = LucilleEngineStatus.fromJson(json);
      expect(s.running, isFalse);
      expect(s.user, isEmpty);
      expect(s.pCores, 0);
    });

    test('offline factory returns non-running status', () {
      final s = LucilleEngineStatus.offline();
      expect(s.running, isFalse);
      expect(s.activeProcesses, 0);
    });
  });

  group('PipelineResult', () {
    test('fromJson parses a successful pipeline run', () {
      final json = {
        'success': true,
        'blocks': 5,
        'passed': 4,
        'rejected': 1,
        'high_risk': true,
        'consensus': true,
        'human': true,
        'applied': true,
        'checkpoint': 'abc123',
        'latency_ms': 1500,
        'mock': false,
      };
      final r = PipelineResult.fromJson(json);
      expect(r.success, isTrue);
      expect(r.totalBlocks, 5);
      expect(r.passedBlocks, 4);
      expect(r.rejectedBlocks, 1);
      expect(r.highRisk, isTrue);
      expect(r.consensusApproved, isTrue);
      expect(r.humanApproved, isTrue);
      expect(r.applied, isTrue);
      expect(r.checkpointId, 'abc123');
      expect(r.latencyMs, 1500);
      expect(r.mock, isFalse);
      expect(r.error, isNull);
    });

    test('fromJson handles error response', () {
      final json = {
        'success': false,
        'error': 'consensus gate blocked',
        'mock': true,
      };
      final r = PipelineResult.fromJson(json);
      expect(r.success, isFalse);
      expect(r.error, 'consensus gate blocked');
      expect(r.mock, isTrue);
      expect(r.totalBlocks, 0);
    });

    test('fromJson handles empty/minimal response', () {
      final r = PipelineResult.fromJson({});
      expect(r.success, isFalse);
      expect(r.totalBlocks, 0);
      expect(r.mock, isFalse);
      expect(r.error, isNull);
    });
  });
}

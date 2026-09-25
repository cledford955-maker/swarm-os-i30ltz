import 'package:flutter_test/flutter_test.dart';
import 'package:swarm_flutter/services/swarm_health_service.dart';

void main() {
  group('SwarmHealthSnapshot', () {
    test('fromJson parses a real LucyServer response', () {
      final json = <String, dynamic>{
        'status': 'ok',
        'version': '6.2.72',
        'build_date': '2026-09-24',
        'uptime_seconds': 3661,
        'lucy_mount_gb_used': 82.3,
        'lucy_mount_gb_total': 250.0,
        'services': {
          'lucy_server': 'ok',
          'gaming_agent': 'ok',
          'google_workspace': 'connection refused',
        },
      };
      final snap = SwarmHealthSnapshot.fromJson(json);

      expect(snap.status, 'ok');
      expect(snap.isOk, isTrue);
      expect(snap.version, '6.2.72');
      expect(snap.uptimeSeconds, 3661);
      expect(snap.uptimeFormatted, '1h 1m');
      expect(snap.diskUsedGb, 82.3);
      expect(snap.diskTotalGb, 250.0);
      expect(snap.diskFreeGb, closeTo(167.7, 0.01));
      expect(snap.diskPercent, closeTo(32.9, 0.1));
      expect(snap.serviceOk('lucy_server'), isTrue);
      expect(snap.serviceOk('gaming_agent'), isTrue);
      expect(snap.serviceOk('google_workspace'), isFalse);
      expect(snap.isStale(), isFalse); // just created
    });

    test('fromJson handles degraded status', () {
      final snap = SwarmHealthSnapshot.fromJson(<String, dynamic>{
        'status': 'degraded',
        'version': '6.2.72',
        'services': {'lucy_server': 'ok', 'gaming_agent': 'timeout'},
      });
      expect(snap.isOk, isFalse);
      expect(snap.serviceOk('gaming_agent'), isFalse);
    });

    test('empty snapshot is stale and has unknown status', () {
      final empty = SwarmHealthSnapshot.empty;
      expect(empty.status, 'unknown');
      expect(empty.isStale(), isTrue);
      expect(empty.isOk, isFalse);
      expect(empty.version, '…');
    });

    test('staleness respects custom maxAge', () {
      final snap = SwarmHealthSnapshot.fromJson(<String, dynamic>{
        'status': 'ok',
        'version': '6.2.72',
        'services': {},
      });
      // just created — not stale even at 1s
      expect(snap.isStale(const Duration(seconds: 1)), isFalse);
    });

    test('uptime formats days correctly', () {
      final snap = SwarmHealthSnapshot.fromJson(<String, dynamic>{
        'status': 'ok',
        'version': '6.2.72',
        'uptime_seconds': 90061, // 1d 1h 1m 1s
        'services': {},
      });
      expect(snap.uptimeFormatted, '1d 1h');
    });
  });
}

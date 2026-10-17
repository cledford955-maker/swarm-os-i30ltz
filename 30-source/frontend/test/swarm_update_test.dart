import 'package:flutter_test/flutter_test.dart';
import 'package:swarm_flutter/services/swarm_update_service.dart';

void main() {
  group('SwarmUpdateSnapshot', () {
    test('fromJson parses an update-available response', () {
      final snap = SwarmUpdateSnapshot.fromJson(<String, dynamic>{
        'current_version': '6.2.72',
        'latest_version': '6.2.75',
        'update_available': true,
        'checked_at': '2026-09-25T12:34:56Z',
        'latest_iso': {
          'filename': 'swarm-os-v6.2.75-abc12345-2026.09.25-x86_64.iso',
          'version': '6.2.75',
          'path': '/mnt/ventoy/ISO/SWARM_OS/swarm-os-v6.2.75-abc12345-2026.09.25-x86_64.iso',
          'size_bytes': 3221225472, // 3.0 GiB
          'sha256': 'abc123def456',
          'mod_time': '2026-09-25T12:00:00Z',
        },
      });

      expect(snap.currentVersion, '6.2.72');
      expect(snap.latestVersion, '6.2.75');
      expect(snap.updateAvailable, isTrue);
      expect(snap.latestIso, isNotNull);
      expect(snap.latestIso!.filename,
          'swarm-os-v6.2.75-abc12345-2026.09.25-x86_64.iso');
      expect(snap.latestIso!.version, '6.2.75');
      expect(snap.latestIso!.sha256, 'abc123def456');
      expect(snap.latestIso!.sizeGb, closeTo(3.0, 0.01));
      expect(snap.latestIso!.modTime, isNotNull);
    });

    test('fromJson handles no-update-available response', () {
      final snap = SwarmUpdateSnapshot.fromJson(<String, dynamic>{
        'current_version': '6.2.72',
        'latest_version': '6.2.72',
        'update_available': false,
        'checked_at': '2026-09-25T12:34:56Z',
        'latest_iso': {
          'filename': 'swarm-os-v6.2.72.iso',
          'version': '6.2.72',
          'path': '/mnt/ventoy/ISO/SWARM_OS/swarm-os-v6.2.72.iso',
          'size_bytes': 3000000000,
          'sha256': '',
          'mod_time': '',
        },
      });

      expect(snap.updateAvailable, isFalse);
      expect(snap.latestVersion, '6.2.72');
      expect(snap.latestIso!.sha256, isEmpty);
      expect(snap.latestIso!.modTime, isNull);
    });

    test('fromJson handles no-store response (latest_iso null)', () {
      final snap = SwarmUpdateSnapshot.fromJson(<String, dynamic>{
        'current_version': '6.2.72',
        'latest_version': null,
        'update_available': false,
        'checked_at': '2026-09-25T12:34:56Z',
        'latest_iso': null,
      });

      expect(snap.updateAvailable, isFalse);
      expect(snap.latestIso, isNull);
      expect(snap.latestVersion, isNull);
    });

    test('empty snapshot is safe to consume', () {
      final e = SwarmUpdateSnapshot.empty;
      expect(e.updateAvailable, isFalse);
      expect(e.latestIso, isNull);
      expect(e.latestVersion, isNull);
      expect(e.currentVersion, '?');
    });
  });
}

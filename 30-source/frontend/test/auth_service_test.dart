import 'package:flutter_test/flutter_test.dart';
import 'package:swarm_flutter/services/auth_service.dart';

void main() {
  group('PasskeyCredential', () {
    test('fromJson parses full credential', () {
      final json = {
        'id': 'cred-abc-123',
        'name': 'Pixel 9 Pro',
        'created_at': '2026-09-20T10:30:00Z',
      };
      final c = PasskeyCredential.fromJson(json);
      expect(c.id, 'cred-abc-123');
      expect(c.name, 'Pixel 9 Pro');
      expect(c.createdAt, '2026-09-20T10:30:00Z');
    });

    test('fromJson handles minimal credential (id only)', () {
      final c = PasskeyCredential.fromJson({'id': 'abc'});
      expect(c.id, 'abc');
      expect(c.name, 'abc');
      expect(c.createdAt, isEmpty);
    });

    test('fromJson handles empty map', () {
      final c = PasskeyCredential.fromJson({});
      expect(c.id, isEmpty);
      expect(c.name, isEmpty);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:swarm_flutter/services/google_workspace_service.dart';

void main() {
  group('GoogleAuthStatus', () {
    test('fromJson parses fully-authenticated status', () {
      final s = GoogleAuthStatus.fromJson(<String, dynamic>{
        'authenticated': true,
        'has_credentials': true,
        'email': 'user@example.com',
        'name': 'Test User',
      });
      expect(s.authenticated, isTrue);
      expect(s.hasCredentials, isTrue);
      expect(s.email, 'user@example.com');
      expect(s.name, 'Test User');
      expect(s.isOffline, isFalse);
      expect(s.error, isNull);
    });

    test('fromJson handles pre-upload state', () {
      final s = GoogleAuthStatus.fromJson(<String, dynamic>{
        'authenticated': false,
        'has_credentials': false,
        'email': null,
        'name': null,
      });
      expect(s.authenticated, isFalse);
      expect(s.hasCredentials, isFalse);
      expect(s.isOffline, isFalse);
    });

    test('fromJson handles credentials-uploaded-but-not-signed-in state', () {
      // Common intermediate state: user uploaded credentials.json but has
      // not yet completed the browser consent flow.
      final s = GoogleAuthStatus.fromJson(<String, dynamic>{
        'authenticated': false,
        'has_credentials': true,
      });
      expect(s.authenticated, isFalse);
      expect(s.hasCredentials, isTrue);
    });

    test('offline sentinel reads as offline', () {
      final s = GoogleAuthStatus.offline;
      expect(s.authenticated, isFalse);
      expect(s.hasCredentials, isFalse);
      expect(s.isOffline, isTrue);
      expect(s.error, isNotNull);
    });

    test('fromJson with only an error field reads as offline', () {
      final s = GoogleAuthStatus.fromJson(<String, dynamic>{
        'error': 'connection refused',
      });
      expect(s.isOffline, isTrue);
      expect(s.error, 'connection refused');
    });
  });
}

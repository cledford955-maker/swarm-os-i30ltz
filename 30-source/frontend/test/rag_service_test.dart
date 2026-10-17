import 'package:flutter_test/flutter_test.dart';
import 'package:swarm_flutter/services/rag_service.dart';

void main() {
  group('RagDocument', () {
    test('fromJson parses full document', () {
      final json = {
        'text': 'The quick brown fox jumps over the lazy dog.',
        'source': 'test-doc-1',
      };
      final d = RagDocument.fromJson(json);
      expect(d.text, 'The quick brown fox jumps over the lazy dog.');
      expect(d.source, 'test-doc-1');
    });

    test('fromJson handles missing source', () {
      final d = RagDocument.fromJson({'text': 'hello'});
      expect(d.text, 'hello');
      expect(d.source, isEmpty);
    });

    test('fromJson handles empty map', () {
      final d = RagDocument.fromJson({});
      expect(d.text, isEmpty);
      expect(d.source, isEmpty);
    });

    test('fromJson handles numeric values gracefully', () {
      final d = RagDocument.fromJson({'text': 42, 'source': 123});
      expect(d.text, '42');
      expect(d.source, '123');
    });
  });
}

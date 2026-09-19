import 'package:flutter_test/flutter_test.dart';
import 'package:swarm_flutter/models/swarm.dart';

void main() {
  group('SWARM Architecture Tests', () {
    test('Default coding swarm is Kimi K2.6, Qwen 2.5 Coder, GLM 5.3, DeepSeek R1 (2026-09-19)', () {
      final swarm = swarms['default-coding-swarm']!;
      expect(swarm.models.length, equals(4));

      expect(swarm.models.any((m) => m.id == 'moonshotai/kimi-k2.6'), isTrue);
      expect(swarm.models.any((m) => m.id == 'qwen/qwen-2.5-coder-32b-instruct'), isTrue);
      expect(swarm.models.any((m) => m.id == 'z-ai/glm-5.3'), isTrue);
      expect(swarm.models.any((m) => m.id == 'deepseek/deepseek-r1'), isTrue);
    });

    test('Nemotron swarm is the real current Nemotron 3 Ultra, not the retired 120B entry', () {
      final swarm = swarms['nemotron-swarm']!;
      expect(swarm.models.length, equals(1));
      final nemotron = swarm.models.first;
      expect(nemotron.id, equals('nvidia/nemotron-3-ultra-550b-a55b'));
      expect(nemotron.name, contains('Nemotron 3 Ultra'));
      // nvidia/nemotron-120b-ultra (the swarm's model before 2026-09-19) was
      // confirmed absent from OpenRouter's live /api/v1/models — dead.
      expect(swarm.models.any((m) => m.id == 'nvidia/nemotron-120b-ultra'), isFalse);
    });

    test('All catalog models have price strings and descriptions', () {
      expect(allModels.length, greaterThanOrEqualTo(120));
      for (final model in allModels) {
        expect(model.id, isNotEmpty);
        expect(model.name, isNotEmpty);
        expect(model.pricePer1M, isNotEmpty);
      }
    });

    test('The 3 models added 2026-09-19 exist with real live-verified pricing', () {
      for (final id in ['moonshotai/kimi-k2.6', 'z-ai/glm-5.3', 'nvidia/nemotron-3-ultra-550b-a55b']) {
        final m = allModels.firstWhere((m) => m.id == id);
        expect(m.pricePer1M, isNotEmpty);
        expect(m.provider, equals(ProviderId.openrouter));
      }
    });
  });
}

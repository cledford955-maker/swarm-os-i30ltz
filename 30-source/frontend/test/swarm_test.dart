import 'package:flutter_test/flutter_test.dart';
import 'package:swarm_flutter/models/swarm.dart';

void main() {
  group('SWARM Architecture Tests', () {
    test('Default flagship swarm includes all 7 specialized agents', () {
      final swarm = swarms['default-coding-swarm']!;
      expect(swarm.models.length, equals(7));

      // 1. Leader / Orchestrator: Claude Opus 4.6
      expect(swarm.models.any((m) => m.id == 'anthropic/claude-opus-4.6'), isTrue);

      // 2. Systems & Backend: GPT-5.6 Sol
      expect(swarm.models.any((m) => m.id == 'openai/gpt-5.6-sol'), isTrue);

      // 3. Frontend & Layout: Kimi K3
      expect(swarm.models.any((m) => m.id == 'moonshotai/kimi-k3:free' || m.id == 'moonshotai/kimi-k3'), isTrue);

      // 4. Tool, Shell & AST: DeepSeek-V4 Pro
      expect(swarm.models.any((m) => m.id == 'deepseek/deepseek-v4-pro'), isTrue);

      // 5. QA & Verification: Gemini 3.7 Flash
      expect(swarm.models.any((m) => m.id == 'google/gemini-3.7-flash'), isTrue);

      // 6. Auto-Complete: GLM 5.2
      expect(swarm.models.any((m) => m.id == 'zhipu/glm-5.2-autocomplete'), isTrue);

      // 7. System Evals & Optimization: Nemotron Ultra
      final nemotron = swarm.models.firstWhere((m) => m.id == 'nvidia/nemotron-120b-ultra');
      expect(nemotron.name, contains('Nemotron Ultra'));
      expect(nemotron.role, contains('Optimization'));
    });

    test('All catalog models have price strings and descriptions', () {
      expect(allModels.length, greaterThanOrEqualTo(120));
      for (final model in allModels) {
        expect(model.id, isNotEmpty);
        expect(model.name, isNotEmpty);
        expect(model.pricePer1M, isNotEmpty);
      }
    });

    test('Nemotron Ultra model is present and configured as FREE in catalog', () {
      final nemotron = allModels.firstWhere((m) => m.id == 'nvidia/nemotron-120b-ultra');
      expect(nemotron.name, contains('Nemotron Ultra'));
      expect(nemotron.pricePer1M, equals('FREE'));
      expect(nemotron.provider, equals(ProviderId.nvidia));
    });
  });
}

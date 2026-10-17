import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/lucille_assistant_client.dart';
import '../models/lucille_brief.dart';
import '../models/lucille_game.dart';

final lucilleAssistantClientProvider = Provider<LucilleAssistantClient>((ref) {
  return LucilleAssistantClient();
});

/// Polls /api/artifact (Team Brief + threads + jobs). Lucille Assistant has
/// a real SSE stream (/api/threads/stream) for instant updates; polling is
/// the simpler first pass — good enough for a Brief that changes on human
/// timescales (comments, Ask replies a few seconds after asking).
class TeamBriefNotifier extends AsyncNotifier<TeamBrief> {
  Timer? _timer;
  static const _interval = Duration(seconds: 12);

  @override
  Future<TeamBrief> build() async {
    ref.onDispose(() => _timer?.cancel());
    _timer = Timer.periodic(_interval, (_) => refresh());
    return _fetch();
  }

  Future<TeamBrief> _fetch() =>
      ref.read(lucilleAssistantClientProvider).fetchArtifact();

  Future<void> refresh() async {
    state = await AsyncValue.guard(_fetch);
  }
}

final teamBriefProvider =
    AsyncNotifierProvider<TeamBriefNotifier, TeamBrief>(TeamBriefNotifier.new);

/// Which anchor's thread is expanded in the Team Brief UI (null = none).
final expandedAnchorProvider = StateProvider<String?>((ref) => null);

class GameMarksNotifier extends AsyncNotifier<List<GameMark>> {
  @override
  Future<List<GameMark>> build() => _fetch();

  Future<List<GameMark>> _fetch() =>
      ref.read(lucilleAssistantClientProvider).fetchGameMarks();

  Future<void> refresh() async {
    state = await AsyncValue.guard(_fetch);
  }
}

final gameMarksProvider =
    AsyncNotifierProvider<GameMarksNotifier, List<GameMark>>(GameMarksNotifier.new);

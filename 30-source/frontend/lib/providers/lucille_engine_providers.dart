import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/lucille_engine_service.dart';

final lucilleEngineServiceProvider = Provider<LucilleEngineService>((ref) {
  return LucilleEngineService();
});

class LucilleEngineNotifier extends AsyncNotifier<LucilleEngineStatus> {
  Timer? _timer;
  static const _interval = Duration(seconds: 10);

  @override
  Future<LucilleEngineStatus> build() async {
    ref.onDispose(() => _timer?.cancel());
    _startPolling();
    return _fetch();
  }

  void _startPolling() {
    _timer?.cancel();
    _timer = Timer.periodic(_interval, (_) async {
      state = await AsyncValue.guard(_fetch);
    });
  }

  Future<LucilleEngineStatus> _fetch() async {
    final svc = ref.read(lucilleEngineServiceProvider);
    return svc.getStatus();
  }
}

final lucilleEngineStatusProvider =
    AsyncNotifierProvider<LucilleEngineNotifier, LucilleEngineStatus>(
  LucilleEngineNotifier.new,
);

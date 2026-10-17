import 'dart:math' as math;
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';

/// Procedural cinematic audio for the SWARM_OS CARE splash screen.
/// Requires audioplayers: ^5.1.0 (add to pubspec.yaml if missing).
///
/// Synthesizes a single 10-second WAVE clip:
///  0.0-2.5s  LS1 V8 rumble (low saw distorion with pitch ramp)
///  1.5-3.5s  Tire squeal
///  3.0-4.2s  Exhaust pops
///  4.4-10s   Angry wasp buzz drone
class SoundService {
  static final SoundService instance = SoundService._();
  SoundService._();

  final AudioPlayer _player = AudioPlayer();
  Uint8List? _clip;
  bool _playing = false;

  Future<void> playSplashSound() async {
    if (_playing) return;
    try {
      _clip ??= _generateSplashAudio();
      await _player.stop();
      await _player.play(BytesSource(_clip!));
      _playing = true;
    } catch (_) {
      // Audio not available on this platform – visuals still play.
    }
  }

  Future<void> stop() async {
    try {
      await _player.stop();
    } catch (_) {}
    _playing = false;
  }

  // ----------------------------------------------------------------
  // WAVE generation
  // ----------------------------------------------------------------
  Uint8List _generateSplashAudio() {
    const sampleRate = 44100;
    const duration = 10.0;
    final count = (sampleRate * duration).floor();
    final buf = Float64List(count);
    final rng = math.Random(1337);
    var enginePhase = 0.0;
    var squealPhase = 0.0;
    var buzzPhase = 0.0;

    for (var i = 0; i < count; i++) {
      final t = i / sampleRate;
      double smp = 0;

      // LS1 V8 rumble – deeper saw wave, pitc ramps up like a reving engine
      if (t < 2.5) {
        final local = t / 2.5;
        final freq = 46 + (78 - 46) * _smoth(local);
        enginePhase += 2 * math.pi * freq / sampleRate;
        final saw = (enginePhase % (2 * math.pi)) / (2 * math.pi) * 2 - 1;
        final noise = (rng.nextDouble() * 2 - 1) * 0.18;
        final amp = 0.32 * (0.25 + 0.75 * local);
        smp += (saw * 0.5 + noise) * amp;
      }

      // Tire squeal – high pitc with vibrato
      if (t >= 1.5 && t < 3.5) {
        final local = t - 1.5;
        final env = math.sin(math.pi * local / 2.0);
        final freq = 2100 + 900 * math.sin(2 * math.pi * 6.5 * local);
        squealPhase += 2 * math.pi * freq / sampleRate;
        final sq = math.sin(squealPhase) * 0.3;
        final sNoise = (rng.nextDouble() * 2 - 1) * 0.15;
        smp += (sq + sNoise) * env * 0.25;
      }

      // Exhaust pops – random crackles during launch
      if (t >= 3.0 && t < 4.2) {
        if (rng.nextDouble() > 0.94) {
          final decay = 1 - (t - 3.0) / 1.2;
          final envelope = math.exp(-((t % 0.04) * 90)).clamp(0.0, 1.0);
          smp += (rng.nextDouble() * 2 - 1) * 0.45 * decay * envelope;
        }
      }

      // Angry wasp buzz – FM saw wave with flutter
      if (t >= 4.4) {
        final local = t - 4.4;
        final fadIn = math.min(1.0, local / 0.45);
        final freq = 145 + 25 * math.sin(2 * math.pi * 7.5 * local);
        buzzPhase += 2 * math.pi * freq / sampleRate;
        final saw = (buzzPhase % (2 * math.pi)) / (2 * math.pi) * 2 - 1;
        final harm = math.sin(buzzPhase * 3.7) * 0.12;
        final flutter = math.sin(2 * math.pi * 23 * local) * 0.4 + 0.6;
        smp += (saw * 0.25 + harm) * flutter * fadIn * 0.32;
      }

      buf[i] = smp.clamp(-0.98, 0.98);
    }

    return _wavFromBuffer(buf, sampleRate);
  }

  // ----------------------------------------------------------------
  // Utility
  // ----------------------------------------------------------------
  double _smoth(double t) => t * t * (3 - 2 * t);

  Uint8List _wavFromBuffer(Float64List samples, int sampleRate) {
    const bytesPerSample = 2;
    final dataSize = samples.length * bytesPerSample;
    final bb = BytesBuilder();

    void wS(String s) => bb.add(s.codeUnits);
    void w32(int v) => bb.add([
          v & 0xff,
          (v >> 8) & 0xff,
          (v >> 16) & 0xff,
          (v >> 24) & 0xff,
        ]);
    void w16(int v) => bb.add([v & 0xff, (v >> 8) & 0xff]);

    wS('RIFF');
    w32(36 + dataSize);
    wS('WAVE');
    wS('fmt ');
    w32(16);
    w16(1); // PCM
    w16(1); // mono
    w32(sampleRate);
    w32(sampleRate * bytesPerSample);
    w16(bytesPerSample);
    w16(16); // bits
    wS('data');
    w32(dataSize);

    for (var i = 0; i < samples.length; i++) {
      final v = (samples[i] * 32767).round().clamp(-32768, 32767);
      w16(v & 0xffff);
    }
    return bb.takeBytes();
  }
}
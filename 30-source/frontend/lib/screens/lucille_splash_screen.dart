import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

/// ═══════════════════════════════════════════════════════════════
/// LUCILLE CINEMATIC VIDEO SPLASH SCREEN
/// ═══════════════════════════════════════════════════════════════
/// Plays the Grok-generated 1999 Trans-Am WS6 → cyber-wasp nest
/// MP4 video fullscreen with audio via media_kit (Linux native),
/// then auto-transitions to the Hub.
/// ═══════════════════════════════════════════════════════════════
class LucilleSplashScreen extends StatefulWidget {
  final VoidCallback onComplete;
  final Duration duration;

  const LucilleSplashScreen({
    super.key,
    required this.onComplete,
    this.duration = const Duration(seconds: 9),
  });

  @override
  State<LucilleSplashScreen> createState() => _LucilleSplashScreenState();
}

class _LucilleSplashScreenState extends State<LucilleSplashScreen>
    with TickerProviderStateMixin {
  late final Player _player;
  late final VideoController _videoController;
  late final AnimationController _fadeInController;
  late final AnimationController _brandPulseController;
  late final Animation<double> _fadeIn;
  late final Animation<double> _brandPulse;

  Timer? _fallbackTimer;
  bool _videoReady = false;
  bool _videoFailed = false;
  bool _completed = false;
  StreamSubscription? _completedSub;
  StreamSubscription? _errorSub;

  static const Color _cyan = Color(0xFF00E5FF);
  static const Color _blue = Color(0xFF0066FF);
  static const Color _asphalt = Color(0xFF04030A);

  @override
  void initState() {
    super.initState();

    // ── Animation controllers ──
    _fadeInController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeIn = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeInController, curve: Curves.easeOut),
    );

    _brandPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
    _brandPulse = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _brandPulseController, curve: Curves.easeInOut),
    );

    // ── Media Kit player ──
    _player = Player();
    _videoController = VideoController(_player);

    _initVideo();

    // Fallback auto-complete if everything fails
    _fallbackTimer = Timer(widget.duration + const Duration(seconds: 3), () {
      _finish();
    });
  }

  Future<void> _initVideo() async {
    try {
      // Listen for playback completion
      _completedSub = _player.stream.completed.listen((completed) {
        if (completed) _finish();
      });

      // Listen for errors
      _errorSub = _player.stream.error.listen((error) {
        debugPrint('media_kit error: $error');
      });

      // Try the bundled asset path first (Flutter release bundle)
      final bundlePath = '${Directory.current.path}/data/flutter_assets/assets/splash/lucille_transam_splash.mp4';
      const devPath = '/run/media/i30ltz/lucy-master/Lucille-v6/frontend/assets/splash/lucille_transam_splash.mp4';

      String videoPath;
      if (File(bundlePath).existsSync()) {
        videoPath = bundlePath;
      } else if (File(devPath).existsSync()) {
        videoPath = devPath;
      } else {
        // Last resort — look relative to executable
        final exeDir = File(Platform.resolvedExecutable).parent.path;
        final exePath = '$exeDir/data/flutter_assets/assets/splash/lucille_transam_splash.mp4';
        if (File(exePath).existsSync()) {
          videoPath = exePath;
        } else {
          throw FileSystemException('Video file not found', bundlePath);
        }
      }

      debugPrint('Playing splash video from: $videoPath');

      await _player.open(Media(videoPath), play: true);
      await _player.setVolume(100.0);

      if (!mounted) return;
      setState(() => _videoReady = true);
      _fadeInController.forward();
    } catch (e) {
      debugPrint('Video splash failed: $e');
      if (mounted) {
        setState(() => _videoFailed = true);
        _fadeInController.forward();
        Timer(const Duration(seconds: 4), _finish);
      }
    }
  }

  void _finish() {
    if (_completed) return;
    _completed = true;
    _fallbackTimer?.cancel();
    widget.onComplete();
  }

  @override
  void dispose() {
    _fallbackTimer?.cancel();
    _completedSub?.cancel();
    _errorSub?.cancel();
    _player.dispose();
    _fadeInController.dispose();
    _brandPulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _asphalt,
      body: AnimatedBuilder(
        animation: Listenable.merge([_fadeInController, _brandPulseController]),
        builder: (context, _) {
          return Stack(
            fit: StackFit.expand,
            children: [
              // ─── Video Layer ─────────────────────────────────────
              if (_videoReady)
                Opacity(
                  opacity: _fadeIn.value,
                  child: Video(
                    controller: _videoController,
                    fit: BoxFit.cover,
                    controls: noVideoControls,
                  ),
                )
              else if (_videoFailed)
                Opacity(
                  opacity: _fadeIn.value,
                  child: Image.asset(
                    'assets/splash/transam_1440p.jpg',
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                )
              else
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 32,
                        height: 32,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: _cyan.withValues(alpha: 0.7),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'INITIALIZING LUCILLE...',
                        style: TextStyle(
                          color: _cyan.withValues(alpha: 0.5),
                          fontSize: 11,
                          letterSpacing: 3.0,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

              // ─── Cinematic Vignette ──────────────────────────────
              if (_videoReady || _videoFailed)
                Opacity(
                  opacity: _fadeIn.value,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: Alignment.center,
                        radius: 1.2,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.4),
                        ],
                      ),
                    ),
                  ),
                ),

              // ─── LUCILLE Branding (Top-Left) ─────────────────────
              if (_videoReady || _videoFailed)
                Positioned(
                  top: 36,
                  left: 36,
                  child: Opacity(
                    opacity: _fadeIn.value,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ShaderMask(
                          shaderCallback: (bounds) => const LinearGradient(
                            colors: [_cyan, Colors.white, _blue],
                            stops: [0.0, 0.5, 1.0],
                          ).createShader(bounds),
                          child: const Text(
                            'LUCILLE',
                            style: TextStyle(
                              fontSize: 52,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 16,
                              color: Colors.white,
                              height: 1.0,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: _cyan.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                    color: _cyan.withValues(alpha: 0.5)),
                              ),
                              child: const Text(
                                '1999 TRANS-AM WS6',
                                style: TextStyle(
                                  color: _cyan,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.5,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'SWARM OS v5 [BETA]',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.55),
                                fontSize: 11,
                                letterSpacing: 3.5,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

              // ─── Bottom Tagline ──────────────────────────────────
              if (_videoReady || _videoFailed)
                Positioned(
                  bottom: 36,
                  left: 0,
                  right: 0,
                  child: Opacity(
                    opacity: _fadeIn.value * _brandPulse.value,
                    child: const Text(
                      'THE SWARM DEVOURS ALL',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFFFFCC00),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 8,
                      ),
                    ),
                  ),
                ),

              // ─── Skip Button (Top-Right) ─────────────────────────
              Positioned(
                top: 36,
                right: 36,
                child: Opacity(
                  opacity: _fadeIn.value.clamp(0.0, 1.0),
                  child: ElevatedButton.icon(
                    onPressed: _finish,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black.withValues(alpha: 0.7),
                      foregroundColor: _cyan,
                      side: BorderSide(color: _cyan.withValues(alpha: 0.6)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.skip_next_rounded, size: 18),
                    label: const Text(
                      'SKIP TO HUB',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                        fontSize: 11.5,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Empty controls — we don't want play/pause/seek UI on the splash.
Widget noVideoControls(VideoState state) => const SizedBox.shrink();

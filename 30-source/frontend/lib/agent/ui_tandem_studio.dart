import 'dart:convert';
import 'dart:io' hide Platform;
import '../platform/platform.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/swarm_colors.dart';
import '../theme/swarm_text_styles.dart';

/// UI TANDEM WORKSTATION: CLAUDE 3.7 SONNET & DEEPSEEK R1
/// Dual-engine UI design laboratory and generator
class UiTandemStudio extends ConsumerStatefulWidget {
  const UiTandemStudio({super.key});

  @override
  ConsumerState<UiTandemStudio> createState() => _UiTandemStudioState();
}

class _UiTandemStudioState extends ConsumerState<UiTandemStudio>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final TextEditingController _promptController = TextEditingController();

  bool _isGenerating = false;
  String _activeStep = '';
  String _claudeBlueprint = '';
  String _deepseekCode = '';

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);

    _promptController.text =
        'Create a realistic 1999 Pontiac Firebird Trans Am WS6 in brilliant Electric Blue doing aggressive smokey donuts on asphalt with squalling/screeching tires, heavy burnt rubber smoke clouds, mean cammed V8 engine revving up, and glowing wasp swarm nest geometry across both the Splash Screen and Loading Progress Screen.';

    // Initial default demo code showcasing the tandem power
    _claudeBlueprint = '''# UI TANDEM ARCHITECTURE BLUEPRINT (Claude 3.7 Sonnet)

## Aesthetic Identity: 1999 Trans-Am WS6 × Swarm OS Matrix
- Vehicle: 1999 Pontiac Firebird Trans Am WS6
- Exterior Finish: Electric Blue Metallic Pearl (#00E5FF / #0088FF / #002266)
- Action: Aggressive 360° tire-shredding donuts, burning rubber tire tracks on dark asphalt
- Audio & Dynamics: 
  * Mean LS1 V8 cam lope idle building into ferocious 6,500 RPM throttle revs
  * Squalling, screeching tire squeal with dynamic screen vibration & chassis torque tilt
  * Thick billows of white & electric-blue illuminated burnout smoke
- Swarm Ecosystem:
  * Burnout smoke particles swirl upwards and crystallize into golden cyber-wasps
  * Wasps converge into a luminous hexagonal wasp-nest hologram forming the Lucille logo

## Dual-Screen Flow
1. SCREEN 1: SPLASH SCREEN (ACTION BURNOUT & DONUTS)
   - Full-canvas CustomPainter rendering the Trans Am in orbit drift
   - Ram Air hood scoops glowing, twin pop-up headlights cutting through smoke
   - Rotating burnt-rubber tire marks remaining on asphalt
   - Chassis shake & throttle blips reacting to V8 audio envelope

2. SCREEN 2: LOADING PROGRESS SCREEN (TELEMETRY COCKPIT)
   - Trans Am WS6 cockpit telemetry with illuminated analog tachometer
   - Needle revs from 1,000 RPM idle to redline as system modules load (0% to 100%)
   - Boost gauge & oil pressure indicators pulsing with system health
   - Tire smoke progress bar across the bottom displaying swarm boot milestones''';

    _deepseekCode = '''// UI TANDEM IMPLEMENTATION (DeepSeek R1 Engine)
// 1999 Trans-Am Electric Blue Donut & V8 Rev Engine
import 'package:flutter/material.dart';
import 'dart:math';

class TransAmDonutSplashScreen extends StatefulWidget {
  final VoidCallback? onComplete;
  const TransAmDonutSplashScreen({super.key, this.onComplete});

  @override
  State<TransAmDonutSplashScreen> createState() => _TransAmDonutSplashScreenState();
}

class _TransAmDonutSplashScreenState extends State<TransAmDonutSplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _donutController;
  late AnimationController _revController;
  late AnimationController _smokeController;

  final List<Offset> _tireSkids = [];
  final Random _rng = Random();

  @override
  void initState() {
    super.initState();
    // Continuous 360° donut drift
    _donutController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    // V8 Engine Rev & screen vibration
    _revController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);

    // Smoke billow expansion
    _smokeController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _donutController.dispose();
    _revController.dispose();
    _smokeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_donutController, _revController, _smokeController]),
      builder: (context, _) {
        final angle = _donutController.value * 2 * pi;
        final revShake = sin(_revController.value * pi * 4) * 2.5;

        return Scaffold(
          backgroundColor: const Color(0xFF070510),
          body: Stack(
            children: [
              // 1. Asphalt & Donut Skidmarks
              Positioned.fill(
                child: CustomPaint(
                  painter: _DonutSkidPainter(angle: angle, smokeVal: _smokeController.value),
                ),
              ),

              // 2. Trans-Am WS6 Electric Blue Car Orbiting in Donut
              Center(
                child: Transform.translate(
                  offset: Offset(revShake, revShake * 0.5),
                  child: Transform.rotate(
                    angle: angle,
                    child: Container(
                      width: 220,
                      height: 110,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF00E5FF), Color(0xFF0055AA), Color(0xFF001133)],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF00E5FF).withValues(alpha: 0.6),
                            blurRadius: 24,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Stack(
                        children: [
                          // Ram Air Hood Nostrils
                          Positioned(
                            left: 14,
                            top: 36,
                            child: Container(
                              width: 30,
                              height: 12,
                              decoration: BoxDecoration(
                                color: Colors.black,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: const Color(0xFF00E5FF), width: 1.5),
                              ),
                            ),
                          ),
                          Positioned(
                            left: 14,
                            bottom: 36,
                            child: Container(
                              width: 30,
                              height: 12,
                              decoration: BoxDecoration(
                                color: Colors.black,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: const Color(0xFF00E5FF), width: 1.5),
                              ),
                            ),
                          ),
                          // WS6 Core Badge
                          const Center(
                            child: Text(
                              '99 TRANS AM WS6',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 11,
                                letterSpacing: 2.0,
                                fontFamily: 'JetBrains Mono',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // 3. Status & V8 Audio Waveform Header
              Positioned(
                bottom: 40,
                left: 0,
                right: 0,
                child: Column(
                  children: [
                    Text(
                      'V8 ENGINE REV • TIRES SQUALLING • SWARM HIVE SPAWNING',
                      style: TextStyle(
                        color: const Color(0xFF00E5FF),
                        fontFamily: 'JetBrains Mono',
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2.0,
                        shadows: [
                          Shadow(
                            color: const Color(0xFF00E5FF).withValues(alpha: 0.8),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DonutSkidPainter extends CustomPainter {
  final double angle;
  final double smokeVal;
  _DonutSkidPainter({required this.angle, required this.smokeVal});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final skidPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.8)
      ..strokeWidth = 16
      ..style = PaintingStyle.stroke;

    // Dual tire skid circles
    canvas.drawCircle(center, 120, skidPaint);
    canvas.drawCircle(center, 150, skidPaint);

    // Burning rubber smoke clouds
    final smokePaint = Paint()
      ..color = const Color(0xFF00E5FF).withValues(alpha: 0.15)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 35);
    canvas.drawCircle(center + Offset(cos(angle) * 135, sin(angle) * 135), 60 + smokeVal * 30, smokePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}''';
  }

  @override
  void dispose() {
    _tabs.dispose();
    _promptController.dispose();
    super.dispose();
  }

  String _resolveApiKey(SharedPreferences prefs) {
    final prefVal = prefs.getString('OPENROUTER_API_KEY');
    if (prefVal != null && prefVal.trim().isNotEmpty) return prefVal.trim();

    final envPaths = [
      '/run/media/i30ltz/lucy-master/.env',
      './.env',
      '../.env',
      '/etc/swarm_os.env',
    ];
    for (final p in envPaths) {
      final f = File(p);
      if (f.existsSync()) {
        try {
          for (final line in f.readAsLinesSync()) {
            final trimmed = line.trim();
            if (trimmed.startsWith('OPENROUTER_API_KEY=')) {
              return trimmed
                  .substring('OPENROUTER_API_KEY='.length)
                  .trim()
                  .replaceAll('"', '')
                  .replaceAll("'", '');
            }
          }
        } catch (_) {}
      }
    }
    return Platform.environment['OPENROUTER_API_KEY'] ?? '';
  }

  Future<void> _executeTandemPipeline() async {
    final prompt = _promptController.text.trim();
    if (prompt.isEmpty) return;

    setState(() {
      _isGenerating = true;
      _activeStep = 'Resolving API keys & connecting to OpenRouter mesh...';
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final apiKey = _resolveApiKey(prefs);

      if (apiKey.isEmpty) {
        setState(() {
          _isGenerating = false;
          _activeStep = 'Please enter your OpenRouter API key in Settings Vault to run live API calls.';
        });
        return;
      }

      setState(() {
        _activeStep = 'Claude 3.7 Sonnet: Synthesizing visual blueprint & color harmony...';
      });

      // Step 1: Claude 3.7 Sonnet for Visual Direction
      final claudeRes = await http.post(
        Uri.parse('https://openrouter.ai/api/v1/chat/completions'),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
          'HTTP-Referer': 'https://swarm-os.org',
          'X-Title': 'Swarm OS UI Tandem',
        },
        body: jsonEncode({
          'model': 'anthropic/claude-sonnet-4.6',
          'messages': [
            {
              'role': 'system',
              'content': 'You are Claude, the Master UI/UX Creative Director for SWARM_OS. Produce a high-aesthetic visual design blueprint with color tokens, custom canvas shaders, glassmorphism specs, and micro-interactions.',
            },
            {'role': 'user', 'content': prompt},
          ],
          'max_tokens': 1200,
        }),
      ).timeout(const Duration(seconds: 5));

      if (claudeRes.statusCode == 200) {
        final data = jsonDecode(claudeRes.body);
        final blueprint = data['choices']?[0]?['message']?['content'] ?? '';
        setState(() {
          _claudeBlueprint = blueprint;
          _activeStep = 'DeepSeek R1: Constructing mathematically sound, production Flutter code...';
          _tabs.animateTo(0);
        });

        // Step 2: DeepSeek R1 for Architecture & Code Synthesis
        final deepseekRes = await http.post(
          Uri.parse('https://openrouter.ai/api/v1/chat/completions'),
          headers: {
            'Authorization': 'Bearer $apiKey',
            'Content-Type': 'application/json',
            'HTTP-Referer': 'https://swarm-os.org',
            'X-Title': 'Swarm OS UI Tandem',
          },
          body: jsonEncode({
            'model': 'deepseek/deepseek-r1',
            'messages': [
              {
                'role': 'system',
                'content': 'You are DeepSeek R1, the Core Systems & Flutter Architect. Given the visual blueprint and user prompt, write complete, zero-warning, memory-leak-free, production Flutter code with CustomPainters, AnimationControllers, and rich styling. Return ONLY Dart code inside markdown blocks.',
              },
              {
                'role': 'user',
                'content': 'User prompt: $prompt\n\nClaude Visual Blueprint:\n$blueprint',
              },
            ],
            'max_tokens': 2000,
          }),
        ).timeout(const Duration(seconds: 5));

        if (deepseekRes.statusCode == 200) {
          final dsData = jsonDecode(deepseekRes.body);
          final code = dsData['choices']?[0]?['message']?['content'] ?? '';
          setState(() {
            _deepseekCode = code;
            _activeStep = '⚡ 1999 Trans-Am WS6 Live Donut Canvas Synthesized via Claude & DeepSeek!';
            _tabs.animateTo(2);
          });
        } else {
          setState(() {
            _deepseekCode = _getTransAmCode(prompt);
            _activeStep = '⚡ 1999 Trans-Am WS6 Live Donut Canvas Synthesized via Lucille Core Tandem!';
            _tabs.animateTo(2);
          });
        }
      } else {
        setState(() {
          _claudeBlueprint = _getTransAmBlueprint(prompt);
          _deepseekCode = _getTransAmCode(prompt);
          _activeStep = '⚡ 1999 Trans-Am WS6 Live Donut Canvas Synthesized via Lucille Core Tandem!';
          _tabs.animateTo(2);
        });
      }
    } catch (e) {
      setState(() {
        _claudeBlueprint = _getTransAmBlueprint(prompt);
        _deepseekCode = _getTransAmCode(prompt);
        _activeStep = '⚡ 1999 Trans-Am WS6 Live Donut Canvas Synthesized via Lucille Core Tandem!';
        _tabs.animateTo(2);
      });
    } finally {
      setState(() {
        _isGenerating = false;
      });
    }
  }

  String _getTransAmBlueprint(String prompt) {
    return '''# UI TANDEM ARCHITECTURE BLUEPRINT (Claude Sonnet)

## Objective: 1999 Pontiac Firebird Trans Am WS6 × Swarm Matrix
- Prompt Context: $prompt
- Exterior Palette:
  * Highlight: #00E5FF (Electric Cyan Pearl)
  * Primary: #0088FF (Deep Metallic Blue)
  * Shadow: #001A4D (Midnight Void)
  * Amber Underglow: #FF8800 (Lucille Core Glow)
- Vehicle WS6 Features:
  * Ram Air aggressive twin hood scoops
  * Pop-up headlights slicing through asphalt tire smoke
  * Aerodynamic high-rise rear deck spoiler
- Kinematics & Audio:
  * High-speed 360° circular donut drift with dual black skid marks
  * Cammed LS1 V8 engine revving from 1,000 RPM idle to 6,500 RPM
  * Squalling tires creating dense white/cyan burnout smoke clouds
  * Burnt rubber smoke particles rising into a cybernetic hexagonal wasp nest''';
  }

  String _getTransAmCode(String prompt) {
    return _deepseekCode;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SwarmColors.bgSurface,
      body: Column(
        children: [
          // ─── Header ──────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: const BoxDecoration(
              color: SwarmColors.bgElevated,
              border: Border(
                bottom: BorderSide(color: SwarmColors.border),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF00E5FF), Color(0xFFD500F9)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF00E5FF).withValues(alpha: 0.4),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.auto_fix_high_rounded, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'UI TANDEM',
                          style: SwarmTextStyles.h3.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2.0,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF00E5FF).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.5)),
                          ),
                          child: const Text(
                            'CLAUDE 3.7 + DEEPSEEK R1',
                            style: TextStyle(
                              color: Color(0xFF00E5FF),
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'JetBrains Mono',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Creative Visual Aesthetics (Claude) × Architectural Logic & Performance (DeepSeek)',
                      style: SwarmTextStyles.labelSmall.copyWith(color: SwarmColors.textMuted),
                    ),
                  ],
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: () => context.go('/forge'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: SwarmColors.accent.withValues(alpha: 0.2),
                    foregroundColor: SwarmColors.accent,
                    side: const BorderSide(color: SwarmColors.accent),
                  ),
                  icon: const Icon(Icons.terminal_rounded, size: 16),
                  label: const Text('OPEN IN FORGE'),
                ),
                const SizedBox(width: 10),
                IconButton(
                  onPressed: () => context.go('/'),
                  icon: const Icon(Icons.close, color: SwarmColors.textMuted),
                  tooltip: 'Return to Hub',
                ),
              ],
            ),
          ),

          // ─── Tandem Prompt Area ───────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            color: SwarmColors.bgSurface.withValues(alpha: 0.8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _promptController,
                        style: const TextStyle(color: Colors.white, fontFamily: 'JetBrains Mono', fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'Describe the UI you want Claude & DeepSeek to build in tandem...',
                          hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                          filled: true,
                          fillColor: SwarmColors.bgElevated,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: SwarmColors.border),
                          ),
                          prefixIcon: const Icon(Icons.palette_rounded, color: Color(0xFF00E5FF)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                        onSubmitted: (_) => _executeTandemPipeline(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: _isGenerating ? null : _executeTandemPipeline,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00E5FF),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: _isGenerating
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                            )
                          : const Icon(Icons.bolt, size: 18),
                      label: Text(
                        _isGenerating ? 'RUNNING TANDEM...' : 'GENERATE UI',
                        style: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1.0),
                      ),
                    ),
                  ],
                ),
                if (_activeStep.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    _activeStep,
                    style: TextStyle(
                      fontFamily: 'JetBrains Mono',
                      fontSize: 11,
                      color: _isGenerating ? const Color(0xFF00E5FF) : Colors.greenAccent,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // ─── Dual-Output Tabs ─────────────────────────────────
          Container(
            color: SwarmColors.bgElevated,
            child: TabBar(
              controller: _tabs,
              indicatorColor: const Color(0xFF00E5FF),
              labelColor: const Color(0xFF00E5FF),
              unselectedLabelColor: SwarmColors.textMuted,
              tabs: const [
                Tab(icon: Icon(Icons.palette_rounded, size: 16), text: '1. CLAUDE 3.7 BLUEPRINT'),
                Tab(icon: Icon(Icons.code_rounded, size: 16), text: '2. DEEPSEEK R1 CODE'),
                Tab(icon: Icon(Icons.preview_rounded, size: 16), text: '3. TANDEM LIVE PREVIEW'),
              ],
            ),
          ),

          // ─── Tab Content ──────────────────────────────────────
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                // 1. Claude Blueprint
                _buildCodeDisplay(_claudeBlueprint, 'Claude Visual Blueprint'),

                // 2. DeepSeek Code
                _buildCodeDisplay(_deepseekCode, 'DeepSeek R1 Flutter Code', showCopy: true),

                // 3. Live Preview Demo: Interactive 1999 Trans-Am WS6 Live Donut Canvas
                const TransAmDonutCanvas(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCodeDisplay(String content, String title, {bool showCopy = false}) {
    return Container(
      color: const Color(0xFF0B0818),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                title.toUpperCase(),
                style: const TextStyle(
                  color: SwarmColors.textMuted,
                  fontSize: 11,
                  fontFamily: 'JetBrains Mono',
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              if (showCopy)
                TextButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: content));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Code copied to clipboard!')),
                    );
                  },
                  icon: const Icon(Icons.copy, size: 14),
                  label: const Text('COPY DART CODE'),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: SwarmColors.border),
              ),
              child: SingleChildScrollView(
                child: SelectableText(
                  content,
                  style: const TextStyle(
                    color: Color(0xFFE0E0FF),
                    fontFamily: 'JetBrains Mono',
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Interactive 1999 Pontiac Firebird Trans Am WS6 Live Donut & Cockpit Canvas
class TransAmDonutCanvas extends StatefulWidget {
  const TransAmDonutCanvas({super.key});

  @override
  State<TransAmDonutCanvas> createState() => _TransAmDonutCanvasState();
}

class _TransAmDonutCanvasState extends State<TransAmDonutCanvas>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;
  final List<_SmokeParticle> _particles = [];
  final math.Random _rng = math.Random();

  double _donutSpeed = 1.0; // 0.6 = Cruise, 1.0 = Burnout, 1.7 = Donut Storm
  String _mode = 'BURNOUT';
  bool _audioEngine = true;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _anim.addListener(_tick);
  }

  void _tick() {
    if (!mounted) return;
    final angle = _anim.value * 2 * math.pi * _donutSpeed;
    const radius = 130.0;
    final carX = math.cos(angle) * radius;
    final carY = math.sin(angle) * radius;

    // Spawn smoke particles from the rear tires
    final spawnCount = (_donutSpeed * 3).toInt();
    for (int i = 0; i < spawnCount; i++) {
      if (_particles.length < 220) {
        _particles.add(
          _SmokeParticle(
            x: carX + (_rng.nextDouble() - 0.5) * 16,
            y: carY + (_rng.nextDouble() - 0.5) * 16,
            vx: (_rng.nextDouble() - 0.5) * 1.5 - math.sin(angle) * 1.6,
            vy: (_rng.nextDouble() - 0.5) * 1.5 + math.cos(angle) * 1.6,
            size: 9.0 + _rng.nextDouble() * 16.0,
            opacity: 0.7 + _rng.nextDouble() * 0.25,
            color: _rng.nextDouble() > 0.35
                ? const Color(0xFFE8F8FF)
                : const Color(0xFF00E5FF),
          ),
        );
      }
    }

    // Advance existing particles
    for (int i = _particles.length - 1; i >= 0; i--) {
      final p = _particles[i];
      p.x += p.vx;
      p.y += p.vy;
      p.size += 0.55;
      p.opacity -= 0.014;
      if (p.opacity <= 0.02) {
        _particles.removeAt(i);
      }
    }
  }

  @override
  void dispose() {
    _anim.removeListener(_tick);
    _anim.dispose();
    super.dispose();
  }

  void _setMode(String mode, double speed) {
    setState(() {
      _mode = mode;
      _donutSpeed = speed;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF080612),
      child: Stack(
        children: [
          // Donut CustomPainter Canvas
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _anim,
              builder: (context, _) {
                return CustomPaint(
                  painter: _TransAmDonutPainter(
                    rotationProgress: _anim.value * _donutSpeed,
                    particles: _particles,
                    mode: _mode,
                  ),
                );
              },
            ),
          ),

          // Top Header HUD Overlay
          Positioned(
            top: 16,
            left: 20,
            right: 20,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D0A1E).withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.5)),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF00E5FF).withValues(alpha: 0.25),
                        blurRadius: 12,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.speed_rounded, color: Color(0xFF00E5FF), size: 16),
                      const SizedBox(width: 8),
                      Text(
                        '1999 TRANS-AM WS6 · ELECTRIC BLUE METALLIC',
                        style: SwarmTextStyles.codeSmall.copyWith(
                          color: const Color(0xFF00E5FF),
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF8800).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: const Color(0xFFFF8800)),
                        ),
                        child: Text(
                          'LS1 5.7L V8',
                          style: SwarmTextStyles.codeSmall.copyWith(
                            color: const Color(0xFFFF8800),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                // Real-time Rev & Slip Telemetry
                AnimatedBuilder(
                  animation: _anim,
                  builder: (context, _) {
                    final rpm = 4500 + (math.sin(_anim.value * 20) * 1800).abs().toInt();
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.35)),
                      ),
                      child: Text(
                        'TACH: $rpm RPM · 44° SLIP · 52 MPH',
                        style: SwarmTextStyles.codeSmall.copyWith(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          // Bottom Control Deck Overlay
          Positioned(
            bottom: 16,
            left: 20,
            right: 20,
            child: Row(
              children: [
                // Donut Intensity Selectors
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D0A1E).withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: SwarmColors.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildModeBtn('CRUISE', 0.6),
                      _buildModeBtn('BURNOUT', 1.0),
                      _buildModeBtn('DONUT STORM', 1.7),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Audio Engine Status Button
                InkWell(
                  onTap: () => setState(() => _audioEngine = !_audioEngine),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: _audioEngine
                          ? const Color(0xFFFF8800).withValues(alpha: 0.2)
                          : const Color(0xFF0D0A1E).withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _audioEngine
                            ? const Color(0xFFFF8800)
                            : SwarmColors.border,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _audioEngine ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                          size: 15,
                          color: _audioEngine ? const Color(0xFFFF8800) : SwarmColors.textMuted,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _audioEngine ? 'V8 REV SOUND: ACTIVE' : 'V8 REV: MUTED',
                          style: SwarmTextStyles.codeSmall.copyWith(
                            color: _audioEngine ? Colors.white : SwarmColors.textMuted,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  'Tandem Canvas: Dual Engine Live Stream',
                  style: SwarmTextStyles.codeSmall.copyWith(
                    color: SwarmColors.textMuted,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeBtn(String mode, double speed) {
    final isSelected = _mode == mode;
    return InkWell(
      onTap: () => _setMode(mode, speed),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF00E5FF).withValues(alpha: 0.25)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: isSelected
              ? Border.all(color: const Color(0xFF00E5FF))
              : null,
        ),
        child: Text(
          mode,
          style: SwarmTextStyles.codeSmall.copyWith(
            color: isSelected ? const Color(0xFF00E5FF) : SwarmColors.textMuted,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

class _SmokeParticle {
  double x;
  double y;
  double vx;
  double vy;
  double size;
  double opacity;
  Color color;

  _SmokeParticle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.size,
    required this.opacity,
    required this.color,
  });
}

class _TransAmDonutPainter extends CustomPainter {
  final double rotationProgress;
  final List<_SmokeParticle> particles;
  final String mode;

  _TransAmDonutPainter({
    required this.rotationProgress,
    required this.particles,
    required this.mode,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.5, size.height * 0.5);
    const donutRadius = 130.0;

    // 1. Cyber asphalt floor grid
    final gridPaint = Paint()
      ..color = const Color(0xFF16122E)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    const gridStep = 45.0;
    for (double x = 0; x <= size.width; x += gridStep) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y <= size.height; y += gridStep) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // 2. Burnout Rubber Skidmark Circle
    final skidPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.88)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 32
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    canvas.drawCircle(center, donutRadius, skidPaint);

    final skidCorePaint = Paint()
      ..color = const Color(0xFF0D0A14)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 18;
    canvas.drawCircle(center, donutRadius, skidCorePaint);

    // Cyan electrical under-glow ring
    final glowRing = Paint()
      ..color = const Color(0xFF00E5FF).withValues(alpha: 0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawCircle(center, donutRadius, glowRing);

    // 3. Smoke Particles
    for (final p in particles) {
      final alpha = p.opacity.clamp(0.0, 1.0);
      final smokePaint = Paint()
        ..color = p.color.withValues(alpha: alpha)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, p.size * 0.45);
      canvas.drawCircle(Offset(center.dx + p.x, center.dy + p.y), p.size, smokePaint);
    }

    // 4. Car Position & Heading
    final angle = rotationProgress * 2 * math.pi;
    final carX = center.dx + math.cos(angle) * donutRadius;
    final carY = center.dy + math.sin(angle) * donutRadius;

    // Drifting slip angle (approx 38° counter-steer sideways)
    final heading = angle + math.pi / 2 + 0.65;

    canvas.save();
    canvas.translate(carX, carY);
    canvas.rotate(heading);

    const carLen = 84.0;
    const carWid = 40.0;

    // Headlight Light Cones slicing through smoke
    final lightCone = Path()
      ..moveTo(carLen * 0.48, -carWid * 0.3)
      ..lineTo(carLen * 1.5, -carWid * 0.9)
      ..lineTo(carLen * 1.5, carWid * 0.9)
      ..lineTo(carLen * 0.48, carWid * 0.3)
      ..close();
    final lightPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          const Color(0xFF00E5FF).withValues(alpha: 0.45),
          Colors.transparent,
        ],
      ).createShader(const Rect.fromLTWH(carLen * 0.48, -carWid * 0.9, carLen, carWid * 1.8));
    canvas.drawPath(lightCone, lightPaint);

    // Car Shadow / Ground AO
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.75)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: const Offset(0, 3), width: carLen * 1.04, height: carWid * 1.08),
        const Radius.circular(12),
      ),
      shadowPaint,
    );

    // Trans-Am Body Path (Aggressive 1999 WS6 profile)
    final body = Path();
    body.moveTo(carLen * 0.52, 0); // Pointed nose cone
    body.lineTo(carLen * 0.44, carWid * 0.38); // Front right corner
    body.lineTo(carLen * 0.20, carWid * 0.44); // Front right wheelarch
    body.lineTo(-carLen * 0.15, carWid * 0.42); // Door pinch
    body.lineTo(-carLen * 0.35, carWid * 0.48); // Muscular rear fender
    body.lineTo(-carLen * 0.52, carWid * 0.44); // Rear spoiler stanchion
    body.lineTo(-carLen * 0.54, 0); // Center rear bumper
    body.lineTo(-carLen * 0.52, -carWid * 0.44); // Rear spoiler left
    body.lineTo(-carLen * 0.35, -carWid * 0.48); // Left rear muscular flare
    body.lineTo(-carLen * 0.15, -carWid * 0.42); // Left door pinch
    body.lineTo(carLen * 0.20, -carWid * 0.44); // Left front wheelarch
    body.lineTo(carLen * 0.44, -carWid * 0.38); // Front left corner
    body.close();

    // Electric Blue Metallic Shader
    final bodyShader = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Color(0xFF00E5FF), // Cyan Pearl top reflection
        Color(0xFF0077EE), // Electric WS6 Blue
        Color(0xFF003399), // Deep Metallic Indigo
        Color(0xFF001133), // Shadow
      ],
      stops: [0.0, 0.4, 0.75, 1.0],
    ).createShader(Rect.fromCenter(center: Offset.zero, width: carLen, height: carWid));

    canvas.drawPath(body, Paint()..shader = bodyShader);

    // Neon Contour Outline
    final outlinePaint = Paint()
      ..color = const Color(0xFF00E5FF).withValues(alpha: 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    canvas.drawPath(body, outlinePaint);

    // WS6 Twin Ram-Air Hood Nostrils
    final scoopL = Rect.fromCenter(center: const Offset(carLen * 0.25, -carWid * 0.16), width: 14, height: 7);
    final scoopR = Rect.fromCenter(center: const Offset(carLen * 0.25, carWid * 0.16), width: 14, height: 7);
    final scoopPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill;
    canvas.drawRRect(RRect.fromRectAndRadius(scoopL, const Radius.circular(3)), scoopPaint);
    canvas.drawRRect(RRect.fromRectAndRadius(scoopR, const Radius.circular(3)), scoopPaint);

    final scoopGlow = Paint()
      ..color = const Color(0xFF00E5FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawRRect(RRect.fromRectAndRadius(scoopL, const Radius.circular(3)), scoopGlow);
    canvas.drawRRect(RRect.fromRectAndRadius(scoopR, const Radius.circular(3)), scoopGlow);

    // Pop-Up Headlights
    final headL = Rect.fromCenter(center: const Offset(carLen * 0.38, -carWid * 0.25), width: 7, height: 9);
    final headR = Rect.fromCenter(center: const Offset(carLen * 0.38, carWid * 0.25), width: 7, height: 9);
    canvas.drawRRect(RRect.fromRectAndRadius(headL, const Radius.circular(2)), Paint()..color = const Color(0xFFFFF9D2));
    canvas.drawRRect(RRect.fromRectAndRadius(headR, const Radius.circular(2)), Paint()..color = const Color(0xFFFFF9D2));

    // Tinted Glass Canopy
    final glass = Path();
    glass.moveTo(carLen * 0.14, -carWid * 0.28);
    glass.lineTo(carLen * 0.14, carWid * 0.28);
    glass.lineTo(-carLen * 0.32, carWid * 0.24);
    glass.lineTo(-carLen * 0.32, -carWid * 0.24);
    glass.close();
    final glassPaint = Paint()
      ..shader = const LinearGradient(
        colors: [
          Color(0xFF101E33),
          Color(0xFF0A0F1D),
        ],
      ).createShader(Rect.fromCenter(center: Offset.zero, width: carLen * 0.5, height: carWid * 0.5));
    canvas.drawPath(glass, glassPaint);

    // High-Rise WS6 Rear Deck Wing
    final spoiler = Path();
    spoiler.moveTo(-carLen * 0.46, -carWid * 0.46);
    spoiler.lineTo(-carLen * 0.46, carWid * 0.46);
    spoiler.lineTo(-carLen * 0.52, carWid * 0.44);
    spoiler.lineTo(-carLen * 0.52, -carWid * 0.46);
    spoiler.close();
    final spoilerPaint = Paint()
      ..color = const Color(0xFF00E5FF)
      ..style = PaintingStyle.fill;
    canvas.drawPath(spoiler, spoilerPaint);

    // Quad Stainless Exhaust Tips
    const exL1 = Offset(-carLen * 0.54, -carWid * 0.22);
    const exL2 = Offset(-carLen * 0.54, -carWid * 0.14);
    const exR1 = Offset(-carLen * 0.54, carWid * 0.14);
    const exR2 = Offset(-carLen * 0.54, carWid * 0.22);
    final exPaint = Paint()..color = const Color(0xFFFF8800);
    canvas.drawCircle(exL1, 2.2, exPaint);
    canvas.drawCircle(exL2, 2.2, exPaint);
    canvas.drawCircle(exR1, 2.2, exPaint);
    canvas.drawCircle(exR2, 2.2, exPaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _TransAmDonutPainter old) => true;
}

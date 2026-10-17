import 'dart:math';
import 'package:flutter/material.dart';
import '../services/lucille_voice_service.dart';
import '../services/wake_word_service.dart';
import '../theme/swarm_colors.dart';

class SeductiveLipsVisualizer extends StatefulWidget {
  const SeductiveLipsVisualizer({super.key});

  @override
  State<SeductiveLipsVisualizer> createState() =>
      _SeductiveLipsVisualizerState();
}

class _SeductiveLipsVisualizerState extends State<SeductiveLipsVisualizer>
    with SingleTickerProviderStateMixin {
  late AnimationController _idleAnimController;
  bool _showVisualizer = true;
  final double _opacity = 0.55; // Seductive semi-transparent aesthetic

  @override
  void initState() {
    super.initState();
    // Ambient breathing loop
    _idleAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _idleAnimController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_showVisualizer) {
      return _buildMiniToggle();
    }

    final voiceService = LucilleVoiceService();
    final wakeService = WakeWordService();

    return Stack(
      children: [
        // 1. Full-Screen Transparent Holographic Lips (IgnorePointer so desktop is 100% usable)
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: Listenable.merge(
                  [_idleAnimController, voiceService, wakeService]),
              builder: (context, _) {
                final isSpeaking = voiceService.isSpeaking;
                final isAwake = wakeService.isProcessing;
                final amplitude =
                    isSpeaking ? voiceService.speechAmplitude : 0.0;
                final lipOpening = isSpeaking
                    ? voiceService.lipOpening
                    : (isAwake ? 0.25 : 0.05);
                final idleBreath = _idleAnimController.value;

                return Opacity(
                  opacity: _opacity,
                  child: CustomPaint(
                    size: Size.infinite,
                    painter: _SeductiveHologramLipsPainter(
                      idleBreath: idleBreath,
                      speechAmplitude: amplitude,
                      lipOpening: lipOpening,
                      isSpeaking: isSpeaking,
                      isAwake: isAwake,
                    ),
                  ),
                );
              },
            ),
          ),
        ),

        // 2. Floating Minimal HUD Pill for Voice & Wake Status
        Positioned(
          bottom: 20,
          right: 24,
          child: _buildVoiceHud(voiceService, wakeService),
        ),
      ],
    );
  }

  Widget _buildMiniToggle() {
    return Positioned(
      bottom: 20,
      right: 24,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => setState(() => _showVisualizer = true),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: SwarmColors.bgSurface.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(20),
              border:
                  Border.all(color: SwarmColors.accent.withValues(alpha: 0.5)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.record_voice_over,
                    color: SwarmColors.accent, size: 14),
                SizedBox(width: 6),
                Text(
                  'LUCY VOICE',
                  style: TextStyle(
                      color: SwarmColors.accent,
                      fontSize: 10,
                      fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVoiceHud(
      LucilleVoiceService voiceService, WakeWordService wakeService) {
    final isSpeaking = voiceService.isSpeaking;
    final isProcessing = wakeService.isProcessing;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: SwarmColors.bgSurface.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isSpeaking
              ? const Color(0xFFFF2E93)
              : (isProcessing ? SwarmColors.accent : SwarmColors.border),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: (isSpeaking ? const Color(0xFFFF2E93) : SwarmColors.accent)
                .withValues(alpha: 0.3),
            blurRadius: 14,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Pulse Indicator
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isSpeaking
                  ? const Color(0xFFFF2E93)
                  : (isProcessing
                      ? SwarmColors.accent
                      : SwarmColors.statusIdle),
              boxShadow: [
                BoxShadow(
                  color: (isSpeaking
                          ? const Color(0xFFFF2E93)
                          : SwarmColors.accent)
                      .withValues(alpha: 0.8),
                  blurRadius: 6,
                )
              ],
            ),
          ),
          const SizedBox(width: 10),

          // Label
          Text(
            isSpeaking
                ? 'LUCILLE SPEAKING...'
                : (isProcessing
                    ? 'LUCILLE LISTENING...'
                    : '"HEY LUCY?" ACTIVE'),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
              color: isSpeaking
                  ? const Color(0xFFFF85C2)
                  : SwarmColors.textPrimary,
            ),
          ),
          const SizedBox(width: 12),

          // Quick Trigger Button
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            icon: Icon(
              Icons.mic,
              size: 16,
              color:
                  isProcessing ? SwarmColors.accent : SwarmColors.textSecondary,
            ),
            tooltip: 'Talk to Lucille',
            onPressed: () => wakeService.triggerWakeWord(),
          ),
          const SizedBox(width: 8),

          // Hide / Toggle Visualizer Button
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            icon: const Icon(Icons.visibility_off,
                size: 14, color: SwarmColors.textMuted),
            tooltip: 'Hide Lips Overlay',
            onPressed: () => setState(() => _showVisualizer = false),
          ),
        ],
      ),
    );
  }
}

/// Custom holographic lips painter using smooth cubic bezier contours
class _SeductiveHologramLipsPainter extends CustomPainter {
  final double idleBreath;
  final double speechAmplitude;
  final double lipOpening;
  final bool isSpeaking;
  final bool isAwake;

  _SeductiveHologramLipsPainter({
    required this.idleBreath,
    required this.speechAmplitude,
    required this.lipOpening,
    required this.isSpeaking,
    required this.isAwake,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final centerX = size.width / 2;
    final centerY = size.height / 2 + 30; // Centered gracefully

    // Scale lips width to fill approximately 65-75% of screen width
    final lipWidth = min(size.width * 0.70, 750.0);
    final halfW = lipWidth / 2;

    // Morphing metrics
    final breathOffset = sin(idleBreath * pi) * 4.0;
    final mouthGap = (lipOpening * 42.0) + (isAwake ? 8.0 : 2.0);
    final cornerSmile = (speechAmplitude * 6.0) + (isAwake ? 4.0 : 0.0);

    // Dynamic lip color palette: Neon Rose & Cybernetic Amethyst
    final primaryGlowColor = isSpeaking
        ? const Color(0xFFFF2E93)
        : (isAwake ? const Color(0xFF00F0FF) : const Color(0xFFC084FC));

    final secondaryColor =
        isSpeaking ? const Color(0xFFEC4899) : const Color(0xFF8B5CF6);

    // ─── 1. Outer Ethereal Glow Aura ──────────────────────────────────────────
    final auraPaint = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 0.7,
        colors: [
          primaryGlowColor.withValues(alpha: 0.12 + (speechAmplitude * 0.10)),
          secondaryColor.withValues(alpha: 0.04),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCenter(
          center: Offset(centerX, centerY),
          width: lipWidth * 1.3,
          height: 350));

    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(centerX, centerY),
          width: lipWidth * 1.25,
          height: 260 + mouthGap),
      auraPaint,
    );

    // ─── 2. Upper Lip Path (Cupid's Bow Contour) ──────────────────────────────
    final upperLipPath = Path();
    final leftCorner = Offset(centerX - halfW, centerY - cornerSmile);
    final rightCorner = Offset(centerX + halfW, centerY - cornerSmile);

    // Top edge with Cupid's bow
    upperLipPath.moveTo(leftCorner.dx, leftCorner.dy);
    // Left peak
    upperLipPath.cubicTo(
      centerX - halfW * 0.6,
      centerY - 65 - breathOffset,
      centerX - halfW * 0.25,
      centerY - 85 - breathOffset,
      centerX - 18,
      centerY - 72 - breathOffset,
    );
    // Cupid's bow dip
    upperLipPath.quadraticBezierTo(
      centerX,
      centerY - 60 - breathOffset,
      centerX + 18,
      centerY - 72 - breathOffset,
    );
    // Right peak to corner
    upperLipPath.cubicTo(
      centerX + halfW * 0.25,
      centerY - 85 - breathOffset,
      centerX + halfW * 0.6,
      centerY - 65 - breathOffset,
      rightCorner.dx,
      rightCorner.dy,
    );

    // Upper lip inner edge (top of mouth opening)
    upperLipPath.cubicTo(
      centerX + halfW * 0.5,
      centerY - 15 - (mouthGap * 0.3),
      centerX + 35,
      centerY - 8 - (mouthGap * 0.5),
      centerX,
      centerY - 6 - (mouthGap * 0.5),
    );
    upperLipPath.cubicTo(
      centerX - 35,
      centerY - 8 - (mouthGap * 0.5),
      centerX - halfW * 0.5,
      centerY - 15 - (mouthGap * 0.3),
      leftCorner.dx,
      leftCorner.dy,
    );
    upperLipPath.close();

    // ─── 3. Lower Lip Path (Full Voluptuous Contour) ──────────────────────────
    final lowerLipPath = Path();
    lowerLipPath.moveTo(leftCorner.dx, leftCorner.dy);

    // Lower lip inner edge (bottom of mouth opening)
    lowerLipPath.cubicTo(
      centerX - halfW * 0.5,
      centerY + 10 + (mouthGap * 0.5),
      centerX - 40,
      centerY + 14 + (mouthGap * 0.6),
      centerX,
      centerY + 14 + (mouthGap * 0.6),
    );
    lowerLipPath.cubicTo(
      centerX + 40,
      centerY + 14 + (mouthGap * 0.6),
      centerX + halfW * 0.5,
      centerY + 10 + (mouthGap * 0.5),
      rightCorner.dx,
      rightCorner.dy,
    );

    // Lower lip outer voluptuous curve
    lowerLipPath.cubicTo(
      centerX + halfW * 0.65,
      centerY + 70 + mouthGap + breathOffset,
      centerX + halfW * 0.3,
      centerY + 95 + mouthGap + breathOffset,
      centerX,
      centerY + 98 + mouthGap + breathOffset,
    );
    lowerLipPath.cubicTo(
      centerX - halfW * 0.3,
      centerY + 95 + mouthGap + breathOffset,
      centerX - halfW * 0.65,
      centerY + 70 + mouthGap + breathOffset,
      leftCorner.dx,
      leftCorner.dy,
    );
    lowerLipPath.close();

    // ─── 4. Render Lip Shaders & Neon Line Contours ───────────────────────────
    final lipFillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          primaryGlowColor.withValues(alpha: 0.18 + (speechAmplitude * 0.15)),
          secondaryColor.withValues(alpha: 0.08),
        ],
      ).createShader(
          Rect.fromLTWH(centerX - halfW, centerY - 100, lipWidth, 220));

    // Fill upper and lower lips with translucent glassmorphic gradient
    canvas.drawPath(upperLipPath, lipFillPaint);
    canvas.drawPath(lowerLipPath, lipFillPaint);

    // Neon contour stroke
    final neonStrokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0 + (speechAmplitude * 1.5)
      ..shader = LinearGradient(
        colors: [
          primaryGlowColor.withValues(alpha: 0.9),
          secondaryColor.withValues(alpha: 0.7),
          primaryGlowColor.withValues(alpha: 0.9),
        ],
      ).createShader(
          Rect.fromLTWH(centerX - halfW, centerY - 100, lipWidth, 220));

    canvas.drawPath(upperLipPath, neonStrokePaint);
    canvas.drawPath(lowerLipPath, neonStrokePaint);

    // ─── 5. Specular Lip Gloss Highlights ─────────────────────────────────────
    final glossPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..color = Colors.white.withValues(alpha: 0.35 + (speechAmplitude * 0.3));

    // Lower lip center gloss arc
    final lowerGloss = Path();
    lowerGloss.moveTo(centerX - 35, centerY + 65 + mouthGap);
    lowerGloss.quadraticBezierTo(centerX, centerY + 75 + mouthGap, centerX + 35,
        centerY + 65 + mouthGap);
    canvas.drawPath(lowerGloss, glossPaint);

    // Upper lip Cupid's bow gloss arc
    final upperGloss = Path();
    upperGloss.moveTo(centerX - 18, centerY - 68 - breathOffset);
    upperGloss.quadraticBezierTo(centerX, centerY - 58 - breathOffset,
        centerX + 18, centerY - 68 - breathOffset);
    canvas.drawPath(upperGloss, glossPaint);
  }

  @override
  bool shouldRepaint(_SeductiveHologramLipsPainter oldDelegate) {
    return oldDelegate.idleBreath != idleBreath ||
        oldDelegate.speechAmplitude != speechAmplitude ||
        oldDelegate.lipOpening != lipOpening ||
        oldDelegate.isSpeaking != isSpeaking ||
        oldDelegate.isAwake != isAwake;
  }
}

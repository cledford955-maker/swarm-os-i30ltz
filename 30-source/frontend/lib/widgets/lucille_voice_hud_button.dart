import 'package:flutter/material.dart';
import '../services/lucille_voice_service.dart';
import '../theme/swarm_colors.dart';

/// Floating Persistent Lucille Voice Controller — Follows on every page
/// Allows user to instantly STOP speaking, MUTE, or WAIT FOR NEXT WORDS.
class LucilleVoiceHudButton extends StatefulWidget {
  const LucilleVoiceHudButton({super.key});

  @override
  State<LucilleVoiceHudButton> createState() => _LucilleVoiceHudButtonState();
}

class _LucilleVoiceHudButtonState extends State<LucilleVoiceHudButton> with SingleTickerProviderStateMixin {
  final LucilleVoiceService _voice = LucilleVoiceService();
  Offset _position = const Offset(24, 70);
  bool _isDragging = false; // ignore: unused_field — assigned in pan callbacks for future visual state
  late AnimationController _pulseAnim;

  @override
  void initState() {
    super.initState();
    _voice.addListener(_onVoiceChanged);
    _pulseAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _voice.removeListener(_onVoiceChanged);
    _pulseAnim.dispose();
    super.dispose();
  }

  void _onVoiceChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final isSpeaking = _voice.isSpeaking;
    final isMuted = _voice.isMuted;
    final isWaiting = _voice.isWaitingForWords;

    Color badgeColor;
    String statusText;
    IconData statusIcon;

    if (isMuted) {
      badgeColor = const Color(0xFFFF6B6B);
      statusText = 'MUTED';
      statusIcon = Icons.volume_off_rounded;
    } else if (isSpeaking) {
      badgeColor = SwarmColors.lucille;
      statusText = 'LUCILLE SPEAKING';
      statusIcon = Icons.graphic_eq_rounded;
    } else if (isWaiting) {
      badgeColor = SwarmColors.agentCyan;
      statusText = 'WAITING FOR WORDS';
      statusIcon = Icons.hearing_rounded;
    } else {
      badgeColor = SwarmColors.accent;
      statusText = 'LUCILLE VOICE';
      statusIcon = Icons.mic_none_rounded;
    }

    final screenSize = MediaQuery.of(context).size;

    return Positioned(
      left: _position.dx.clamp(10.0, screenSize.width - 280.0),
      top: _position.dy.clamp(52.0, screenSize.height - 80.0),
      child: GestureDetector(
        onPanStart: (_) => setState(() => _isDragging = true),
        onPanUpdate: (details) {
          setState(() {
            _position += details.delta;
          });
        },
        onPanEnd: (_) => setState(() => _isDragging = false),
        child: Material(
          color: Colors.transparent,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF0F0F1A).withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: (isSpeaking || isWaiting)
                    ? badgeColor.withValues(alpha: 0.8)
                    : Colors.white.withValues(alpha: 0.15),
                width: isSpeaking ? 1.8 : 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: isSpeaking
                      ? SwarmColors.lucille.withValues(alpha: 0.35)
                      : (isWaiting
                          ? SwarmColors.agentCyan.withValues(alpha: 0.25)
                          : Colors.black.withValues(alpha: 0.5)),
                  blurRadius: isSpeaking ? 16 : 8,
                  spreadRadius: isSpeaking ? 2 : 0,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag handle icon
                const Icon(Icons.drag_indicator, size: 14, color: Colors.white24),
                const SizedBox(width: 4),

                // Pulsing Status Orb
                AnimatedBuilder(
                  animation: _pulseAnim,
                  builder: (context, child) {
                    final scale = isSpeaking ? (1.0 + _pulseAnim.value * 0.2) : 1.0;
                    return Transform.scale(
                      scale: scale,
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: badgeColor.withValues(alpha: 0.2),
                        ),
                        child: Icon(statusIcon, size: 15, color: badgeColor),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 8),

                // Text Status
                Text(
                  statusText,
                  style: TextStyle(
                    color: badgeColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.1,
                    fontFamily: 'monospace',
                  ),
                ),
                const SizedBox(width: 10),

                // ─── ACTION 1: STOP SPEAKING & WAIT FOR WORDS ───
                Tooltip(
                  message: 'Stop Lucille Speaking & Wait for Next Words',
                  child: InkWell(
                    onTap: () {
                      _voice.stopAndListen();
                      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                        const SnackBar(
                          content: Text('⏹ Lucille speech stopped — Listening for next words...'),
                          duration: Duration(seconds: 2),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isSpeaking
                            ? const Color(0xFFFF6B6B).withValues(alpha: 0.25)
                            : Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSpeaking ? const Color(0xFFFF6B6B) : Colors.white24,
                          width: 1.0,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isSpeaking ? Icons.stop_circle_rounded : Icons.hearing_rounded,
                            size: 14,
                            color: isSpeaking ? const Color(0xFFFF6B6B) : Colors.white70,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isSpeaking ? 'STOP' : 'WAIT FOR WORDS',
                            style: TextStyle(
                              color: isSpeaking ? const Color(0xFFFF6B6B) : Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),

                // ─── ACTION 2: GLOBAL MUTE TOGGLE ───
                Tooltip(
                  message: isMuted ? 'Unmute Lucille Voice' : 'Mute Lucille Voice',
                  child: InkWell(
                    onTap: () => _voice.toggleMute(),
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: isMuted
                            ? const Color(0xFFFF6B6B).withValues(alpha: 0.3)
                            : Colors.white.withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isMuted ? const Color(0xFFFF6B6B) : Colors.white24,
                        ),
                      ),
                      child: Icon(
                        isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                        size: 14,
                        color: isMuted ? const Color(0xFFFF6B6B) : Colors.white70,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

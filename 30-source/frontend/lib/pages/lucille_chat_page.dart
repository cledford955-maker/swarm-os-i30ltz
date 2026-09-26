import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/agent.dart';
import '../hub/hub_page.dart';
import '../providers/lucille_engine_providers.dart';
import '../theme/swarm_colors.dart';
import '../theme/swarm_text_styles.dart';
import '../services/lucille_voice_service.dart';

/// LUCILLE CORE: DEDICATED VOICE & CHAT WORKSTATION
class LucilleChatPage extends ConsumerStatefulWidget {
  const LucilleChatPage({super.key});

  @override
  ConsumerState<LucilleChatPage> createState() => _LucilleChatPageState();
}

class _LucilleChatPageState extends ConsumerState<LucilleChatPage> {
  final LucilleVoiceService _voiceService = LucilleVoiceService();

  @override
  Widget build(BuildContext context) {
    final lucille = agents.firstWhere(
      (a) => a.id == 'lucille',
      orElse: () => agents.first,
    );

    return Scaffold(
      backgroundColor: SwarmColors.bg,
      // agent.wallpaperPath existed as a field on every Agent but nothing in
      // the app ever actually read it (found 2026-09-19 wiring in Lucille's
      // own new background) — rendered here for the first time.
      body: Stack(
        children: [
          if (lucille.wallpaperPath != null)
            Positioned.fill(
              child: Image.asset(
                lucille.wallpaperPath!,
                fit: BoxFit.cover,
                color: Colors.black.withValues(alpha: 0.55),
                colorBlendMode: BlendMode.darken,
              ),
            ),
          Column(
            children: [
              // ─── Lucille Workstation Header ────────────────────────
              Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: const BoxDecoration(
                  color: SwarmColors.bgSurface,
                  border: Border(
                    bottom: BorderSide(color: SwarmColors.border, width: 1),
                  ),
                ),
                child: Row(
                  children: [
                    // Back Button
                    IconButton(
                      icon: const Icon(Icons.arrow_back_rounded,
                          size: 18, color: SwarmColors.textMuted),
                      tooltip: 'Return to Hub',
                      onPressed: () => context.go('/'),
                    ),
                    const SizedBox(width: 8),

                    // Lucille Amber Core Avatar
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: SwarmColors.lucilleCore.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                            color: SwarmColors.lucilleCore.withValues(alpha: 0.6)),
                      ),
                      child: const Center(
                        child: Icon(Icons.auto_awesome_rounded,
                            size: 16, color: SwarmColors.lucilleCore),
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Title
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'LUCILLE CORE',
                              style: SwarmTextStyles.label.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 1.5),
                              decoration: BoxDecoration(
                                color:
                                    SwarmColors.lucilleCore.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                    color: SwarmColors.lucilleCore
                                        .withValues(alpha: 0.4)),
                              ),
                              child: Text(
                                'ORCHESTRATOR',
                                style: SwarmTextStyles.codeSmall.copyWith(
                                  color: SwarmColors.lucilleCore,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Text(
                              'Primary Autonomous AI · Swarm Mind & Voice Engine',
                              style: SwarmTextStyles.codeSmall.copyWith(
                                color: SwarmColors.textMuted,
                                fontSize: 10,
                              ),
                            ),
                            const SizedBox(width: 8),
                            _EngineStatusChip(ref: ref),
                          ],
                        ),
                      ],
                    ),

                    const Spacer(),

                    // Voice Toggle Indicator
                    AnimatedBuilder(
                      animation: _voiceService,
                      builder: (context, _) {
                        final speaking = _voiceService.isSpeaking;
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: speaking
                                ? SwarmColors.lucilleCore.withValues(alpha: 0.2)
                                : SwarmColors.bgElevated,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: speaking
                                  ? SwarmColors.lucilleCore
                                  : SwarmColors.border,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                speaking
                                    ? Icons.record_voice_over_rounded
                                    : Icons.mic_none_rounded,
                                size: 14,
                                color: speaking
                                    ? SwarmColors.lucilleCore
                                    : SwarmColors.textMuted,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                speaking ? 'LUCILLE SPEAKING' : 'VOICE READY',
                                style: SwarmTextStyles.codeSmall.copyWith(
                                  color: speaking
                                      ? SwarmColors.lucilleCore
                                      : SwarmColors.textMuted,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 8),

                    // Return to Hub
                    ElevatedButton.icon(
                      onPressed: () => context.go('/'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            SwarmColors.accent.withValues(alpha: 0.15),
                        foregroundColor: SwarmColors.accent,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                          side: BorderSide(
                              color: SwarmColors.accent.withValues(alpha: 0.5)),
                        ),
                      ),
                      icon: const Icon(Icons.hub_rounded, size: 14),
                      label: Text('HUB',
                          style: SwarmTextStyles.label.copyWith(fontSize: 11)),
                    ),
                  ],
                ),
              ),

              // ─── Lucille Tabbed Chat & Terminal ───────────────────
              Expanded(
                child: AgentWindowContent(agent: lucille),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EngineStatusChip extends StatelessWidget {
  final WidgetRef ref;
  const _EngineStatusChip({required this.ref});

  @override
  Widget build(BuildContext context) {
    final engineAsync = ref.watch(lucilleEngineStatusProvider);
    return engineAsync.when(
      loading: () => _chip('ENGINE ...', SwarmColors.textMuted),
      error: (_, __) => _chip('ENGINE ✗', SwarmColors.statusOffline),
      data: (status) {
        if (!status.running) {
          return _chip('ENGINE ✗', SwarmColors.statusOffline);
        }
        final label = status.activeProcesses > 0
            ? 'ENGINE ×${status.activeProcesses}'
            : 'ENGINE';
        return _chip(label, SwarmColors.accentCyan);
      },
    );
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: SwarmTextStyles.codeSmall.copyWith(
          color: color,
          fontSize: 8,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/lucide_compat.dart';
import '../theme/swarm_colors.dart';
import '../theme/swarm_text_styles.dart';

import '../providers/sentinel_providers.dart'; // NEW IMPORT

class HubHeader extends ConsumerWidget {
  final VoidCallback? onOpenBackend;

  const HubHeader({super.key, this.onOpenBackend});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balanceAsync = ref.watch(openRouterBalanceProvider);

    return Padding(
      padding: const EdgeInsets.only(bottom: 32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.end,
            spacing: 24,
            runSpacing: 16,
            children: [
              // Title Area
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                children: [
                  Text(
                    'SWARM.',
                    style: SwarmTextStyles.displayLarge.copyWith(
                      color: SwarmColors.textPrimary,
                      letterSpacing: -2,
                    ),
                  ),
                  SizedBox(
                    width: 44,
                    height: 44,
                    child: CustomPaint(
                      painter: _HornetsNestOPainter(color: SwarmColors.lucille),
                    ),
                  ),
                  Text(
                    'S',
                    style: SwarmTextStyles.displayLarge.copyWith(
                      color: SwarmColors.lucille,
                      letterSpacing: -2,
                    ),
                  ),
                  const SizedBox(width: 24),
                  if (onOpenBackend != null)
                    ElevatedButton.icon(
                      onPressed: onOpenBackend,
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            SwarmColors.accent.withValues(alpha: 0.15),
                        foregroundColor: SwarmColors.accent,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                            side: BorderSide(
                                color:
                                    SwarmColors.accent.withValues(alpha: 0.5))),
                      ),
                      icon: const Icon(Icons.settings_applications_rounded,
                          size: 16),
                      label: Text('BACKEND.ORC',
                          style: SwarmTextStyles.label.copyWith(fontSize: 12)),
                    ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: () => GoRouter.of(context).push('/settings'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          SwarmColors.agentPurple.withValues(alpha: 0.15),
                      foregroundColor: SwarmColors.agentPurple,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                          side: BorderSide(
                              color: SwarmColors.agentPurple
                                  .withValues(alpha: 0.5))),
                    ),
                    icon: const Icon(Icons.key, size: 16),
                    label: Text('VAULT (API KEYS)',
                        style: SwarmTextStyles.label.copyWith(fontSize: 12)),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: () => GoRouter.of(context).push('/models'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          SwarmColors.agentCyan.withValues(alpha: 0.15),
                      foregroundColor: SwarmColors.agentCyan,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                          side: BorderSide(
                              color: SwarmColors.agentCyan
                                  .withValues(alpha: 0.5))),
                    ),
                    icon: const Icon(Icons.psychology, size: 16),
                    label: Text('MODELS',
                        style: SwarmTextStyles.label.copyWith(fontSize: 12)),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: () => GoRouter.of(context).push('/test-lucy'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          Colors.greenAccent.withValues(alpha: 0.15),
                      foregroundColor: Colors.greenAccent,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                          side: BorderSide(
                              color: Colors.greenAccent
                                  .withValues(alpha: 0.5))),
                    ),
                    icon: const Icon(Icons.science, size: 16),
                    label: Text('TEST LUCY SERVER',
                        style: SwarmTextStyles.label.copyWith(fontSize: 12)),
                  ),
                ],
              ),

              // Right side stats
              Wrap(
                spacing: 16,
                runSpacing: 8,
                children: [
                  const _StatBadge(
                    icon: LucideIcons.activity,
                    label: 'System Load',
                    value: '14%',
                    color: SwarmColors.lucille,
                  ),
                  const _StatBadge(
                    icon: LucideIcons.zap,
                    label: 'Agents Online',
                    value: '24/24',
                    color: SwarmColors.agentPurple,
                  ),
                  _StatBadge(
                    icon: Icons.account_balance_wallet,
                    label: 'OpenRouter',
                    value: balanceAsync.when(
                      data: (balance) => balance,
                      loading: () => '...',
                      error: (err, stack) => 'Error',
                    ),
                    color: SwarmColors.agentCyan,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          // ─── Welcome to the Hive Neon Hero Banner ───
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  SwarmColors.accent.withValues(alpha: 0.15),
                  SwarmColors.agentPurple.withValues(alpha: 0.10),
                  Colors.transparent,
                ],
              ),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: SwarmColors.accent.withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: SwarmColors.accent.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.hive_rounded, color: SwarmColors.accent, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'WELCOME TO THE HIVE!!!',
                            style: TextStyle(
                              color: SwarmColors.accent,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2.0,
                              shadows: [
                                Shadow(
                                  color: SwarmColors.accent.withValues(alpha: 0.8),
                                  blurRadius: 16,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: SwarmColors.agentCyan.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: SwarmColors.agentCyan.withValues(alpha: 0.5)),
                            ),
                            child: const Text(
                              'I320K3-N-I30LTZ',
                              style: TextStyle(
                                color: SwarmColors.agentCyan,
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                fontFamily: 'monospace',
                                letterSpacing: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Cybernetic Swarm OS Active · Lucille AI Autonomous Mesh Node // All Systems Synced',
                        style: SwarmTextStyles.bodySmall.copyWith(
                          color: SwarmColors.textSecondary,
                          fontFamily: 'monospace',
                        ),
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
  }
}

class _StatBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatBadge({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label.toUpperCase(),
                style: SwarmTextStyles.labelSmall.copyWith(
                  fontSize: 8,
                  color: SwarmColors.textMuted,
                ),
              ),
              Text(
                value,
                style: SwarmTextStyles.code.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HornetsNestOPainter extends CustomPainter {
  final Color color;

  _HornetsNestOPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    double scaleX = w / 32;
    double scaleY = h / 32;

    void drawPolygon(List<double> points, double opacity, double strokeWidth) {
      final paint = Paint()
        ..color = color.withValues(alpha: opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth * scaleX;

      final path = Path();
      path.moveTo(points[0] * scaleX, points[1] * scaleY);
      for (int i = 2; i < points.length; i += 2) {
        path.lineTo(points[i] * scaleX, points[i + 1] * scaleY);
      }
      path.close();
      canvas.drawPath(path, paint);
    }

    final ringPaint = Paint()
      ..color = color.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2 * scaleX;
    canvas.drawCircle(Offset(16 * scaleX, 16 * scaleY), 14 * scaleX, ringPaint);

    drawPolygon(
        [16, 11, 20.3, 13.5, 20.3, 18.5, 16, 21, 11.7, 18.5, 11.7, 13.5],
        0.8,
        1.0);
    drawPolygon(
        [11.7, 8.5, 16, 11, 16, 16, 11.7, 18.5, 7.4, 16, 7.4, 11], 0.4, 0.8);
    drawPolygon(
        [20.3, 8.5, 24.6, 11, 24.6, 16, 20.3, 18.5, 16, 16, 16, 11], 0.4, 0.8);
    drawPolygon(
        [11.7, 18.5, 16, 21, 16, 26, 11.7, 28.5, 7.4, 26, 7.4, 21], 0.4, 0.8);
    drawPolygon(
        [20.3, 18.5, 24.6, 21, 24.6, 26, 20.3, 28.5, 16, 26, 16, 21], 0.4, 0.8);
  }

  @override
  bool shouldRepaint(_HornetsNestOPainter oldDelegate) =>
      color != oldDelegate.color;
}

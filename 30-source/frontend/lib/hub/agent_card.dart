import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../agent/agent_chat.dart';
import '../models/agent.dart';
import '../models/swarm.dart';
import '../widgets/hexagon_painter.dart';

class AgentCard extends ConsumerStatefulWidget {
  final Agent agent;
  final double size;
  final VoidCallback? onTap;

  const AgentCard({
    super.key,
    required this.agent,
    this.size = 120,
    this.onTap,
  });

  @override
  ConsumerState<AgentCard> createState() => _AgentCardState();
}

class _AgentCardState extends ConsumerState<AgentCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  String _getModelBadge(String modelId) {
    if (modelId == 'openrouter/auto' || modelId == 'autorouter-swarm') {
      return '⚡ AutoRouter';
    }
    if (modelId == 'x-ai/grok-imagine-video-1.5') return '🎬 Grok Video 1.5';
    if (modelId == 'video-generation-swarm') return '🎬 Video';
    if (modelId == 'nim-free-power-swarm') return '🚀 NIM Free';
    if (modelId == 'default-coding-swarm') return '🧠 Flagship';
    final s = swarms[modelId];
    if (s != null) return s.name;
    final m = allModels.where((model) => model.id == modelId).firstOrNull;
    if (m != null) {
      if (m.keywords.contains('video')) return '🎬 ${m.name}';
      if (m.id.endsWith(':free')) return '🚀 ${m.name}';
      return m.name;
    }
    return modelId.split('/').last;
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.agent;
    final s = widget.size;
    final h = s * 1.1547; // flat-top hex height ratio
    final currentModel = ref.watch(agentModelProvider(a.id));
    final modelBadge = _getModelBadge(currentModel);

    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (context, _) {
          final glowOpacity = 0.2 + (_pulse.value * 0.4);
          return SizedBox(
            width: s,
            height: h,
            child: Stack(
              children: [
                // Filled background
                CustomPaint(
                  size: Size(s, h),
                  painter: HexPainter(
                    color: a.color.withValues(alpha: a.isOnline ? 0.10 : 0.04),
                    filled: true,
                  ),
                ),
                // Glowing border
                CustomPaint(
                  size: Size(s, h),
                  painter: HexPainter(
                    color: a.isOnline
                        ? a.color.withValues(alpha: 0.8)
                        : a.color.withValues(alpha: 0.2),
                    strokeWidth: a.isOnline ? 1.8 : 0.8,
                    glowColor: a.isOnline
                        ? a.color.withValues(alpha: glowOpacity)
                        : null,
                  ),
                ),
                // Content clipped to hex
                ClipPath(
                  clipper: HexClipper(),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Status dot
                        Container(
                          width: 5,
                          height: 5,
                          margin: const EdgeInsets.only(bottom: 4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: a.isOnline
                                ? a.color
                                : Colors.white24,
                            boxShadow: a.isOnline
                                ? [BoxShadow(color: a.color.withValues(alpha: 0.6), blurRadius: 6)]
                                : null,
                          ),
                        ),
                        // Icon
                        Icon(
                          a.icon,
                          color: a.isOnline ? a.color : a.color.withValues(alpha: 0.3),
                          size: s * 0.18,
                        ),
                        const SizedBox(height: 3),
                        // Name
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Text(
                            a.name.toUpperCase(),
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: a.isOnline ? 0.95 : 0.35),
                              fontSize: s * 0.08,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.1,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 2),
                        // Role
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Text(
                            a.role,
                            style: TextStyle(
                              color: a.color.withValues(alpha: a.isOnline ? 0.55 : 0.2),
                              fontSize: s * 0.06,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 3),
                        // Assigned Model Badge
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 10),
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.45),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: a.color.withValues(alpha: 0.4),
                              width: 0.8,
                            ),
                          ),
                          child: Text(
                            modelBadge,
                            style: TextStyle(
                              color: a.color.withValues(alpha: 0.9),
                              fontSize: s * 0.052,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'JetBrains Mono',
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Open/empty hexagon that sits between agent hexagons.
class OpenHexCard extends StatelessWidget {
  final double size;

  const OpenHexCard({super.key, this.size = 120});

  @override
  Widget build(BuildContext context) {
    final h = size * 1.1547;
    return SizedBox(
      width: size,
      height: h,
      child: CustomPaint(
        size: Size(size, h),
        painter: HexPainter(
          color: Colors.white.withValues(alpha: 0.06),
          strokeWidth: 0.7,
        ),
      ),
    );
  }
}
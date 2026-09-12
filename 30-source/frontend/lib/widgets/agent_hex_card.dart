import 'package:flutter/material.dart';
import '../models/agent.dart';
import 'hexagon_painter.dart';

class AgentHexCard extends StatefulWidget {
  final Agent agent;
  final double size;
  final VoidCallback? onTap;

  const AgentHexCard({
    super.key,
    required this.agent,
    this.size = 120,
    this.onTap,
  });

  @override
  State<AgentHexCard> createState() => _AgentHexCardState();
}

class _AgentHexCardState extends State<AgentHexCard>
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

  @override
  Widget build(BuildContext context) {
    final a = widget.agent;
    final s = widget.size;
    final h = s * 1.1547;

    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedWidget2(
        listenable: _pulse,
        builder: (context) {
          final glow = 0.3 + (_pulse.value * 0.4);
          return SizedBox(
            width: s,
            height: h,
            child: Stack(
              children: [
                // Fill
                CustomPaint(
                  size: Size(s, h),
                  painter: HexPainter(
                    color: a.color.withValues(alpha: a.active ? 0.12 : 0.05),
                    filled: true,
                  ),
                ),
                // Glowing border
                CustomPaint(
                  size: Size(s, h),
                  painter: HexPainter(
                    color: a.active
                        ? a.color.withValues(alpha: 0.8)
                        : a.color.withValues(alpha: 0.25),
                    strokeWidth: a.active ? 2.0 : 1.0,
                    glowColor: a.active
                        ? a.color.withValues(alpha: glow)
                        : null,
                  ),
                ),
                // Content
                ClipPath(
                  clipper: HexClipper(),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Status dot
                        Container(
                          width: 6,
                          height: 6,
                          margin: const EdgeInsets.only(bottom: 6),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: a.active ? a.color : Colors.white24,
                            boxShadow: a.active
                                ? [BoxShadow(color: a.color.withValues(alpha: 0.6), blurRadius: 6)]
                                : null,
                          ),
                        ),
                        Icon(a.icon, color: a.active ? a.color : a.color.withValues(alpha: 0.3), size: s * 0.22),
                        const SizedBox(height: 4),
                        Text(
                          a.name,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: a.active ? 0.95 : 0.4),
                            fontSize: s * 0.1,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          a.role,
                          style: TextStyle(
                            color: a.color.withValues(alpha: a.active ? 0.6 : 0.2),
                            fontSize: s * 0.075,
                          ),
                        ),
                        const SizedBox(height: 6),
                        SizedBox(
                          width: s * 0.4,
                          height: 2,
                          child: LinearProgressIndicator(
                            value: a.active ? 1.0 : 0.0,
                            backgroundColor: Colors.white10,
                            valueColor: AlwaysStoppedAnimation(
                              a.color.withValues(alpha: a.active ? 0.6 : 0.15),
                            ),
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

class AnimatedWidget2 extends AnimatedWidget {
  final Widget Function(BuildContext) builder;

  const AnimatedWidget2({
    super.key,
    required super.listenable,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) => builder(context);
}
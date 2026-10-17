import 'package:flutter/material.dart';
import '../theme/swarm_colors.dart';

/// Animated status indicator dot with optional pulse glow.
enum SwarmStatus { online, offline, idle, busy, critical }

class StatusDot extends StatefulWidget {
  final SwarmStatus status;
  final double size;
  final bool pulse;

  const StatusDot({
    super.key,
    required this.status,
    this.size = 8,
    this.pulse = true,
  });

  @override
  State<StatusDot> createState() => _StatusDotState();
}

class _StatusDotState extends State<StatusDot> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _pulseAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    if (widget.pulse && widget.status == SwarmStatus.online) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(StatusDot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pulse && widget.status == SwarmStatus.online) {
      if (!_controller.isAnimating) _controller.repeat(reverse: true);
    } else {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color get _color => switch (widget.status) {
    SwarmStatus.online => SwarmColors.statusOnline,
    SwarmStatus.offline => SwarmColors.statusOffline,
    SwarmStatus.idle => SwarmColors.statusIdle,
    SwarmStatus.busy => SwarmColors.statusBusy,
    SwarmStatus.critical => SwarmColors.statusCritical,
  };

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseAnim,
      builder: (context, child) {
        return Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            color: _color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: _color.withValues(alpha: 0.3 + (_pulseAnim.value * 0.3)),
                blurRadius: 4 + (_pulseAnim.value * 4),
                spreadRadius: _pulseAnim.value * 2,
              ),
            ],
          ),
        );
      },
    );
  }
}

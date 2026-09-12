import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/telemetry_providers.dart';
import '../providers/sentinel_providers.dart';
import '../theme/swarm_colors.dart';
import '../theme/swarm_text_styles.dart';

/// System HUD overlay — top-bar-integrated status strip.
/// Shows CPU%, RAM%, temp, SSE connection, kernel, and uptime live.
class SwarmHud extends ConsumerWidget {
  const SwarmHud({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final telemetry = ref.watch(telemetryProvider);
    final sseStatus = ref.watch(sseEventsProvider);

    final bool sentinelOnline = sseStatus.hasValue;

    return telemetry.when(
      loading: () => const _HudStrip(
          snapshot: TelemetrySnapshot.empty, sentinelOnline: false),
      error: (_, __) => const _HudStrip(
          snapshot: TelemetrySnapshot.empty, sentinelOnline: false),
      data: (snap) => _HudStrip(snapshot: snap, sentinelOnline: sentinelOnline),
    );
  }
}

class _HudStrip extends StatelessWidget {
  final TelemetrySnapshot snapshot;
  final bool sentinelOnline;

  const _HudStrip({required this.snapshot, required this.sentinelOnline});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Sentinel Connection Dot
        _HudIndicator(
          color: sentinelOnline
              ? SwarmColors.statusOnline
              : SwarmColors.statusOffline,
          pulse: sentinelOnline,
          label: sentinelOnline ? 'SENTINEL' : 'OFFLINE',
        ),
        const SizedBox(width: 12),

        // CPU
        _HudGauge(
          label: 'CPU',
          value: snapshot.cpuPercent,
          max: 100,
          color: _gaugeColor(snapshot.cpuPercent, 100),
          suffix: '%',
        ),
        const SizedBox(width: 12),

        // RAM
        _HudGauge(
          label: 'RAM',
          value: snapshot.ramUsedGb,
          max: snapshot.ramTotalGb > 0 ? snapshot.ramTotalGb : 16,
          color: _gaugeColor(snapshot.ramPercent, 100),
          suffix: 'GB',
        ),
        const SizedBox(width: 12),

        // Temp
        if (snapshot.cpuTempC > 0) ...[
          _HudStat(
            label: 'TEMP',
            value: '${snapshot.cpuTempC.toStringAsFixed(0)}°C',
            color: snapshot.cpuTempC > 80
                ? SwarmColors.statusCritical
                : SwarmColors.textMuted,
          ),
          const SizedBox(width: 12),
        ],

        // Uptime
        _HudStat(
          label: 'UP',
          value: snapshot.uptimeFormatted,
          color: SwarmColors.textMuted,
        ),
      ],
    );
  }

  Color _gaugeColor(double value, double max) {
    final pct = value / max;
    if (pct > 0.85) return SwarmColors.statusCritical;
    if (pct > 0.65) return SwarmColors.statusIdle;
    return SwarmColors.accent;
  }
}

class _HudIndicator extends StatefulWidget {
  final Color color;
  final bool pulse;
  final String label;

  const _HudIndicator(
      {required this.color, required this.pulse, required this.label});

  @override
  State<_HudIndicator> createState() => _HudIndicatorState();
}

class _HudIndicatorState extends State<_HudIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200));
    _anim = Tween<double>(begin: 0.3, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
    if (widget.pulse) _ctrl.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(_HudIndicator old) {
    super.didUpdateWidget(old);
    if (widget.pulse && !_ctrl.isAnimating) {
      _ctrl.repeat(reverse: true);
    } else if (!widget.pulse) {
      _ctrl.stop();
      _ctrl.value = 0;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        AnimatedBuilder(
          animation: _anim,
          builder: (_, __) => Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: widget.color.withValues(alpha: _anim.value),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                    color: widget.color.withValues(alpha: _anim.value * 0.6),
                    blurRadius: 4)
              ],
            ),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          widget.label,
          style: SwarmTextStyles.labelSmall
              .copyWith(color: widget.color, fontSize: 9),
        ),
      ],
    );
  }
}

class _HudGauge extends StatelessWidget {
  final String label;
  final double value;
  final double max;
  final Color color;
  final String suffix;

  const _HudGauge(
      {required this.label,
      required this.value,
      required this.max,
      required this.color,
      required this.suffix});

  @override
  Widget build(BuildContext context) {
    final pct = (value / max).clamp(0.0, 1.0);
    return Row(
      children: [
        Text(label,
            style: SwarmTextStyles.labelSmall
                .copyWith(fontSize: 9, color: SwarmColors.textMuted)),
        const SizedBox(width: 4),
        SizedBox(
          width: 36,
          height: 4,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: pct,
              backgroundColor: SwarmColors.border,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          '${value.toStringAsFixed(1)}$suffix',
          style: SwarmTextStyles.codeSmall
              .copyWith(fontSize: 9, color: color, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class _HudStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _HudStat(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(label,
            style: SwarmTextStyles.labelSmall
                .copyWith(fontSize: 9, color: SwarmColors.textMuted)),
        const SizedBox(width: 4),
        Text(value,
            style: SwarmTextStyles.codeSmall.copyWith(
                fontSize: 9, color: color, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

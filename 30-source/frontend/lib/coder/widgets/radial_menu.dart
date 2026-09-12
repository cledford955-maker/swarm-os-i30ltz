import 'dart:math';
import 'package:flutter/material.dart';
import '../../theme/swarm_colors.dart';

// ─── Sector data ─────────────────────────────────────────────────────────────
class RadialItem {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const RadialItem({required this.icon, required this.label, required this.color, required this.onTap});
}

// ─── Radial menu overlay ─────────────────────────────────────────────────────
class RadialMenuOverlay extends StatefulWidget {
  final List<RadialItem> items;
  final VoidCallback onDismiss;
  final Offset center;

  const RadialMenuOverlay({
    super.key,
    required this.items,
    required this.onDismiss,
    this.center = Offset.zero,
  });

  @override
  State<RadialMenuOverlay> createState() => _RadialMenuOverlayState();
}

class _RadialMenuOverlayState extends State<RadialMenuOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _anim;
  int? _hoveredIndex;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 200));
    _anim.forward();
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  void _updatePointer(Offset local) {
    setState(() {
      final dx = local.dx - _center(context).dx;
      final dy = local.dy - _center(context).dy;
      final dist = sqrt(dx * dx + dy * dy);
      if (dist < 48 || dist > 160) {
        _hoveredIndex = null;
        return;
      }
      var angle = atan2(dy, dx) * 180 / pi + 90;
      if (angle < 0) angle += 360;
      _hoveredIndex = (angle / (360 / widget.items.length)).floor() % widget.items.length;
    });
  }

  Offset _center(BuildContext ctx) {
    if (widget.center != Offset.zero) return widget.center;
    final sz = MediaQuery.of(ctx).size;
    return Offset(sz.width / 2, sz.height / 2);
  }

  @override
  Widget build(BuildContext context) {
    final center = _center(context);
    return GestureDetector(
      onTap: widget.onDismiss,
      onPanUpdate: (d) => _updatePointer(d.localPosition + center),
      child: Stack(children: [
        // Dim background
        Container(color: Colors.black.withValues(alpha: 0.55)),
        // Menu
        AnimatedBuilder(
          animation: _anim,
          builder: (_, __) {
            final scale = CurvedAnimation(parent: _anim, curve: Curves.elasticOut);
            return CustomPaint(
              painter: _RadialPainter(
                items: widget.items,
                center: center,
                hovered: _hoveredIndex,
                progress: _anim.value,
              ),
              child: Stack(children: [
                // Center button (cancel)
                Positioned(
                  left: center.dx - 24,
                  top: center.dy - 24,
                  child: ScaleTransition(
                    scale: scale,
                    child: GestureDetector(
                      onTap: widget.onDismiss,
                      child: Container(
                        width: 48, height: 48,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: SwarmColors.bgElevated,
                        ),
                        child: const Icon(Icons.close_rounded, size: 20, color: SwarmColors.textMuted),
                      ),
                    ),
                  ),
                ),
                // Sector labels + icons
                ...List.generate(widget.items.length, (i) {
                  final item = widget.items[i];
                  final angle = (i / widget.items.length) * 2 * pi - pi / 2;
                  const r = 100.0;
                  final x = center.dx + r * cos(angle);
                  final y = center.dy + r * sin(angle);
                  final hovered = _hoveredIndex == i;
                  return Positioned(
                    left: x - 28,
                    top: y - 28,
                    child: ScaleTransition(
                      scale: CurvedAnimation(parent: _anim, curve: Interval(i / widget.items.length * 0.4, 0.7 + i / widget.items.length * 0.3, curve: Curves.elasticOut)),
                      child: GestureDetector(
                        onTap: () { item.onTap(); widget.onDismiss(); },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 120),
                          width: 56, height: 56,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: hovered ? item.color.withValues(alpha: 0.25) : SwarmColors.bgElevated.withValues(alpha: 0.9),
                            border: Border.all(color: hovered ? item.color : SwarmColors.border, width: hovered ? 2 : 1),
                            boxShadow: hovered ? [BoxShadow(color: item.color.withValues(alpha: 0.4), blurRadius: 12)] : null,
                          ),
                          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                            Icon(item.icon, size: 18, color: hovered ? item.color : SwarmColors.textMuted),
                            const SizedBox(height: 2),
                            Text(item.label, style: TextStyle(fontSize: 8, color: hovered ? item.color : SwarmColors.textDisabled, fontWeight: hovered ? FontWeight.bold : FontWeight.normal), textAlign: TextAlign.center),
                          ]),
                        ),
                      ),
                    ),
                  );
                }),
              ]),
            );
          },
        ),
      ]),
    );
  }
}

// ─── Radial sectors painter ───────────────────────────────────────────────────
class _RadialPainter extends CustomPainter {
  final List<RadialItem> items;
  final Offset center;
  final int? hovered;
  final double progress;

  _RadialPainter({required this.items, required this.center, required this.hovered, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final n = items.length;
    final sweepAngle = 2 * pi / n;

    for (int i = 0; i < n; i++) {
      final startAngle = i * sweepAngle - pi / 2 - sweepAngle / 2;
      final isHov = hovered == i;
      final color = items[i].color;

      final paint = Paint()
        ..color = isHov ? color.withValues(alpha: 0.12) : const Color(0x0A76BEFF)
        ..style = PaintingStyle.fill;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: 135 * progress),
        startAngle,
        sweepAngle,
        true,
        paint,
      );

      // Divider line
      final lineAngle = startAngle;
      final linePaint = Paint()
        ..color = SwarmColors.border.withValues(alpha: 0.5)
        ..strokeWidth = 0.5
        ..style = PaintingStyle.stroke;
      canvas.drawLine(
        center + Offset(cos(lineAngle) * 44, sin(lineAngle) * 44),
        center + Offset(cos(lineAngle) * 130, sin(lineAngle) * 130),
        linePaint,
      );
    }

    // Outer ring
    final ringPaint = Paint()
      ..color = SwarmColors.border
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawCircle(center, 130 * progress, ringPaint);

    // Inner ring (dead zone)
    canvas.drawCircle(center, 44 * progress, ringPaint);
  }

  @override
  bool shouldRepaint(_RadialPainter old) => old.hovered != hovered || old.progress != progress;
}

// ─── Static show helper ───────────────────────────────────────────────────────
OverlayEntry? _currentRadialEntry;

void showRadialMenu({
  required BuildContext context,
  required List<RadialItem> items,
  Offset center = Offset.zero,
}) {
  _currentRadialEntry?.remove();
  late OverlayEntry entry;
  entry = OverlayEntry(builder: (_) => RadialMenuOverlay(
    items: items,
    center: center,
    onDismiss: () {
      entry.remove();
      _currentRadialEntry = null;
    },
  ));
  _currentRadialEntry = entry;
  Overlay.of(context).insert(entry);
}

void dismissRadialMenu() {
  _currentRadialEntry?.remove();
  _currentRadialEntry = null;
}

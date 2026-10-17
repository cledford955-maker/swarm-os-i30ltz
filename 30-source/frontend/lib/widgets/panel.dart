import 'package:flutter/material.dart';
import '../theme/swarm_colors.dart';
import '../theme/swarm_text_styles.dart';

/// Reusable panel container — the primary layout primitive in SWARM OS.
/// Replaces the Panel/PanelHeader components from primitives.tsx.
class SwarmPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final Color? color;
  final bool hasBorder;
  final double borderRadius;
  final VoidCallback? onTap;

  const SwarmPanel({
    super.key,
    required this.child,
    this.padding,
    this.color,
    this.hasBorder = true,
    this.borderRadius = 12,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final panel = AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color ?? SwarmColors.bgElevated,
        borderRadius: BorderRadius.circular(borderRadius),
        border: hasBorder
            ? Border.all(color: SwarmColors.border, width: 1)
            : null,
      ),
      child: child,
    );

    if (onTap != null) {
      return MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(onTap: onTap, child: panel),
      );
    }
    return panel;
  }
}

/// Header row for a SwarmPanel — title + optional trailing widget.
class SwarmPanelHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;
  final IconData? icon;
  final Color? accentColor;

  const SwarmPanelHeader({
    super.key,
    required this.title,
    this.trailing,
    this.icon,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final accent = accentColor ?? SwarmColors.accent;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: accent),
            const SizedBox(width: 8),
          ],
          Text(
            title.toUpperCase(),
            style: SwarmTextStyles.label.copyWith(
              color: accent,
              letterSpacing: 1.5,
            ),
          ),
          const Spacer(),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

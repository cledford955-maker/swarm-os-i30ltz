import 'package:flutter/material.dart';
import '../theme/swarm_colors.dart';
import '../theme/swarm_text_styles.dart';

enum SwarmButtonVariant { primary, secondary, ghost, danger }

/// Styled button matching SWARM OS design system.
class SwarmButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final SwarmButtonVariant variant;
  final bool compact;
  final bool loading;

  const SwarmButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.variant = SwarmButtonVariant.primary,
    this.compact = false,
    this.loading = false,
  });

  @override
  State<SwarmButton> createState() => _SwarmButtonState();
}

class _SwarmButtonState extends State<SwarmButton> {
  bool _hovered = false;

  Color get _bg => switch (widget.variant) {
    SwarmButtonVariant.primary => _hovered ? SwarmColors.accent.withValues(alpha: 0.85) : SwarmColors.accent,
    SwarmButtonVariant.secondary => _hovered ? SwarmColors.bgHover : SwarmColors.bgElevated,
    SwarmButtonVariant.ghost => _hovered ? SwarmColors.bgHover : Colors.transparent,
    SwarmButtonVariant.danger => _hovered ? SwarmColors.statusCritical.withValues(alpha: 0.85) : SwarmColors.statusCritical,
  };

  Color get _fg => switch (widget.variant) {
    SwarmButtonVariant.primary => SwarmColors.bg,
    SwarmButtonVariant.secondary => SwarmColors.textPrimary,
    SwarmButtonVariant.ghost => SwarmColors.textSecondary,
    SwarmButtonVariant.danger => SwarmColors.textPrimary,
  };

  Color get _borderColor => switch (widget.variant) {
    SwarmButtonVariant.primary => Colors.transparent,
    SwarmButtonVariant.secondary => SwarmColors.border,
    SwarmButtonVariant.ghost => Colors.transparent,
    SwarmButtonVariant.danger => Colors.transparent,
  };

  @override
  Widget build(BuildContext context) {
    final isDisabled = widget.onPressed == null || widget.loading;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: isDisabled ? SystemMouseCursors.forbidden : SystemMouseCursors.click,
      child: GestureDetector(
        onTap: isDisabled ? null : widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: EdgeInsets.symmetric(
            horizontal: widget.compact ? 10 : 16,
            vertical: widget.compact ? 6 : 10,
          ),
          decoration: BoxDecoration(
            color: isDisabled ? _bg.withValues(alpha: 0.5) : _bg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _borderColor, width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.loading) ...[
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: _fg,
                  ),
                ),
                const SizedBox(width: 8),
              ] else if (widget.icon != null) ...[
                Icon(widget.icon, size: 14, color: _fg),
                const SizedBox(width: 8),
              ],
              Text(
                widget.label.toUpperCase(),
                style: SwarmTextStyles.label.copyWith(
                  color: _fg,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

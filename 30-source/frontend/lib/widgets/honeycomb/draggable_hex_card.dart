import 'package:flutter/material.dart';
import 'hexagon_clipper.dart';

/// A draggable hexagon card that can be picked up and snapped to grid slots.
class DraggableHexCard extends StatefulWidget {
  final int slotIndex;
  final String cardId;
  final Widget child;
  final double hexWidth;
  final double hexHeight;
  final Color borderColor;
  final Color? glowColor;
  final double borderWidth;
  final double glowRadius;
  final bool isDraggable;
  final VoidCallback? onDragStarted;
  final VoidCallback? onDragEnd;

  const DraggableHexCard({
    super.key,
    required this.slotIndex,
    required this.cardId,
    required this.child,
    required this.hexWidth,
    required this.hexHeight,
    this.borderColor = const Color(0xFF00FFFF),
    this.glowColor,
    this.borderWidth = 1.5,
    this.glowRadius = 8.0,
    this.isDraggable = true,
    this.onDragStarted,
    this.onDragEnd,
  });

  @override
  State<DraggableHexCard> createState() => _DraggableHexCardState();
}

class _DraggableHexCardState extends State<DraggableHexCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Widget _buildHexCard({double opacity = 1.0, bool ghost = false}) {
    return AnimatedBuilder(
      animation: _pulseAnim,
      builder: (context, _) {
        final glow = ghost ? 0.0 : widget.glowRadius * _pulseAnim.value;
        return Opacity(
          opacity: opacity,
          child: HexagonWidget(
            width: widget.hexWidth,
            height: widget.hexHeight,
            flatTop: true,
            borderColor: ghost
                ? widget.borderColor.withValues(alpha: 0.2)
                : widget.borderColor,
            borderWidth: widget.borderWidth,
            glowColor: ghost
                ? Colors.transparent
                : (widget.glowColor ?? widget.borderColor.withValues(alpha: 0.4)),
            glowRadius: glow,
            child: widget.child,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isDraggable) {
      return _buildHexCard();
    }

    return Draggable<String>(
      data: widget.cardId,
      onDragStarted: () {
        widget.onDragStarted?.call();
      },
      onDragEnd: (_) {
        widget.onDragEnd?.call();
      },
      feedback: Material(
        color: Colors.transparent,
        child: Transform.scale(
          scale: 1.08,
          child: _buildHexCard(opacity: 0.85),
        ),
      ),
      childWhenDragging: _buildHexCard(opacity: 0.2, ghost: true),
      child: _buildHexCard(),
    );
  }
}
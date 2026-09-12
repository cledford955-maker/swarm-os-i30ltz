import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'window_manager.dart';
import '../theme/swarm_colors.dart';
import '../theme/swarm_text_styles.dart';

// ─── Resize handle dimensions ───
const double _kCorner = 16.0; // corner grip square
const double _kEdge = 8.0;   // edge strip thickness

/// The draggable, resizable floating window widget.
class OsWindowWidget extends ConsumerWidget {
  final AppWindow window;
  const OsWindowWidget({super.key, required this.window});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (window.isMaximized) {
      return Positioned.fill(child: _windowBody(ref, context));
    }
    return Positioned(
      left: window.position.dx,
      top: window.position.dy,
      width: window.size.width,
      height: window.size.height,
      child: _windowBody(ref, context),
    );
  }

  Widget _windowBody(WidgetRef ref, BuildContext context) {
    final focused = window.isFocused;
    return GestureDetector(
      onTapDown: (_) {
        if (!focused) ref.read(windowProvider.notifier).focusWindow(window.id);
      },
      child: Stack(clipBehavior: Clip.none, children: [
        // ── Frame + content ──
        Container(
          decoration: BoxDecoration(
            color: SwarmColors.bgSurface.withValues(alpha: 0.96),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: focused
                  ? SwarmColors.accent.withValues(alpha: 0.75)
                  : SwarmColors.border,
              width: focused ? 1.5 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: focused ? 0.55 : 0.30),
                blurRadius: focused ? 32 : 14,
                offset: const Offset(0, 8),
              ),
              if (focused)
                BoxShadow(
                  color: SwarmColors.accent.withValues(alpha: 0.08),
                  blurRadius: 0,
                  spreadRadius: 1,
                ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(11),
            child: Column(children: [
              _TitleBar(window: window),
              Expanded(child: window.content),
            ]),
          ),
        ),

        // ── 8 resize handles (only when not maximized) ──
        if (!window.isMaximized) ...[
          // Corners
          _ResizeHandle(window: window, fromLeft: false, fromTop: false,
            cursor: SystemMouseCursors.resizeUpLeftDownRight,
            rect: _br(_kCorner)),
          _ResizeHandle(window: window, fromLeft: true, fromTop: false,
            cursor: SystemMouseCursors.resizeUpRightDownLeft,
            rect: _bl(_kCorner)),
          _ResizeHandle(window: window, fromLeft: false, fromTop: true,
            cursor: SystemMouseCursors.resizeUpRightDownLeft,
            rect: _tr(_kCorner)),
          _ResizeHandle(window: window, fromLeft: true, fromTop: true,
            cursor: SystemMouseCursors.resizeUpLeftDownRight,
            rect: _tl(_kCorner)),

          // Edges
          _ResizeHandle(window: window, fromLeft: false, fromTop: false,
            cursor: SystemMouseCursors.resizeColumn,
            constrainY: true,
            rect: _right(_kEdge, _kCorner)),
          _ResizeHandle(window: window, fromLeft: true, fromTop: false,
            cursor: SystemMouseCursors.resizeColumn,
            constrainY: true,
            rect: _left(_kEdge, _kCorner)),
          _ResizeHandle(window: window, fromLeft: false, fromTop: false,
            cursor: SystemMouseCursors.resizeRow,
            constrainX: true,
            rect: _bottom(_kEdge, _kCorner)),
          _ResizeHandle(window: window, fromLeft: false, fromTop: true,
            cursor: SystemMouseCursors.resizeRow,
            constrainX: true,
            rect: _top(_kEdge, _kCorner)),
        ],
      ]),
    );
  }

  // ─── Helper rects for handle positions ───
  _HandleRect _br(double c) =>
      _HandleRect(right: 0, bottom: 0, width: c, height: c);
  _HandleRect _bl(double c) =>
      _HandleRect(left: 0, bottom: 0, width: c, height: c);
  _HandleRect _tr(double c) =>
      _HandleRect(right: 0, top: 0, width: c, height: c);
  _HandleRect _tl(double c) =>
      _HandleRect(left: 0, top: 0, width: c, height: c);
  _HandleRect _right(double e, double c) =>
      _HandleRect(right: 0, top: c, bottom: c, width: e);
  _HandleRect _left(double e, double c) =>
      _HandleRect(left: 0, top: c, bottom: c, width: e);
  _HandleRect _bottom(double e, double c) =>
      _HandleRect(left: c, right: c, bottom: 0, height: e);
  _HandleRect _top(double e, double c) =>
      _HandleRect(left: c, right: c, top: 0, height: e);
}

// ─────────────────────────────────────────────────────────────
// Title bar — draggable, with controls
// ─────────────────────────────────────────────────────────────

class _TitleBar extends ConsumerWidget {
  final AppWindow window;
  const _TitleBar({required this.window});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MouseRegion(
      cursor: SystemMouseCursors.move,
      child: GestureDetector(
        onPanStart: (_) {
          if (!window.isFocused) {
            ref.read(windowProvider.notifier).focusWindow(window.id);
          }
        },
        onPanUpdate: (d) {
          ref.read(windowProvider.notifier).updateWindowPosition(window.id, d.delta);
        },
        child: Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: SwarmColors.bgElevated,
            border: const Border(bottom: BorderSide(color: SwarmColors.border)),
          ),
          child: Row(children: [
            // Window title + timestamp
            Expanded(child: Row(children: [
              Flexible(
                child: Text(
                  window.title,
                  style: SwarmTextStyles.label.copyWith(
                    color: window.isFocused
                        ? SwarmColors.textPrimary
                        : SwarmColors.textMuted,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _formatCreatedAt(window.createdAt),
                style: SwarmTextStyles.labelSmall.copyWith(
                  fontSize: 9,
                  color: SwarmColors.textMuted.withValues(alpha: 0.45),
                  fontFamily: 'JetBrains Mono',
                ),
              ),
            ])),

            // Maximize / restore
            _TitleButton(
              icon: window.isMaximized
                  ? Icons.close_fullscreen
                  : Icons.open_in_full,
              cursor: SystemMouseCursors.click,
              onTap: () =>
                  ref.read(windowProvider.notifier).toggleMaximize(window.id),
            ),
            const SizedBox(width: 8),

            // Close
            _TitleButton(
              icon: Icons.close,
              cursor: SystemMouseCursors.click,
              hoverColor: const Color(0xFFFF5F57),
              onTap: () =>
                  ref.read(windowProvider.notifier).closeWindow(window.id),
            ),
          ]),
        ),
      ),
    );
  }
}

class _TitleButton extends StatefulWidget {
  final IconData icon;
  final MouseCursor cursor;
  final Color? hoverColor;
  final VoidCallback onTap;
  const _TitleButton({
    required this.icon,
    required this.cursor,
    required this.onTap,
    this.hoverColor,
  });

  @override
  State<_TitleButton> createState() => _TitleButtonState();
}

class _TitleButtonState extends State<_TitleButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final color = _hovered
        ? (widget.hoverColor ?? SwarmColors.accent)
        : SwarmColors.textMuted;
    return MouseRegion(
      cursor: widget.cursor,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(widget.icon, size: 15, color: color),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Resize handle
// ─────────────────────────────────────────────────────────────

class _HandleRect {
  final double? left, top, right, bottom, width, height;
  const _HandleRect(
      {this.left, this.top, this.right, this.bottom, this.width, this.height});
}

class _ResizeHandle extends ConsumerWidget {
  final AppWindow window;
  final bool fromLeft;
  final bool fromTop;
  final MouseCursor cursor;
  final _HandleRect rect;
  // When true the corresponding axis delta is zeroed before forwarding
  final bool constrainX;
  final bool constrainY;

  const _ResizeHandle({
    required this.window,
    required this.fromLeft,
    required this.fromTop,
    required this.cursor,
    required this.rect,
    this.constrainX = false,
    this.constrainY = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Positioned(
      left: rect.left,
      top: rect.top,
      right: rect.right,
      bottom: rect.bottom,
      width: rect.width,
      height: rect.height,
      child: MouseRegion(
        cursor: cursor,
        child: GestureDetector(
          onPanStart: (_) {
            if (!window.isFocused) {
              ref.read(windowProvider.notifier).focusWindow(window.id);
            }
          },
          onPanUpdate: (d) {
            final delta = Offset(
              constrainX ? 0 : d.delta.dx,
              constrainY ? 0 : d.delta.dy,
            );
            ref.read(windowProvider.notifier).resizeWindowFromEdge(
              window.id,
              fromLeft: fromLeft,
              fromTop: fromTop,
              delta: delta,
            );
          },
          // Transparent but captures events
          child: Container(color: Colors.transparent),
        ),
      ),
    );
  }
}

// ─── Format timestamp ───
String _formatCreatedAt(DateTime dt) {
  final h = dt.hour.toString().padLeft(2, '0');
  final m = dt.minute.toString().padLeft(2, '0');
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];
  return '$h:$m · ${months[dt.month - 1]} ${dt.day}';
}

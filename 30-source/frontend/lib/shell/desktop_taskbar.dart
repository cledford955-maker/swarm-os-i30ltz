// ═══════════════════════════════════════════════════════════════
// Swarm OS — Static desktop taskbar (2026-10-15)
//
// Lists every open window (including minimized ones) in a fixed bar
// pinned to the bottom of the screen. Entries are ordered by when the
// window was opened, never by focus/z-order, so a tile never jumps
// around just because you clicked it — "static" means it stays put.
// Clicking an entry: unminimizes it, switches to its desktop page if
// needed, and focuses it. Clicking the already-focused entry minimizes
// it (standard taskbar toggle).
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'window_manager.dart';
import 'desktop_geometry.dart';
import '../theme/swarm_colors.dart';
import '../theme/swarm_text_styles.dart';

class DesktopTaskbar extends ConsumerWidget {
  const DesktopTaskbar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final windows = ref.watch(windowProvider);
    if (windows.isEmpty) return const SizedBox.shrink();

    final activePage = ref.watch(activeDesktopPageProvider);
    final entries = List<AppWindow>.from(windows)
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      height: DesktopGeometry.taskbarHeight,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: SwarmColors.bgElevated.withValues(alpha: 0.96),
          border: const Border(top: BorderSide(color: SwarmColors.border)),
        ),
        child: Row(
          children: [
            Expanded(
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: entries
                    .map((w) => _TaskbarEntry(
                          window: w,
                          isCurrentPage: w.desktopPage == activePage,
                        ))
                    .toList(),
              ),
            ),
            _Clock(),
          ],
        ),
      ),
    );
  }
}

class _TaskbarEntry extends ConsumerWidget {
  final AppWindow window;
  final bool isCurrentPage;
  const _TaskbarEntry({required this.window, required this.isCurrentPage});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isActive = window.isFocused && isCurrentPage && !window.isMinimized;

    return GestureDetector(
      onTap: () {
        final notifier = ref.read(windowProvider.notifier);
        if (!isCurrentPage) {
          ref.read(activeDesktopPageProvider.notifier).state = window.desktopPage;
          notifier.focusWindow(window.id);
        } else if (isActive) {
          notifier.toggleMinimize(window.id);
        } else {
          notifier.focusWindow(window.id);
        }
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 3),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        constraints: const BoxConstraints(minWidth: 96, maxWidth: 200),
        decoration: BoxDecoration(
          color: isActive
              ? SwarmColors.accentSurface
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isActive
                ? SwarmColors.accent.withValues(alpha: 0.5)
                : SwarmColors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              window.isMinimized ? Icons.remove : Icons.crop_square,
              size: 12,
              color: window.isMinimized
                  ? SwarmColors.textMuted
                  : (isActive ? SwarmColors.accent : SwarmColors.textSecondary),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                window.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: SwarmTextStyles.labelSmall.copyWith(
                  color: window.isMinimized
                      ? SwarmColors.textMuted
                      : (isActive ? SwarmColors.textPrimary : SwarmColors.textSecondary),
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Clock extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: Stream.periodic(const Duration(seconds: 1)),
      builder: (_, __) {
        final n = DateTime.now();
        return Padding(
          padding: const EdgeInsets.only(left: 10),
          child: Text(
            '${n.hour.toString().padLeft(2, '0')}:${n.minute.toString().padLeft(2, '0')}',
            style: SwarmTextStyles.labelSmall.copyWith(
              color: SwarmColors.textMuted,
              fontFamily: 'JetBrains Mono',
            ),
          ),
        );
      },
    );
  }
}

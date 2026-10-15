import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/launch_status.dart';
import 'desktop_geometry.dart';

/// Represents a single floating window in the SWARM OS environment.
class AppWindow {
  final String id;
  final String title;
  final Offset position;
  final Size size;
  final bool isFocused;
  final bool isMaximized;
  final int desktopPage;
  final Widget content;
  final DateTime createdAt;

  AppWindow({
    required this.id,
    required this.title,
    required this.position,
    required this.size,
    this.isFocused = true,
    this.isMaximized = false,
    this.desktopPage = 0,
    required this.content,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  AppWindow copyWith({
    Offset? position,
    Size? size,
    bool? isFocused,
    bool? isMaximized,
    int? desktopPage,
    Widget? content,
  }) {
    return AppWindow(
      id: id,
      title: title,
      position: position ?? this.position,
      size: size ?? this.size,
      isFocused: isFocused ?? this.isFocused,
      isMaximized: isMaximized ?? this.isMaximized,
      desktopPage: desktopPage ?? this.desktopPage,
      content: content ?? this.content,
      createdAt: createdAt,
    );
  }
}

/// State notifier to manage the list of floating windows.
class WindowManager extends StateNotifier<List<AppWindow>> {
  final int Function() _readCurrentPage;
  final void Function(int) _setCurrentPage;

  WindowManager(this._readCurrentPage, this._setCurrentPage) : super([]);

  void openWindow(AppWindow window) {
    LaunchStatusRegistry.setRunning(window.id);
    final page = _readCurrentPage();
    // Keep focus state on other desktops; only the current desktop gets focus.
    final updated = state.map((w) => w.copyWith(
      isFocused: w.desktopPage == page ? false : w.isFocused,
    )).toList();

    // Check if window already exists
    final existingIndex = updated.indexWhere((w) => w.id == window.id);
    if (existingIndex >= 0) {
      final existing = updated.removeAt(existingIndex);
      updated.add(existing.copyWith(
        isFocused: true,
        desktopPage: page,
      )); // Move the existing instance to this desktop and bring it forward
    } else {
      // Every new window starts centered between the desktop icon rails,
      // whatever position the caller asked for.
      final spot = DesktopGeometry.place(window.size, updated.length);
      updated.add(window.copyWith(
        position: spot.topLeft,
        size: spot.size,
        isFocused: true,
        desktopPage: page,
      ));
    }
    state = updated;
  }

  void toggleMaximize(String id) {
    state = [
      for (final w in state)
        if (w.id == id)
          w.copyWith(isMaximized: !w.isMaximized, isFocused: true)
        else if (w.desktopPage == _readCurrentPage())
          w.copyWith(isFocused: false)
        else
          w
    ];
  }

  void moveWindowToNextPage(String id) {
    final index = state.indexWhere((w) => w.id == id);
    if (index < 0) return;
    final targetPage = state[index].desktopPage + 1;
    final updated = state.map((w) => w.copyWith(
      desktopPage: w.id == id ? targetPage : w.desktopPage,
      isFocused: w.id == id ? true : (w.desktopPage == targetPage ? false : w.isFocused),
    )).toList();
    final moved = updated.removeAt(index);
    updated.add(moved);
    state = updated;
    _setCurrentPage(targetPage);
  }

  void focusWindow(String id) {
    final target = state.where((w) => w.id == id).firstOrNull;
    if (target == null) return;
    final updated = state.map((w) => w.copyWith(
      isFocused: w.id == id ? true : (w.desktopPage == target.desktopPage ? false : w.isFocused),
    )).toList();
    
    final index = updated.indexWhere((w) => w.id == id);
    if (index >= 0) {
      final window = updated.removeAt(index);
      updated.add(window); // Move to end of list (rendered on top)
    }
    state = updated;
  }

  void updateWindowPosition(String id, Offset delta) {
    state = state.map((w) {
      if (w.id == id) {
        return w.copyWith(position: w.position + delta);
      }
      return w;
    }).toList();
  }

  void updateWindowSize(String id, Size delta) {
    state = state.map((w) {
      if (w.id == id) {
        final newSize = Size(
          (w.size.width + delta.width).clamp(300.0, 4000.0),
          (w.size.height + delta.height).clamp(200.0, 4000.0),
        );
        return w.copyWith(size: newSize);
      }
      return w;
    }).toList();
  }

  // Resize from any edge or corner.
  // fromLeft/fromTop = the anchor edge is moving (so position shifts too).
  void resizeWindowFromEdge(String id,
      {required bool fromLeft,
      required bool fromTop,
      required Offset delta}) {
    state = state.map((w) {
      if (w.id != id) return w;

      const minW = 280.0;
      const minH = 160.0;

      // Proposed new size
      double newW =
          (w.size.width + (fromLeft ? -delta.dx : delta.dx)).clamp(minW, 4000.0);
      double newH =
          (w.size.height + (fromTop ? -delta.dy : delta.dy)).clamp(minH, 4000.0);

      // Actual size change after clamping
      final actualDW = newW - w.size.width;
      final actualDH = newH - w.size.height;

      // When dragging a left/top edge the position must shift to keep the
      // opposite edge stationary.
      final newX = w.position.dx + (fromLeft ? -actualDW : 0);
      final newY = w.position.dy + (fromTop ? -actualDH : 0);

      return w.copyWith(
        position: Offset(newX, newY),
        size: Size(newW, newH),
      );
    }).toList();
  }
}

/// Riverpod provider for the window manager system.
final windowProvider = StateNotifierProvider<WindowManager, List<AppWindow>>((ref) {
  return WindowManager(
    () => ref.read(activeDesktopPageProvider),
    (page) => ref.read(activeDesktopPageProvider.notifier).state = page,
  );
});

/// The currently visible workspace. Pages are created simply by navigating
/// forward; window instances and their contents remain in [windowProvider].
final activeDesktopPageProvider = StateProvider<int>((ref) => 0);

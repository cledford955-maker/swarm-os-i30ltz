import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Represents a single floating window in the SWARM OS environment.
class AppWindow {
  final String id;
  final String title;
  final Offset position;
  final Size size;
  final bool isFocused;
  final bool isMaximized;
  final Widget content;
  final DateTime createdAt;

  AppWindow({
    required this.id,
    required this.title,
    required this.position,
    required this.size,
    this.isFocused = true,
    this.isMaximized = false,
    required this.content,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  AppWindow copyWith({
    Offset? position,
    Size? size,
    bool? isFocused,
    bool? isMaximized,
    Widget? content,
  }) {
    return AppWindow(
      id: id,
      title: title,
      position: position ?? this.position,
      size: size ?? this.size,
      isFocused: isFocused ?? this.isFocused,
      isMaximized: isMaximized ?? this.isMaximized,
      content: content ?? this.content,
      createdAt: createdAt,
    );
  }
}

/// State notifier to manage the list of floating windows.
class WindowManager extends StateNotifier<List<AppWindow>> {
  WindowManager() : super([]);

  void openWindow(AppWindow window) {
    // Unfocus all other windows
    final updated = state.map((w) => w.copyWith(isFocused: false)).toList();
    
    // Check if window already exists
    final existingIndex = updated.indexWhere((w) => w.id == window.id);
    if (existingIndex >= 0) {
      final existing = updated.removeAt(existingIndex);
      updated.add(existing.copyWith(isFocused: true)); // Move to front
    } else {
      updated.add(window.copyWith(isFocused: true));
    }
    state = updated;
  }

  void toggleMaximize(String id) {
    state = [
      for (final w in state)
        if (w.id == id) w.copyWith(isMaximized: !w.isMaximized, isFocused: true) else w.copyWith(isFocused: false)
    ];
  }

  void closeWindow(String id) {
    final updated = state.where((w) => w.id != id).toList();
    if (updated.isNotEmpty && state.firstWhere((w) => w.id == id).isFocused) {
      // Focus the new top window if the closed one was focused
      final last = updated.removeLast();
      updated.add(last.copyWith(isFocused: true));
    }
    state = updated;
  }

  void focusWindow(String id) {
    final updated = state.map((w) => w.copyWith(isFocused: w.id == id)).toList();
    
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
  return WindowManager();
});

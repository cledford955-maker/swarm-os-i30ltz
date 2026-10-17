import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swarm_flutter/shell/window_manager.dart';

void main() {
  group('WindowManager', () {
    late WindowManager wm;
    int currentPage = 0;

    setUp(() {
      currentPage = 0;
      wm = WindowManager(
        () => currentPage,
        (page) => currentPage = page,
      );
    });

    test('openWindow adds window and sets focused', () {
      wm.openWindow(AppWindow(
        id: 'term',
        title: 'Terminal',
        position: const Offset(100, 100),
        size: const Size(600, 400),
        content: const SizedBox(),
      ));

      expect(wm.state.length, 1);
      final w = wm.state.first;
      expect(w.id, 'term');
      expect(w.isFocused, isTrue);
      expect(w.isMinimized, isFalse);
      expect(w.isMaximized, isFalse);
    });

    test('opening second window unfocuses first window on same page', () {
      wm.openWindow(AppWindow(
        id: 'term',
        title: 'Terminal',
        position: const Offset(100, 100),
        size: const Size(600, 400),
        content: const SizedBox(),
      ));
      wm.openWindow(AppWindow(
        id: 'files',
        title: 'Files',
        position: const Offset(200, 200),
        size: const Size(500, 350),
        content: const SizedBox(),
      ));

      expect(wm.state.length, 2);
      expect(wm.state.firstWhere((w) => w.id == 'term').isFocused, isFalse);
      expect(wm.state.firstWhere((w) => w.id == 'files').isFocused, isTrue);
    });

    test('toggleMinimize minimizes window and toggle again unminimizes', () {
      wm.openWindow(AppWindow(
        id: 'term',
        title: 'Terminal',
        position: const Offset(100, 100),
        size: const Size(600, 400),
        content: const SizedBox(),
      ));

      wm.toggleMinimize('term');
      expect(wm.state.first.isMinimized, isTrue);
      expect(wm.state.first.isFocused, isFalse);

      wm.toggleMinimize('term');
      expect(wm.state.first.isMinimized, isFalse);
      expect(wm.state.first.isFocused, isTrue);
    });

    test('re-opening an existing minimized window unminimizes and focuses it', () {
      final win = AppWindow(
        id: 'term',
        title: 'Terminal',
        position: const Offset(100, 100),
        size: const Size(600, 400),
        content: const SizedBox(),
      );
      wm.openWindow(win);
      wm.toggleMinimize('term');
      expect(wm.state.first.isMinimized, isTrue);

      wm.openWindow(win);
      expect(wm.state.first.isMinimized, isFalse);
      expect(wm.state.first.isFocused, isTrue);
    });

    test('closeWindow removes window and focuses top remaining window', () {
      wm.openWindow(AppWindow(
        id: 'w1',
        title: 'Window 1',
        position: const Offset(50, 50),
        size: const Size(400, 300),
        content: const SizedBox(),
      ));
      wm.openWindow(AppWindow(
        id: 'w2',
        title: 'Window 2',
        position: const Offset(100, 100),
        size: const Size(400, 300),
        content: const SizedBox(),
      ));

      expect(wm.state.firstWhere((w) => w.id == 'w2').isFocused, isTrue);

      wm.closeWindow('w2');
      expect(wm.state.length, 1);
      expect(wm.state.first.id, 'w1');
      expect(wm.state.first.isFocused, isTrue);
    });

    test('focusWindow brings window to front, unminimizes and sets focus', () {
      wm.openWindow(AppWindow(
        id: 'w1',
        title: 'Window 1',
        position: const Offset(50, 50),
        size: const Size(400, 300),
        content: const SizedBox(),
      ));
      wm.openWindow(AppWindow(
        id: 'w2',
        title: 'Window 2',
        position: const Offset(100, 100),
        size: const Size(400, 300),
        content: const SizedBox(),
      ));
      wm.toggleMinimize('w1');

      wm.focusWindow('w1');
      expect(wm.state.last.id, 'w1'); // moved to end of list (on top)
      expect(wm.state.last.isFocused, isTrue);
      expect(wm.state.last.isMinimized, isFalse);
      expect(wm.state.firstWhere((w) => w.id == 'w2').isFocused, isFalse);
    });

    test('toggleMaximize toggles maximization and unminimizes', () {
      wm.openWindow(AppWindow(
        id: 'w1',
        title: 'Window 1',
        position: const Offset(50, 50),
        size: const Size(400, 300),
        content: const SizedBox(),
      ));

      wm.toggleMaximize('w1');
      expect(wm.state.first.isMaximized, isTrue);
      expect(wm.state.first.isMinimized, isFalse);

      wm.toggleMaximize('w1');
      expect(wm.state.first.isMaximized, isFalse);
    });
  });
}

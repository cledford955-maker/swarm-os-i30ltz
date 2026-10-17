import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart' as wm;
import '../theme/swarm_colors.dart';
import 'window_manager.dart';

class PowerControls extends ConsumerWidget {
  const PowerControls({super.key});

  void _shutdownOS() async {
    await Process.run('systemctl', ['poweroff']);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final windows = ref.watch(windowProvider);
    final activeWindow =
        windows.where((w) => w.isFocused && !w.isMinimized).firstOrNull;

    return Row(
      children: [
        // Fullscreen toggle / recovery button (F11)
        IconButton(
          icon: const Icon(Icons.fullscreen, size: 18),
          color: SwarmColors.textMuted,
          hoverColor: SwarmColors.accent,
          tooltip: 'Toggle Fullscreen (F11)',
          onPressed: () async {
            final isFs = await wm.windowManager.isFullScreen();
            await wm.windowManager.setFullScreen(!isFs);
          },
        ),
        if (activeWindow != null) ...[
          IconButton(
            icon: const Icon(Icons.remove, size: 18),
            color: SwarmColors.textMuted,
            hoverColor: SwarmColors.accent,
            tooltip: 'Minimize ${activeWindow.title}',
            onPressed: () => ref
                .read(windowProvider.notifier)
                .toggleMinimize(activeWindow.id),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            color: SwarmColors.textMuted,
            hoverColor: Colors.redAccent,
            tooltip: 'Close ${activeWindow.title}',
            onPressed: () => ref
                .read(windowProvider.notifier)
                .closeWindow(activeWindow.id),
          ),
        ],
        const SizedBox(width: 8),
        Container(
          width: 1,
          height: 24,
          color: SwarmColors.border,
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.power_settings_new, size: 20),
          color: SwarmColors.statusCritical,
          hoverColor: Colors.red,
          tooltip: 'OS SHUTDOWN',
          onPressed: _shutdownOS,
        ),
      ],
    );
  }
}

class HardwareControls extends StatelessWidget {
  const HardwareControls({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.gamepad, size: 18),
          color: SwarmColors.lucille,
          tooltip: 'Gamepad Connected',
          onPressed: () {},
        ),
        IconButton(
          icon: const Icon(Icons.bluetooth, size: 18),
          color: SwarmColors.textMuted,
          tooltip: 'Bluetooth Settings',
          onPressed: () {},
        ),
        IconButton(
          icon: const Icon(Icons.wifi, size: 18),
          color: SwarmColors.textMuted,
          tooltip: 'NetworkManager',
          onPressed: () {},
        ),
        IconButton(
          icon: const Icon(Icons.volume_up, size: 18),
          color: SwarmColors.textMuted,
          tooltip: 'PipeWire Audio',
          onPressed: () {},
        ),
      ],
    );
  }
}

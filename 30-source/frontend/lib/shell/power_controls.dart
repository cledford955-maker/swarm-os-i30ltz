import 'dart:io';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import '../theme/swarm_colors.dart';

class PowerControls extends StatelessWidget {
  const PowerControls({super.key});

  void _shutdownOS() async {
    await Process.run('systemctl', ['poweroff']);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.minimize, size: 18),
          color: SwarmColors.textMuted,
          hoverColor: SwarmColors.accent,
          onPressed: () => windowManager.minimize(),
        ),
        IconButton(
          icon: const Icon(Icons.close, size: 18),
          color: SwarmColors.textMuted,
          hoverColor: Colors.redAccent,
          onPressed: () => windowManager.close(),
        ),
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

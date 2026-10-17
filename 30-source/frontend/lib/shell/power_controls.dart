import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:provider/provider.dart' as p;
import 'package:window_manager/window_manager.dart' as wm;
import '../theme/swarm_colors.dart';
import '../theme/swarm_text_styles.dart';
import '../services/volume_service.dart';
import '../services/bluetooth_service.dart';
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

/// Anchors a dismissible popover panel under a button using a
/// [LayerLink], so the panel tracks the button without manual
/// RenderBox offset math.
class _AnchoredPopoverButton extends StatefulWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final Widget Function(BuildContext context, VoidCallback close) popoverBuilder;
  const _AnchoredPopoverButton({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.popoverBuilder,
  });

  @override
  State<_AnchoredPopoverButton> createState() => _AnchoredPopoverButtonState();
}

class _AnchoredPopoverButtonState extends State<_AnchoredPopoverButton> {
  final LayerLink _link = LayerLink();
  OverlayEntry? _entry;

  void _toggle() {
    if (_entry != null) {
      _close();
    } else {
      _open();
    }
  }

  void _open() {
    final overlay = Overlay.of(context);
    _entry = OverlayEntry(
      builder: (context) => Stack(
        children: [
          // Outside-tap dismiss barrier.
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _close,
              child: const SizedBox.expand(),
            ),
          ),
          CompositedTransformFollower(
            link: _link,
            showWhenUnlinked: false,
            offset: const Offset(-180, 32),
            child: widget.popoverBuilder(context, _close),
          ),
        ],
      ),
    );
    overlay.insert(_entry!);
  }

  void _close() {
    _entry?.remove();
    _entry = null;
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _entry?.remove();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _link,
      child: IconButton(
        icon: Icon(widget.icon, size: 18),
        color: widget.color,
        tooltip: widget.tooltip,
        onPressed: () {
          setState(_toggle);
        },
      ),
    );
  }
}

Widget _popoverShell({required String title, required Widget child}) {
  return Material(
    color: Colors.transparent,
    child: Container(
      width: 260,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: SwarmColors.bgElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: SwarmColors.border),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.55), blurRadius: 24, offset: const Offset(0, 10)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, style: SwarmTextStyles.label),
          const SizedBox(height: 10),
          child,
        ],
      ),
    ),
  );
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
        _AnchoredPopoverButton(
          icon: Icons.bluetooth,
          color: SwarmColors.textMuted,
          tooltip: 'Bluetooth Settings',
          popoverBuilder: (context, close) => _popoverShell(
            title: 'BLUETOOTH',
            child: p.ChangeNotifierProvider.value(
              value: context.read<BluetoothService>(),
              child: const _BluetoothPanel(),
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.wifi, size: 18),
          color: SwarmColors.textMuted,
          tooltip: 'NetworkManager',
          onPressed: () {},
        ),
        _AnchoredPopoverButton(
          icon: Icons.volume_up,
          color: SwarmColors.textMuted,
          tooltip: 'PipeWire Audio',
          popoverBuilder: (context, close) => _popoverShell(
            title: 'VOLUME',
            child: p.ChangeNotifierProvider.value(
              value: context.read<VolumeService>(),
              child: const _VolumePanel(),
            ),
          ),
        ),
      ],
    );
  }
}

class _VolumePanel extends StatelessWidget {
  const _VolumePanel();

  @override
  Widget build(BuildContext context) {
    return p.Consumer<VolumeService>(
      builder: (context, vol, _) {
        if (!vol.available) {
          return Text(
            vol.error ?? 'Audio control unavailable',
            style: SwarmTextStyles.bodySmall,
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                IconButton(
                  padding: EdgeInsets.zero,
                  icon: Icon(
                    vol.muted || vol.volume == 0
                        ? Icons.volume_off
                        : (vol.volume < 0.5 ? Icons.volume_down : Icons.volume_up),
                    size: 18,
                    color: SwarmColors.accent,
                  ),
                  onPressed: vol.toggleMute,
                ),
                Expanded(
                  child: Slider(
                    value: vol.volume.clamp(0.0, 1.0),
                    activeColor: SwarmColors.accent,
                    onChanged: (v) => vol.setVolume(v),
                  ),
                ),
                SizedBox(
                  width: 36,
                  child: Text(
                    '${(vol.volume * 100).round()}%',
                    style: SwarmTextStyles.labelSmall,
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _BluetoothPanel extends StatelessWidget {
  const _BluetoothPanel();

  @override
  Widget build(BuildContext context) {
    return p.Consumer<BluetoothService>(
      builder: (context, bt, _) {
        if (!bt.available) {
          return Text(
            bt.error ?? 'Bluetooth unavailable',
            style: SwarmTextStyles.bodySmall,
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(bt.powered ? 'On' : 'Off', style: SwarmTextStyles.bodySmall),
                ),
                Switch(
                  value: bt.powered,
                  activeThumbColor: SwarmColors.accent,
                  onChanged: bt.setPowered,
                ),
              ],
            ),
            if (bt.powered) ...[
              const SizedBox(height: 6),
              if (bt.devices.isEmpty)
                Text('No paired devices', style: SwarmTextStyles.bodySmall)
              else
                ...bt.devices.map((d) => _DeviceRow(device: d)),
              const SizedBox(height: 6),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: bt.scanning ? null : bt.scan,
                  child: Text(bt.scanning ? 'Scanning…' : 'Scan for devices'),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _DeviceRow extends StatelessWidget {
  final BluetoothDevice device;
  const _DeviceRow({required this.device});

  @override
  Widget build(BuildContext context) {
    final bt = context.read<BluetoothService>();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(
            device.connected ? Icons.bluetooth_connected : Icons.bluetooth,
            size: 14,
            color: device.connected ? SwarmColors.accent : SwarmColors.textMuted,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              device.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: SwarmTextStyles.bodySmall,
            ),
          ),
          TextButton(
            style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(50, 28)),
            onPressed: () =>
                device.connected ? bt.disconnect(device.mac) : bt.connect(device.mac),
            child: Text(device.connected ? 'Disconnect' : 'Connect'),
          ),
        ],
      ),
    );
  }
}

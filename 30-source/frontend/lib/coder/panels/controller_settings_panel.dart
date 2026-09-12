import 'package:flutter/material.dart';
import '../../theme/swarm_colors.dart';
import '../../theme/swarm_text_styles.dart';
import '../controller_mode.dart';

class ControllerSettingsPanel extends StatefulWidget {
  const ControllerSettingsPanel({super.key});

  @override
  State<ControllerSettingsPanel> createState() => _ControllerSettingsPanelState();
}

class _ControllerSettingsPanelState extends State<ControllerSettingsPanel> {
  final _ctrl = ControllerMode.instance;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(_onChanged);
  }

  @override
  void dispose() {
    _ctrl.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() => setState(() {});

  static const _actionLabels = <ControllerAction, String>{
    ControllerAction.none:           '— None —',
    ControllerAction.radialMenu:     'Radial Menu',
    ControllerAction.virtualKeyboard:'Virtual Keyboard',
    ControllerAction.save:           'Save File',
    ControllerAction.closeTab:       'Close Tab',
    ControllerAction.nextTab:        'Next Tab',
    ControllerAction.prevTab:        'Previous Tab',
    ControllerAction.gitPanel:       'Open Git Panel',
    ControllerAction.terminal:       'Open Terminal',
    ControllerAction.search:         'Global Search',
    ControllerAction.run:            'Run Task',
    ControllerAction.split:          'Split Editor',
  };

  static const _buttonLabels = <int, String>{
    0:  'A / Cross',
    1:  'B / Circle',
    2:  'X / Square',
    3:  'Y / Triangle',
    4:  'LB / L1',
    5:  'RB / R1',
    6:  'LT / L2',
    7:  'RT / R2',
    8:  'Select / Share',
    9:  'Start / Options',
    10: 'L3 (Left Stick)',
    11: 'R3 (Right Stick)',
  };

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // Header
      Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: SwarmColors.border))),
        child: Row(children: [
          const Icon(Icons.sports_esports_rounded, size: 16, color: SwarmColors.agentPurple),
          const SizedBox(width: 8),
          Text('Controller / Gamepad', style: SwarmTextStyles.h2.copyWith(fontSize: 13)),
          const Spacer(),
          // Enable toggle
          Row(children: [
            Text('Enable', style: const TextStyle(fontSize: 11, color: SwarmColors.textMuted)),
            const SizedBox(width: 6),
            Switch(
              value: _ctrl.active,
              onChanged: (v) => v ? _ctrl.enable() : _ctrl.disable(),
              activeThumbColor: SwarmColors.agentPurple,
              trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? SwarmColors.agentPurple.withValues(alpha: 0.3) : SwarmColors.bgElevated),
            ),
          ]),
        ]),
      ),
      // Status bar
      _StatusBar(ctrl: _ctrl),
      const Divider(height: 1, color: SwarmColors.border),
      // Content
      Expanded(child: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Button mapping
          const _SLabel('BUTTON MAPPING'),
          const Text('Assign IDE actions to controller buttons.', style: TextStyle(fontSize: 11, color: SwarmColors.textMuted)),
          const SizedBox(height: 10),
          ..._buttonLabels.entries.map((e) => _ButtonRow(
            buttonIndex: e.key,
            buttonLabel: e.value,
            currentAction: _ctrl.buttonMap[e.key] ?? ControllerAction.none,
            actionLabels: _actionLabels,
            onChanged: (a) => _ctrl.setButtonAction(e.key, a),
          )),
          const SizedBox(height: 14),
          // Reset
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _ctrl.resetButtonMap,
              icon: const Icon(Icons.restart_alt_rounded, size: 14),
              label: const Text('Reset to defaults', style: TextStyle(fontSize: 12)),
              style: OutlinedButton.styleFrom(foregroundColor: SwarmColors.textMuted, side: const BorderSide(color: SwarmColors.border), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)), padding: const EdgeInsets.symmetric(vertical: 8)),
            ),
          ),
          const SizedBox(height: 14),
          // Axis / sensitivity info
          const _SLabel('AXIS NAVIGATION'),
          _InfoBox(
            icon: Icons.gamepad_rounded,
            text: 'Left stick: scroll editor / navigate code\nRight stick X: switch tabs\nD-pad: navigate file explorer\nHold RB + stick: seek in file',
          ),
          const SizedBox(height: 10),
          const _SLabel('QUICK REFERENCE'),
          _InfoBox(
            icon: Icons.info_outline_rounded,
            text: 'Hold RB → radial action menu\nLB → on-screen virtual keyboard\nSelect + Start → toggle controller mode\nHold A+B (3s) → emergency disable',
          ),
        ]),
      )),
    ]);
  }
}

// ─── Status bar ───────────────────────────────────────────────────────────────
class _StatusBar extends StatelessWidget {
  final ControllerMode ctrl;
  const _StatusBar({required this.ctrl});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        color: SwarmColors.bgSurface,
        child: Row(children: [
          Container(
            width: 8, height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: ctrl.connected ? SwarmColors.agentEmerald : (ctrl.active ? SwarmColors.agentAmber : SwarmColors.textDisabled),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(
            ctrl.connected
                ? 'Controller connected: ${ctrl.devicePath ?? "unknown"}'
                : (ctrl.active ? 'Scanning for controller... (js0/js1)' : 'Controller mode disabled'),
            style: TextStyle(fontSize: 11, color: ctrl.connected ? SwarmColors.agentEmerald : SwarmColors.textMuted),
          )),
          if (!ctrl.connected && ctrl.active)
            const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 1.5, color: SwarmColors.agentAmber)),
        ]),
      );
}

// ─── Button row ───────────────────────────────────────────────────────────────
class _ButtonRow extends StatelessWidget {
  final int buttonIndex;
  final String buttonLabel;
  final ControllerAction currentAction;
  final Map<ControllerAction, String> actionLabels;
  final ValueChanged<ControllerAction> onChanged;

  const _ButtonRow({required this.buttonIndex, required this.buttonLabel, required this.currentAction, required this.actionLabels, required this.onChanged});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(children: [
          // Button badge
          Container(
            width: 28, height: 20,
            decoration: BoxDecoration(color: SwarmColors.agentPurple.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(3), border: Border.all(color: SwarmColors.agentPurple.withValues(alpha: 0.3))),
            child: Center(child: Text('B$buttonIndex', style: const TextStyle(fontSize: 9, color: SwarmColors.agentPurple, fontWeight: FontWeight.bold, fontFamily: 'monospace'))),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(buttonLabel, style: const TextStyle(fontSize: 11, color: SwarmColors.textSecondary))),
          const SizedBox(width: 8),
          // Dropdown
          SizedBox(
            width: 150,
            child: DropdownButton<ControllerAction>(
              value: currentAction,
              isDense: true,
              dropdownColor: SwarmColors.bgElevated,
              underline: Container(height: 1, color: SwarmColors.border),
              style: const TextStyle(fontSize: 11, color: SwarmColors.textPrimary),
              items: actionLabels.entries.map((e) => DropdownMenuItem(
                value: e.key,
                child: Text(e.value, style: TextStyle(fontSize: 11, color: e.key == ControllerAction.none ? SwarmColors.textDisabled : SwarmColors.textPrimary)),
              )).toList(),
              onChanged: (v) { if (v != null) onChanged(v); },
            ),
          ),
        ]),
      );
}

// ─── Info box ─────────────────────────────────────────────────────────────────
class _InfoBox extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoBox({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: SwarmColors.bgElevated, borderRadius: BorderRadius.circular(6), border: Border.all(color: SwarmColors.border)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 14, color: SwarmColors.textDisabled),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 11, color: SwarmColors.textMuted, height: 1.6))),
        ]),
      );
}

class _SLabel extends StatelessWidget {
  final String text;
  const _SLabel(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: SwarmColors.textMuted, letterSpacing: 1.2)),
      );
}

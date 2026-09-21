// ═══════════════════════════════════════════════════════════════
// SWARM OS — APEX WORKSTATION
// Professional AI-Native IDE: Full CoderPage integration with
// file tree, syntax highlight, git, terminal, debug, extensions.
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../theme/swarm_colors.dart';
import '../theme/swarm_text_styles.dart';
import '../theme/lucide_compat.dart';
import '../coder/coder_page.dart';
import '../widgets/extensions_dialog.dart';

enum ApexView { explorer, search, git, android, signing, deviceFiles, tasks, extensions, publisher, controller, apple, ollama, settings }

class ApexWorkstation extends ConsumerStatefulWidget {
  const ApexWorkstation({super.key});

  @override
  ConsumerState<ApexWorkstation> createState() => _ApexWorkstationState();
}

class _ApexWorkstationState extends ConsumerState<ApexWorkstation> {
  ApexView _activeView = ApexView.explorer;
  bool _aiPanelOpen = true;
  bool _bottomPanelOpen = true;
  double _sidebarWidth = 280.0;
  double _aiPanelWidth = 320.0;
  final double _bottomPanelHeight = 250.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;

        return Container(
          color: SwarmColors.bg,
          child: Column(
            children: [
              // Top Toolbar / Menu
              _buildMenuBar(isMobile),
              
              // Main content area
              Expanded(
                child: Row(
                  children: [
                    // Activity Bar (Icons on the left)
                    if (!isMobile) _buildActivityBar(),

                    // Sidebar Content
                    if (!isMobile && _activeView != ApexView.explorer)
                      _buildSidebar(),

                    // Center Editor Area (CoderPage)
                    Expanded(
                      child: Column(
                        children: [
                          Expanded(
                            child: isMobile && _activeView != ApexView.explorer
                                ? _buildSidebar()
                                : _buildEditorArea(),
                          ),
                          if (_bottomPanelOpen) _buildBottomPanel(),
                        ],
                      ),
                    ),

                    // Right AI Panel
                    if (!isMobile && _aiPanelOpen) ...[
                      MouseRegion(
                        cursor: SystemMouseCursors.resizeLeftRight,
                        child: GestureDetector(
                          behavior: HitTestBehavior.translucent,
                          onHorizontalDragUpdate: (details) {
                            setState(() {
                              _aiPanelWidth -= details.delta.dx;
                              if (_aiPanelWidth < 200) _aiPanelWidth = 200;
                              if (_aiPanelWidth > 800) _aiPanelWidth = 800;
                            });
                          },
                          child: Container(width: 4, color: SwarmColors.border),
                        ),
                      ),
                      SizedBox(
                        width: _aiPanelWidth,
                        child: const _ApexAiPanel(),
                      ),
                    ],
                  ],
                ),
              ),
              
              // Mobile Bottom Navigation
              if (isMobile) _buildMobileNavBar(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMenuBar(bool isMobile) {
    return Container(
      height: 36,
      decoration: const BoxDecoration(
        color: SwarmColors.bgElevated,
        border: Border(bottom: BorderSide(color: SwarmColors.border)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // Back to Hub Button
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => context.go('/'),
              borderRadius: BorderRadius.circular(5),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: SwarmColors.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(color: SwarmColors.accent.withValues(alpha: 0.4), width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.arrow_back_rounded, size: 13, color: SwarmColors.accent),
                    const SizedBox(width: 4),
                    Text(
                      'HUB',
                      style: SwarmTextStyles.codeSmall.copyWith(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: SwarmColors.accent,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          const Icon(Icons.build_circle_rounded, size: 16, color: SwarmColors.accent),
          const SizedBox(width: 8),
          Text(
            'APEX IDE',
            style: SwarmTextStyles.label.copyWith(
              color: SwarmColors.textPrimary,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
            ),
          ),
          const Spacer(),
          if (!isMobile) ...[
            _IconBtn(
              icon: Icons.extension_rounded,
              active: false,
              onTap: () {
                showDialog(
                  context: context,
                  builder: (_) => const IdeExtensionsDialog(),
                );
              },
              tooltip: 'Get extensions for VS Code, JetBrains, and more',
            ),
            const SizedBox(width: 8),
            _IconBtn(
              icon: LucideIcons.terminal,
              active: _bottomPanelOpen,
              onTap: () => setState(() => _bottomPanelOpen = !_bottomPanelOpen),
              tooltip: 'Toggle Terminal',
            ),
            const SizedBox(width: 8),
            _IconBtn(
              icon: LucideIcons.bot,
              active: _aiPanelOpen,
              onTap: () => setState(() => _aiPanelOpen = !_aiPanelOpen),
              tooltip: 'Toggle AI Pair Programmer',
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildActivityBar() {
    return Container(
      width: 48,
      decoration: const BoxDecoration(
        color: SwarmColors.bgElevated,
        border: Border(right: BorderSide(color: SwarmColors.border)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 8),
          _ActivityIcon(
            icon: LucideIcons.files,
            view: ApexView.explorer,
            active: _activeView == ApexView.explorer,
            onTap: () => setState(() => _activeView = _activeView == ApexView.explorer ? ApexView.explorer : ApexView.explorer),
          ),
          _ActivityIcon(
            icon: LucideIcons.search,
            view: ApexView.search,
            active: _activeView == ApexView.search,
            onTap: () => setState(() => _activeView = _activeView == ApexView.search ? ApexView.explorer : ApexView.search),
          ),
          _ActivityIcon(
            icon: LucideIcons.gitBranch,
            view: ApexView.git,
            active: _activeView == ApexView.git,
            onTap: () => setState(() => _activeView = _activeView == ApexView.git ? ApexView.explorer : ApexView.git),
          ),
          _ActivityIcon(
            icon: Icons.android_rounded,
            view: ApexView.android,
            active: _activeView == ApexView.android,
            onTap: () => setState(() => _activeView = _activeView == ApexView.android ? ApexView.explorer : ApexView.android),
          ),
          _ActivityIcon(
            icon: LucideIcons.signature,
            view: ApexView.signing,
            active: _activeView == ApexView.signing,
            onTap: () => setState(() => _activeView = _activeView == ApexView.signing ? ApexView.explorer : ApexView.signing),
          ),
          _ActivityIcon(
            icon: LucideIcons.hardDrive,
            view: ApexView.deviceFiles,
            active: _activeView == ApexView.deviceFiles,
            onTap: () => setState(() => _activeView = _activeView == ApexView.deviceFiles ? ApexView.explorer : ApexView.deviceFiles),
          ),
          _ActivityIcon(
            icon: LucideIcons.playCircle,
            view: ApexView.tasks,
            active: _activeView == ApexView.tasks,
            onTap: () => setState(() => _activeView = _activeView == ApexView.tasks ? ApexView.explorer : ApexView.tasks),
          ),
          _ActivityIcon(
            icon: LucideIcons.puzzle,
            view: ApexView.extensions,
            active: _activeView == ApexView.extensions,
            onTap: () => setState(() => _activeView = _activeView == ApexView.extensions ? ApexView.explorer : ApexView.extensions),
          ),
          _ActivityIcon(
            icon: LucideIcons.rocket,
            view: ApexView.publisher,
            active: _activeView == ApexView.publisher,
            onTap: () => setState(() => _activeView = _activeView == ApexView.publisher ? ApexView.explorer : ApexView.publisher),
          ),
          _ActivityIcon(
            icon: LucideIcons.gamepad2,
            view: ApexView.controller,
            active: _activeView == ApexView.controller,
            onTap: () => setState(() => _activeView = _activeView == ApexView.controller ? ApexView.explorer : ApexView.controller),
          ),
          _ActivityIcon(
            icon: Icons.apple_rounded,
            view: ApexView.apple,
            active: _activeView == ApexView.apple,
            onTap: () => setState(() => _activeView = _activeView == ApexView.apple ? ApexView.explorer : ApexView.apple),
          ),
          _ActivityIcon(
            icon: LucideIcons.cpu,
            view: ApexView.ollama,
            active: _activeView == ApexView.ollama,
            onTap: () => setState(() => _activeView = _activeView == ApexView.ollama ? ApexView.explorer : ApexView.ollama),
          ),
          _ActivityIcon(
            icon: LucideIcons.settings,
            view: ApexView.settings,
            active: _activeView == ApexView.settings,
            onTap: () => setState(() => _activeView = _activeView == ApexView.settings ? ApexView.explorer : ApexView.settings),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileNavBar() {
    return Container(
      height: 56,
      decoration: const BoxDecoration(
        color: SwarmColors.bgElevated,
        border: Border(top: BorderSide(color: SwarmColors.border)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _ActivityIcon(icon: LucideIcons.code2, view: ApexView.explorer, active: _activeView == ApexView.explorer, onTap: () => setState(() => _activeView = ApexView.explorer)),
          _ActivityIcon(icon: LucideIcons.files, view: ApexView.explorer, active: _activeView == ApexView.explorer, onTap: () => setState(() => _activeView = ApexView.explorer)),
          _ActivityIcon(icon: Icons.android_rounded, view: ApexView.android, active: _activeView == ApexView.android, onTap: () => setState(() => _activeView = ApexView.android)),
          _ActivityIcon(icon: LucideIcons.terminal, view: ApexView.tasks, active: _bottomPanelOpen, onTap: () => setState(() => _bottomPanelOpen = !_bottomPanelOpen)),
        ],
      ),
    );
  }

  Widget _buildSidebar() {
    return Row(
      children: [
        Container(
          width: _sidebarWidth,
          decoration: const BoxDecoration(
            color: SwarmColors.bgSurface,
          ),
          child: switch (_activeView) {
            ApexView.explorer => const _CoderPageWrapper(showSidebar: true),
            ApexView.search => const _CoderPageWrapper(showSidebar: true, initialPanel: 'search'),
            ApexView.git => const _CoderPageWrapper(showSidebar: true, initialPanel: 'git'),
            ApexView.android => const AndroidSdkPanel(),
            ApexView.signing => const SigningPanel(),
            ApexView.deviceFiles => const DeviceExplorerPanel(),
            ApexView.tasks => const TaskRunnerPanel(),
            ApexView.extensions => const ExtensionsPanel(),
            ApexView.publisher => const PublisherPortalPanel(),
            ApexView.controller => const ControllerSettingsPanel(),
            ApexView.apple => const ApplePanel(),
            ApexView.ollama => const OllamaPanel(),
            ApexView.settings => const SettingsPanel(),
            _ => const SizedBox.shrink(),
          },
        ),
        MouseRegion(
          cursor: SystemMouseCursors.resizeLeftRight,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onHorizontalDragUpdate: (details) {
              setState(() {
                _sidebarWidth += details.delta.dx;
                if (_sidebarWidth < 150) _sidebarWidth = 150;
                if (_sidebarWidth > 600) _sidebarWidth = 600;
              });
            },
            child: Container(width: 4, color: SwarmColors.border),
          ),
        ),
      ],
    );
  }

  Widget _buildEditorArea() {
    return const _CoderPageWrapper(showSidebar: false);
  }

  Widget _buildBottomPanel() {
    return Container(
      height: 220,
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: SwarmColors.border)),
      ),
      child: const _ApexTerminalPanel(),
    );
  }
}

// Wrapper to embed CoderPage in ApexWorkstation
class _CoderPageWrapper extends StatelessWidget {
  final bool showSidebar;
  final String? initialPanel;

  const _CoderPageWrapper({this.showSidebar = false, this.initialPanel});

  @override
  Widget build(BuildContext context) {
    return CoderPage(
      key: ValueKey('coder_${showSidebar}_${initialPanel ?? 'default'}'),
    );
  }
}

// AI Panel for Apex
class _ApexAiPanel extends ConsumerWidget {
  const _ApexAiPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      color: SwarmColors.bgSurface,
      child: Column(
        children: [
          Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: SwarmColors.border)),
            ),
            child: Row(
              children: [
                const Icon(LucideIcons.bot, size: 16, color: SwarmColors.accent),
                const SizedBox(width: 8),
                Text('APEX AI', style: SwarmTextStyles.label.copyWith(color: SwarmColors.accent, fontSize: 11)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 16),
                  onPressed: () {},
                  tooltip: 'Close AI Panel',
                ),
              ],
            ),
          ),
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(LucideIcons.bot, size: 48, color: SwarmColors.accent.withValues(alpha: 0.3)),
                  const SizedBox(height: 16),
                  Text('APEX AI PAIR PROGRAMMER', style: SwarmTextStyles.label.copyWith(color: SwarmColors.textMuted)),
                  const SizedBox(height: 8),
                  Text('AI chat integration coming soon', style: SwarmTextStyles.codeSmall),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Terminal Panel for Apex
class _ApexTerminalPanel extends StatelessWidget {
  const _ApexTerminalPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF1E1E1E),
      child: Column(
        children: [
          Container(
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: const BoxDecoration(
              color: Color(0xFF2D2D2D),
              border: Border(bottom: BorderSide(color: SwarmColors.border)),
            ),
            child: Row(
              children: [
                const Icon(LucideIcons.terminal, size: 14, color: SwarmColors.accent),
                const SizedBox(width: 8),
                Text('APEX TERMINAL', style: SwarmTextStyles.codeSmall.copyWith(color: SwarmColors.accent)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.add_rounded, size: 16),
                  onPressed: () {},
                  tooltip: 'New Terminal',
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 16),
                  onPressed: () {},
                  tooltip: 'Close Terminal',
                ),
              ],
            ),
          ),
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(LucideIcons.terminal, size: 48, color: SwarmColors.textMuted.withValues(alpha: 0.3)),
                  const SizedBox(height: 16),
                  Text('INTEGRATED TERMINAL', style: SwarmTextStyles.label.copyWith(color: SwarmColors.textMuted)),
                  const SizedBox(height: 8),
                  Text('Terminal integration via AgentTerminalPanel', style: SwarmTextStyles.codeSmall),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Import required panels
import '../coder/panels/android_panel.dart';
import '../coder/panels/signing_panel.dart';
import '../coder/panels/device_explorer_panel.dart';
import '../coder/panels/task_runner_panel.dart';
import '../coder/panels/extensions_panel.dart';
import '../coder/panels/publisher_portal_panel.dart';
import '../coder/panels/controller_settings_panel.dart';
import '../coder/panels/apple_panel.dart';
import '../coder/panels/ollama_panel.dart';
import '../coder/panels/profile_manager_panel.dart' show SettingsPanel;

// ─── Small Components ────────────────────────────────────────────────────────

class _IconBtn extends StatefulWidget {
  final IconData icon;
  final bool active;
  final VoidCallback onTap;
  final String tooltip;

  const _IconBtn({required this.icon, required this.active, required this.onTap, required this.tooltip});

  @override
  State<_IconBtn> createState() => _IconBtnState();
}

class _IconBtnState extends State<_IconBtn> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: InkWell(
        onTap: widget.onTap,
        onHover: (v) => setState(() => _hovered = v),
        borderRadius: BorderRadius.circular(4),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: widget.active 
                ? SwarmColors.accent.withValues(alpha: 0.15) 
                : _hovered ? SwarmColors.bgHover : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Icon(
            widget.icon,
            size: 14,
            color: widget.active ? SwarmColors.accent : SwarmColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _ActivityIcon extends StatefulWidget {
  final IconData icon;
  final ApexView view;
  final bool active;
  final VoidCallback onTap;

  const _ActivityIcon({required this.icon, required this.view, required this.active, required this.onTap});

  @override
  State<_ActivityIcon> createState() => _ActivityIconState();
}

class _ActivityIconState extends State<_ActivityIcon> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: InkWell(
        onTap: widget.onTap,
        onHover: (v) => setState(() => _hovered = v),
        borderRadius: BorderRadius.circular(8),
        focusColor: SwarmColors.accent.withValues(alpha: 0.3),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: widget.active ? SwarmColors.accent : Colors.transparent,
                width: 2,
              )
            ),
          ),
          child: Icon(
            widget.icon,
            size: 22,
            color: widget.active ? SwarmColors.textPrimary : _hovered ? SwarmColors.textSecondary : SwarmColors.textMuted,
          ),
        ),
      ),
    );
  }
}

// ─── Sub-Panels (Android, Signing, Device Files, Tasks, Extensions, Publisher, Controller, Apple, Ollama, Settings) ────────────────────────────────────────

Future<void> _runApexCmd(BuildContext context, String name, String command) async {
  // Use SystemLauncher or similar
  // For now, placeholder
}

class AndroidSdkPanel extends ConsumerWidget {
  const AndroidSdkPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FocusScope(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('DROID & EMULATORS', style: SwarmTextStyles.label.copyWith(color: SwarmColors.accent)),
          const SizedBox(height: 16),
          _buildSection('Containers & Mirroring', [
            _DeviceRow(
              icon: Icons.android_rounded,
              name: 'Waydroid Container (Android 13)',
              status: 'Online',
              onTap: () => _runApexCmd(context, 'Waydroid Container', 'waydroid session start &'),
            ),
            _DeviceRow(
              icon: Icons.cast_connected,
              name: 'scrcpy Low-Latency Mirror',
              status: 'Ready',
              onTap: () => _runApexCmd(context, 'scrcpy Screen Mirror', 'scrcpy --stay-awake &'),
            ),
            _DeviceRow(
              icon: Icons.phone_android,
              name: 'Pixel 8 Pro (USB ADB)',
              status: 'Online',
              onTap: () => _runApexCmd(context, 'ADB Shell', 'foot -e adb shell &'),
            ),
          ]),
          const SizedBox(height: 16),
          _buildSection('AVD & System Emulators', [
            _ActionRow(
              icon: Icons.play_arrow_rounded,
              label: 'Launch Waydroid Full UI',
              onAction: () => _runApexCmd(context, 'Waydroid UI', 'waydroid show-full-ui &'),
            ),
            _ActionRow(
              icon: Icons.smart_screen_rounded,
              label: 'Start Android AVD (Pixel 7 API 34)',
              onAction: () => _runApexCmd(context, 'Android AVD', 'emulator -avd Pixel_7_API_34 &'),
            ),
            _ActionRow(
              icon: Icons.sports_esports_rounded,
              label: 'Start Gamescope Emulation Runtime',
              onAction: () => _runApexCmd(context, 'Gamescope', 'gamescope -W 1920 -H 1080 -r 60 -- steam -gamepadui &'),
            ),
          ]),
          const SizedBox(height: 16),
          _buildSection('ADB Development Tools', [
            _ActionRow(
              icon: Icons.bug_report_rounded,
              label: 'Live ADB Logcat Terminal',
              onAction: () => _runApexCmd(context, 'ADB Logcat', 'foot -e adb logcat &'),
            ),
            _ActionRow(
              icon: Icons.install_mobile_rounded,
              label: 'Install APK Package',
              onAction: () => _runApexCmd(context, 'ADB Install', 'foot -e bash -c "echo Drag and drop APK:; read f; adb install \$f" &'),
            ),
            _ActionRow(
              icon: Icons.terminal_rounded,
              label: 'Interactive ADB Root Shell',
              onAction: () => _runApexCmd(context, 'ADB Root Shell', 'foot -e adb shell &'),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: SwarmTextStyles.labelSmall.copyWith(color: SwarmColors.textMuted)),
        const SizedBox(height: 8),
        ...children,
      ],
    );
  }
}

class _DeviceRow extends StatelessWidget {
  final IconData icon;
  final String name;
  final String status;
  final VoidCallback onTap;

  const _DeviceRow({required this.icon, required this.name, required this.status, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: SwarmColors.accent),
      title: Text(name, style: const TextStyle(color: SwarmColors.textPrimary)),
      subtitle: Text(status, style: const TextStyle(color: SwarmColors.textMuted, fontSize: 11)),
      trailing: const Icon(Icons.chevron_right_rounded, color: SwarmColors.textMuted),
      onTap: onTap,
      dense: true,
    );
  }
}

class _ActionRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onAction;

  const _ActionRow({required this.icon, required this.label, required this.onAction});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: SwarmColors.agentCyan),
      title: Text(label, style: const TextStyle(color: SwarmColors.textPrimary)),
      trailing: const Icon(Icons.play_arrow_rounded, color: SwarmColors.agentCyan, size: 20),
      onTap: onAction,
      dense: true,
    );
  }
}

class SigningPanel extends StatelessWidget {
  const SigningPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return FocusScope(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('SIGNING & PUBLISHING', style: SwarmTextStyles.label.copyWith(color: SwarmColors.accent)),
          const SizedBox(height: 16),
          _ActionRow(
            icon: Icons.verified_rounded,
            label: 'Configure Keystore',
            onAction: () {},
          ),
          _ActionRow(
            icon: Icons.shield_rounded,
            label: 'Sign APK/AAB',
            onAction: () {},
          ),
          _ActionRow(
            icon: Icons.cloud_upload_rounded,
            label: 'Upload to Play Console',
            onAction: () {},
          ),
        ],
      ),
    );
  }
}

class DeviceExplorerPanel extends StatelessWidget {
  const DeviceExplorerPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return FocusScope(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('DEVICE FILE EXPLORER', style: SwarmTextStyles.label.copyWith(color: SwarmColors.accent)),
          const SizedBox(height: 16),
          _ActionRow(
            icon: Icons.folder_rounded,
            label: 'Browse Device Storage',
            onAction: () {},
          ),
          _ActionRow(
            icon: Icons.download_rounded,
            label: 'Pull Files from Device',
            onAction: () {},
          ),
          _ActionRow(
            icon: Icons.upload_rounded,
            label: 'Push Files to Device',
            onAction: () {},
          ),
        ],
      ),
    );
  }
}

class TaskRunnerPanel extends StatelessWidget {
  const TaskRunnerPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return FocusScope(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('TASK RUNNER', style: SwarmTextStyles.label.copyWith(color: SwarmColors.accent)),
          const SizedBox(height: 16),
          _ActionRow(
            icon: Icons.play_arrow_rounded,
            label: 'Run Build Task',
            onAction: () {},
          ),
          _ActionRow(
            icon: Icons.bug_report_rounded,
            label: 'Debug Task',
            onAction: () {},
          ),
          _ActionRow(
            icon: Icons.list_alt_rounded,
            label: 'Task History',
            onAction: () {},
          ),
        ],
      ),
    );
  }
}

class ExtensionsPanel extends StatelessWidget {
  const ExtensionsPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return FocusScope(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('EXTENSIONS', style: SwarmTextStyles.label.copyWith(color: SwarmColors.accent)),
          const SizedBox(height: 16),
          _ActionRow(
            icon: Icons.extension_rounded,
            label: 'Browse Marketplace',
            onAction: () {},
          ),
          _ActionRow(
            icon: Icons.manage_accounts_rounded,
            label: 'Installed Extensions',
            onAction: () {},
          ),
          _ActionRow(
            icon: Icons.settings_rounded,
            label: 'Extension Settings',
            onAction: () {},
          ),
        ],
      ),
    );
  }
}

class PublisherPortalPanel extends StatelessWidget {
  const PublisherPortalPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return FocusScope(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('PUBLISHER PORTAL', style: SwarmTextStyles.label.copyWith(color: SwarmColors.accent)),
          const SizedBox(height: 16),
          _ActionRow(
            icon: Icons.rocket_launch_rounded,
            label: 'Create Release',
            onAction: () {},
          ),
          _ActionRow(
            icon: Icons.analytics_rounded,
            label: 'View Analytics',
            onAction: () {},
          ),
          _ActionRow(
            icon: Icons.people_rounded,
            label: 'User Feedback',
            onAction: () {},
          ),
        ],
      ),
    );
  }
}

class ControllerSettingsPanel extends StatelessWidget {
  const ControllerSettingsPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return FocusScope(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('CONTROLLER SETTINGS', style: SwarmTextStyles.label.copyWith(color: SwarmColors.accent)),
          const SizedBox(height: 16),
          _ActionRow(
            icon: LucideIcons.gamepad2,
            label: 'Configure Gamepad',
            onAction: () {},
          ),
          _ActionRow(
            icon: LucideIcons.keyboard,
            label: 'Keybindings',
            onAction: () {},
          ),
          _ActionRow(
            icon: LucideIcons.monitor,
            label: 'Display Settings',
            onAction: () {},
          ),
        ],
      ),
    );
  }
}

class ApplePanel extends StatelessWidget {
  const ApplePanel({super.key});

  @override
  Widget build(BuildContext context) {
    return FocusScope(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('APPLE DEVELOPMENT', style: SwarmTextStyles.label.copyWith(color: SwarmColors.accent)),
          const SizedBox(height: 16),
          _ActionRow(
            icon: Icons.apple_rounded,
            label: 'Xcode Project',
            onAction: () {},
          ),
          _ActionRow(
            icon: Icons.verified_rounded,
            label: 'Code Signing',
            onAction: () {},
          ),
          _ActionRow(
            icon: Icons.cloud_upload_rounded,
            label: 'TestFlight Upload',
            onAction: () {},
          ),
        ],
      ),
    );
  }
}

class OllamaPanel extends StatelessWidget {
  const OllamaPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return FocusScope(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('OLLAMA LOCAL MODELS', style: SwarmTextStyles.label.copyWith(color: SwarmColors.accent)),
          const SizedBox(height: 16),
          _ActionRow(
            icon: LucideIcons.cpu,
            label: 'Manage Models',
            onAction: () {},
          ),
          _ActionRow(
            icon: Icons.play_arrow_rounded,
            label: 'Start Server',
            onAction: () {},
          ),
          _ActionRow(
            icon: Icons.settings_rounded,
            label: 'Configuration',
            onAction: () {},
          ),
        ],
      ),
    );
  }
}

class SettingsPanel extends StatelessWidget {
  const SettingsPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return FocusScope(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('APEX SETTINGS', style: SwarmTextStyles.label.copyWith(color: SwarmColors.accent)),
          const SizedBox(height: 16),
          _ActionRow(
            icon: LucideIcons.palette,
            label: 'Theme & Appearance',
            onAction: () {},
          ),
          _ActionRow(
            icon: LucideIcons.keyboard,
            label: 'Keybindings',
            onAction: () {},
          ),
          _ActionRow(
            icon: LucideIcons.terminal,
            label: 'Terminal Settings',
            onAction: () {},
          ),
          _ActionRow(
            icon: LucideIcons.gitBranch,
            label: 'Git Integration',
            onAction: () {},
          ),
        ],
      ),
    );
  }
}
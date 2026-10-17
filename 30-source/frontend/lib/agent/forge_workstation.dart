import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../theme/swarm_colors.dart';
import '../services/system_launcher.dart';
import '../theme/swarm_text_styles.dart';
import '../theme/lucide_compat.dart';
import 'vault_browser.dart'; // We can reuse the file browser
import '../hub/agent_terminal.dart';
import 'agent_chat.dart';
import '../widgets/extensions_dialog.dart';

enum ForgeView { explorer, android, vms, network, multi, code }

class ForgeWorkstation extends ConsumerStatefulWidget {
  const ForgeWorkstation({super.key});

  @override
  ConsumerState<ForgeWorkstation> createState() => _ForgeWorkstationState();
}

class _ForgeWorkstationState extends ConsumerState<ForgeWorkstation> {
  ForgeView _activeView = ForgeView.code;
  bool _aiPanelOpen = true;
  bool _bottomPanelOpen = true;
  double _sidebarWidth = 280.0;
  double _aiPanelWidth = 320.0;

  @override
  Widget build(BuildContext context) {
    // LayoutBuilder makes it responsive (Mobile vs Desktop)
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

                    // Sidebar Content (Explorer, Android, VMs)
                    if (!isMobile && _activeView != ForgeView.code)
                      _buildSidebar(),

                    // Center Editor & Bottom Panel
                    Expanded(
                      child: Column(
                        children: [
                          Expanded(
                            child: isMobile && _activeView != ForgeView.code
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
                        child: const AgentChatPanel(agentId: 'forge'),
                      ),
                    ],
                  ],
                ),
              ),
              
              // Mobile Bottom Navigation (replaces Activity Bar)
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
            'FORGE AT LUCILLE\'S CORE',
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
              tooltip: 'Get the new extensions for VS Code, JetBrains, and more',
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
            view: ForgeView.explorer,
            active: _activeView == ForgeView.explorer,
            onTap: () => setState(() => _activeView = _activeView == ForgeView.explorer ? ForgeView.code : ForgeView.explorer),
          ),
          _ActivityIcon(
            icon: Icons.android_rounded,
            view: ForgeView.android,
            active: _activeView == ForgeView.android,
            onTap: () => setState(() => _activeView = _activeView == ForgeView.android ? ForgeView.code : ForgeView.android),
          ),
          _ActivityIcon(
            icon: LucideIcons.boxes,
            view: ForgeView.vms,
            active: _activeView == ForgeView.vms,
            onTap: () => setState(() => _activeView = _activeView == ForgeView.vms ? ForgeView.code : ForgeView.vms),
          ),
          _ActivityIcon(
            icon: LucideIcons.layers,
            view: ForgeView.multi,
            active: _activeView == ForgeView.multi,
            onTap: () => setState(() => _activeView = _activeView == ForgeView.multi ? ForgeView.code : ForgeView.multi),
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
          _ActivityIcon(icon: LucideIcons.code2, view: ForgeView.code, active: _activeView == ForgeView.code, onTap: () => setState(() => _activeView = ForgeView.code)),
          _ActivityIcon(icon: LucideIcons.files, view: ForgeView.explorer, active: _activeView == ForgeView.explorer, onTap: () => setState(() => _activeView = ForgeView.explorer)),
          _ActivityIcon(icon: Icons.android_rounded, view: ForgeView.android, active: _activeView == ForgeView.android, onTap: () => setState(() => _activeView = ForgeView.android)),
          _ActivityIcon(icon: LucideIcons.terminal, view: ForgeView.vms, active: _bottomPanelOpen, onTap: () => setState(() => _bottomPanelOpen = !_bottomPanelOpen)),
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
            ForgeView.explorer => const VaultFileBrowser(),
            ForgeView.android => const AndroidSdkPanel(),
            ForgeView.vms => const VmManagerPanel(),
            ForgeView.multi => const MultiPlatformPanel(),
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
    return Container(
      color: const Color(0xFF1E1E1E), // standard VS Code dark bg
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(LucideIcons.code2, size: 48, color: SwarmColors.textMuted.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            Text('FORGE CODE EDITOR', style: SwarmTextStyles.label.copyWith(color: SwarmColors.textMuted)),
            const SizedBox(height: 8),
            Text('Select a file from Explorer to begin', style: SwarmTextStyles.codeSmall),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomPanel() {
    return Container(
      height: 220,
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: SwarmColors.border)),
      ),
      child: const AgentTerminalPanel(
        agentId: 'forge',
        agentName: 'Forge Terminal',
        accentColor: SwarmColors.accent,
      ),
    );
  }
}

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
  final ForgeView view;
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
      child: InkWell( // InkWell auto-supports D-pad/keyboard Focus traversal!
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

// ─── Sub-Panels (Android, VMs, Multi) ────────────────────────────────────────

Future<void> _runForgeCmd(BuildContext context, String name, String command) async {
  await SystemLauncher.launch(context, command, displayName: name);
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
              onTap: () => _runForgeCmd(context, 'Waydroid Container', 'waydroid session start &'),
            ),
            _DeviceRow(
              icon: Icons.cast_connected,
              name: 'scrcpy Low-Latency Mirror',
              status: 'Ready',
              onTap: () => _runForgeCmd(context, 'scrcpy Screen Mirror', 'scrcpy --stay-awake &'),
            ),
            _DeviceRow(
              icon: Icons.phone_android,
              name: 'Pixel 8 Pro (USB ADB)',
              status: 'Online',
              onTap: () => _runForgeCmd(context, 'ADB Shell', 'foot -e adb shell &'),
            ),
          ]),
          const SizedBox(height: 16),
          _buildSection('AVD & System Emulators', [
            _ActionRow(
              icon: Icons.play_arrow_rounded,
              label: 'Launch Waydroid Full UI',
              onAction: () => _runForgeCmd(context, 'Waydroid UI', 'waydroid show-full-ui &'),
            ),
            _ActionRow(
              icon: Icons.smart_screen_rounded,
              label: 'Start Android AVD (Pixel 7 API 34)',
              onAction: () => _runForgeCmd(context, 'Android AVD', 'emulator -avd Pixel_7_API_34 &'),
            ),
            _ActionRow(
              icon: Icons.sports_esports_rounded,
              label: 'Start Gamescope Emulation Runtime',
              onAction: () => _runForgeCmd(context, 'Gamescope', 'gamescope -W 1920 -H 1080 -r 60 -- steam -gamepadui &'),
            ),
          ]),
          const SizedBox(height: 16),
          _buildSection('ADB Development Tools', [
            _ActionRow(
              icon: Icons.bug_report_rounded,
              label: 'Live ADB Logcat Terminal',
              onAction: () => _runForgeCmd(context, 'ADB Logcat', 'foot -e adb logcat &'),
            ),
            _ActionRow(
              icon: Icons.install_mobile_rounded,
              label: 'Install APK Package',
              onAction: () => _runForgeCmd(context, 'ADB Install', 'foot -e bash -c "echo Drag and drop APK:; read f; adb install \$f" &'),
            ),
            _ActionRow(
              icon: Icons.terminal_rounded,
              label: 'Interactive ADB Root Shell',
              onAction: () => _runForgeCmd(context, 'ADB Root Shell', 'foot -e adb shell &'),
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

class VmManagerPanel extends StatelessWidget {
  const VmManagerPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return FocusScope(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('VIRTUAL MACHINES & KVM', style: SwarmTextStyles.label.copyWith(color: SwarmColors.accent)),
          const SizedBox(height: 16),
          _DeviceRow(
            icon: Icons.memory,
            name: 'SWARM OS Native VM (QEMU/KVM)',
            status: 'Ready',
            onTap: () => _runForgeCmd(context, 'Swarm OS QEMU VM', '/run/media/i30ltz/lucy-master/Swarm-Flutter-beta/ISO/vm_launch_test.sh &'),
          ),
          _DeviceRow(
            icon: LucideIcons.monitor,
            name: 'Ubuntu 24.04 Dev Sandbox',
            status: 'Running',
            onTap: () => _runForgeCmd(context, 'Ubuntu Docker Container', 'foot -e docker exec -it ubuntu-dev bash &'),
          ),
          _DeviceRow(
            icon: Icons.window_rounded,
            name: 'Windows 11 Workstation (KVM)',
            status: 'Stopped',
            onTap: () => _runForgeCmd(context, 'Windows 11 VM', 'quickemu --vm windows-11.conf &'),
          ),
          _DeviceRow(
            icon: Icons.apple_rounded,
            name: 'macOS Sequoia (QEMU)',
            status: 'Stopped',
            onTap: () => _runForgeCmd(context, 'macOS VM', 'quickemu --vm macos-sequoia.conf &'),
          ),
          const SizedBox(height: 16),
          _buildSection('Quick VM Actions', [
            _ActionRow(
              icon: Icons.add_to_queue_rounded,
              label: 'Launch Custom ISO in QEMU Acceleration',
              onAction: () => _runForgeCmd(context, 'Custom QEMU', '/run/media/i30ltz/lucy-master/Swarm-Flutter-beta/ISO/vm_launch_test.sh &'),
            ),
            _ActionRow(
              icon: Icons.list_alt_rounded,
              label: 'List Active KVM & QEMU Processes',
              onAction: () => _runForgeCmd(context, 'Process List', 'foot -e bash -c "ps aux | grep -E \'qemu|kvm\'; read -p \'Press enter...\'" &'),
            ),
            _ActionRow(
              icon: Icons.stop_circle_rounded,
              label: 'Kill All Running QEMU / KVM VMs',
              onAction: () => _runForgeCmd(context, 'Kill VMs', 'killall qemu-system-x86_64 2>/dev/null || true'),
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

class MultiPlatformPanel extends StatelessWidget {
  const MultiPlatformPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return FocusScope(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('MULTI-PLATFORM COMPILER', style: SwarmTextStyles.label.copyWith(color: SwarmColors.accent)),
          const SizedBox(height: 16),
          _ActionRow(
            icon: Icons.flutter_dash_rounded,
            label: 'Build Flutter Linux Release',
            onAction: () => _runForgeCmd(context, 'Flutter Linux', 'cd /run/media/i30ltz/lucy-master/Swarm-Flutter-beta && flutter build linux --release &'),
          ),
          _ActionRow(
            icon: Icons.build_circle_rounded,
            label: 'Compile C++ Lucille Backend (CMake/Make)',
            onAction: () => _runForgeCmd(context, 'C++ Lucille Backend', 'cd /run/media/i30ltz/lucy-master/Swarm-Flutter-beta/backend/cpp_project/build && make -j\$(nproc) &'),
          ),
          _ActionRow(
            icon: Icons.disc_full_rounded,
            label: 'Build Native Archiso Appliance',
            onAction: () => _runForgeCmd(context, 'Archiso Appliance Build', 'foot -e /run/media/i30ltz/lucy-master/Swarm-Flutter-beta/ISO/build_native_iso.sh &'),
          ),
          _ActionRow(
            icon: Icons.sync_rounded,
            label: 'Sync Beta to Stable & Auto-Commit',
            onAction: () => _runForgeCmd(context, 'Sync Beta to Stable', '/run/media/i30ltz/lucy-master/Swarm-Flutter-beta/sync_beta_to_stable.sh &'),
          ),
        ],
      ),
    );
  }
}

// ─── Reusable List Rows ──────────────────────────────────────────────────────

class _DeviceRow extends StatefulWidget {
  final IconData icon;
  final String name;
  final String status;
  final VoidCallback? onTap;

  const _DeviceRow({
    required this.icon,
    required this.name,
    required this.status,
    this.onTap,
  });

  @override
  State<_DeviceRow> createState() => _DeviceRowState();
}

class _DeviceRowState extends State<_DeviceRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final isOnline = widget.status == 'Online' || widget.status == 'Running' || widget.status == 'Ready';

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        onTap: widget.onTap,
        onHover: (v) => setState(() => _hovered = v),
        borderRadius: BorderRadius.circular(8),
        focusColor: SwarmColors.accent.withValues(alpha: 0.25),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
          decoration: BoxDecoration(
            color: _hovered ? SwarmColors.bgElevated : SwarmColors.bgSurface.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _hovered ? SwarmColors.accent.withValues(alpha: 0.5) : SwarmColors.border,
            ),
          ),
          child: Row(
            children: [
              Icon(widget.icon, size: 16, color: isOnline ? SwarmColors.accent : SwarmColors.textSecondary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.name,
                  style: SwarmTextStyles.bodySmall.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: SwarmColors.textPrimary,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: (isOnline ? SwarmColors.statusOnline : SwarmColors.statusOffline).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  widget.status,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: isOnline ? SwarmColors.statusOnline : SwarmColors.statusOffline,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.play_circle_outline, size: 16, color: SwarmColors.accent),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionRow extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onAction;

  const _ActionRow({required this.icon, required this.label, required this.onAction});

  @override
  State<_ActionRow> createState() => _ActionRowState();
}

class _ActionRowState extends State<_ActionRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        onTap: widget.onAction,
        onHover: (v) => setState(() => _hovered = v),
        borderRadius: BorderRadius.circular(8),
        focusColor: SwarmColors.accent.withValues(alpha: 0.25),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
          decoration: BoxDecoration(
            color: _hovered ? SwarmColors.bgElevated : SwarmColors.bgSurface.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _hovered ? SwarmColors.accent.withValues(alpha: 0.5) : SwarmColors.border,
            ),
          ),
          child: Row(
            children: [
              Icon(widget.icon, size: 16, color: SwarmColors.accent),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.label,
                  style: SwarmTextStyles.bodySmall.copyWith(
                    fontSize: 12,
                    color: SwarmColors.textPrimary,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right, size: 16, color: SwarmColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}


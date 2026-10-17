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
import '../coder/panels/profile_manager_panel.dart';
import '../coder/panels/android_panel.dart';
import '../coder/panels/signing_panel.dart';
import '../coder/panels/device_explorer_panel.dart';
import '../coder/panels/task_runner_panel.dart';
import '../coder/panels/extensions_panel.dart';
import '../coder/panels/publisher_portal_panel.dart';
import '../coder/panels/controller_settings_panel.dart';
import '../coder/panels/apple_panel.dart';
import '../coder/panels/ollama_panel.dart';
import '../services/workspace_state_service.dart';
import '../widgets/extensions_dialog.dart';
import '../widgets/swarm_terminal.dart';
import 'agent_chat.dart';

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
            onTap: () => setState(() => _activeView = ApexView.explorer),
          ),
          _ActivityIcon(
            icon: LucideIcons.search,
            view: ApexView.search,
            active: _activeView == ApexView.search,
            onTap: () => setState(() => _activeView = ApexView.search),
          ),
          _ActivityIcon(
            icon: LucideIcons.gitBranch,
            view: ApexView.git,
            active: _activeView == ApexView.git,
            onTap: () => setState(() => _activeView = ApexView.git),
          ),
          _ActivityIcon(
            icon: Icons.android_rounded,
            view: ApexView.android,
            active: _activeView == ApexView.android,
            onTap: () => setState(() => _activeView = ApexView.android),
          ),
          _ActivityIcon(
            icon: LucideIcons.signature,
            view: ApexView.signing,
            active: _activeView == ApexView.signing,
            onTap: () => setState(() => _activeView = ApexView.signing),
          ),
          _ActivityIcon(
            icon: LucideIcons.hardDrive,
            view: ApexView.deviceFiles,
            active: _activeView == ApexView.deviceFiles,
            onTap: () => setState(() => _activeView = ApexView.deviceFiles),
          ),
          _ActivityIcon(
            icon: LucideIcons.playCircle,
            view: ApexView.tasks,
            active: _activeView == ApexView.tasks,
            onTap: () => setState(() => _activeView = ApexView.tasks),
          ),
          _ActivityIcon(
            icon: LucideIcons.puzzle,
            view: ApexView.extensions,
            active: _activeView == ApexView.extensions,
            onTap: () => setState(() => _activeView = ApexView.extensions),
          ),
          _ActivityIcon(
            icon: LucideIcons.rocket,
            view: ApexView.publisher,
            active: _activeView == ApexView.publisher,
            onTap: () => setState(() => _activeView = ApexView.publisher),
          ),
          _ActivityIcon(
            icon: LucideIcons.gamepad2,
            view: ApexView.controller,
            active: _activeView == ApexView.controller,
            onTap: () => setState(() => _activeView = ApexView.controller),
          ),
          _ActivityIcon(
            icon: Icons.apple_rounded,
            view: ApexView.apple,
            active: _activeView == ApexView.apple,
            onTap: () => setState(() => _activeView = ApexView.apple),
          ),
          _ActivityIcon(
            icon: LucideIcons.cpu,
            view: ApexView.ollama,
            active: _activeView == ApexView.ollama,
            onTap: () => setState(() => _activeView = ApexView.ollama),
          ),
          _ActivityIcon(
            icon: LucideIcons.settings,
            view: ApexView.settings,
            active: _activeView == ApexView.settings,
            onTap: () => setState(() => _activeView = ApexView.settings),
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
    // Real panels need the active workspace path — same persisted workspace
    // CoderPage itself loads (WorkspaceStateService), so both surfaces agree.
    final workspace = WorkspaceStateService.instance.snapshot.workspacePath;
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
            ApexView.android => AndroidPanel(projectPath: workspace),
            ApexView.signing => SigningPanel(projectPath: workspace),
            ApexView.deviceFiles => const DeviceExplorerPanel(),
            ApexView.tasks => TaskRunnerPanel(projectPath: workspace),
            ApexView.extensions => const ExtensionsPanel(),
            ApexView.publisher => const PublisherPortalPanel(),
            ApexView.controller => const ControllerSettingsPanel(),
            ApexView.apple => ApplePanel(projectPath: workspace),
            ApexView.ollama => const OllamaPanel(),
            ApexView.settings => const ProfileManagerPanel(),
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

// AI Panel for Apex — the real streaming AgentChatPanel (LucyServer /lucy
// SSE pipeline with per-agent model selection), not a placeholder. The
// 'apex' agent id carries its own model assignment + persona from
// models/agent.dart, so this is a full AI pair programmer in the IDE.
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
          // The real chat — streams from the agent's assigned swarm model.
          const Expanded(child: AgentChatPanel(agentId: 'apex')),
        ],
      ),
    );
  }
}

// Terminal Panel for Apex — the real SwarmTerminal (multi-pane, PTY-backed,
// with copy/paste context menu), not a placeholder.
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
              ],
            ),
          ),
          const Expanded(
            child: SwarmTerminal(initialPanes: 1),
          ),
        ],
      ),
    );
  }
}

// ─── Sub-Panels ─────────────────────────────────────────────────────────────
// All activity-bar views now render the REAL panels from lib/coder/panels/
// (AndroidPanel, SigningPanel, DeviceExplorerPanel, TaskRunnerPanel,
// ExtensionsPanel, PublisherPortalPanel, ControllerSettingsPanel, ApplePanel,
// OllamaPanel) — the placeholder stubs that used to live here were deleted
// 2026-09-21. They duplicated the coder panels with every action a no-op.

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
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/agent.dart';
import '../shell/window_manager.dart';
import '../agent/agent_chat.dart';
import '../agent/vault_browser.dart';
import '../agent/forge_workstation.dart';
import '../backend/orchestrator.dart';
import 'hub_header.dart';
import 'agent_grid.dart';
import 'agent_terminal.dart';
import 'desktop_apps.dart'; // NEW IMPORT
import '../widgets/vital_tracker_dialog.dart';
import '../theme/swarm_colors.dart';
import '../theme/swarm_text_styles.dart';

class HubPage extends ConsumerStatefulWidget {
  const HubPage({super.key});

  @override
  ConsumerState<HubPage> createState() => _HubPageState();
}

/// Direct agent route target used by registry tiles and `/agent/:id` links.
class AgentDetailRoute extends StatelessWidget {
  final String agentId;

  const AgentDetailRoute({super.key, required this.agentId});

  @override
  Widget build(BuildContext context) {
    final agent = getAgent(agentId);
    if (agent == null) {
      return Scaffold(
        backgroundColor: SwarmColors.bgBase,
        body: Center(child: Text('Agent "$agentId" was not found.')),
      );
    }
    return Scaffold(
      backgroundColor: SwarmColors.bgBase,
      appBar: AppBar(
        title: Text(agent.name),
        backgroundColor: SwarmColors.bgSurface,
      ),
      body: AgentWindowContent(agent: agent),
    );
  }
}

class _HubPageState extends ConsumerState<HubPage> {
  bool _showOrc = false;

  @override
  Widget build(BuildContext context) {
    if (_showOrc) {
      return OrchestrationHub(
        onClose: () => setState(() => _showOrc = false),
      );
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final horizontalPad = screenWidth < 1200 ? 20.0 : 36.0;
    final verticalPad = screenWidth < 1200 ? 16.0 : 28.0;

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPad,
        vertical: verticalPad,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HubHeader(onOpenBackend: () => setState(() => _showOrc = true)),
          AgentGrid(
            agents: agents,
            onAgentTap: (agent) {
              if (agent.id == 'apex') {
                context.go('/apex');
                return;
              }
              if (agent.id == 'forge') {
                context.go('/forge');
                return;
              }
              if (agent.id == 'ui_tandem') {
                context.go('/ui_tandem');
                return;
              }
              if (agent.id == 'vital') {
                VitalTrackerDialog.show(context);
                return;
              }
              ref.read(windowProvider.notifier).openWindow(
                    AppWindow(
                      id: 'agent_${agent.id}',
                      title: '${agent.name} · ${agent.role}',
                      position: const Offset(100, 50),
                      size: agent.id == 'forge'
                          ? const Size(900, 650)
                          : const Size(700, 500),
                      content: AgentWindowContent(agent: agent),
                    ),
                  );
            },
          ),
          DesktopAppsGrid(), // OS APPS RENDERED HERE
        ],
      ),
    );
  }
}

/// Tabbed window content: Chat tab + Terminal tab.
class AgentWindowContent extends StatefulWidget {
  final Agent agent;
  const AgentWindowContent({super.key, required this.agent});

  @override
  State<AgentWindowContent> createState() => _AgentWindowContentState();
}

class _AgentWindowContentState extends State<AgentWindowContent>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  bool get _isVault =>
      ['document_manager', 'vault', 'coder', 'droid'].contains(widget.agent.id);
  bool get _isForge => widget.agent.id == 'forge';

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: _isVault ? 3 : 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // If it's forge, skip the standard tabs and render the full IDE Workstation
    if (_isForge) {
      return const ForgeWorkstation();
    }

    return Column(
      children: [
        if (widget.agent.id == 'droid')
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: const BoxDecoration(
              color: Color(0xFF130D24),
              border: Border(bottom: BorderSide(color: SwarmColors.border)),
            ),
            child: Row(
              children: [
                const Icon(Icons.android_rounded,
                    size: 16, color: SwarmColors.agentCyan),
                const SizedBox(width: 8),
                Text(
                  'DROID AT LUCILLE\'S CORE',
                  style: SwarmTextStyles.codeSmall.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 1.0,
                  ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: SwarmColors.agentCyan.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                        color: SwarmColors.agentCyan.withValues(alpha: 0.4)),
                  ),
                  child: const Text(
                    'AI CODER',
                    style: TextStyle(
                      fontFamily: 'JetBrains Mono',
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: SwarmColors.agentCyan,
                    ),
                  ),
                ),
              ],
            ),
          ),
        Container(
          color: const Color(0xFF150F28),
          child: TabBar(
            controller: _tabs,
            indicatorColor: widget.agent.accent,
            indicatorWeight: 2,
            labelColor: widget.agent.accent,
            unselectedLabelColor: const Color(0xFF7A6E96),
            labelStyle: const TextStyle(
              fontFamily: 'JetBrains Mono',
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.0,
            ),
            tabs: [
              const Tab(icon: Icon(Icons.chat_rounded, size: 14), text: 'CHAT'),
              const Tab(
                  icon: Icon(Icons.terminal_rounded, size: 14),
                  text: 'TERMINAL'),
              if (_isVault)
                const Tab(
                    icon: Icon(Icons.folder_open_rounded, size: 14),
                    text: 'FILES'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              AgentChatPanel(agentId: widget.agent.id),
              AgentTerminalPanel(
                agentId: widget.agent.id,
                agentName: widget.agent.name,
                accentColor: widget.agent.accent,
              ),
              if (_isVault) const VaultFileBrowser(),
            ],
          ),
        ),
      ],
    );
  }
}

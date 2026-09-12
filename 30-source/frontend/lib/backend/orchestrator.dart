import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/swarm_colors.dart';
import '../theme/swarm_text_styles.dart';
import '../models/agent.dart';

enum OrcTab { swarm, rag, nemclaw, trace, ov }

class OrchestrationHub extends ConsumerStatefulWidget {
  final VoidCallback onClose;
  const OrchestrationHub({super.key, required this.onClose});

  @override
  ConsumerState<OrchestrationHub> createState() => _OrchestrationHubState();
}

class _OrchestrationHubState extends ConsumerState<OrchestrationHub> {
  OrcTab _activeTab = OrcTab.swarm;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: SwarmColors.bg,
      child: Column(
        children: [
          // Header
          Container(
            height: 48,
            decoration: const BoxDecoration(
              color: SwarmColors.bgElevated,
              border: Border(bottom: BorderSide(color: SwarmColors.border)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_rounded, size: 20, color: SwarmColors.textMuted),
                  onPressed: widget.onClose,
                  tooltip: 'Back to Hub',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 16),
                Text('BACKEND.', style: SwarmTextStyles.label.copyWith(fontSize: 14)),
                Text('ORC', style: SwarmTextStyles.label.copyWith(color: SwarmColors.accent, fontSize: 14)),
                const SizedBox(width: 16),
                Text('Orchestration Control Center', style: SwarmTextStyles.codeSmall.copyWith(color: SwarmColors.textMuted)),
              ],
            ),
          ),
          
          // Main layout
          Expanded(
            child: Row(
              children: [
                // Sidebar
                Container(
                  width: 240,
                  decoration: const BoxDecoration(
                    color: SwarmColors.bgSurface,
                    border: Border(right: BorderSide(color: SwarmColors.border)),
                  ),
                  child: ListView(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    children: [
                      _NavBtn(
                        id: OrcTab.swarm,
                        icon: Icons.hub_rounded,
                        label: 'Swarm Router',
                        sub: '12 agent slots · hot-swap',
                        active: _activeTab == OrcTab.swarm,
                        onTap: () => setState(() => _activeTab = OrcTab.swarm),
                      ),
                      _NavBtn(
                        id: OrcTab.rag,
                        icon: Icons.data_usage_rounded,
                        label: 'RAG Memory',
                        sub: 'Vector store · inject context',
                        active: _activeTab == OrcTab.rag,
                        onTap: () => setState(() => _activeTab = OrcTab.rag),
                      ),
                      _NavBtn(
                        id: OrcTab.nemclaw,
                        icon: Icons.smart_toy_rounded,
                        label: 'NemClaw',
                        sub: 'Structured pipeline runner',
                        active: _activeTab == OrcTab.nemclaw,
                        onTap: () => setState(() => _activeTab = OrcTab.nemclaw),
                      ),
                      _NavBtn(
                        id: OrcTab.trace,
                        icon: Icons.account_tree_rounded,
                        label: 'OpenClaw Trace',
                        sub: 'ReAct agent trace viewer',
                        active: _activeTab == OrcTab.trace,
                        onTap: () => setState(() => _activeTab = OrcTab.trace),
                      ),
                      _NavBtn(
                        id: OrcTab.ov,
                        icon: Icons.bolt_rounded,
                        label: 'OV Optimizer',
                        sub: 'OpenVINO IR · precision targets',
                        active: _activeTab == OrcTab.ov,
                        onTap: () => setState(() => _activeTab = OrcTab.ov),
                      ),
                    ],
                  ),
                ),
                
                // Content area
                Expanded(
                  child: switch (_activeTab) {
                    OrcTab.swarm => const _SwarmPanel(),
                    OrcTab.rag => const _RagPanel(),
                    _ => Center(
                        child: Text(
                          'Pipeline under construction for native target.',
                          style: SwarmTextStyles.code.copyWith(color: SwarmColors.textMuted),
                        ),
                      ),
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NavBtn extends StatefulWidget {
  final OrcTab id;
  final IconData icon;
  final String label;
  final String sub;
  final bool active;
  final VoidCallback onTap;

  const _NavBtn({required this.id, required this.icon, required this.label, required this.sub, required this.active, required this.onTap});

  @override
  State<_NavBtn> createState() => _NavBtnState();
}

class _NavBtnState extends State<_NavBtn> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: widget.onTap,
      onHover: (v) => setState(() => _hovered = v),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: widget.active ? SwarmColors.accent.withValues(alpha: 0.1) : _hovered ? SwarmColors.bgHover : Colors.transparent,
          border: Border(
            left: BorderSide(
              color: widget.active ? SwarmColors.accent : Colors.transparent,
              width: 3,
            )
          )
        ),
        child: Row(
          children: [
            Icon(widget.icon, size: 20, color: widget.active ? SwarmColors.accent : SwarmColors.textSecondary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.label, style: SwarmTextStyles.body.copyWith(fontWeight: FontWeight.w600, color: widget.active ? SwarmColors.textPrimary : SwarmColors.textSecondary)),
                  const SizedBox(height: 2),
                  Text(widget.sub, style: SwarmTextStyles.code.copyWith(fontSize: 9, color: SwarmColors.textMuted)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── SWARM PANEL ─────────────────────────────────────────────────────────────

class _SwarmPanel extends ConsumerStatefulWidget {
  const _SwarmPanel();

  @override
  ConsumerState<_SwarmPanel> createState() => _SwarmPanelState();
}

class _SwarmPanelState extends ConsumerState<_SwarmPanel> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Top 12 agents for the 12 slots
    final slots = agents.take(12).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.hub_rounded, size: 16, color: SwarmColors.accent),
              const SizedBox(width: 8),
              Text('SWARM ROUTER', style: SwarmTextStyles.label.copyWith(color: SwarmColors.textPrimary)),
              const Spacer(),
              Text('12 active / 12', style: SwarmTextStyles.codeSmall.copyWith(color: SwarmColors.textMuted)),
            ],
          ),
        ),
        const Divider(height: 1, color: SwarmColors.border),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: slots.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final a = slots[i];
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: SwarmColors.bgElevated,
                  border: Border.all(color: SwarmColors.border),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    Icon(a.icon, size: 16, color: a.accent),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 80,
                      child: Text(a.name, style: SwarmTextStyles.code.copyWith(fontWeight: FontWeight.bold, color: SwarmColors.textPrimary)),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('IDLE — Waiting for routing dispatch', style: SwarmTextStyles.codeSmall.copyWith(color: SwarmColors.textMuted)),
                          const SizedBox(height: 2),
                          Text('llama3.1:latest · 0 tok', style: SwarmTextStyles.codeSmall.copyWith(color: SwarmColors.textMuted.withValues(alpha: 0.5))),
                        ],
                      ),
                    ),
                    Container(
                      width: 8, height: 8,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: SwarmColors.textMuted,
                      ),
                    )
                  ],
                ),
              );
            },
          ),
        ),
        const Divider(height: 1, color: SwarmColors.border),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('BROADCAST TO ALL AGENTS', style: SwarmTextStyles.codeSmall.copyWith(color: SwarmColors.textMuted)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 32,
                      child: TextField(
                        controller: _ctrl,
                        style: SwarmTextStyles.code.copyWith(fontSize: 12),
                        decoration: InputDecoration(
                          hintText: 'Task for all agents...',
                          hintStyle: SwarmTextStyles.code.copyWith(fontSize: 12, color: SwarmColors.textMuted),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                          filled: true,
                          fillColor: SwarmColors.bg,
                          enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: SwarmColors.border), borderRadius: BorderRadius.circular(4)),
                          focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: SwarmColors.accent), borderRadius: BorderRadius.circular(4)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: SwarmColors.accent.withValues(alpha: 0.15),
                      foregroundColor: SwarmColors.accent,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4), side: BorderSide(color: SwarmColors.accent.withValues(alpha: 0.5))),
                    ),
                    icon: const Icon(Icons.radio_rounded, size: 14),
                    label: const Text('TX'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── RAG INSPECTOR ────────────────────────────────────────────────────────────

class _RagPanel extends StatefulWidget {
  const _RagPanel();

  @override
  State<_RagPanel> createState() => _RagPanelState();
}

class _RagPanelState extends State<_RagPanel> {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.data_usage_rounded, size: 16, color: SwarmColors.accent),
              const SizedBox(width: 8),
              Text('RAG MEMORY STORE', style: SwarmTextStyles.label.copyWith(color: SwarmColors.textPrimary)),
              const Spacer(),
              Text('0 chunks · TF-IDF cosine', style: SwarmTextStyles.codeSmall.copyWith(color: SwarmColors.textMuted)),
            ],
          ),
        ),
        const Divider(height: 1, color: SwarmColors.border),
        Expanded(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.hub_rounded, size: 48, color: SwarmColors.border),
                const SizedBox(height: 16),
                Text('Vector Database Not Connected', style: SwarmTextStyles.label.copyWith(color: SwarmColors.textMuted)),
                const SizedBox(height: 8),
                Text('Initialize Swarm_OS Python engine to load indices.', style: SwarmTextStyles.codeSmall),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

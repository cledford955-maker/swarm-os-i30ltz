import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:provider/provider.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import '../models/agent.dart';
import '../models/swarm.dart';
import '../services/live_model_catalog_service.dart';
import '../theme/swarm_colors.dart';
import '../theme/swarm_text_styles.dart';
import '../widgets/extensions_dialog.dart';
import '../widgets/agent_avatar.dart';
import '../agent/agent_chat.dart';

/// The real price for a model right now, and whether it still exists on
/// OpenRouter at all — cross-checked against the live catalog rather than
/// trusting the static SwarmModel.pricePer1M, which has been found stale.
/// Local/Ollama models aren't OpenRouter-checkable and are never flagged.
({String price, bool isDead}) liveModelStatus(SwarmModel m, LiveModelCatalogService liveCatalog) {
  if (m.provider == ProviderId.ollama) {
    return (price: m.pricePer1M ?? 'FREE', isDead: false);
  }
  if (!liveCatalog.hasData) {
    return (price: m.pricePer1M ?? 'FREE', isDead: false);
  }
  final live = liveCatalog.byId(m.id);
  if (live != null) return (price: live.pricePer1MDisplay, isDead: false);
  return (price: m.pricePer1M ?? 'FREE', isDead: true);
}

class SwarmPage extends ConsumerStatefulWidget {
  const SwarmPage({super.key});

  @override
  ConsumerState<SwarmPage> createState() => _SwarmPageState();
}

class _SwarmPageState extends ConsumerState<SwarmPage> {
  List<SwarmConfig> _customSwarms = [];
  bool _loadingCustom = true;
  String _selectedAgentId = 'all';

  Agent? get _selectedAgent => agents.where((a) => a.id == _selectedAgentId).firstOrNull;
  String get _selectedAgentName => _selectedAgentId == 'all' ? 'All Agents' : (_selectedAgent?.name ?? _selectedAgentId);

  @override
  void initState() {
    super.initState();
    _refreshCustomSwarms();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      p.Provider.of<LiveModelCatalogService>(context, listen: false).ensureLoaded();
    });
  }

  Future<void> _refreshCustomSwarms() async {
    final list = await loadCustomSwarms();
    if (mounted) {
      setState(() {
        _customSwarms = list;
        _loadingCustom = false;
      });
    }
  }

  void _assignSwarmToAgent(String swarmId, String swarmName, {String? specificAgentId}) {
    final targetAgentId = specificAgentId ?? _selectedAgentId;

    if (targetAgentId == 'all') {
      for (final a in agents) {
        ref.read(agentModelProvider(a.id).notifier).state = swarmId;
      }
    } else {
      ref.read(agentModelProvider(targetAgentId).notifier).state = swarmId;
    }

    // Persist to SharedPreferences
    SharedPreferences.getInstance().then((prefs) {
      if (targetAgentId == 'all') {
        for (final a in agents) {
          prefs.setString('SWARM_AGENT_MODEL_${a.id}', swarmId);
        }
      } else {
        prefs.setString('SWARM_AGENT_MODEL_$targetAgentId', swarmId);
      }
    });

    final targetAgent = agents.where((a) => a.id == targetAgentId).firstOrNull;
    final targetName = targetAgentId == 'all'
        ? 'All Active Agents'
        : (targetAgent?.name ?? targetAgentId);

    final isVideo = swarmId == 'video-generation-swarm';
    final isAuto = swarmId == 'autorouter-swarm';

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF160F2C),
        duration: const Duration(seconds: 4),
        content: Row(
          children: [
            Icon(
              isAuto
                  ? Icons.alt_route_rounded
                  : isVideo
                      ? Icons.videocam_rounded
                      : Icons.hub_rounded,
              color: isAuto
                  ? SwarmColors.warning
                  : isVideo
                      ? SwarmColors.agentPink
                      : SwarmColors.accent,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: RichText(
                text: TextSpan(
                  text: 'Assigned Swarm ',
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  children: [
                    TextSpan(
                      text: swarmName,
                      style: const TextStyle(
                        color: SwarmColors.accent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const TextSpan(text: ' ➔ '),
                    TextSpan(
                      text: targetName,
                      style: TextStyle(
                        color: targetAgent?.accent ?? SwarmColors.agentCyan,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        action: SnackBarAction(
          label: targetAgentId == 'all' ? 'OPEN HUB' : 'OPEN ${targetName.toUpperCase()}',
          textColor: SwarmColors.accent,
          onPressed: () {
            if (targetAgentId == 'forge') {
              context.go('/forge');
            } else if (targetAgentId == 'lucille' || targetAgentId == 'orchestrator') {
              context.go('/lucille');
            } else if (targetAgentId == 'droid') {
              context.go('/agent/droid');
            } else if (targetAgentId == 'ui_tandem') {
              context.go('/agent/ui_tandem');
            } else if (targetAgentId == 'vital') {
              context.go('/agent/vital');
            } else if (targetAgentId == 'all') {
              context.go('/');
            } else {
              context.go('/agent/$targetAgentId');
            }
          },
        ),
      ),
    );
  }

  void _openCreateSwarmDialog() {
    showDialog(
      context: context,
      builder: (ctx) => _CreateCustomSwarmDialog(
        onCreated: (newSwarm) async {
          await saveCustomSwarm(newSwarm);
          await _refreshCustomSwarms();
          if (mounted) {
            _assignSwarmToAgent(newSwarm.id, newSwarm.name);
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final flagshipSwarm = swarms['default-coding-swarm']!;
    final otherStandardSwarms = swarms.values.where((s) => s.id != 'default-coding-swarm').toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Action Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'SWARM ARCHITECTURES',
                          style: SwarmTextStyles.displayLarge.copyWith(
                            fontSize: 26,
                            letterSpacing: 1.5,
                            color: SwarmColors.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: SwarmColors.accent.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: SwarmColors.accent.withValues(alpha: 0.5)),
                          ),
                          child: Text(
                            'ORCHESTRATION ENGINE',
                            style: SwarmTextStyles.codeSmall.copyWith(
                              color: SwarmColors.accent,
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Multi-agent clusters configured for distributed reasoning, systems logic, UI layouts, automated execution, QA, and auto-complete.',
                      style: SwarmTextStyles.body.copyWith(color: SwarmColors.textMuted),
                    ),
                  ],
                ),
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (_) => const IdeExtensionsDialog(),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: SwarmColors.agentPurple.withValues(alpha: 0.2),
                        foregroundColor: SwarmColors.agentPurple,
                        side: BorderSide(color: SwarmColors.agentPurple.withValues(alpha: 0.6)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.extension_rounded, size: 16),
                      label: const Text('GET EXTENSIONS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: _openCreateSwarmDialog,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: SwarmColors.accent,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('CREATE CUSTOM SWARM', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),

            // ─── Target Agent Assignment Bar ────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF130D26),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: (_selectedAgent?.accent ?? SwarmColors.accent).withValues(alpha: 0.5),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: (_selectedAgent?.accent ?? SwarmColors.accent).withValues(alpha: 0.08),
                    blurRadius: 16,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.person_pin_rounded,
                            color: _selectedAgent?.accent ?? SwarmColors.accent,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'ASSIGNING SWARM TO AGENT:',
                            style: SwarmTextStyles.label.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.0,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      if (_selectedAgentId != 'all')
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: SwarmColors.bgElevated,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: SwarmColors.border),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'Active: ',
                                style: TextStyle(color: SwarmColors.textMuted, fontSize: 11),
                              ),
                              Text(
                                ref.watch(agentModelProvider(_selectedAgentId)),
                                style: TextStyle(
                                  color: _selectedAgent?.accent ?? SwarmColors.accent,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        ...agents.map((agent) {
                          final isSelected = _selectedAgentId == agent.id;
                          final agentCurrentModel = ref.watch(agentModelProvider(agent.id));

                          return Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: InkWell(
                              onTap: () => setState(() => _selectedAgentId = agent.id),
                              borderRadius: BorderRadius.circular(8),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? agent.accent.withValues(alpha: 0.22)
                                      : SwarmColors.bgElevated,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isSelected ? agent.accent : SwarmColors.border,
                                    width: isSelected ? 1.8 : 1.0,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    AgentAvatar(agentId: agent.id, size: 18),
                                    const SizedBox(width: 8),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          agent.name,
                                          style: TextStyle(
                                            color: isSelected ? Colors.white : SwarmColors.textPrimary,
                                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                            fontSize: 12,
                                          ),
                                        ),
                                        Text(
                                          agentCurrentModel.split('/').last,
                                          style: TextStyle(
                                            color: isSelected ? agent.accent : SwarmColors.textMuted,
                                            fontSize: 9.5,
                                            fontFamily: 'JetBrains Mono',
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }),
                        // All Agents Option
                        InkWell(
                          onTap: () => setState(() => _selectedAgentId = 'all'),
                          borderRadius: BorderRadius.circular(8),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: _selectedAgentId == 'all'
                                  ? SwarmColors.warning.withValues(alpha: 0.22)
                                  : SwarmColors.bgElevated,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: _selectedAgentId == 'all'
                                    ? SwarmColors.warning
                                    : SwarmColors.border,
                                width: _selectedAgentId == 'all' ? 1.8 : 1.0,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.public_rounded,
                                  size: 16,
                                  color: _selectedAgentId == 'all' ? SwarmColors.warning : SwarmColors.textMuted,
                                ),
                                const SizedBox(width: 8),
                                const Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'ALL AGENTS (GLOBAL)',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                    Text(
                                      'Broadcast to all',
                                      style: TextStyle(
                                        color: SwarmColors.textMuted,
                                        fontSize: 9.5,
                                        fontFamily: 'JetBrains Mono',
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // ─── 1. HERO: FLAGSHIP SOTA CODING SWARM ──────────────────────────────
            _buildFlagshipHero(flagshipSwarm),

            const SizedBox(height: 36),

            // ─── 2. CUSTOM SWARMS ROOM ───────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.hub_rounded, color: SwarmColors.agentCyan, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'CUSTOM SWARMS',
                      style: SwarmTextStyles.title.copyWith(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: SwarmColors.agentCyan.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${_customSwarms.length} CONFIGURED',
                        style: const TextStyle(color: SwarmColors.agentCyan, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                TextButton.icon(
                  onPressed: _openCreateSwarmDialog,
                  icon: const Icon(Icons.add_circle_outline, size: 16, color: SwarmColors.agentCyan),
                  label: const Text('Add Another Custom Swarm', style: TextStyle(color: SwarmColors.agentCyan, fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_loadingCustom)
              const Center(child: Padding(padding: EdgeInsets.all(24.0), child: CircularProgressIndicator()))
            else if (_customSwarms.isEmpty)
              _buildEmptyCustomSwarmNotice()
            else
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: _customSwarms.map((s) => _buildSwarmCard(s, isCustom: true)).toList(),
              ),

            const SizedBox(height: 40),

            // ─── 3. PRE-CONFIGURED SWARMS ─────────────────────────────────────────
            Row(
              children: [
                const Icon(Icons.layers_rounded, color: SwarmColors.agentPurple, size: 20),
                const SizedBox(width: 8),
                Text(
                  'STANDARD & SPECIALIZED SWARMS',
                  style: SwarmTextStyles.title.copyWith(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Each swarm contains curated AI models with full pricing, descriptions, and specialized node responsibilities.',
              style: SwarmTextStyles.bodySmall.copyWith(color: SwarmColors.textMuted),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: otherStandardSwarms.map((s) => _buildSwarmCard(s, isCustom: false)).toList(),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Hero Flagship Swarm Card ───────────────────────────────────────────
  Widget _buildFlagshipHero(SwarmConfig swarm) {
    final currentTargetModel = _selectedAgentId == 'all'
        ? ref.watch(agentModelProvider('lucille'))
        : ref.watch(agentModelProvider(_selectedAgentId));
    final isSelected = currentTargetModel == swarm.id;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: SwarmColors.accent, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: SwarmColors.accent.withValues(alpha: 0.15),
            blurRadius: 28,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: SwarmColors.accent.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: SwarmColors.accent),
                    ),
                    child: const Icon(Icons.stars_rounded, color: SwarmColors.accent, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        swarm.name,
                        style: SwarmTextStyles.title.copyWith(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: SwarmColors.accent,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        swarm.role,
                        style: SwarmTextStyles.bodySmall.copyWith(color: SwarmColors.textSecondary),
                      ),
                    ],
                  ),
                ],
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: SwarmColors.bgElevated,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: SwarmColors.border),
                    ),
                    child: Text(
                      'EST. COST: ${swarm.estimatedPrice ?? r'~$1.85 / 1M'}',
                      style: SwarmTextStyles.codeSmall.copyWith(
                        color: SwarmColors.accentSky,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: () => _assignSwarmToAgent(swarm.id, swarm.name),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isSelected ? SwarmColors.accent : SwarmColors.bgElevated,
                      foregroundColor: isSelected ? Colors.black : SwarmColors.textPrimary,
                      side: BorderSide(color: isSelected ? SwarmColors.accent : SwarmColors.border),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                    icon: Icon(
                      isSelected ? Icons.check_circle_rounded : Icons.hub_rounded,
                      size: 16,
                      color: isSelected ? Colors.black : SwarmColors.accent,
                    ),
                    label: Text(
                      isSelected
                          ? 'ACTIVE ON ${_selectedAgentName.toUpperCase()}'
                          : 'ASSIGN SWARM TO ${_selectedAgentName.toUpperCase()}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, fontFamily: 'JetBrains Mono'),
                    ),
                  ),
                  const SizedBox(width: 6),
                  PopupMenuButton<String>(
                    tooltip: 'Assign swarm to specific agent...',
                    color: const Color(0xFF160F2C),
                    icon: Container(
                      height: 36,
                      width: 36,
                      decoration: BoxDecoration(
                        color: SwarmColors.bgElevated,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: SwarmColors.border),
                      ),
                      child: const Center(
                        child: Icon(Icons.person_add_alt_1_rounded, size: 16, color: SwarmColors.textSecondary),
                      ),
                    ),
                    itemBuilder: (context) => [
                      ...agents.map((a) => PopupMenuItem<String>(
                        value: a.id,
                        child: Row(
                          children: [
                            AgentAvatar(agentId: a.id, size: 16),
                            const SizedBox(width: 8),
                            Text(
                              'Assign to ${a.name}',
                              style: const TextStyle(color: Colors.white, fontSize: 12),
                            ),
                          ],
                        ),
                      )),
                      const PopupMenuDivider(),
                      const PopupMenuItem<String>(
                        value: 'all',
                        child: Row(
                          children: [
                            Icon(Icons.public_rounded, size: 14, color: SwarmColors.warning),
                            SizedBox(width: 8),
                            Text(
                              'Assign to All Agents',
                              style: TextStyle(color: SwarmColors.warning, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ],
                    onSelected: (agentId) => _assignSwarmToAgent(swarm.id, swarm.name, specificAgentId: agentId),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(color: SwarmColors.border),
          const SizedBox(height: 16),

          Text(
            'ASSIGNED AGENT ROLES & MODELS (${swarm.models.length} SPECIALIZED NODES):',
            style: SwarmTextStyles.labelSmall.copyWith(
              color: SwarmColors.textMuted,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),

          // Grid Cards for the Flagship Swarm (Adapts for 7 nodes)
          LayoutBuilder(
            builder: (context, constraints) {
              final crossAxisCount = constraints.maxWidth > 1050 ? 4 : (constraints.maxWidth > 650 ? 3 : 2);
              final cardWidth = (constraints.maxWidth - ((crossAxisCount - 1) * 12)) / crossAxisCount;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: swarm.models.map((m) => _buildAgentRoleCard(m, cardWidth: cardWidth)).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAgentRoleCard(SwarmModel model, {required double cardWidth}) {
    final liveCatalog = p.Provider.of<LiveModelCatalogService>(context);
    final status = liveModelStatus(model, liveCatalog);
    Color accent = SwarmColors.accent;
    if (model.role.contains('Leader')) accent = SwarmColors.accent;
    if (model.role.contains('Systems')) accent = SwarmColors.agentPurple;
    if (model.role.contains('Frontend')) accent = SwarmColors.agentSky;
    if (model.role.contains('Tool') || model.role.contains('Shell')) accent = SwarmColors.agentCyan;
    if (model.role.contains('QA')) accent = SwarmColors.agentPink;
    if (model.role.contains('Auto-Complete')) accent = SwarmColors.lucille;
    if (model.role.contains('Evals') || model.role.contains('Optimization')) accent = SwarmColors.success;

    return Container(
      width: cardWidth < 260 ? double.infinity : cardWidth,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: SwarmColors.bgElevated.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accent.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  model.role.toUpperCase(),
                  style: SwarmTextStyles.codeSmall.copyWith(
                    color: accent,
                    fontWeight: FontWeight.bold,
                    fontSize: 9,
                  ),
                ),
              ),
              if (model.isOnSale)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: SwarmColors.success.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: SwarmColors.success.withValues(alpha: 0.6)),
                  ),
                  child: Text(
                    model.saleDiscount ?? 'ON SALE',
                    style: const TextStyle(
                      color: SwarmColors.success,
                      fontWeight: FontWeight.bold,
                      fontSize: 9,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            model.name,
            style: const TextStyle(
              color: SwarmColors.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            model.id,
            style: SwarmTextStyles.codeSmall.copyWith(
              color: SwarmColors.textMuted,
              fontSize: 9.5,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Text(
            model.description,
            style: const TextStyle(
              color: SwarmColors.textSecondary,
              fontSize: 11,
              height: 1.3,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    status.price,
                    style: TextStyle(
                      color: status.price == 'FREE' ? SwarmColors.success : SwarmColors.accentSky,
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              if (status.isDead)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: SwarmColors.error.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: SwarmColors.error.withValues(alpha: 0.6)),
                  ),
                  child: const Text(
                    '⚠ NOT ON OPENROUTER',
                    style: TextStyle(color: SwarmColors.error, fontSize: 8, fontWeight: FontWeight.bold),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: SwarmColors.bgSurface,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    model.provider.name.toUpperCase(),
                    style: const TextStyle(color: SwarmColors.textMuted, fontSize: 8.5),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Swarm Card ──────────────────────────────────────────────────────────
  Widget _buildSwarmCard(SwarmConfig s, {required bool isCustom}) {
    final currentTargetModel = _selectedAgentId == 'all'
        ? ref.watch(agentModelProvider('lucille'))
        : ref.watch(agentModelProvider(_selectedAgentId));
    final isSelected = currentTargetModel == s.id;

    final isVideo = s.id == 'video-generation-swarm';
    final isAuto = s.id == 'autorouter-swarm';
    final isNim = s.id == 'nim-free-power-swarm';

    Color cardAccent = SwarmColors.accent;
    if (isVideo) cardAccent = SwarmColors.agentPink;
    if (isAuto) cardAccent = SwarmColors.warning;
    if (isNim) cardAccent = SwarmColors.agentPurple;

    return Container(
      width: 380,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isSelected
            ? SwarmColors.accent.withValues(alpha: 0.08)
            : Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? SwarmColors.accent : cardAccent.withValues(alpha: 0.5),
          width: isSelected ? 1.8 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.name,
                      style: TextStyle(
                        color: isSelected ? SwarmColors.accent : Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      s.role,
                      style: const TextStyle(color: SwarmColors.textMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (isCustom)
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: SwarmColors.error, size: 18),
                  tooltip: 'Delete Custom Swarm',
                  onPressed: () async {
                    await deleteCustomSwarm(s.id);
                    await _refreshCustomSwarms();
                  },
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Aggregate Price: ${s.estimatedPrice ?? "FREE"}',
            style: TextStyle(
              color: cardAccent,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 14),

          // Models list inside this Swarm
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: SwarmColors.bgElevated,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: SwarmColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'MODELS LISTED (${s.models.length}):',
                  style: SwarmTextStyles.codeSmall.copyWith(
                    color: SwarmColors.textMuted,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                ...s.models.map((m) => Padding(
                  padding: const EdgeInsets.only(bottom: 6.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Icon(Icons.lens, size: 6, color: cardAccent),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                '${m.name} (${m.role})',
                                style: const TextStyle(color: SwarmColors.textSecondary, fontSize: 11),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          if (m.isOnSale)
                            Container(
                              margin: const EdgeInsets.only(right: 6),
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: SwarmColors.success.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: const Text('SALE', style: TextStyle(color: SwarmColors.success, fontSize: 8, fontWeight: FontWeight.bold)),
                            ),
                          Builder(builder: (ctx) {
                            final st = liveModelStatus(m, p.Provider.of<LiveModelCatalogService>(ctx));
                            return Text(
                              st.isDead ? '⚠ DEAD' : st.price,
                              style: TextStyle(
                                color: st.isDead
                                    ? SwarmColors.error
                                    : (st.price == 'FREE' ? SwarmColors.success : SwarmColors.accentSky),
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                              ),
                            );
                          }),
                        ],
                      ),
                    ],
                  ),
                )),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Select button row
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 34,
                  child: ElevatedButton.icon(
                    onPressed: () => _assignSwarmToAgent(s.id, s.name),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isSelected ? cardAccent : cardAccent.withValues(alpha: 0.18),
                      foregroundColor: isSelected ? Colors.black : cardAccent,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                        side: BorderSide(color: cardAccent.withValues(alpha: 0.6)),
                      ),
                    ),
                    icon: Icon(
                      isSelected
                          ? Icons.check_circle_rounded
                          : isVideo
                              ? Icons.videocam_rounded
                              : isAuto
                                  ? Icons.alt_route_rounded
                                  : Icons.hub_rounded,
                      size: 13,
                    ),
                    label: Text(
                      isSelected
                          ? 'ACTIVE ON ${_selectedAgentName.toUpperCase()}'
                          : 'ASSIGN SWARM TO ${_selectedAgentName.toUpperCase()}',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'JetBrains Mono',
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              PopupMenuButton<String>(
                tooltip: 'Assign swarm to specific agent...',
                color: const Color(0xFF160F2C),
                icon: Container(
                  height: 34,
                  width: 34,
                  decoration: BoxDecoration(
                    color: SwarmColors.bgElevated,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: SwarmColors.border),
                  ),
                  child: const Center(
                    child: Icon(Icons.person_add_alt_1_rounded, size: 14, color: SwarmColors.textSecondary),
                  ),
                ),
                itemBuilder: (context) => [
                  ...agents.map((a) => PopupMenuItem<String>(
                    value: a.id,
                    child: Row(
                      children: [
                        AgentAvatar(agentId: a.id, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          'Assign to ${a.name}',
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ],
                    ),
                  )),
                  const PopupMenuDivider(),
                  const PopupMenuItem<String>(
                    value: 'all',
                    child: Row(
                      children: [
                        Icon(Icons.public_rounded, size: 14, color: SwarmColors.warning),
                        SizedBox(width: 8),
                        Text(
                          'Assign to All Agents',
                          style: TextStyle(color: SwarmColors.warning, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ],
                onSelected: (agentId) => _assignSwarmToAgent(s.id, s.name, specificAgentId: agentId),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyCustomSwarmNotice() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: SwarmColors.border, style: BorderStyle.solid),
      ),
      child: Column(
        children: [
          const Icon(Icons.dashboard_customize_rounded, color: SwarmColors.agentCyan, size: 36),
          const SizedBox(height: 12),
          const Text(
            'Room for Custom Swarms',
            style: TextStyle(color: SwarmColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          const Text(
            'Compose and save your own unique multi-agent meshes using any model from the 70 NVIDIA NIM or 50 OpenRouter library.',
            style: TextStyle(color: SwarmColors.textMuted, fontSize: 12),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _openCreateSwarmDialog,
            style: ElevatedButton.styleFrom(
              backgroundColor: SwarmColors.agentCyan.withValues(alpha: 0.15),
              foregroundColor: SwarmColors.agentCyan,
              side: const BorderSide(color: SwarmColors.agentCyan),
            ),
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Create Your First Custom Swarm', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

/// Dialog for creating a custom swarm
class _CreateCustomSwarmDialog extends StatefulWidget {
  final Function(SwarmConfig) onCreated;

  const _CreateCustomSwarmDialog({required this.onCreated});

  @override
  State<_CreateCustomSwarmDialog> createState() => _CreateCustomSwarmDialogState();
}

class _CreateCustomSwarmDialogState extends State<_CreateCustomSwarmDialog> {
  final _nameController = TextEditingController(text: 'My Autonomous Team');
  final _roleController = TextEditingController(text: 'Custom Specialized Engineering');

  // 7 selected models for the custom swarm
  late SwarmModel _leaderModel;
  late SwarmModel _backendModel;
  late SwarmModel _frontendModel;
  late SwarmModel _toolModel;
  late SwarmModel _qaModel;
  late SwarmModel _autocompleteModel;
  late SwarmModel _sysoptModel;

  @override
  void initState() {
    super.initState();
    // Default selections
    _leaderModel = allModels.firstWhere((m) => m.id == 'anthropic/claude-opus-4.6');
    _backendModel = allModels.firstWhere((m) => m.id == 'openai/gpt-5.6-sol');
    _frontendModel = allModels.firstWhere((m) => m.id == 'moonshotai/kimi-k3:free', orElse: () => allModels.firstWhere((m) => m.id == 'moonshotai/kimi-k3'));
    _toolModel = allModels.firstWhere((m) => m.id == 'deepseek/deepseek-v4-pro');
    _qaModel = allModels.firstWhere((m) => m.id == 'google/gemini-3.7-flash');
    _autocompleteModel = allModels.firstWhere((m) => m.id == 'zhipu/glm-5.2-autocomplete');
    _sysoptModel = allModels.firstWhere((m) => m.id == 'nvidia/nemotron-120b-ultra');
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: SwarmColors.bgSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: SwarmColors.border),
      ),
      child: Container(
        width: 720,
        height: 640,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.group_add_rounded, color: SwarmColors.accent, size: 24),
                    const SizedBox(width: 10),
                    Text(
                      'Create Custom Swarm',
                      style: SwarmTextStyles.title.copyWith(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: SwarmColors.textMuted),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              style: const TextStyle(color: SwarmColors.textPrimary),
              decoration: const InputDecoration(
                labelText: 'Swarm Name',
                labelStyle: TextStyle(color: SwarmColors.accent),
                filled: true,
                fillColor: SwarmColors.bgElevated,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _roleController,
              style: const TextStyle(color: SwarmColors.textPrimary),
              decoration: const InputDecoration(
                labelText: 'Swarm Purpose / Role',
                labelStyle: TextStyle(color: SwarmColors.accent),
                filled: true,
                fillColor: SwarmColors.bgElevated,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'ASSIGN MODELS TO SPECIALIZED AGENT ROLES:',
              style: SwarmTextStyles.labelSmall.copyWith(color: SwarmColors.textMuted),
            ),
            const SizedBox(height: 8),

            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _buildModelPickerRow('Leader / Orchestrator', _leaderModel, (m) => setState(() => _leaderModel = m)),
                    _buildModelPickerRow('Systems & Backend', _backendModel, (m) => setState(() => _backendModel = m)),
                    _buildModelPickerRow('Frontend & Layout', _frontendModel, (m) => setState(() => _frontendModel = m)),
                    _buildModelPickerRow('Tool, Shell & AST', _toolModel, (m) => setState(() => _toolModel = m)),
                    _buildModelPickerRow('QA & Verification Loop', _qaModel, (m) => setState(() => _qaModel = m)),
                    _buildModelPickerRow('Auto-Complete Engine', _autocompleteModel, (m) => setState(() => _autocompleteModel = m)),
                    _buildModelPickerRow('System Evals & Opt', _sysoptModel, (m) => setState(() => _sysoptModel = m)),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('CANCEL', style: TextStyle(color: SwarmColors.textMuted)),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: () {
                    final newSwarm = SwarmConfig(
                      id: 'custom-${DateTime.now().millisecondsSinceEpoch}',
                      name: _nameController.text.trim().isEmpty ? 'Custom Swarm' : _nameController.text.trim(),
                      role: _roleController.text.trim().isEmpty ? 'Custom Engineering' : _roleController.text.trim(),
                      models: [
                        _leaderModel,
                        _backendModel,
                        _frontendModel,
                        _toolModel,
                        _qaModel,
                        _autocompleteModel,
                        _sysoptModel,
                      ],
                      estimatedPrice: r'~$1.20 / 1M (Custom)',
                      isCustom: true,
                    );
                    widget.onCreated(newSwarm);
                    Navigator.of(context).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: SwarmColors.accent,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  ),
                  child: const Text('SAVE CUSTOM SWARM', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModelPickerRow(String roleTitle, SwarmModel current, Function(SwarmModel) onSelected) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: SwarmColors.bgElevated,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: SwarmColors.border),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 160,
              child: Text(
                roleTitle,
                style: const TextStyle(color: SwarmColors.textSecondary, fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Builder(builder: (ctx) {
                final liveCatalog = p.Provider.of<LiveModelCatalogService>(ctx);
                // Custom-swarm building is exactly where "no dead models"
                // matters most — don't let a user pick one that will fail
                // when they actually try to chat with it. Live-dead entries
                // are dropped from the picker entirely, except `current`
                // itself: a previously-saved swarm might already reference
                // one, and DropdownButton crashes if its value isn't among
                // its items — so it stays selectable (visibly flagged) only
                // because it's already selected, never offered fresh.
                final pickable = allModels.where((m) {
                  if (m.id == current.id) return true;
                  return !liveModelStatus(m, liveCatalog).isDead;
                }).toList();
                return DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: current.id,
                    isExpanded: true,
                    dropdownColor: SwarmColors.bgElevated,
                    items: pickable.map((m) {
                      final st = liveModelStatus(m, liveCatalog);
                      return DropdownMenuItem(
                        value: m.id,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                '${st.isDead ? '⚠ ' : ''}${m.name} (${m.provider.name.toUpperCase()})',
                                style: TextStyle(color: st.isDead ? SwarmColors.error : SwarmColors.textPrimary, fontSize: 12),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              st.isDead ? 'NOT ON OPENROUTER' : st.price,
                              style: TextStyle(
                                color: st.isDead ? SwarmColors.error : (st.price == 'FREE' ? SwarmColors.success : SwarmColors.accentSky),
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        final selected = allModels.firstWhere((m) => m.id == val);
                        onSelected(selected);
                      }
                    },
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}

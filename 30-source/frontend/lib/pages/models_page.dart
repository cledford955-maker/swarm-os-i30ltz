import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import '../agent/agent_chat.dart';
import '../models/agent.dart';
import '../models/swarm.dart';
import '../services/live_model_catalog_service.dart';
import '../skills/nvidia_nim_skill.dart';
import '../theme/swarm_colors.dart';
import '../theme/swarm_text_styles.dart';
import '../widgets/extensions_dialog.dart';
import '../providers/skill_router_providers.dart';

/// Adapts a live-fetched OpenRouter model into a SwarmModel so it can flow
/// through the existing model-card UI unchanged. Only ever built from data
/// LiveModelCatalogService actually fetched — never a hand-typed guess.
SwarmModel swarmModelFromLive(LiveModel m) {
  return SwarmModel(
    id: m.id,
    name: m.name,
    role: 'Live-verified · ${m.contextDisplay} context',
    provider: m.isNvidiaFree ? ProviderId.nvidia : ProviderId.openrouter,
    tier: m.isFree ? ModelTier.freeOnline : ModelTier.paidOnline,
    pricePer1M: m.pricePer1MDisplay,
    contextWindow: m.contextDisplay,
    description: m.description.isNotEmpty ? m.description : 'Live model from OpenRouter — no static description available.',
    keywords: const ['live'],
  );
}

class ModelsPage extends ConsumerStatefulWidget {
  const ModelsPage({super.key});

  @override
  ConsumerState<ModelsPage> createState() => _ModelsPageState();
}

class _ModelsPageState extends ConsumerState<ModelsPage> {
  String _searchQuery = '';
  String _selectedFilter = 'ALL';
  String _selectedAgentId = 'lucille';
  String? _selectedLiveCategory;
  List<LiveModel> _liveCategoryResults = [];
  bool _loadingLiveCategory = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      p.Provider.of<LiveModelCatalogService>(context, listen: false).ensureLoaded();
    });
  }

  Future<void> _selectLiveCategory(String category) async {
    setState(() {
      _selectedFilter = 'LIVE CATEGORY';
      _selectedLiveCategory = category;
      _loadingLiveCategory = true;
    });
    final catalog = p.Provider.of<LiveModelCatalogService>(context, listen: false);
    final results = await catalog.fetchCategory(category);
    if (!mounted) return;
    setState(() {
      _liveCategoryResults = results;
      _loadingLiveCategory = false;
    });
  }

  Agent? get _selectedAgent =>
      agents.where((a) => a.id == _selectedAgentId).firstOrNull;

  String get _selectedAgentName {
    if (_selectedAgentId == 'all') return 'All Agents';
    return _selectedAgent?.name ?? _selectedAgentId;
  }

  String _getModelDisplayName(String modelId) {
    final s = swarms[modelId];
    if (s != null) return s.name;
    final m = allModels.where((model) => model.id == modelId).firstOrNull;
    if (m != null) return m.name;
    return modelId;
  }

  String _getModelShortName(String modelId) {
    if (modelId == 'openrouter/auto' || modelId == 'autorouter-swarm') {
      return '⚡ AutoRouter';
    }
    if (modelId == 'x-ai/grok-imagine-video-1.5') return '🎬 Grok Video 1.5';
    if (modelId == 'video-generation-swarm') return '🎬 Video Swarm';
    if (modelId == 'nim-free-power-swarm') return '🚀 NIM Free Mesh';
    if (modelId == 'default-coding-swarm') return '🧠 Flagship Mesh';
    final s = swarms[modelId];
    if (s != null) return s.name;
    final m = allModels.where((model) => model.id == modelId).firstOrNull;
    if (m != null) {
      if (m.keywords.contains('video')) return '🎬 ${m.name}';
      if (m.id.endsWith(':free')) return '🚀 ${m.name}';
      return m.name;
    }
    return modelId.split('/').last;
  }

  void _assignModelToAgent(String modelId, String modelName, {String? specificAgentId, bool isVideo = false, bool isAuto = false}) {
    final targetAgentId = specificAgentId ?? _selectedAgentId;

    if (targetAgentId == 'all') {
      for (final a in agents) {
        ref.read(agentModelProvider(a.id).notifier).state = modelId;
      }
    } else {
      ref.read(agentModelProvider(targetAgentId).notifier).state = modelId;
    }

    // Persist to SharedPreferences
    SharedPreferences.getInstance().then((prefs) {
      if (targetAgentId == 'all') {
        for (final a in agents) {
          prefs.setString('SWARM_AGENT_MODEL_${a.id}', modelId);
        }
      } else {
        prefs.setString('SWARM_AGENT_MODEL_$targetAgentId', modelId);
      }
    });

    final targetAgent = agents.where((a) => a.id == targetAgentId).firstOrNull;
    final targetName = targetAgentId == 'all'
        ? 'All Active Agents'
        : (targetAgent?.name ?? targetAgentId);

    final bool isVideoModel = isVideo ||
        modelId == 'video-generation-swarm' ||
        modelId.contains('grok') ||
        modelId.contains('veo') ||
        modelId.contains('sora') ||
        modelId.contains('kling') ||
        modelId.contains('wan') ||
        modelId.contains('hailuo');

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF160F2C),
        duration: const Duration(seconds: 4),
        content: Row(
          children: [
            Icon(
              isAuto || modelId == 'openrouter/auto'
                  ? Icons.alt_route_rounded
                  : isVideoModel
                      ? Icons.videocam_rounded
                      : Icons.check_circle_rounded,
              color: isAuto || modelId == 'openrouter/auto'
                  ? SwarmColors.warning
                  : isVideoModel
                      ? SwarmColors.agentPink
                      : SwarmColors.success,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: RichText(
                text: TextSpan(
                  text: 'Assigned ',
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  children: [
                    TextSpan(
                      text: modelName,
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

  @override
  Widget build(BuildContext context) {
    final liveCatalog = p.Provider.of<LiveModelCatalogService>(context);

    // A static OpenRouter-provider entry counts as "dead" once live data has
    // loaded and that exact id isn't in it — before the first live fetch
    // completes, nothing is excluded this way (liveCatalog.hasData is false),
    // so the list is never empty on cold start.
    bool isDeadStaticEntry(SwarmModel m) {
      if (!liveCatalog.hasData) return false;
      if (m.provider != ProviderId.openrouter && m.provider != ProviderId.nvidia) return false;
      return !liveCatalog.exists(m.id);
    }

    List<SwarmModel> filteredModels;
    if (_selectedFilter == 'LIVE CODING') {
      filteredModels = liveCatalog.topCodingModels(limit: 100).map(swarmModelFromLive).toList();
    } else if (_selectedFilter == 'LIVE CATEGORY' && _selectedLiveCategory != null) {
      filteredModels = _liveCategoryResults.map(swarmModelFromLive).toList();
    } else if (_selectedFilter == 'NVIDIA NIM' && liveCatalog.hasData) {
      filteredModels = liveCatalog.nvidiaNimFree.map(swarmModelFromLive).toList();
    } else {
      filteredModels = allModels.where((m) {
        if (isDeadStaticEntry(m)) return false;
        // Category filter
        if (_selectedFilter == 'ON SALE' && !m.isOnSale) return false;
        if (_selectedFilter == 'NVIDIA NIM' && m.provider != ProviderId.nvidia) return false;
        if (_selectedFilter == 'OPENROUTER' && m.provider != ProviderId.openrouter) return false;
        if (_selectedFilter == 'LOCAL' && m.provider != ProviderId.ollama) return false;
        if (_selectedFilter == 'VIDEO' && !m.keywords.contains('video')) return false;
        if (_selectedFilter == 'AUTOROUTER' && !m.keywords.contains('autorouter')) return false;
        return true;
      }).toList();
    }

    if (_searchQuery.isNotEmpty && _selectedFilter != 'LIVE CODING' && _selectedFilter != 'LIVE CATEGORY') {
      final query = _searchQuery.toLowerCase();
      filteredModels = filteredModels.where((m) {
        final matchId = m.id.toLowerCase().contains(query);
        final matchName = m.name.toLowerCase().contains(query);
        final matchRole = m.role.toLowerCase().contains(query);
        final matchDesc = m.description.toLowerCase().contains(query);
        final matchKw = m.keywords.any((k) => k.toLowerCase().contains(query));
        return matchId || matchName || matchRole || matchDesc || matchKw;
      }).toList();
    }

    final onSaleCount = allModels.where((m) => m.isOnSale && !isDeadStaticEntry(m)).length;
    final nvidiaCount = liveCatalog.hasData ? liveCatalog.nvidiaNimFree.length : allModels.where((m) => m.provider == ProviderId.nvidia).length;
    final openrouterCount = allModels.where((m) => m.provider == ProviderId.openrouter && !isDeadStaticEntry(m)).length;
    final videoCount = allModels.where((m) => m.keywords.contains('video')).length;
    final autoRouterCount = allModels.where((m) => m.keywords.contains('autorouter')).length;
    final deadCount = liveCatalog.hasData ? allModels.where(isDeadStaticEntry).length : 0;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── Header & Top Actions ──────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI MODEL & SWARM REGISTRY',
                      style: SwarmTextStyles.displayLarge.copyWith(
                        fontSize: 26,
                        letterSpacing: 1.5,
                        color: SwarmColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Browse and orchestrate verified LLMs: Free NVIDIA NIM endpoints, OpenRouter models & AutoRouter, high-fidelity video generation suite, and multi-agent swarms.',
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
                      onPressed: () => context.go('/swarm'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: SwarmColors.accent,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.hub_rounded, size: 16),
                      label: const Text('MANAGE SWARMS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
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
                            'ASSIGNING MODEL TO AGENT:',
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
                                'Active Model: ',
                                style: TextStyle(color: SwarmColors.textMuted, fontSize: 11),
                              ),
                              Text(
                                _getModelDisplayName(ref.watch(agentModelProvider(_selectedAgentId))),
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
                          final modelDisplay = _getModelShortName(agentCurrentModel);

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
                                    color: isSelected
                                        ? agent.accent
                                        : SwarmColors.border,
                                    width: isSelected ? 1.8 : 1.0,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      agent.icon,
                                      size: 16,
                                      color: isSelected ? agent.accent : SwarmColors.textMuted,
                                    ),
                                    const SizedBox(width: 8),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          agent.name,
                                          style: TextStyle(
                                            color: isSelected ? Colors.white : SwarmColors.textSecondary,
                                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                            fontSize: 12,
                                          ),
                                        ),
                                        Text(
                                          modelDisplay,
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

            // ─── Swarms Overview Section (All Models Listed) ────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.layers_rounded, color: SwarmColors.accent, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'SWARM ARCHITECTURES (ALL MODELS LISTED)',
                      style: SwarmTextStyles.title.copyWith(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                TextButton.icon(
                  onPressed: () => context.go('/swarm'),
                  icon: const Icon(Icons.arrow_forward, size: 14, color: SwarmColors.accent),
                  label: const Text('Configure Custom Swarms', style: TextStyle(color: SwarmColors.accent, fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 12),

            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: swarms.values.map((s) => _buildSwarmSummaryCard(s)).toList(),
            ),

            const SizedBox(height: 44),

            // ─── Search and Filter Bar ─────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.psychology_rounded, color: SwarmColors.agentCyan, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'COMPLETE MODEL LIBRARY (${filteredModels.length} / ${allModels.length})',
                      style: SwarmTextStyles.title.copyWith(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Search text field
            Container(
              decoration: BoxDecoration(
                color: SwarmColors.bgElevated,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: SwarmColors.border),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  const Icon(Icons.search_rounded, color: SwarmColors.textMuted, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      style: const TextStyle(color: SwarmColors.textPrimary),
                      decoration: const InputDecoration(
                        hintText: 'Search 120+ models by name, role, ID, provider, or keywords (e.g. "Claude", "NIM", "Sale", "Coder", "GLM")...',
                        hintStyle: TextStyle(color: SwarmColors.textMuted, fontSize: 13),
                        border: InputBorder.none,
                      ),
                      onChanged: (val) => setState(() => _searchQuery = val),
                    ),
                  ),
                  if (_searchQuery.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.clear, size: 16, color: SwarmColors.textMuted),
                      onPressed: () => setState(() => _searchQuery = ''),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Filter Chips
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildFilterChip('ALL', 'ALL (${allModels.length})', SwarmColors.accent),
                _buildFilterChip('LIVE CODING', 'LIVE CODING (TOP ${liveCatalog.topCodingModels(limit: 100).length} 🔴)', SwarmColors.success),
                _buildFilterChip('NVIDIA NIM', 'NVIDIA NIM ($nvidiaCount FREE)', SwarmColors.agentPurple),
                _buildFilterChip('OPENROUTER', 'OPENROUTER ($openrouterCount)', SwarmColors.agentCyan),
                _buildFilterChip('VIDEO', 'VIDEO ($videoCount 🎬)', SwarmColors.agentPink),
                _buildFilterChip('AUTOROUTER', 'AUTOROUTER ($autoRouterCount ⚡)', SwarmColors.warning),
                _buildFilterChip('ON SALE', 'ON SALE ($onSaleCount 🔥)', SwarmColors.success),
                _buildFilterChip('LOCAL', 'LOCAL OFFLINE (OLLAMA)', SwarmColors.textMuted),
                _buildLiveCategoryChip(),
              ],
            ),
            const SizedBox(height: 8),

            // Live catalog status — shows the ground truth this page is
            // filtering against, and how many static entries it hid because
            // they don't exist on OpenRouter right now.
            Row(
              children: [
                Icon(
                  liveCatalog.hasData ? Icons.wifi_tethering : (liveCatalog.loading ? Icons.sync : Icons.wifi_off),
                  size: 13,
                  color: liveCatalog.hasData ? SwarmColors.success : SwarmColors.textMuted,
                ),
                const SizedBox(width: 6),
                Text(
                  liveCatalog.hasData
                      ? 'Live: ${liveCatalog.all.length} models from OpenRouter${liveCatalog.fetchedAt != null ? ' · fetched ${_timeAgo(liveCatalog.fetchedAt!)}' : ''}${deadCount > 0 ? ' · $deadCount static entries hidden (not on OpenRouter right now)' : ''}'
                      : (liveCatalog.loading ? 'Fetching live OpenRouter catalog…' : 'Live catalog not loaded yet — showing static list only'),
                  style: const TextStyle(color: SwarmColors.textMuted, fontSize: 11),
                ),
                if (liveCatalog.hasData) ...[
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => liveCatalog.refresh(),
                    child: const Text('Refresh', style: TextStyle(color: SwarmColors.agentCyan, fontSize: 11, fontWeight: FontWeight.w600)),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),

            // Quick Info Bar for AutoRouter & Video Models
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: SwarmColors.bgSurface.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: SwarmColors.border),
              ),
              child: Row(
                children: [
                  const Icon(Icons.tips_and_updates_rounded,
                      size: 16, color: SwarmColors.accentSky),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Tip: Selecting an agent above assigns chosen models directly to that agent. Click the "ASSIGN" button on any card to immediately assign it.',
                      style: SwarmTextStyles.codeSmall.copyWith(
                        color: SwarmColors.textMuted,
                        fontSize: 10.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ─── NVIDIA NIM Health / Cost Dashboard ────────────────────────────
            _buildNimDashboard(ref, liveCatalog),
            const SizedBox(height: 16),

            // ─── Model Cards Grid ──────────────────────────────────────────────
            if (filteredModels.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(40),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: SwarmColors.border),
                ),
                child: Center(
                  child: Text(
                    (_selectedFilter == 'LIVE CODING' && liveCatalog.loading) ||
                            (_selectedFilter == 'LIVE CATEGORY' && _loadingLiveCategory)
                        ? 'Fetching live results from OpenRouter…'
                        : (_selectedFilter == 'LIVE CODING' || _selectedFilter == 'NVIDIA NIM') && !liveCatalog.hasData
                            ? 'Live catalog hasn\'t loaded yet — check your connection and try Refresh above.'
                            : 'No models found matching your search and filter criteria.',
                    style: const TextStyle(color: SwarmColors.textMuted),
                  ),
                ),
              )
            else
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: filteredModels.map((m) => _buildModelCard(m)).toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String filterKey, String label, Color activeColor) {
    final isSelected = _selectedFilter == filterKey;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => setState(() => _selectedFilter = filterKey),
      selectedColor: activeColor.withValues(alpha: 0.25),
      backgroundColor: SwarmColors.bgElevated,
      side: BorderSide(
        color: isSelected ? activeColor : SwarmColors.border,
        width: isSelected ? 1.5 : 1.0,
      ),
      labelStyle: TextStyle(
        color: isSelected ? activeColor : SwarmColors.textSecondary,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
        fontSize: 11,
      ),
    );
  }

  String _timeAgo(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    return '${d.inHours}h ago';
  }

  /// Live browse by one of OpenRouter's own real category values (confirmed
  /// against the API, not guessed) — 'programming' covers coding; the rest
  /// (roleplay, marketing, technology, science, translation, legal, finance,
  /// health, trivia, academia) are the only other categories the API accepts.
  Widget _buildLiveCategoryChip() {
    final isSelected = _selectedFilter == 'LIVE CATEGORY';
    return PopupMenuButton<String>(
      onSelected: _selectLiveCategory,
      itemBuilder: (ctx) => kOpenRouterCategories
          .map((c) => PopupMenuItem(value: c, child: Text(c.toUpperCase())))
          .toList(),
      child: ChoiceChip(
        label: Text(_selectedLiveCategory != null && isSelected
            ? 'LIVE: ${_selectedLiveCategory!.toUpperCase()}${_loadingLiveCategory ? '…' : ' (${_liveCategoryResults.length})'}'
            : 'LIVE CATEGORY ▾'),
        selected: isSelected,
        onSelected: (_) {},
        selectedColor: SwarmColors.agentPink.withValues(alpha: 0.25),
        backgroundColor: SwarmColors.bgElevated,
        side: BorderSide(
          color: isSelected ? SwarmColors.agentPink : SwarmColors.border,
          width: isSelected ? 1.5 : 1.0,
        ),
        labelStyle: TextStyle(
          color: isSelected ? SwarmColors.agentPink : SwarmColors.textSecondary,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          fontSize: 11,
        ),
      ),
    );
  }

  Widget _buildSwarmSummaryCard(SwarmConfig s) {
    final isDefault = s.isDefault;
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
        color: isDefault
            ? SwarmColors.accent.withValues(alpha: 0.08)
            : Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDefault ? SwarmColors.accent : cardAccent.withValues(alpha: 0.5),
          width: isDefault ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  s.name,
                  style: TextStyle(
                    color: isDefault ? SwarmColors.accent : Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isDefault)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: SwarmColors.accent,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text('DEFAULT', style: TextStyle(color: Colors.black, fontSize: 9, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(s.role, style: const TextStyle(color: SwarmColors.textMuted, fontSize: 11.5)),
          const SizedBox(height: 10),
          Text(
            'Est. Cost: ${s.estimatedPrice ?? "FREE"}',
            style: TextStyle(color: cardAccent, fontSize: 11.5, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: SwarmColors.bgElevated,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'MODELS LISTED (${s.models.length}):',
                  style: const TextStyle(color: SwarmColors.textMuted, fontSize: 8.5, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                ...s.models.map((m) => Padding(
                  padding: const EdgeInsets.only(bottom: 2.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          '• ${m.name} (${m.role})',
                          style: const TextStyle(color: SwarmColors.textSecondary, fontSize: 10),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        m.pricePer1M ?? 'FREE',
                        style: TextStyle(
                          color: m.pricePer1M == 'FREE' ? SwarmColors.success : SwarmColors.agentSky,
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                )),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Swarm Assign Button Row
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 32,
                  child: ElevatedButton.icon(
                    onPressed: () => _assignModelToAgent(s.id, s.name, isVideo: isVideo, isAuto: isAuto),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: cardAccent.withValues(alpha: 0.18),
                      foregroundColor: cardAccent,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                        side: BorderSide(color: cardAccent.withValues(alpha: 0.6)),
                      ),
                    ),
                    icon: Icon(
                      isVideo
                          ? Icons.videocam_rounded
                          : isAuto
                              ? Icons.alt_route_rounded
                              : Icons.hub_rounded,
                      size: 13,
                    ),
                    label: Text(
                      'ASSIGN SWARM TO ${_selectedAgentName.toUpperCase()}',
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
                  height: 32,
                  width: 32,
                  decoration: BoxDecoration(
                    color: SwarmColors.bgElevated,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: SwarmColors.border),
                  ),
                  child: const Center(
                    child: Icon(Icons.person_add_alt_1_rounded, size: 13, color: SwarmColors.textSecondary),
                  ),
                ),
                onSelected: (agentId) => _assignModelToAgent(s.id, s.name, specificAgentId: agentId, isVideo: isVideo, isAuto: isAuto),
                itemBuilder: (context) => [
                  ...agents.map((a) => PopupMenuItem(
                        value: a.id,
                        child: Row(
                          children: [
                            Icon(a.icon, size: 14, color: a.accent),
                            const SizedBox(width: 8),
                            Text('Assign to ${a.name}', style: const TextStyle(fontSize: 12, color: Colors.white)),
                          ],
                        ),
                      )),
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                    value: 'all',
                    child: Row(
                      children: [
                        Icon(Icons.public_rounded, size: 14, color: SwarmColors.warning),
                        SizedBox(width: 8),
                        Text('Assign to All Agents', style: TextStyle(fontSize: 12, color: SwarmColors.warning, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModelCard(SwarmModel m) {
    Color providerColor;
    switch (m.provider) {
      case ProviderId.nvidia:
        providerColor = SwarmColors.agentPurple;
        break;
      case ProviderId.openrouter:
        providerColor = SwarmColors.agentCyan;
        break;
      case ProviderId.ollama:
        providerColor = SwarmColors.agentPink;
        break;
    }

    final isVideo = m.keywords.contains('video');
    final isAuto = m.id == 'openrouter/auto';

    return Container(
      width: 320,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isAuto
              ? SwarmColors.warning.withValues(alpha: 0.6)
              : isVideo
                  ? SwarmColors.agentPink.withValues(alpha: 0.6)
                  : m.isOnSale
                      ? SwarmColors.success.withValues(alpha: 0.6)
                      : SwarmColors.border,
          width: (isAuto || isVideo || m.isOnSale) ? 1.5 : 1.0,
        ),
        boxShadow: [
          if (m.isOnSale)
            BoxShadow(
              color: SwarmColors.success.withValues(alpha: 0.1),
              blurRadius: 10,
            ),
          if (isVideo)
            BoxShadow(
              color: SwarmColors.agentPink.withValues(alpha: 0.1),
              blurRadius: 10,
            ),
          if (isAuto)
            BoxShadow(
              color: SwarmColors.warning.withValues(alpha: 0.1),
              blurRadius: 10,
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row with Provider and Sale/Video/Auto Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: providerColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: providerColor.withValues(alpha: 0.4)),
                ),
                child: Text(
                  m.provider.name.toUpperCase(),
                  style: TextStyle(
                    color: providerColor,
                    fontSize: 8.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isVideo)
                    Container(
                      margin: const EdgeInsets.only(right: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: SwarmColors.agentPink.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: SwarmColors.agentPink.withValues(alpha: 0.6)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.videocam_rounded, color: SwarmColors.agentPink, size: 10),
                          SizedBox(width: 3),
                          Text(
                            'VIDEO',
                            style: TextStyle(color: SwarmColors.agentPink, fontSize: 8.5, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  if (isAuto)
                    Container(
                      margin: const EdgeInsets.only(right: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: SwarmColors.warning.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: SwarmColors.warning.withValues(alpha: 0.6)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.alt_route_rounded, color: SwarmColors.warning, size: 10),
                          SizedBox(width: 3),
                          Text(
                            'AUTOROUTER',
                            style: TextStyle(color: SwarmColors.warning, fontSize: 8.5, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  if (m.isOnSale)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: SwarmColors.success.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: SwarmColors.success),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.local_fire_department, color: SwarmColors.success, size: 10),
                          const SizedBox(width: 2),
                          Text(
                            m.saleDiscount ?? 'SALE',
                            style: const TextStyle(color: SwarmColors.success, fontSize: 8.5, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Name and ID
          Text(
            m.name,
            style: const TextStyle(
              color: SwarmColors.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            m.id,
            style: SwarmTextStyles.codeSmall.copyWith(
              color: SwarmColors.textMuted,
              fontSize: 9.5,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),

          // Role
          Text(
            m.role,
            style: const TextStyle(
              color: SwarmColors.accent,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),

          // Description
          Text(
            m.description,
            style: const TextStyle(
              color: SwarmColors.textSecondary,
              fontSize: 11,
              height: 1.3,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),

          // Price & Context Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    m.pricePer1M ?? 'FREE',
                    style: TextStyle(
                      color: m.pricePer1M == 'FREE' ? SwarmColors.success : SwarmColors.accentSky,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (m.originalPricePer1M != null) ...[
                    const SizedBox(width: 6),
                    Text(
                      m.originalPricePer1M!,
                      style: const TextStyle(
                        color: SwarmColors.textMuted,
                        decoration: TextDecoration.lineThrough,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ],
              ),
              if (m.contextWindow != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: SwarmColors.bgElevated,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    m.contextWindow!,
                    style: const TextStyle(color: SwarmColors.textMuted, fontSize: 9),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Route to Agent Button Row with Quick Agent Popup Menu
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 32,
                  child: ElevatedButton.icon(
                    onPressed: () => _assignModelToAgent(m.id, m.name, isVideo: isVideo, isAuto: isAuto),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isAuto
                          ? SwarmColors.warning.withValues(alpha: 0.22)
                          : isVideo
                              ? SwarmColors.agentPink.withValues(alpha: 0.22)
                              : (_selectedAgent?.accent ?? SwarmColors.accent).withValues(alpha: 0.15),
                      foregroundColor: isAuto
                          ? SwarmColors.warning
                          : isVideo
                              ? SwarmColors.agentPink
                              : (_selectedAgent?.accent ?? SwarmColors.accent),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                        side: BorderSide(
                          color: isAuto
                              ? SwarmColors.warning.withValues(alpha: 0.7)
                              : isVideo
                                  ? SwarmColors.agentPink.withValues(alpha: 0.7)
                                  : (_selectedAgent?.accent ?? SwarmColors.accent).withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                    icon: Icon(
                      isAuto
                          ? Icons.alt_route_rounded
                          : isVideo
                              ? Icons.videocam_rounded
                              : Icons.check_circle_outline_rounded,
                      size: 13,
                    ),
                    label: Text(
                      'ASSIGN TO ${_selectedAgentName.toUpperCase()}',
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
                tooltip: 'Assign to specific agent...',
                color: const Color(0xFF160F2C),
                icon: Container(
                  height: 32,
                  width: 32,
                  decoration: BoxDecoration(
                    color: SwarmColors.bgElevated,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: SwarmColors.border),
                  ),
                  child: const Center(
                    child: Icon(Icons.person_add_alt_1_rounded, size: 13, color: SwarmColors.textSecondary),
                  ),
                ),
                onSelected: (agentId) => _assignModelToAgent(m.id, m.name, specificAgentId: agentId, isVideo: isVideo, isAuto: isAuto),
                itemBuilder: (context) => [
                  ...agents.map((a) => PopupMenuItem(
                        value: a.id,
                        child: Row(
                          children: [
                            Icon(a.icon, size: 14, color: a.accent),
                            const SizedBox(width: 8),
                            Text('Assign to ${a.name}', style: const TextStyle(fontSize: 12, color: Colors.white)),
                          ],
                        ),
                      )),
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                    value: 'all',
                    child: Row(
                      children: [
                        Icon(Icons.public_rounded, size: 14, color: SwarmColors.warning),
                        SizedBox(width: 8),
                        Text('Assign to All Agents', style: TextStyle(fontSize: 12, color: SwarmColors.warning, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNimDashboard(WidgetRef ref, LiveModelCatalogService catalog) {
    final voiceService = ref.watch(nvidiaVoiceServiceProvider);
    final ragService = ref.watch(nvidiaRagServiceProvider);
    final imageService = ref.watch(nvidiaImageServiceProvider);

    final nimSkills = NvidiaNimSkillRegistry.all;
    final freeNimModels = catalog.hasData ? catalog.nvidiaNimFree : <LiveModel>[];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF130D26),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: SwarmColors.agentPurple.withValues(alpha: 0.5), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: SwarmColors.agentPurple.withValues(alpha: 0.08),
            blurRadius: 16,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.dashboard_customize_rounded, color: SwarmColors.agentPurple, size: 20),
              const SizedBox(width: 8),
              Text(
                'NVIDIA NIM HEALTH & COST DASHBOARD',
                style: SwarmTextStyles.title.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: SwarmColors.agentPurple,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: SwarmColors.agentPurple.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: SwarmColors.agentPurple.withValues(alpha: 0.4)),
                ),
                child: Text(
                  '${freeNimModels.length} FREE NIMs LIVE',
                  style: const TextStyle(
                    color: SwarmColors.agentPurple,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'JetBrains Mono',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Skill cards row
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: nimSkills.map((skill) {
              final isFree = skill.costTier == NimSkillCostTier.free;
              final liveModel = freeNimModels.where((m) => m.id == skill.defaultModelId).firstOrNull;
              final isAvailable = liveModel != null;
              final statusColor = isAvailable ? SwarmColors.success : SwarmColors.error;

              return Container(
                width: 280,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isAvailable
                        ? SwarmColors.success.withValues(alpha: 0.5)
                        : SwarmColors.border,
                    width: isAvailable ? 1.5 : 1.0,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                          ),
                          child: Text(
                            isAvailable ? 'LIVE' : 'UNAVAILABLE',
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 7.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (isFree)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: SwarmColors.success.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: SwarmColors.success.withValues(alpha: 0.4)),
                            ),
                            child: const Text(
                              'FREE',
                              style: TextStyle(
                                color: SwarmColors.success,
                                fontSize: 7.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      skill.name,
                      style: const TextStyle(
                        color: SwarmColors.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      skill.defaultModelId,
                      style: SwarmTextStyles.codeSmall.copyWith(
                        color: SwarmColors.textMuted,
                        fontSize: 8.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      skill.description,
                      style: const TextStyle(
                        color: SwarmColors.textSecondary,
                        fontSize: 9.5,
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Cost: ${skill.costTier.name.toUpperCase()}',
                            style: TextStyle(
                              color: isFree ? SwarmColors.success : SwarmColors.warning,
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (isAvailable && liveModel != null)
                          Text(
                            liveModel.pricePer1MDisplay,
                            style: const TextStyle(
                              color: SwarmColors.success,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'JetBrains Mono',
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 16),

          // Quick test buttons row
          Row(
            children: [
              Expanded(
                child: _buildNimTestButton(
                  'Test STT',
                  Icons.mic_rounded,
                  SwarmColors.agentCyan,
                  () async {
                    // Would need an audio file - placeholder
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('STT test requires audio file input')),
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildNimTestButton(
                  'Test TTS',
                  Icons.record_voice_over_rounded,
                  SwarmColors.agentPink,
                  () async {
                    final agent = getAgent('vital') ?? agents.first;
                    try {
                      final path = await voiceService.speakWithDefaultAgent(
                        'NVIDIA Riva FastPitch test from SWARM OS dashboard.',
                      );
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('TTS generated: $path')),
                      );
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('TTS failed: $e')),
                      );
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildNimTestButton(
                  'Test Embed',
                  Icons.data_array_rounded,
                  SwarmColors.success,
                  () async {
                    final agent = getAgent('librarian') ?? agents.first;
                    try {
                      final vectors = await ragService.embedWithDefaultAgent([
                        'SWARM OS is a Flutter desktop AI operating system.',
                        'NVIDIA NIM provides free inference endpoints.',
                      ]);
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Embedded ${vectors.length} chunks, dim=${vectors.first.length}')),
                      );
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Embed failed: $e')),
                      );
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildNimTestButton(
                  'Test Image',
                  Icons.image_rounded,
                  SwarmColors.agentPurple,
                  () async {
                    final agent = getAgent('ui_tandem') ?? agents.first;
                    try {
                      final img = await imageService.generateWithDefaultAgent(
                        'Cyberpunk SWARM OS desktop, neon cyan and magenta, glassmorphism UI',
                      );
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Image: ${img.url.isNotEmpty ? "OK" : "No URL"}')),
                      );
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Image failed: $e')),
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNimTestButton(String label, IconData icon, Color color, VoidCallback onPressed) {
    return SizedBox(
      height: 40,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color.withValues(alpha: 0.15),
          foregroundColor: color,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
            side: BorderSide(color: color.withValues(alpha: 0.5)),
          ),
        ),
        icon: Icon(icon, size: 14),
        label: Text(
          label,
          style: const TextStyle(
            fontFamily: 'JetBrains Mono',
            fontSize: 9.5,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

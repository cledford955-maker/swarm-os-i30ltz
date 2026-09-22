import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/agent.dart';
import '../models/swarm.dart';
import '../providers/sentinel_providers.dart';
import '../theme/swarm_colors.dart';
import '../theme/swarm_text_styles.dart';
import 'chat_message.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/lucille_voice_service.dart';
import 'package:go_router/go_router.dart';

// ─── Chat State ─────────────────────────────────────────────────────────────

// Was a hardcoded 'default-coding-swarm' for every agent regardless of id —
// agent.defaultSwarmId existed on the Agent model but nothing ever read it,
// so per-agent defaults (antigravity-swarm, therapist-swarm, nemotron-swarm
// for system/gaming/eval agents, ...) were dead metadata. Now reads it.
final agentModelProvider = StateProvider.family<String, String>(
    (ref, agentId) => getAgent(agentId)?.defaultSwarmId ?? 'default-coding-swarm');

class ChatMsg {
  final String id;
  final bool isUser;
  String text;
  final bool isStreaming;

  ChatMsg({
    required this.id,
    required this.isUser,
    required this.text,
    this.isStreaming = false,
  });

  ChatMsg copyWith({String? text, bool? isStreaming}) => ChatMsg(
        id: id,
        isUser: isUser,
        text: text ?? this.text,
        isStreaming: isStreaming ?? this.isStreaming,
      );
}

// Per-agent chat history provider
final _chatProvider =
    StateNotifierProvider.family<ChatNotifier, List<ChatMsg>, String>(
  (ref, agentId) => ChatNotifier(agentId),
);

class ChatNotifier extends StateNotifier<List<ChatMsg>> {
  final String agentId;
  static const _uuid = Uuid();

  ChatNotifier(this.agentId) : super([]) {
    // Greeting
    final agent = getAgent(agentId);
    if (agent != null) {
      state = [
        ChatMsg(
          id: _uuid.v4(),
          isUser: false,
          text: _greeting(agent),
        )
      ];
    }
  }

  String _greeting(Agent agent) {
    final greetings = <String, String>{
      'lucille':
          'LUCILLE CORE online. All subsystems nominal. How can I orchestrate for you?',
      'atlas':
          'ATLAS here. Ready to run your day — tasks, reminders, or a full briefing?',
      'nova': 'Hey, I\'m Nova. Always here when you need to talk.',
      'sage': 'SAGE online. What\'s on your mind?',
      'forge': 'FORGE ready. Repository loaded. What are we building?',
      'sysadmin':
          'SysAdmin reporting. All host metrics nominal. Need a diagnostic?',
      'warden': 'WARDEN active. System health: nominal. What needs monitoring?',
      'sting': 'STING online. Threat feed live. No active alerts.',
    };
    return greetings[agent.id] ??
        '${agent.name} online. ${agent.role} subsystem ready.';
  }

  String addPlaceholder() {
    final id = _uuid.v4();
    state = [
      ...state,
      ChatMsg(id: id, isUser: false, text: '', isStreaming: true)
    ];
    return id;
  }

  void addUserMessage(String text) {
    state = [...state, ChatMsg(id: _uuid.v4(), isUser: true, text: text)];
  }

  void updateStreaming(String id, String text) {
    state = state.map((m) => m.id == id ? m.copyWith(text: text) : m).toList();
  }

  void finalizeStreaming(String id, String fullText) {
    state = state
        .map((m) =>
            m.id == id ? m.copyWith(text: fullText, isStreaming: false) : m)
        .toList();
  }

  void removeMessage(String id) {
    state = state.where((m) => m.id != id).toList();
  }

  void replaceWithSummary(String summary) {
    state = [
      ChatMsg(
          id: _uuid.v4(),
          isUser: false,
          text: '⚡️ **Context Summarized:**\n\n$summary')
    ];
  }
}

// ─── Suggested Prompts ──────────────────────────────────────────────────────

const _prompts = <String, List<String>>{
  'lucille': [
    'Route a task to SysAdmin',
    'Show swarm node status',
    'Optimize this system'
  ],
  'atlas': ['Plan my day', 'Summarize my unread', 'Delegate to a specialist'],
  'nova': ['I had a rough day', 'Tell me something good', 'Just want to talk'],
  'sage': [
    'I feel anxious',
    'Help me reframe this',
    'Guide a grounding exercise'
  ],
  'forge': ['Refactor this code', 'Write unit tests', 'Explain this function'],
  'quill': [
    'Summarize my sources',
    'Draft an outline',
    'Make an audio overview'
  ],
  'vita': ['How\'s my recovery?', 'Plan a workout', 'Explain my sleep data'],
  'vault': [
    'Find my roadmap doc',
    'Organize downloads',
    'Summarize this folder'
  ],
  'postman': ['Draft replies', 'Triage my inbox', 'Unsubscribe from noise'],
  'ledger': ['Research this market', 'Compare competitors', 'Build a brief'],
  'coin': ['Show my cashflow', 'Am I over budget?', 'Rebalance ideas'],
  'tempo': ['Find a focus block', 'Prep my 3pm', 'Reschedule conflicts'],
  'roam': ['Plan a weekend trip', 'Find cheap flights', 'Build an itinerary'],
  'warden': ['Show CPU usage', 'List top processes', 'Check disk space'],
  'sting': ['Scan for threats', 'Show CVE alerts', 'Check firewall rules'],
  'sysadmin': ['Check RAM usage', 'List systemd services', 'Run pacman -Syu'],
};

List<String> _getPrompts(String agentId) =>
    _prompts[agentId] ??
    ['Tell me about yourself', 'What can you do?', 'Help me get started'];

// ─── Main Chat Panel Widget ──────────────────────────────────────────────────

class AgentChatPanel extends ConsumerStatefulWidget {
  final String agentId;

  const AgentChatPanel({
    super.key,
    required this.agentId,
  });

  @override
  ConsumerState<AgentChatPanel> createState() => _AgentChatPanelState();
}

class _AgentChatPanelState extends ConsumerState<AgentChatPanel> {
  final _ctrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _streaming = false;
  bool _autoSpeakEnabled = true;

  Agent? get _agent => getAgent(widget.agentId);

  @override
  void initState() {
    super.initState();
    _loadSavedModel();
  }

  Future<void> _loadSavedModel() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('SWARM_AGENT_MODEL_${widget.agentId}');
      if (saved != null && saved.isNotEmpty) {
        if (mounted) {
          ref.read(agentModelProvider(widget.agentId).notifier).state = saved;
        }
      }
    } catch (_) {}
  }

  void _setAgentModel(String modelId) {
    ref.read(agentModelProvider(widget.agentId).notifier).state = modelId;
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString('SWARM_AGENT_MODEL_${widget.agentId}', modelId);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  String _getProjectContext(String dirPath) {
    if (dirPath == '/home' || dirPath == '/') return ''; // Prevent huge trees
    final dir = Directory(dirPath);
    if (!dir.existsSync()) return '';

    final buffer = StringBuffer();
    buffer.writeln('\n\n--- PROJECT CONTEXT ---');
    buffer.writeln('Current Active Directory: $dirPath');
    buffer.writeln('You have the ability to read and write files here.');
    buffer.writeln(
        'To write/edit a file, ALWAYS wrap your code block exactly like this:');
    buffer.writeln('<file_write path="/absolute/path/to/file">');
    buffer.writeln('... code ...');
    buffer.writeln('</file_write>');
    buffer.writeln('\nFiles in this directory (shallow):');
    try {
      final List<String> filePaths = [];
      void traverse(Directory d) {
        if (filePaths.length >= 250) return;
        try {
          for (final e in d.listSync(followLinks: false)) {
            if (filePaths.length >= 250) break;
            final name = e.path.split('/').last;
            if (name == '.git' ||
                name == 'build' ||
                name == '.dart_tool' ||
                name == '.idea' ||
                name == 'node_modules') {
              continue;
            }
            filePaths.add(e.path);
            if (e is Directory) traverse(e);
          }
        } catch (_) {}
      }

      traverse(dir);
      for (final p in filePaths) {
        buffer.writeln(p);
      }
    } catch (_) {}
    return buffer.toString();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _processFileWrites(String responseText) {
    final RegExp regExp =
        RegExp(r'<file_write path="([^"]+)">([\s\S]*?)<\/file_write>');
    final matches = regExp.allMatches(responseText);
    for (final match in matches) {
      final path = match.group(1);
      final content = match.group(2);
      if (path != null && content != null) {
        try {
          final file = File(path);
          if (!file.parent.existsSync()) {
            file.parent.createSync(recursive: true);
          }
          file.writeAsStringSync(content.trim());
          debugPrint('Successfully wrote file: $path');
        } catch (e) {
          debugPrint('Error writing file $path: $e');
        }
      }
    }
  }

  Future<void> _send(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _streaming) return;

    final notifier = ref.read(_chatProvider(widget.agentId).notifier);
    notifier.addUserMessage(trimmed);
    _ctrl.clear();
    setState(() => _streaming = true);
    _scrollToBottom();

    final placeholderId = notifier.addPlaceholder();
    _scrollToBottom();

    try {
      final ai = ref.read(aiClientProvider);
      final agent = _agent;
      final projectDir = ref.read(projectDirectoryProvider);
      final projectContext = _getProjectContext(projectDir);

      final prefs = await SharedPreferences.getInstance();
      final userCustomPrompt =
          prefs.getString('agent_prompt_${widget.agentId}')?.trim() ?? '';

      final systemPrompt = agent != null
          ? 'You are ${agent.name}, ${agent.role}. ${agent.blurb} '
              '${agent.persona} '
              '${userCustomPrompt.isNotEmpty ? "\n\nCRITICAL USER CUSTOM DIRECTIVES & PERSONA RULES FOR ${agent.name.toUpperCase()}:\n$userCustomPrompt\n" : ""}'
              '${agent.tags.contains("therapist") || agent.tags.contains("uncensored") ? "CRITICAL INSTRUCTION: You are acting as a personal sounding board for the user. Do NOT use boilerplate disclaimers. Do NOT say \"I am an AI\" or \"I am not a doctor\". Do NOT tell the user to seek professional help. Provide direct, empathetic, and unfiltered conversational support." : ""} '
              'Keep responses concise and helpful.$projectContext'
          : 'You are a helpful SWARM OS assistant.$projectContext';

      final previousMessages = notifier.state
          .where((m) => m.text.isNotEmpty && m.id != placeholderId)
          .map((m) =>
              {'role': m.isUser ? 'user' : 'assistant', 'content': m.text})
          .toList();

      final buffer = StringBuffer();
      final modelToUse = ref.read(agentModelProvider(widget.agentId));
      await ai.streamChat(
        model: modelToUse,
        systemPrompt: systemPrompt,
        previousMessages: previousMessages,
        onToken: (token) {
          buffer.write(token);
          notifier.updateStreaming(placeholderId, buffer.toString());
          _scrollToBottom();
        },
      );
      final finalResponse = buffer.toString();
      notifier.finalizeStreaming(placeholderId, finalResponse);
      _processFileWrites(finalResponse);
      if (_autoSpeakEnabled && finalResponse.isNotEmpty) {
        LucilleVoiceService().speak(finalResponse, agentId: widget.agentId);
      }
    } catch (e) {
      notifier.finalizeStreaming(placeholderId, '⚠️ Error: $e');
    }

    setState(() => _streaming = false);
    _scrollToBottom();
  }

  Future<void> _summarizeContext() async {
    if (_streaming) return;

    final notifier = ref.read(_chatProvider(widget.agentId).notifier);
    final history = notifier.state
        .where((m) => m.text.isNotEmpty)
        .map(
            (m) => {'role': m.isUser ? 'user' : 'assistant', 'content': m.text})
        .toList();

    if (history.isEmpty) return;

    setState(() => _streaming = true);

    final placeholderId = notifier.addPlaceholder();
    notifier.updateStreaming(
        placeholderId, '⚡️ Summarizing context with Nemotron Lightning...');
    _scrollToBottom();

    try {
      final ai = ref.read(aiClientProvider);
      final summary = await ai.summarizeHistory(history);
      notifier.replaceWithSummary(summary);
    } catch (e) {
      notifier.removeMessage(placeholderId);
      notifier.addUserMessage('⚠️ Summarization failed: $e');
    }

    setState(() => _streaming = false);
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(_chatProvider(widget.agentId));
    final agent = _agent;
    final selectedModelId = ref.watch(agentModelProvider(widget.agentId));
    if (agent == null) return const SizedBox.shrink();

    final prompts = _getPrompts(widget.agentId);
    final showPrompts = messages.length <= 1;

    return Column(
      children: [
        // ─── Model Selector ───────────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: const BoxDecoration(
            color: SwarmColors.bgElevated,
            border: Border(bottom: BorderSide(color: SwarmColors.border)),
          ),
          child: Row(
            children: [
              Text('ROUTING:',
                  style: SwarmTextStyles.labelSmall
                      .copyWith(color: SwarmColors.textMuted)),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: selectedModelId,
                    isExpanded: true,
                    dropdownColor: SwarmColors.bgElevated,
                    icon: const Icon(Icons.arrow_drop_down,
                        color: SwarmColors.textMuted, size: 20),
                    items: _buildDropdownItems(selectedModelId),
                    onChanged: (val) {
                      if (val != null) {
                        _setAgentModel(val);
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () => context.go('/models'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: SwarmColors.accent.withValues(alpha: 0.15),
                  foregroundColor: SwarmColors.accent,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                    side: BorderSide(color: SwarmColors.accent.withValues(alpha: 0.4)),
                  ),
                ),
                icon: const Icon(Icons.psychology_rounded, size: 14),
                label: Text('MODELS (120+)', style: SwarmTextStyles.label.copyWith(fontSize: 10)),
              ),
              const SizedBox(width: 8),
              if (messages.length > 2)
                ElevatedButton.icon(
                  onPressed: _streaming ? null : _summarizeContext,
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        SwarmColors.agentCyan.withValues(alpha: 0.15),
                    foregroundColor: SwarmColors.agentCyan,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                      side: BorderSide(
                          color: SwarmColors.agentCyan.withValues(alpha: 0.5)),
                    ),
                  ),
                  icon: const Icon(Icons.bolt, size: 16),
                  label: Text('SUMMARIZE CONTEXT',
                      style: SwarmTextStyles.label.copyWith(fontSize: 10)),
                ),
              const SizedBox(width: 8),
              IconButton(
                icon: Icon(
                  _autoSpeakEnabled
                      ? Icons.volume_up_rounded
                      : Icons.volume_off_rounded,
                  size: 18,
                  color: _autoSpeakEnabled
                      ? SwarmColors.agentCyan
                      : SwarmColors.textMuted,
                ),
                tooltip: _autoSpeakEnabled
                    ? 'Lucy Voice Output Active (Click to mute)'
                    : 'Lucy Voice Output Muted (Click to enable)',
                onPressed: () {
                  setState(() => _autoSpeakEnabled = !_autoSpeakEnabled);
                },
              ),
            ],
          ),
        ),

        // ─── Model Description Banner & Quick Route Chips ──────────
        _buildModelDescriptionBanner(context, selectedModelId),

        // ─── Message List ──────────────────────────────────────────
        Expanded(
          child: ListView.builder(
            controller: _scrollCtrl,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            itemCount: messages.length + (showPrompts ? 1 : 0),
            itemBuilder: (context, i) {
              if (showPrompts && i == messages.length) {
                return _PromptChips(
                  prompts: prompts,
                  accentColor: agent.accent,
                  onTap: _send,
                );
              }
              final msg = messages[i];
              return ChatMessageBubble(
                message: msg,
                agent: agent,
                onRunCommand: (cmd) {
                  ref.read(sentinelClientProvider).sendCommand(cmd);
                },
              );
            },
          ),
        ),

        // ─── Composer ─────────────────────────────────────────────
        _Composer(
          ctrl: _ctrl,
          agent: agent,
          streaming: _streaming,
          onSend: _send,
        ),
      ],
    );
  }

  List<DropdownMenuItem<String>> _buildDropdownItems(String currentModelId) {
    final videoModels = allModels.where((m) => m.keywords.contains('video')).toList();
    final nimFreeModels = allModels.where((m) => m.id.endsWith(':free')).toList();
    final autoRouterModel = allModels.where((m) => m.id == 'openrouter/auto').firstOrNull;
    final otherModels = allModels.where((m) => 
        m.id != 'openrouter/auto' && 
        !m.keywords.contains('video') && 
        !m.id.endsWith(':free')
    ).toList();

    final items = <DropdownMenuItem<String>>[
      // 1. AutoRouter & Smart Dispatch
      const DropdownMenuItem(
        enabled: false,
        child: Text('─── ⚡ AUTOROUTER & SMART ROUTING ───',
            style: TextStyle(
                color: SwarmColors.warning,
                fontSize: 11,
                fontWeight: FontWeight.bold)),
      ),
      if (autoRouterModel != null)
        DropdownMenuItem(
          value: autoRouterModel.id,
          child: Text('⚡ ${autoRouterModel.name} (Auto Intent)',
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13)),
        ),
      if (swarms.containsKey('autorouter-swarm'))
        DropdownMenuItem(
          value: 'autorouter-swarm',
          child: Text('⚡ ${swarms['autorouter-swarm']!.name}',
              style: const TextStyle(
                  color: SwarmColors.warning,
                  fontWeight: FontWeight.bold,
                  fontSize: 13)),
        ),

      // 2. Video Generation Suite
      const DropdownMenuItem(
        enabled: false,
        child: Text('─── 🎬 VIDEO GENERATION SUITE ───',
            style: TextStyle(
                color: SwarmColors.agentPink,
                fontSize: 11,
                fontWeight: FontWeight.bold)),
      ),
      if (swarms.containsKey('video-generation-swarm'))
        DropdownMenuItem(
          value: 'video-generation-swarm',
          child: Text('🎬 ${swarms['video-generation-swarm']!.name}',
              style: const TextStyle(
                  color: SwarmColors.agentPink,
                  fontWeight: FontWeight.bold,
                  fontSize: 13)),
        ),
      ...videoModels.map((m) => DropdownMenuItem(
            value: m.id,
            child: Text('🎬 ${m.name}',
                style: const TextStyle(
                    color: SwarmColors.textPrimary,
                    fontSize: 12.5)),
          )),

      // 3. NVIDIA NIM Free Endpoints
      const DropdownMenuItem(
        enabled: false,
        child: Text('─── 🚀 NVIDIA NIM FREE ENDPOINTS ───',
            style: TextStyle(
                color: SwarmColors.agentPurple,
                fontSize: 11,
                fontWeight: FontWeight.bold)),
      ),
      if (swarms.containsKey('nim-free-power-swarm'))
        DropdownMenuItem(
          value: 'nim-free-power-swarm',
          child: Text('🚀 ${swarms['nim-free-power-swarm']!.name}',
              style: const TextStyle(
                  color: SwarmColors.agentPurple,
                  fontWeight: FontWeight.bold,
                  fontSize: 13)),
        ),
      ...nimFreeModels.map((m) => DropdownMenuItem(
            value: m.id,
            child: Text('🚀 ${m.name}',
                style: const TextStyle(
                    color: SwarmColors.agentPurple,
                    fontWeight: FontWeight.w600,
                    fontSize: 12.5)),
          )),

      // 4. Multi-Agent Swarms
      const DropdownMenuItem(
        enabled: false,
        child: Text('─── 🌐 MULTI-AGENT SWARMS ───',
            style: TextStyle(
                color: SwarmColors.accent,
                fontSize: 11,
                fontWeight: FontWeight.bold)),
      ),
      ...swarms.values
          .where((s) => s.id != 'autorouter-swarm' && s.id != 'video-generation-swarm' && s.id != 'nim-free-power-swarm')
          .map((s) => DropdownMenuItem(
                value: s.id,
                child: Text(s.name,
                    style: const TextStyle(
                        color: SwarmColors.textPrimary,
                        fontSize: 13)),
              )),

      // 5. All Other Models
      const DropdownMenuItem(
        enabled: false,
        child: Text('─── 🧠 ALL OTHER VERIFIED MODELS ───',
            style: TextStyle(
                color: SwarmColors.agentCyan,
                fontSize: 11,
                fontWeight: FontWeight.bold)),
      ),
      ...otherModels.map((m) => DropdownMenuItem(
            value: m.id,
            child: Text('${m.name} (${m.provider.name.toUpperCase()})',
                style: const TextStyle(
                    color: SwarmColors.textSecondary,
                    fontSize: 12.5)),
          )),
    ];

    final allItemValues = items.where((item) => item.value != null).map((item) => item.value!).toSet();
    if (!allItemValues.contains(currentModelId)) {
      items.insert(0, DropdownMenuItem(
        value: currentModelId,
        child: Text('Active ($currentModelId)', style: const TextStyle(color: SwarmColors.accent, fontWeight: FontWeight.bold)),
      ));
    }

    return items;
  }

  Widget _buildModelDescriptionBanner(BuildContext context, String modelId) {
    final selectedSwarm = swarms[modelId];
    final selectedModel =
        allModels.where((m) => m.id == modelId).firstOrNull;

    final String name = selectedSwarm?.name ?? selectedModel?.name ?? modelId;
    final String description = selectedSwarm?.description ??
        selectedModel?.description ??
        'Adaptive routing endpoint for AI agent tasks.';
    final String role = selectedSwarm != null
        ? 'Multi-Agent Mesh'
        : (selectedModel?.role ?? 'LLM Model');
    final String? providerName = selectedModel?.provider.name.toUpperCase();
    final String? price =
        selectedModel?.pricePer1M ?? (selectedSwarm != null ? 'SWARM' : null);
    final String? contextWindow = selectedModel?.contextWindow;

    final bool isAutoRouter =
        modelId == 'openrouter/auto' || modelId == 'autorouter-swarm';
    final bool isVideo = (selectedModel?.keywords.contains('video') ?? false) ||
        modelId == 'video-generation-swarm';
    final bool isNimFree =
        modelId.endsWith(':free') || modelId == 'nim-free-power-swarm';

    Color themeColor = SwarmColors.agentCyan;
    if (isAutoRouter) {
      themeColor = SwarmColors.warning;
    } else if (isVideo) {
      themeColor = SwarmColors.agentPink;
    } else if (isNimFree) {
      themeColor = SwarmColors.agentPurple;
    } else if (selectedSwarm != null) {
      themeColor = SwarmColors.accent;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF100B22),
        border: Border(
          bottom:
              BorderSide(color: themeColor.withValues(alpha: 0.35), width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Badges, Name, Role, Price & Context
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: themeColor.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: themeColor.withValues(alpha: 0.6)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isAutoRouter
                          ? Icons.alt_route_rounded
                          : isVideo
                              ? Icons.videocam_rounded
                              : isNimFree
                                  ? Icons.bolt_rounded
                                  : Icons.hub_rounded,
                      size: 11,
                      color: themeColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isAutoRouter
                          ? 'AUTOROUTER'
                          : isVideo
                              ? 'VIDEO MODEL'
                              : isNimFree
                                  ? 'NIM FREE'
                                  : (providerName ?? 'SWARM'),
                      style: TextStyle(
                        fontFamily: 'JetBrains Mono',
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: themeColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                decoration: BoxDecoration(
                  color: SwarmColors.bgElevated,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: SwarmColors.border),
                ),
                child: Text(
                  role,
                  style: const TextStyle(
                    color: SwarmColors.textMuted,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (price != null) ...[
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: price == 'FREE' || isNimFree
                        ? SwarmColors.success.withValues(alpha: 0.15)
                        : SwarmColors.bgElevated,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: price == 'FREE' || isNimFree
                          ? SwarmColors.success.withValues(alpha: 0.5)
                          : SwarmColors.border,
                    ),
                  ),
                  child: Text(
                    isNimFree ? 'FREE NIM' : price,
                    style: TextStyle(
                      fontFamily: 'JetBrains Mono',
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: price == 'FREE' || isNimFree
                          ? SwarmColors.success
                          : SwarmColors.accentSky,
                    ),
                  ),
                ),
              ],
              if (contextWindow != null) ...[
                const SizedBox(width: 6),
                Text(
                  contextWindow,
                  style: const TextStyle(
                    fontFamily: 'JetBrains Mono',
                    color: SwarmColors.textMuted,
                    fontSize: 9,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 5),

          // Row 2: Model Description
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 2, right: 6),
                child: Icon(
                  Icons.subdirectory_arrow_right_rounded,
                  size: 13,
                  color: SwarmColors.textMuted,
                ),
              ),
              Expanded(
                child: Text(
                  description,
                  style: TextStyle(
                    color: SwarmColors.textSecondary.withValues(alpha: 0.95),
                    fontSize: 11.5,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Row 3: Quick Route Navigation Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                Text(
                  'QUICK ROUTE:',
                  style: SwarmTextStyles.codeSmall.copyWith(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: SwarmColors.textMuted,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(width: 6),
                _buildQuickRouteChip(
                  label: '⚡ AutoRouter',
                  isSelected: isAutoRouter,
                  activeColor: SwarmColors.warning,
                  onTap: () => _setAgentModel('openrouter/auto'),
                ),
                const SizedBox(width: 6),
                _buildQuickRouteChip(
                  label: '🎬 Grok Video 1.5',
                  isSelected: modelId == 'x-ai/grok-imagine-video-1.5',
                  activeColor: SwarmColors.agentPink,
                  onTap: () => _setAgentModel('x-ai/grok-imagine-video-1.5'),
                ),
                const SizedBox(width: 6),
                _buildQuickRouteChip(
                  label: '🎬 Video Suite',
                  isSelected: isVideo && modelId != 'x-ai/grok-imagine-video-1.5',
                  activeColor: SwarmColors.agentPink,
                  onTap: () => _setAgentModel('video-generation-swarm'),
                ),
                const SizedBox(width: 6),
                _buildQuickRouteChip(
                  label: '🚀 Kimi K3 Free',
                  isSelected: modelId == 'moonshotai/kimi-k3:free',
                  activeColor: SwarmColors.agentPurple,
                  onTap: () => _setAgentModel('moonshotai/kimi-k3:free'),
                ),
                const SizedBox(width: 6),
                _buildQuickRouteChip(
                  label: '🧠 DeepSeek R1 Free',
                  isSelected: modelId == 'deepseek-ai/deepseek-r1:free',
                  activeColor: SwarmColors.agentCyan,
                  onTap: () => _setAgentModel('deepseek-ai/deepseek-r1:free'),
                ),
                const SizedBox(width: 6),
                _buildQuickRouteChip(
                  label: '💎 Claude 3.7 Sonnet',
                  isSelected: modelId == 'anthropic/claude-3.7-sonnet',
                  activeColor: const Color(0xFFD97706),
                  onTap: () => _setAgentModel('anthropic/claude-3.7-sonnet'),
                ),
                const SizedBox(width: 6),
                _buildQuickRouteChip(
                  label: '🔎 Browse All (120+)',
                  isSelected: false,
                  activeColor: SwarmColors.accent,
                  onTap: () => GoRouter.of(context).push('/models'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickRouteChip({
    required String label,
    required bool isSelected,
    required Color activeColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            color: isSelected
                ? activeColor.withValues(alpha: 0.2)
                : SwarmColors.bgElevated,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: isSelected
                  ? activeColor.withValues(alpha: 0.8)
                  : SwarmColors.border,
              width: isSelected ? 1.2 : 1.0,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'JetBrains Mono',
              fontSize: 9.5,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected ? activeColor : SwarmColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Prompt Chips ────────────────────────────────────────────────────────────

class _PromptChips extends StatelessWidget {
  final List<String> prompts;
  final Color accentColor;
  final void Function(String) onTap;

  const _PromptChips(
      {required this.prompts, required this.accentColor, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: prompts.map((p) {
          return _HoverChip(
            label: p,
            accentColor: accentColor,
            onTap: () => onTap(p),
          );
        }).toList(),
      ),
    );
  }
}

class _HoverChip extends StatefulWidget {
  final String label;
  final Color accentColor;
  final VoidCallback onTap;

  const _HoverChip(
      {required this.label, required this.accentColor, required this.onTap});

  @override
  State<_HoverChip> createState() => _HoverChipState();
}

class _HoverChipState extends State<_HoverChip> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: _hovered
                ? widget.accentColor.withValues(alpha: 0.15)
                : SwarmColors.bgElevated,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _hovered
                  ? widget.accentColor.withValues(alpha: 0.6)
                  : SwarmColors.border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.auto_awesome, size: 11, color: widget.accentColor),
              const SizedBox(width: 5),
              Text(
                widget.label,
                style: SwarmTextStyles.bodySmall.copyWith(
                  fontSize: 11,
                  color:
                      _hovered ? widget.accentColor : SwarmColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Composer ────────────────────────────────────────────────────────────────

class _Composer extends StatefulWidget {
  final TextEditingController ctrl;
  final Agent agent;
  final bool streaming;
  final void Function(String) onSend;

  const _Composer({
    required this.ctrl,
    required this.agent,
    required this.streaming,
    required this.onSend,
  });

  @override
  State<_Composer> createState() => _ComposerState();
}

class _ComposerState extends State<_Composer> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
      decoration: const BoxDecoration(
        color: SwarmColors.bgSurface,
        border: Border(top: BorderSide(color: SwarmColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Input field
          AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: SwarmColors.bgElevated,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _focused
                    ? widget.agent.accent.withValues(alpha: 0.6)
                    : SwarmColors.border,
                width: _focused ? 1.5 : 1.0,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Focus(
                    onFocusChange: (f) => setState(() => _focused = f),
                    child: TextField(
                      controller: widget.ctrl,
                      contextMenuBuilder: (BuildContext context, EditableTextState editableTextState) {
                        return AdaptiveTextSelectionToolbar.editableText(
                          editableTextState: editableTextState,
                        );
                      },
                      maxLines: 4,
                      minLines: 1,
                      style: SwarmTextStyles.body.copyWith(fontSize: 13),
                      decoration: InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                        hintText: 'Message ${widget.agent.name}…',
                        hintStyle: SwarmTextStyles.body.copyWith(
                          fontSize: 13,
                          color: SwarmColors.textMuted,
                        ),
                      ),
                      onSubmitted: (v) {
                        if (!widget.streaming) widget.onSend(v);
                      },
                      keyboardType: TextInputType.multiline,
                      textInputAction: TextInputAction.newline,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Prominent Paste from clipboard button
                InkWell(
                  onTap: () async {
                    final data = await Clipboard.getData(Clipboard.kTextPlain);
                    if (data?.text != null && data!.text!.isNotEmpty) {
                      final current = widget.ctrl.text;
                      final sel = widget.ctrl.selection;
                      if (sel.isValid && sel.start >= 0 && sel.end >= sel.start) {
                        final newText = current.replaceRange(sel.start, sel.end, data.text!);
                        widget.ctrl.value = TextEditingValue(
                          text: newText,
                          selection: TextSelection.collapsed(offset: (sel.start + data.text!.length).toInt()),
                        );
                      } else {
                        widget.ctrl.text = current + data.text!;
                      }
                    }
                  },
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    height: 32,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: SwarmColors.bgSurface,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: SwarmColors.border),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.content_paste_rounded, size: 13, color: SwarmColors.accentCyan),
                        SizedBox(width: 4),
                        Text(
                          'PASTE',
                          style: TextStyle(
                            fontFamily: 'JetBrains Mono',
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: SwarmColors.accentCyan,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                // Send Button
                AnimatedOpacity(
                  opacity: widget.streaming ? 0.4 : 1.0,
                  duration: const Duration(milliseconds: 200),
                  child: GestureDetector(
                    onTap: widget.streaming
                        ? null
                        : () => widget.onSend(widget.ctrl.text),
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: widget.agent.accent,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: widget.streaming
                          ? const Center(
                              child: SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.black,
                                ),
                              ),
                            )
                          : const Icon(Icons.send_rounded,
                              size: 15, color: Colors.black),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          // Footer hint
          Text(
            'SWARM NODE · ${widget.agent.name} · Enter to send, Shift+Enter for newline',
            style: SwarmTextStyles.labelSmall.copyWith(
              fontSize: 9,
              color: SwarmColors.textMuted.withValues(alpha: 0.6),
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

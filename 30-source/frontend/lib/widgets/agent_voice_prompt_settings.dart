import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/agent.dart';
import '../services/lucille_voice_service.dart';
import '../theme/swarm_colors.dart';

class SwarmVoiceOption {
  final String id;
  final String name;
  final String category; // 'fish', 'foss', 'openai', 'offline'
  final String description;

  const SwarmVoiceOption({
    required this.id,
    required this.name,
    required this.category,
    required this.description,
  });
}

const List<SwarmVoiceOption> kAllSwarmVoices = [
  // ─── 🐟 FISH AUDIO PRO VOICES ─────────────────────────────────────────────
  SwarmVoiceOption(
    id: 'fish-audio/s2.1-pro',
    name: '🐟 Fish Audio S2.1 Pro',
    category: 'fish',
    description: 'Flagship multilingual neural model · OpenRouter & Fish Audio',
  ),
  SwarmVoiceOption(
    id: 'fish:assistant_sarah',
    name: '🐟 Sarah (Fish Pro)',
    category: 'fish',
    description: 'Soft, conversational & intimate female voice preset',
  ),
  SwarmVoiceOption(
    id: 'fish:egirl',
    name: '🐟 E-Girl (Fish Pro)',
    category: 'fish',
    description: 'Playful, breathy & high-energy female character',
  ),
  SwarmVoiceOption(
    id: 'fish:smash_announcer',
    name: '🐟 Smash Announcer (Fish Pro)',
    category: 'fish',
    description: 'Booming, epic tournament announcer male voice',
  ),
  SwarmVoiceOption(
    id: 'fish:mk_announcer',
    name: '🐟 Mortal Kombat Announcer (Fish Pro)',
    category: 'fish',
    description: 'Deep, ominous, cinematic authoritative male',
  ),
  SwarmVoiceOption(
    id: 'fish:slax',
    name: '🐟 Slax Narrator (Fish Pro)',
    category: 'fish',
    description: 'Crisp, calm, clear storytelling male voice',
  ),
  SwarmVoiceOption(
    id: 'fish:verity',
    name: '🐟 Verity (Fish Pro)',
    category: 'fish',
    description: 'Animated, expressive & playful male character',
  ),
  SwarmVoiceOption(
    id: 'fish:jasphina',
    name: '🐟 Jasphina (Fish Pro)',
    category: 'fish',
    description: 'Energetic, confident & fast-speaking female',
  ),
  SwarmVoiceOption(
    id: 'fish:energetic_crowd',
    name: '🐟 Hype Crowd (Fish Pro)',
    category: 'fish',
    description: 'Enthusiastic, dynamic & cheerful hype male',
  ),
  SwarmVoiceOption(
    id: 'fish:a2ksi',
    name: '🐟 A2ksi (Fish Pro)',
    category: 'fish',
    description: 'Playful, dramatic & animated dynamic character',
  ),
  SwarmVoiceOption(
    id: 'fish:miku',
    name: '🐟 Hatsune Miku TTS (Fish Pro)',
    category: 'fish',
    description: 'Virtual idol anime female voice preset',
  ),
  SwarmVoiceOption(
    id: 'fish:markiplier',
    name: '🐟 Deep Narrator (Fish Pro)',
    category: 'fish',
    description: 'Deep, resonant & intense dramatic narrator male',
  ),
  SwarmVoiceOption(
    id: 'fish:farid',
    name: '🐟 Farid (Fish Pro)',
    category: 'fish',
    description: 'Warm, calm, measured wisdom storyteller male',
  ),

  // ─── 🌐 FOSS NEURAL (EDGE-TTS) VOICES ──────────────────────────────────────
  SwarmVoiceOption(
    id: 'en-US-AvaMultilingualNeural',
    name: '🌟 Ava (FOSS Neural)',
    category: 'foss',
    description: 'Expressive, warm & friendly conversational female · ChatGPT 4o',
  ),
  SwarmVoiceOption(
    id: 'en-US-AndrewMultilingualNeural',
    name: '🎙️ Andrew (FOSS Neural)',
    category: 'foss',
    description: 'Warm, confident, authentic & honest male voice',
  ),
  SwarmVoiceOption(
    id: 'en-US-BrianMultilingualNeural',
    name: '🧠 Brian (FOSS Neural)',
    category: 'foss',
    description: 'Approachable, casual & sincere male voice',
  ),
  SwarmVoiceOption(
    id: 'en-US-EmmaMultilingualNeural',
    name: '🦋 Emma (FOSS Neural)',
    category: 'foss',
    description: 'Cheerful, clear & conversational female voice',
  ),
  SwarmVoiceOption(
    id: 'en-US-JennyNeural',
    name: '🌸 Jenny (FOSS Neural)',
    category: 'foss',
    description: 'Friendly, natural & considerate female voice',
  ),
  SwarmVoiceOption(
    id: 'en-US-GuyNeural',
    name: '⚡ Guy (FOSS Neural)',
    category: 'foss',
    description: 'Passionate, casual & natural male voice',
  ),
  SwarmVoiceOption(
    id: 'en-US-AriaNeural',
    name: '✨ Aria (FOSS Neural)',
    category: 'foss',
    description: 'Confident, articulate, positive & sharp female',
  ),
  SwarmVoiceOption(
    id: 'en-US-ChristopherNeural',
    name: '🔬 Christopher (FOSS Neural)',
    category: 'foss',
    description: 'Authoritative, reliable & technical male voice',
  ),
  SwarmVoiceOption(
    id: 'en-US-EricNeural',
    name: '📐 Eric (FOSS Neural)',
    category: 'foss',
    description: 'Rational, steady, calm & thoughtful male',
  ),
  SwarmVoiceOption(
    id: 'en-US-MichelleNeural',
    name: '💼 Michelle (FOSS Neural)',
    category: 'foss',
    description: 'Crisp, pleasant & professional female voice',
  ),
  SwarmVoiceOption(
    id: 'en-US-RogerNeural',
    name: '📜 Roger (FOSS Neural)',
    category: 'foss',
    description: 'Deep, measured, lively & wise male voice',
  ),
  SwarmVoiceOption(
    id: 'en-US-SteffanNeural',
    name: '🚀 Steffan (FOSS Neural)',
    category: 'foss',
    description: 'Modern, swift & rational male voice',
  ),
  SwarmVoiceOption(
    id: 'en-US-AnaNeural',
    name: '🎀 Ana (FOSS Neural)',
    category: 'foss',
    description: 'Cute, gentle & youthful conversational female',
  ),
  SwarmVoiceOption(
    id: 'en-GB-SoniaNeural',
    name: '👑 Sonia (FOSS Neural)',
    category: 'foss',
    description: 'Velvet British seductive & elegant female voice',
  ),
  SwarmVoiceOption(
    id: 'en-GB-RyanNeural',
    name: '🎩 Ryan (FOSS Neural)',
    category: 'foss',
    description: 'Sophisticated, pleasant British male voice',
  ),
  SwarmVoiceOption(
    id: 'en-GB-LibbyNeural',
    name: '☕ Libby (FOSS Neural)',
    category: 'foss',
    description: 'Crisp, articulate & clean British female',
  ),
  SwarmVoiceOption(
    id: 'en-GB-ThomasNeural',
    name: '🏰 Thomas (FOSS Neural)',
    category: 'foss',
    description: 'Warm, classic & reliable British male voice',
  ),
  SwarmVoiceOption(
    id: 'en-GB-MaisieNeural',
    name: '🌻 Maisie (FOSS Neural)',
    category: 'foss',
    description: 'Friendly, positive & approachable British female',
  ),
  SwarmVoiceOption(
    id: 'en-AU-NatashaNeural',
    name: '🦘 Natasha (FOSS Neural)',
    category: 'foss',
    description: 'Natural, friendly Australian English female',
  ),
  SwarmVoiceOption(
    id: 'en-AU-WilliamMultilingualNeural',
    name: '🏄 William (FOSS Neural)',
    category: 'foss',
    description: 'Casual, relaxed Australian English male',
  ),
  SwarmVoiceOption(
    id: 'en-CA-ClaraNeural',
    name: '🍁 Clara (FOSS Neural)',
    category: 'foss',
    description: 'Warm, natural Canadian English female',
  ),
  SwarmVoiceOption(
    id: 'en-CA-LiamNeural',
    name: '🌲 Liam (FOSS Neural)',
    category: 'foss',
    description: 'Friendly & modern Canadian English male',
  ),
  SwarmVoiceOption(
    id: 'en-IE-EmilyNeural',
    name: '🍀 Emily (FOSS Neural)',
    category: 'foss',
    description: 'Charming, friendly Irish English female',
  ),
  SwarmVoiceOption(
    id: 'en-IE-ConnorNeural',
    name: '☘️ Connor (FOSS Neural)',
    category: 'foss',
    description: 'Positive, energetic Irish English male',
  ),
  SwarmVoiceOption(
    id: 'en-IN-NeerjaExpressiveNeural',
    name: '🪷 Neerja (FOSS Neural)',
    category: 'foss',
    description: 'Expressive & melodic Indian English female',
  ),
  SwarmVoiceOption(
    id: 'en-IN-PrabhatNeural',
    name: '🏛️ Prabhat (FOSS Neural)',
    category: 'foss',
    description: 'Professional & articulate Indian English male',
  ),
  SwarmVoiceOption(
    id: 'es-ES-ElviraNeural',
    name: '💃 Elvira (FOSS Neural)',
    category: 'foss',
    description: 'Castilian Spanish natural female voice',
  ),
  SwarmVoiceOption(
    id: 'fr-FR-DeniseNeural',
    name: '🥖 Denise (FOSS Neural)',
    category: 'foss',
    description: 'French natural, melodic female voice',
  ),
  SwarmVoiceOption(
    id: 'de-DE-KatjaNeural',
    name: '🥨 Katja (FOSS Neural)',
    category: 'foss',
    description: 'German clear & confident female voice',
  ),
  SwarmVoiceOption(
    id: 'ja-JP-NanamiNeural',
    name: '🌸 Nanami (FOSS Neural)',
    category: 'foss',
    description: 'Japanese polite & natural female voice',
  ),
  SwarmVoiceOption(
    id: 'zh-CN-XiaoxiaoNeural',
    name: '🏮 Xiaoxiao (FOSS Neural)',
    category: 'foss',
    description: 'Mandarin Chinese warm & expressive female',
  ),

  // ─── 🤖 OPENAI CLOUD (FREE / BYOK) ────────────────────────────────────────
  SwarmVoiceOption(
    id: 'openai:nova',
    name: '💫 Nova (OpenAI Cloud)',
    category: 'openai',
    description: 'Warm, natural, seductive & expressive female voice',
  ),
  SwarmVoiceOption(
    id: 'openai:alloy',
    name: '⚙️ Alloy (OpenAI Cloud)',
    category: 'openai',
    description: 'Balanced, neutral & versatile multi-purpose voice',
  ),
  SwarmVoiceOption(
    id: 'openai:echo',
    name: '🔉 Echo (OpenAI Cloud)',
    category: 'openai',
    description: 'Smooth, resonant & friendly male voice',
  ),
  SwarmVoiceOption(
    id: 'openai:fable',
    name: '📖 Fable (OpenAI Cloud)',
    category: 'openai',
    description: 'British-accented expressive & storytelling voice',
  ),
  SwarmVoiceOption(
    id: 'openai:onyx',
    name: '🛡️ Onyx (OpenAI Cloud)',
    category: 'openai',
    description: 'Deep, rich & authoritative male voice',
  ),
  SwarmVoiceOption(
    id: 'openai:shimmer',
    name: '💎 Shimmer (OpenAI Cloud)',
    category: 'openai',
    description: 'Bright, clear, crisp & upbeat female voice',
  ),

  // ─── 💻 OFFLINE FOSS (ESPEAK-NG) ──────────────────────────────────────────
  SwarmVoiceOption(
    id: 'espeak:en-gb+f3',
    name: '💻 eSpeak British Female',
    category: 'offline',
    description: 'Fast, lightweight 100% offline local synthesized voice',
  ),
  SwarmVoiceOption(
    id: 'espeak:en-us+m3',
    name: '💻 eSpeak US Male',
    category: 'offline',
    description: 'Fast, lightweight 100% offline local synthesized voice',
  ),
  SwarmVoiceOption(
    id: 'espeak:en-scottish',
    name: '💻 eSpeak Scottish',
    category: 'offline',
    description: 'Lightweight offline synthesizer Scottish persona',
  ),
  SwarmVoiceOption(
    id: 'espeak:whisper',
    name: '💻 eSpeak Robotic Whisper',
    category: 'offline',
    description: 'Atmospheric robotic whisper tone for AI hardware nodes',
  ),
];

// Map lookup for quick label retrieval
final Map<String, String> kAvailableSwarmVoices = {
  for (final v in kAllSwarmVoices) v.id: v.name,
};

/// Preset tailored voice assignments for each agent in the Swarm ("Choose For Me")
const Map<String, String> kAutoAssignedSwarmVoices = {
  'lucille': 'fish:assistant_sarah', // Female Fish Audio Pro Sarah (Intimate & Velvet Orchestrator)
  'dr_boltz': 'en-US-RogerNeural', // Deep, measured, wise older male voice (Senior Systems Architect & Sentinel)
  'antigravity': 'en-US-BrianMultilingualNeural', // Authoritative Google AGY 2.0 Engine
  'antigravity_ide': 'openai:onyx', // Deep, resonant AI-First Code Studio & Workstation
  'therapist_1': 'en-US-AvaMultilingualNeural', // Empathetic, warm sounding board
  'nexus': 'en-US-AndrewMultilingualNeural', // Authentic daily briefing node
  'librarian': 'en-GB-RyanNeural', // Sophisticated steam librarian
  'streamer': 'fish:egirl', // Energetic, playful streamer
  'document_manager': 'en-US-BrianMultilingualNeural', // Sincere, approachable docs manager
  'prompt': 'en-US-AriaNeural', // Articulate, sharp prompt specialist
  'hud': 'en-US-JennyNeural', // Friendly, clear interface HUD
  'companion': 'openai:nova', // Warm, intimate companion
  'nemo': 'en-US-ChristopherNeural', // Authoritative security & guardrails
  'hermes': 'en-US-SteffanNeural', // Fast, modern messenger
  'agent_9': 'en-US-EricNeural', // Steady, rational data analyst
  'agent_10': 'en-GB-LibbyNeural', // Crisp code reviewer
  'agent_11': 'openai:onyx', // Deep system architect
  'forge': 'fish:smash_announcer', // Booming industrial forge workstation
  'droid': 'openai:echo', // Smooth robotic hardware node
  'agent_14': 'en-CA-LiamNeural', // Friendly DevOps engineer
  'agent_15': 'en-IE-EmilyNeural', // Charming UI/UX designer
  'agent_16': 'en-US-RogerNeural', // Wise, measured database admin
  'agent_17': 'en-GB-ThomasNeural', // Classic security auditor
  'agent_18': 'en-AU-WilliamMultilingualNeural', // Casual API router
  'agent_19': 'openai:fable', // British creative storyteller
  'agent_20': 'en-IN-NeerjaExpressiveNeural', // Expressive research scientist
  'agent_21': 'es-ES-ElviraNeural', // Global localization specialist
  'agent_22': 'fish:miku', // Vibrant game audio & virtual idol
  'agent_23': 'en-IN-PrabhatNeural', // Professional finance analyst
  'agent_24': 'en-US-MichelleNeural', // Executive assistant
  'gemini_notebook': 'openai:alloy', // Scholarly, crisp research synthesizer
  'gmail_agent': 'openai:echo', // Professional executive inbox dispatcher
  'keepit_agent': 'openai:fable', // Thoughtful, creative ideas and scratchpad scribe
  'daily_briefs': 'en-US-AndrewMultilingualNeural', // Resonant, dynamic morning & evening anchor
  'vital': 'en-US-AvaMultilingualNeural', // Gentle, caring wellness & medication intake physician
  'ui_tandem': 'openai:nova', // Energetic, modern UI architect & design synthesizer
};

class AgentVoicePromptSettings extends StatefulWidget {
  final bool compact;

  const AgentVoicePromptSettings({super.key, this.compact = false});

  @override
  State<AgentVoicePromptSettings> createState() => _AgentVoicePromptSettingsState();
}

class _AgentVoicePromptSettingsState extends State<AgentVoicePromptSettings> {
  final Map<String, String> _selectedVoices = {};
  final Map<String, TextEditingController> _promptControllers = {};
  final TextEditingController _searchController = TextEditingController();
  String _selectedCategory = 'all';
  String _searchQuery = '';
  bool _loading = true;
  String? _expandedAgentId;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _searchController.dispose();
    for (final c in _promptControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  String _getDefaultVoiceForAgent(String agentId) {
    if (kAutoAssignedSwarmVoices.containsKey(agentId)) {
      return kAutoAssignedSwarmVoices[agentId]!;
    }
    return 'en-US-AvaMultilingualNeural';
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final agent in agents) {
        final savedVoice = prefs.getString('agent_voice_${agent.id}');
        _selectedVoices[agent.id] = (savedVoice != null && kAvailableSwarmVoices.containsKey(savedVoice))
            ? savedVoice
            : _getDefaultVoiceForAgent(agent.id);

        final savedPrompt = prefs.getString('agent_prompt_${agent.id}') ?? '';
        _promptControllers[agent.id] = TextEditingController(text: savedPrompt);
      }
      if (agents.isNotEmpty) {
        _expandedAgentId ??= agents.first.id;
      }
    } catch (_) {}
    if (mounted) {
      setState(() => _loading = false);
    }
  }

  /// One-click Auto-Assign for all 27 Swarm Agents ("Choose For Me")
  Future<void> _autoAssignAllVoices() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final agent in agents) {
        final assigned = _getDefaultVoiceForAgent(agent.id);
        _selectedVoices[agent.id] = assigned;
        await prefs.setString('agent_voice_${agent.id}', assigned);
      }

      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: SwarmColors.bgElevated,
            content: Row(
              children: [
                const Icon(Icons.auto_awesome, color: SwarmColors.accent, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '🎉 Assigned distinct tailored voices to all ${agents.length} swarm agents!\n(Lucille: Sonia, Nexus: Andrew, Streamer: E-Girl, Forge: Smash...)',
                    style: const TextStyle(color: SwarmColors.textPrimary, fontSize: 12),
                  ),
                ),
              ],
            ),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: SwarmColors.statusCritical, content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _saveAgent(String agentId, String agentName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final voice = _selectedVoices[agentId] ?? _getDefaultVoiceForAgent(agentId);
      final prompt = _promptControllers[agentId]?.text.trim() ?? '';

      await prefs.setString('agent_voice_$agentId', voice);
      await prefs.setString('agent_prompt_$agentId', prompt);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: SwarmColors.bgElevated,
            content: Text(
              '✅ $agentName voice & prompt saved successfully',
              style: const TextStyle(color: SwarmColors.textPrimary),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: SwarmColors.statusCritical, content: Text('Failed to save: $e')),
        );
      }
    }
  }

  void _testVoice(Agent agent) {
    final voice = _selectedVoices[agent.id] ?? _getDefaultVoiceForAgent(agent.id);
    LucilleVoiceService().speak(
      'Hello! I am ${agent.name}. This is my active voice on SWARM OS. How can I assist your mission today?',
      preferredVoice: voice,
    );
  }

  List<SwarmVoiceOption> _getFilteredVoices() {
    return kAllSwarmVoices.where((v) {
      if (_selectedCategory != 'all' && v.category != _selectedCategory) {
        return false;
      }
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        return v.name.toLowerCase().contains(q) ||
            v.id.toLowerCase().contains(q) ||
            v.description.toLowerCase().contains(q);
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: CircularProgressIndicator(color: SwarmColors.accent),
        ),
      );
    }

    final filteredVoices = _getFilteredVoices();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ─── Header & Auto-Assign Action ────────────────────────────────────
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: SwarmColors.accentSurface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.record_voice_over, color: SwarmColors.accent, size: 16),
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'AGENT VOICES & CUSTOM PROMPTS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  color: SwarmColors.textMuted,
                ),
              ),
            ),
            // Auto-assign "Choose For Me" Button
            ElevatedButton.icon(
              onPressed: _autoAssignAllVoices,
              icon: const Icon(Icons.auto_awesome, size: 13, color: Colors.black),
              label: const Text(
                '🎲 Choose For Me (Auto-Assign)',
                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.black),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: SwarmColors.accent,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                visualDensity: VisualDensity.compact,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        const Text(
          'Choose from Fish Audio Pro, FOSS Neural (Edge-TTS), OpenAI Cloud, and Offline synthesizers for each agent, or click "Choose For Me" to auto-assign distinct voices.',
          style: TextStyle(fontSize: 11, color: SwarmColors.textMuted, height: 1.3),
        ),
        const SizedBox(height: 12),

        // ─── Filter Chips & Search Bar ──────────────────────────────────────
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildCategoryChip('all', 'ALL (50+)'),
              const SizedBox(width: 6),
              _buildCategoryChip('fish', '🐟 FISH PRO'),
              const SizedBox(width: 6),
              _buildCategoryChip('foss', '🌐 FOSS NEURAL'),
              const SizedBox(width: 6),
              _buildCategoryChip('openai', '🤖 OPENAI'),
              const SizedBox(width: 6),
              _buildCategoryChip('offline', '💻 OFFLINE'),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Search Box
        TextField(
          controller: _searchController,
          style: const TextStyle(color: SwarmColors.textPrimary, fontSize: 11),
          onChanged: (val) => setState(() => _searchQuery = val.trim()),
          decoration: InputDecoration(
            isDense: true,
            hintText: 'Search voices by accent, gender, or name (e.g. British, Sarah, Male, Sonia)...',
            hintStyle: const TextStyle(color: SwarmColors.textMuted, fontSize: 10.5),
            prefixIcon: const Icon(Icons.search, size: 14, color: SwarmColors.accent),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 14, color: SwarmColors.textMuted),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                  )
                : null,
            filled: true,
            fillColor: Colors.black.withValues(alpha: 0.25),
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: SwarmColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: SwarmColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: SwarmColors.accent),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // ─── Agent Cards ────────────────────────────────────────────────────
        ...agents.map((agent) {
          final isExpanded = _expandedAgentId == agent.id;
          final currentVoice = _selectedVoices[agent.id] ?? _getDefaultVoiceForAgent(agent.id);
          final promptCtrl = _promptControllers[agent.id] ?? TextEditingController();
          final voiceObj = kAllSwarmVoices.firstWhere(
            (v) => v.id == currentVoice,
            orElse: () => SwarmVoiceOption(
              id: currentVoice,
              name: kAvailableSwarmVoices[currentVoice] ?? currentVoice,
              category: 'foss',
              description: '',
            ),
          );

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: SwarmColors.bgElevated,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isExpanded ? agent.accent.withValues(alpha: 0.6) : SwarmColors.border,
                width: isExpanded ? 1.5 : 1.0,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Agent Header Row
                InkWell(
                  onTap: () {
                    setState(() {
                      _expandedAgentId = isExpanded ? null : agent.id;
                    });
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    child: Row(
                      children: [
                        Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: agent.accent.withValues(alpha: 0.2),
                            border: Border.all(color: agent.accent, width: 1.2),
                          ),
                          child: Icon(agent.icon, color: agent.accent, size: 13),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    agent.name,
                                    style: TextStyle(
                                      color: agent.accent,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12.5,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.3),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: SwarmColors.border, width: 0.5),
                                    ),
                                    child: Text(
                                      voiceObj.name.split('(').first.trim(),
                                      style: const TextStyle(color: SwarmColors.accentSky, fontSize: 9.5),
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                agent.role,
                                style: const TextStyle(color: SwarmColors.textMuted, fontSize: 10),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.play_circle_filled_rounded, size: 20),
                          color: SwarmColors.accent,
                          tooltip: 'Preview ${agent.name} voice',
                          onPressed: () => _testVoice(agent),
                        ),
                        Icon(
                          isExpanded ? Icons.expand_less : Icons.expand_more,
                          color: SwarmColors.textMuted,
                          size: 18,
                        ),
                      ],
                    ),
                  ),
                ),

                // Expanded settings
                if (isExpanded)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Divider(color: SwarmColors.border, height: 12),

                        // Voice Selector
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'ACTIVE VOICE',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.1,
                                color: SwarmColors.accent,
                              ),
                            ),
                            Text(
                              '${filteredVoices.length} available',
                              style: const TextStyle(fontSize: 9.5, color: SwarmColors.textMuted),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),

                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: SwarmColors.border),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              isExpanded: true,
                              value: currentVoice,
                              dropdownColor: SwarmColors.bgSurface,
                              icon: const Icon(Icons.arrow_drop_down, color: SwarmColors.accent),
                              items: () {
                                final options = [...filteredVoices];
                                if (!options.any((v) => v.id == currentVoice)) {
                                  options.insert(0, voiceObj);
                                }
                                return options.map((v) {
                                  return DropdownMenuItem<String>(
                                    value: v.id,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          v.name,
                                          style: const TextStyle(
                                            color: SwarmColors.textPrimary,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        if (v.description.isNotEmpty)
                                          Text(
                                            v.description,
                                            style: const TextStyle(
                                              color: SwarmColors.textMuted,
                                              fontSize: 9,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                      ],
                                    ),
                                  );
                                }).toList();
                              }(),
                              onChanged: (newVoice) {
                                if (newVoice != null) {
                                  setState(() {
                                    _selectedVoices[agent.id] = newVoice;
                                  });
                                }
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Custom System Prompt / Persona
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'CUSTOM SYSTEM PROMPT / PERSONA',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.1,
                                color: SwarmColors.accent,
                              ),
                            ),
                            if (promptCtrl.text.isNotEmpty)
                              GestureDetector(
                                onTap: () {
                                  promptCtrl.clear();
                                  setState(() {});
                                },
                                child: const Text(
                                  'Clear',
                                  style: TextStyle(color: SwarmColors.statusCritical, fontSize: 10),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        TextField(
                          controller: promptCtrl,
                          maxLines: 3,
                          style: const TextStyle(color: SwarmColors.textPrimary, fontSize: 11.5),
                          decoration: InputDecoration(
                            hintText: 'Enter custom persona directives, background story, or tone rules for ${agent.name}...',
                            hintStyle: const TextStyle(color: SwarmColors.textMuted, fontSize: 10.5),
                            filled: true,
                            fillColor: Colors.black.withValues(alpha: 0.3),
                            contentPadding: const EdgeInsets.all(8),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: const BorderSide(color: SwarmColors.border),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: BorderSide(color: agent.accent),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Action Buttons
                        Row(
                          children: [
                            OutlinedButton.icon(
                              onPressed: () => _testVoice(agent),
                              icon: const Icon(Icons.volume_up, size: 13),
                              label: const Text('Test Voice', style: TextStyle(fontSize: 10.5)),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: agent.accent,
                                side: BorderSide(color: agent.accent.withValues(alpha: 0.5)),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              ),
                            ),
                            const Spacer(),
                            ElevatedButton.icon(
                              onPressed: () => _saveAgent(agent.id, agent.name),
                              icon: const Icon(Icons.save, size: 13),
                              label: const Text('Save Agent', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: agent.accent,
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildCategoryChip(String categoryId, String label) {
    final isSelected = _selectedCategory == categoryId;
    return GestureDetector(
      onTap: () => setState(() => _selectedCategory = categoryId),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? SwarmColors.accentSurface : Colors.black.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? SwarmColors.accent : SwarmColors.border,
            width: isSelected ? 1.2 : 0.8,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? SwarmColors.accent : SwarmColors.textMuted,
            fontSize: 9.5,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

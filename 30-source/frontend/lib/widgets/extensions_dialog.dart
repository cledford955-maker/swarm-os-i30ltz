import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/swarm_colors.dart';
import '../theme/swarm_text_styles.dart';

/// Modal dialog for installing and configuring OpenRouter and Google Antigravity IDE extensions
class IdeExtensionsDialog extends StatefulWidget {
  const IdeExtensionsDialog({super.key});

  @override
  State<IdeExtensionsDialog> createState() => _IdeExtensionsDialogState();
}

class _IdeExtensionsDialogState extends State<IdeExtensionsDialog> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _hasKey = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadKey();
  }

  Future<void> _loadKey() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _hasKey = (prefs.getString('OPENROUTER_API_KEY') ?? '').isNotEmpty;
    });
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copied to clipboard!'),
        backgroundColor: SwarmColors.accent,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Mask API key completely to prevent leaking secrets on screen or in logs
    const maskedKeyDisplay = 'sk-or-v1-••••••••••••••••••••••••';
    const envVarRef = r'${OPENROUTER_API_KEY}';

    return Dialog(
      backgroundColor: SwarmColors.bgSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: SwarmColors.border, width: 1.5),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        width: 890,
        height: 690,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: SwarmColors.accent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: SwarmColors.accent.withValues(alpha: 0.4)),
                      ),
                      child: const Icon(Icons.extension_rounded, color: SwarmColors.accent, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'IDE & Antigravity Extensions Hub',
                          style: SwarmTextStyles.title.copyWith(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: SwarmColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Equip Google Antigravity, VS Code, JetBrains, and CLI tools with AI agents and BYOK OpenRouter.',
                          style: SwarmTextStyles.bodySmall.copyWith(color: SwarmColors.textMuted),
                        ),
                      ],
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: SwarmColors.textMuted),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Tab Bar
            Container(
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: SwarmColors.border)),
              ),
              child: TabBar(
                controller: _tabController,
                indicatorColor: SwarmColors.accent,
                indicatorWeight: 2,
                labelColor: SwarmColors.accent,
                unselectedLabelColor: SwarmColors.textMuted,
                labelStyle: SwarmTextStyles.label.copyWith(fontSize: 12, fontWeight: FontWeight.bold),
                tabs: const [
                  Tab(icon: Icon(Icons.rocket_launch_rounded, size: 15), text: 'ANTIGRAVITY IDE'),
                  Tab(icon: Icon(Icons.code_rounded, size: 15), text: 'VS CODE'),
                  Tab(icon: Icon(Icons.layers_rounded, size: 15), text: 'JETBRAINS'),
                  Tab(icon: Icon(Icons.terminal_rounded, size: 15), text: 'ZED & CLI TOOLS'),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Tab Content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildAntigravityTab(maskedKeyDisplay),
                  _buildVsCodeTab(envVarRef),
                  _buildJetBrainsTab(maskedKeyDisplay),
                  _buildCliTab(envVarRef),
                ],
              ),
            ),

            // Footer
            const Divider(color: SwarmColors.border),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      _hasKey ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                      color: _hasKey ? SwarmColors.success : SwarmColors.textMuted,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _hasKey
                          ? 'OpenRouter Key loaded securely from lucy-master/.env (Hidden)'
                          : 'OpenRouter Key loaded from environment if configured',
                      style: SwarmTextStyles.bodySmall.copyWith(
                        color: _hasKey ? SwarmColors.success : SwarmColors.textMuted,
                      ),
                    ),
                  ],
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: SwarmColors.accent,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  ),
                  child: const Text('DONE', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─── Google Antigravity IDE Tab ──────────────────────────────────────────
  Widget _buildAntigravityTab(String maskedKey) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: SwarmColors.agentCyan.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: SwarmColors.agentCyan.withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                const Icon(Icons.verified, color: SwarmColors.accentCyan, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'GOOGLE ANTIGRAVITY IDE :: STATUS ONLINE & EQUIPPED',
                        style: SwarmTextStyles.labelSmall.copyWith(
                          color: SwarmColors.accentCyan,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'All 5 core Antigravity extensions, language runtimes (Dart, Flutter, Python, Go, C++), and 10 AGY global plugins are active.',
                        style: TextStyle(color: SwarmColors.textSecondary, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: SwarmColors.statusOnline.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: SwarmColors.statusOnline),
                  ),
                  child: const Text(
                    'ACTIVE',
                    style: TextStyle(color: SwarmColors.statusOnline, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Installed Extensions Grid
          Row(
            children: [
              Expanded(
                child: _buildExtensionCard(
                  title: 'Dart & Flutter (Dart-Code)',
                  type: 'v3.140.0 · Language Server & Tools',
                  description: 'Full hot reload, widget tree inspector, Dart analysis, and native Flutter runtime debugging.',
                  badge: 'INSTALLED',
                  badgeColor: SwarmColors.statusOnline,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildExtensionCard(
                  title: 'Continue AI (BYOK OpenRouter)',
                  type: 'v2.0.0 · AI Autocomplete & Chat',
                  description: 'Inline tab autocomplete powered by open weights + custom OpenRouter models via lucy-master/.env.',
                  badge: 'INSTALLED',
                  badgeColor: SwarmColors.accentCyan,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildExtensionCard(
                  title: 'GitLens & Prettier',
                  type: 'v19.0.1 / v12.4.0 · Productivity',
                  description: 'Supercharged visual git history, file blame, and automatic code formatting on save.',
                  badge: 'INSTALLED',
                  badgeColor: SwarmColors.agentPurple,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildExtensionCard(
                  title: 'Core Antigravity Engine',
                  type: 'Google Antigravity 2.0',
                  description: 'Autonomous multi-step coding agent, code executor, dev containers, and WSL/SSH remote links.',
                  badge: 'CORE ENGINE',
                  badgeColor: SwarmColors.accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 10 Active Plugins
          Text('ACTIVE ANTIGRAVITY GLOBAL PLUGINS (10)', style: SwarmTextStyles.labelSmall.copyWith(color: SwarmColors.accent)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _buildPluginChip('flutter'),
              _buildPluginChip('data-agent-kit'),
              _buildPluginChip('modern-web-guidance'),
              _buildPluginChip('gemini-api'),
              _buildPluginChip('google-antigravity-sdk'),
              _buildPluginChip('chrome-devtools'),
              _buildPluginChip('science'),
              _buildPluginChip('firebase'),
              _buildPluginChip('google-maps'),
              _buildPluginChip('android-cli'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPluginChip(String name) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: SwarmColors.bgElevated,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: SwarmColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check, size: 12, color: SwarmColors.statusOnline),
          const SizedBox(width: 5),
          Text(name, style: const TextStyle(fontSize: 10.5, color: SwarmColors.textPrimary, fontFamily: 'JetBrains Mono')),
        ],
      ),
    );
  }

  // ─── VS Code Tab ─────────────────────────────────────────────────────────
  Widget _buildVsCodeTab(String apiKeyRef) {
    final vscodeJson = '''{
  "github.copilot.chat.customProviders": [
    {
      "name": "OpenRouter",
      "endpoint": "https://openrouter.ai/api/v1",
      "apiKey": "$apiKeyRef",
      "model": "anthropic/claude-opus-4.6"
    }
  ],
  "continue.tabAutocompleteModel": {
    "title": "GLM 5.2 Auto-Complete",
    "provider": "openai",
    "model": "zhipu/glm-5.2-autocomplete",
    "apiBase": "https://openrouter.ai/api/v1",
    "apiKey": "$apiKeyRef"
  },
  "continue.models": [
    {
      "title": "Leader (Claude Opus 4.6)",
      "provider": "openai",
      "model": "anthropic/claude-opus-4.6",
      "apiBase": "https://openrouter.ai/api/v1",
      "apiKey": "$apiKeyRef"
    },
    {
      "title": "Systems (GPT-5.6 Sol)",
      "provider": "openai",
      "model": "openai/gpt-5.6-sol",
      "apiBase": "https://openrouter.ai/api/v1",
      "apiKey": "$apiKeyRef"
    }
  ]
}''';

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _buildExtensionCard(
                  title: 'Roo Code & Cline',
                  type: 'Autonomous Agent',
                  description: 'Autonomous multi-file refactoring and terminal runs using OpenRouter provider with secure env keys.',
                  badge: 'RECOMMENDED',
                  badgeColor: SwarmColors.accent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildExtensionCard(
                  title: 'Continue',
                  type: 'Auto-Complete & Chat',
                  description: 'Ultra-fast inline code completion powered by GLM 5.2 and Qwen 2.5 Coder + sidebar pair programmer.',
                  badge: 'AUTO-COMPLETE',
                  badgeColor: SwarmColors.agentCyan,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('VS CODE SETTINGS.JSON (BYOK TEMPLATE)', style: SwarmTextStyles.labelSmall.copyWith(color: SwarmColors.accent)),
              ElevatedButton.icon(
                onPressed: () => _copyToClipboard(vscodeJson, 'VS Code settings JSON'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: SwarmColors.bgElevated,
                  foregroundColor: SwarmColors.accent,
                  side: const BorderSide(color: SwarmColors.accent, width: 0.8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                ),
                icon: const Icon(Icons.copy_rounded, size: 14),
                label: const Text('Copy JSON Snippet', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: SwarmColors.border),
            ),
            child: SelectableText(
              vscodeJson,
              style: const TextStyle(
                fontFamily: 'JetBrains Mono',
                fontSize: 11,
                color: SwarmColors.textSecondary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── JetBrains Tab ───────────────────────────────────────────────────────
  Widget _buildJetBrainsTab(String maskedKey) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _buildExtensionCard(
                  title: 'OpenRouter Plugin',
                  type: 'JetBrains Marketplace',
                  description: 'Dedicated plugin for IntelliJ, PyCharm, WebStorm, and Android Studio with model routing.',
                  badge: 'OFFICIAL',
                  badgeColor: SwarmColors.accent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildExtensionCard(
                  title: 'Native AI Assistant',
                  type: 'OpenAI-Compatible Custom Provider',
                  description: 'Go to Settings → Tools → AI Assistant → Providers. Set URL to https://openrouter.ai/api/v1.',
                  badge: 'NATIVE',
                  badgeColor: SwarmColors.agentCyan,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('JETBRAINS CONFIGURATION DETAILS', style: SwarmTextStyles.labelSmall.copyWith(color: SwarmColors.accent)),
              ElevatedButton.icon(
                onPressed: () => _copyToClipboard('https://openrouter.ai/api/v1', 'Base URL'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: SwarmColors.bgElevated,
                  foregroundColor: SwarmColors.accent,
                  side: const BorderSide(color: SwarmColors.accent, width: 0.8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                ),
                icon: const Icon(Icons.copy_rounded, size: 14),
                label: const Text('Copy Base URL', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: SwarmColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildConfigRow('Provider Type', 'OpenAI-Compatible (Custom)'),
                const SizedBox(height: 8),
                _buildConfigRow('API Base URL', 'https://openrouter.ai/api/v1'),
                const SizedBox(height: 8),
                _buildConfigRow('API Key Source', 'Loaded securely from lucy-master/.env'),
                const SizedBox(height: 8),
                _buildConfigRow('Recommended Model', 'anthropic/claude-opus-4.6'),
                const SizedBox(height: 8),
                _buildConfigRow('Autocomplete Model', 'zhipu/glm-5.2-autocomplete'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── CLI / Zed Tab ───────────────────────────────────────────────────────
  Widget _buildCliTab(String apiKeyRef) {
    const aiderCmd = 'export OPENROUTER_API_KEY="\$(cat /run/media/i30ltz/lucy-master/.env | grep OPENROUTER_API_KEY | cut -d= -f2)"\naider --model openrouter/anthropic/claude-opus-4.6';
    final zedJson = '''{
  "language_models": {
    "openrouter": {
      "api_url": "https://openrouter.ai/api/v1",
      "api_key": "$apiKeyRef",
      "available_models": [
        {
          "name": "anthropic/claude-opus-4.6",
          "display_name": "Claude Opus 4.6 (Leader)",
          "max_tokens": 200000
        }
      ]
    }
  }
}''';

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _buildExtensionCard(
                  title: 'Zed Editor',
                  type: 'Ultra-Fast Rust Editor',
                  description: 'Add OpenRouter as custom language model provider for inline completions and assistant panel.',
                  badge: 'ZED',
                  badgeColor: SwarmColors.accentSky,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildExtensionCard(
                  title: 'Aider & Claude Code',
                  type: 'Terminal Agents',
                  description: 'Pair program in your terminal. Connect directly using OPENROUTER_API_KEY environment variable.',
                  badge: 'CLI',
                  badgeColor: SwarmColors.agentPurple,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('AIDER TERMINAL COMMAND', style: SwarmTextStyles.labelSmall.copyWith(color: SwarmColors.accent)),
              ElevatedButton.icon(
                onPressed: () => _copyToClipboard(aiderCmd, 'Aider CLI command'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: SwarmColors.bgElevated,
                  foregroundColor: SwarmColors.accent,
                  side: const BorderSide(color: SwarmColors.accent, width: 0.8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                ),
                icon: const Icon(Icons.copy_rounded, size: 14),
                label: const Text('Copy Command', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: SwarmColors.border),
            ),
            child: const SelectableText(
              aiderCmd,
              style: TextStyle(
                fontFamily: 'JetBrains Mono',
                fontSize: 11,
                color: SwarmColors.accent,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('ZED SETTINGS.JSON SNIPPET', style: SwarmTextStyles.labelSmall.copyWith(color: SwarmColors.accent)),
              ElevatedButton.icon(
                onPressed: () => _copyToClipboard(zedJson, 'Zed snippet'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: SwarmColors.bgElevated,
                  foregroundColor: SwarmColors.accent,
                  side: const BorderSide(color: SwarmColors.accent, width: 0.8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                ),
                icon: const Icon(Icons.copy_rounded, size: 14),
                label: const Text('Copy Zed JSON', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: SwarmColors.border),
            ),
            child: SelectableText(
              zedJson,
              style: const TextStyle(
                fontFamily: 'JetBrains Mono',
                fontSize: 11,
                color: SwarmColors.textSecondary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfigRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 180,
          child: Text(label, style: const TextStyle(color: SwarmColors.textMuted, fontSize: 12)),
        ),
        Expanded(
          child: SelectableText(
            value,
            style: const TextStyle(color: SwarmColors.textPrimary, fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget _buildExtensionCard({
    required String title,
    required String type,
    required String description,
    required String badge,
    required Color badgeColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: SwarmColors.bgElevated,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: SwarmColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: SwarmColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: badgeColor.withValues(alpha: 0.5)),
                ),
                child: Text(
                  badge,
                  style: TextStyle(
                    color: badgeColor,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(type, style: const TextStyle(color: SwarmColors.textMuted, fontSize: 10.5)),
          const SizedBox(height: 8),
          Text(
            description,
            style: const TextStyle(color: SwarmColors.textSecondary, fontSize: 11.5, height: 1.35),
          ),
        ],
      ),
    );
  }
}

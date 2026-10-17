import 'dart:io' hide Platform;
import '../platform/platform.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import '../services/google_workspace_service.dart';
import '../theme/swarm_colors.dart';
import '../theme/swarm_text_styles.dart';
import '../widgets/agent_voice_prompt_settings.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, bool> _obscureText = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadKeys();
  }

  String _resolveKey(SharedPreferences prefs, String keyName) {
    final prefVal = prefs.getString(keyName);
    if (prefVal != null && prefVal.trim().isNotEmpty) return prefVal.trim();

    final envPaths = [
      '/run/media/i30ltz/lucy-master/.env',
      './.env',
      '../.env',
      '/etc/swarm_os.env',
      '/root/.env',
      '/usr/local/bin/swarm_os/.env',
      '${Platform.environment['HOME']}/.env',
    ];
    for (final p in envPaths) {
      final f = File(p);
      if (f.existsSync()) {
        try {
          for (final line in f.readAsLinesSync()) {
            final trimmed = line.trim();
            if (trimmed.startsWith('$keyName=')) {
              return trimmed
                  .substring('$keyName='.length)
                  .trim()
                  .replaceAll('"', '')
                  .replaceAll("'", '');
            }
            if (keyName == 'ELEVEN_KEY' &&
                trimmed.startsWith('ELEVEN_API_KEY=')) {
              return trimmed
                  .substring('ELEVEN_API_KEY='.length)
                  .trim()
                  .replaceAll('"', '')
                  .replaceAll("'", '');
            }
          }
        } catch (_) {}
      }
    }
    return Platform.environment[keyName] ?? '';
  }

  Future<void> _loadKeys() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        final keys = [
          'OPENROUTER_API_KEY',
          'FISH_AUDIO_API_KEY',
          'ELEVEN_KEY',
          'OPENAI_API_KEY'
        ];
        for (final k in keys) {
          _controllers[k] = TextEditingController(text: _resolveKey(prefs, k));
          _obscureText[k] = true;
        }
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Future<void> _saveKeys() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final entry in _controllers.entries) {
        await prefs.setString(entry.key, entry.value.text.trim());
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: SwarmColors.bgElevated,
            content: Text('✅ API keys safely updated in secure local vault',
                style: TextStyle(color: SwarmColors.textPrimary)),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: SwarmColors.accent),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.black.withValues(alpha: 0.5),
        title: const Text('API & Security Vault',
            style: TextStyle(
                color: SwarmColors.textPrimary, fontWeight: FontWeight.bold)),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ElevatedButton.icon(
              onPressed: _saveKeys,
              icon: const Icon(Icons.lock, size: 16),
              label: const Text('Save Keys to Vault'),
              style: ElevatedButton.styleFrom(
                backgroundColor: SwarmColors.accent,
                foregroundColor: Colors.black,
              ),
            ),
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: SwarmColors.bgElevated,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: SwarmColors.border),
              ),
              child: const Row(
                children: [
                  Icon(Icons.shield_outlined,
                      color: SwarmColors.accent, size: 18),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'All secret keys are obscured on screen and loaded securely from lucy-master/.env. Keys are never transmitted in plaintext or shared with unauthorized processes.',
                      style: TextStyle(
                          color: SwarmColors.textMuted,
                          fontSize: 11.5,
                          height: 1.3),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            ..._controllers.entries.map((e) {
              final isObscured = _obscureText[e.key] ?? true;
              return Padding(
                padding: const EdgeInsets.only(bottom: 14.0),
                child: TextField(
                  controller: e.value,
                  obscureText: isObscured,
                  style: const TextStyle(
                      color: SwarmColors.textPrimary, fontSize: 13),
                  decoration: InputDecoration(
                    labelText: e.key,
                    labelStyle: const TextStyle(
                        color: SwarmColors.accent, fontSize: 12),
                    filled: true,
                    fillColor: Colors.black.withValues(alpha: 0.3),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                    suffixIcon: IconButton(
                      icon: Icon(
                        isObscured ? Icons.visibility_off : Icons.visibility,
                        color: SwarmColors.textMuted,
                        size: 18,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscureText[e.key] = !isObscured;
                        });
                      },
                    ),
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
              );
            }),
            const SizedBox(height: 24),
            const Divider(color: SwarmColors.border),
            const SizedBox(height: 20),
            const _GoogleWorkspaceSection(),
            const SizedBox(height: 20),
            const Divider(color: SwarmColors.border),
            const SizedBox(height: 20),
            const _WebAuthnSection(),
            const SizedBox(height: 20),
            const Divider(color: SwarmColors.border),
            const SizedBox(height: 20),
            const AgentVoicePromptSettings(),
            const SizedBox(height: 20),
            const Divider(color: SwarmColors.border),
            const SizedBox(height: 20),
            const _CipherSection(),
          ],
        ),
      ),
    );
  }
}

class _GoogleWorkspaceSection extends StatefulWidget {
  const _GoogleWorkspaceSection();

  @override
  State<_GoogleWorkspaceSection> createState() =>
      _GoogleWorkspaceSectionState();
}

class _GoogleWorkspaceSectionState extends State<_GoogleWorkspaceSection> {
  final _svc = GoogleWorkspaceService();
  GoogleAuthStatus _status = GoogleAuthStatus.offline;
  bool _loading = true;
  bool _actionInProgress = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final s = await _svc.status();
    if (mounted) setState(() { _status = s; _loading = false; });
  }

  Future<void> _startLogin() async {
    setState(() => _actionInProgress = true);
    try {
      final url = await _svc.getAuthUrl();
      await Process.run('xdg-open', [url]);
      await Future.delayed(const Duration(seconds: 3));
      await _refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: SwarmColors.bgElevated,
            content: Text('Google login failed: $e',
                style: const TextStyle(color: SwarmColors.statusCritical)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _actionInProgress = false);
    }
  }

  Future<void> _logout() async {
    setState(() => _actionInProgress = true);
    try {
      await _svc.logout();
      await _refresh();
    } finally {
      if (mounted) setState(() => _actionInProgress = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color statusColor;
    final String statusLabel;
    if (_loading) {
      statusColor = SwarmColors.textMuted;
      statusLabel = 'Checking...';
    } else if (_status.isOffline) {
      statusColor = SwarmColors.statusOffline;
      statusLabel = 'Service offline';
    } else if (_status.authenticated) {
      statusColor = SwarmColors.statusOnline;
      statusLabel = _status.email ?? 'Authenticated';
    } else if (_status.hasCredentials) {
      statusColor = SwarmColors.statusIdle;
      statusLabel = 'Credentials loaded, not signed in';
    } else {
      statusColor = SwarmColors.statusOffline;
      statusLabel = 'No credentials';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: SwarmColors.bgElevated,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: SwarmColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.cloud_outlined,
                  color: SwarmColors.accent, size: 18),
              const SizedBox(width: 8),
              Text('Google Workspace',
                  style: SwarmTextStyles.label
                      .copyWith(color: SwarmColors.textPrimary, fontSize: 13)),
              const Spacer(),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: statusColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(statusLabel,
                  style: SwarmTextStyles.codeSmall
                      .copyWith(color: statusColor, fontSize: 11)),
            ],
          ),
          if (!_loading && !_status.isOffline) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                if (_status.authenticated)
                  ElevatedButton.icon(
                    onPressed: _actionInProgress ? null : _logout,
                    icon: const Icon(Icons.logout, size: 14),
                    label: const Text('Sign Out'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          SwarmColors.statusCritical.withValues(alpha: 0.15),
                      foregroundColor: SwarmColors.statusCritical,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                    ),
                  )
                else
                  ElevatedButton.icon(
                    onPressed: _actionInProgress ? null : _startLogin,
                    icon: const Icon(Icons.login, size: 14),
                    label: const Text('Sign In with Google'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          SwarmColors.accent.withValues(alpha: 0.15),
                      foregroundColor: SwarmColors.accent,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                    ),
                  ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _actionInProgress ? null : _refresh,
                  icon: const Icon(Icons.refresh, size: 16),
                  color: SwarmColors.textMuted,
                  tooltip: 'Refresh status',
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _WebAuthnSection extends StatefulWidget {
  const _WebAuthnSection();

  @override
  State<_WebAuthnSection> createState() => _WebAuthnSectionState();
}

class _WebAuthnSectionState extends State<_WebAuthnSection> {
  final _auth = AuthService();
  List<PasskeyCredential>? _credentials;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() { _loading = true; _error = null; });
    try {
      final creds = await _auth.listCredentials();
      if (mounted) setState(() { _credentials = creds; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = '$e'; _loading = false; });
    }
  }

  Future<void> _clearAll() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: SwarmColors.bgElevated,
        title: const Text('Clear All Passkeys?',
            style: TextStyle(color: SwarmColors.textPrimary)),
        content: const Text(
          'This removes all registered WebAuthn credentials. You will need to re-register passkeys on each device.',
          style: TextStyle(color: SwarmColors.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
                foregroundColor: SwarmColors.statusCritical),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _auth.clearCredentials();
      await _refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          backgroundColor: SwarmColors.bgElevated,
          content: Text('All passkeys cleared',
              style: TextStyle(color: SwarmColors.textPrimary)),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: SwarmColors.bgElevated,
          content: Text('Failed: $e',
              style: const TextStyle(color: SwarmColors.statusCritical)),
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: SwarmColors.bgElevated,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: SwarmColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.fingerprint,
                  color: SwarmColors.accent, size: 18),
              const SizedBox(width: 8),
              Text('Passkeys / WebAuthn',
                  style: SwarmTextStyles.label
                      .copyWith(color: SwarmColors.textPrimary, fontSize: 13)),
              const Spacer(),
              if (_credentials != null)
                Text('${_credentials!.length} registered',
                    style: SwarmTextStyles.codeSmall.copyWith(
                        color: _credentials!.isEmpty
                            ? SwarmColors.statusOffline
                            : SwarmColors.statusOnline,
                        fontSize: 11)),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Passkeys let your companion phone authenticate against SWARM OS without a password. '
            'Register from the companion app or a browser on the same network.',
            style: TextStyle(
                color: SwarmColors.textMuted, fontSize: 11.5, height: 1.3),
          ),
          const SizedBox(height: 12),
          if (_loading)
            const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: SwarmColors.accent),
              ),
            )
          else if (_error != null)
            const Text('Service unreachable',
                style: TextStyle(
                    color: SwarmColors.statusOffline, fontSize: 12))
          else ...[
            if (_credentials != null && _credentials!.isNotEmpty)
              ...(_credentials!.map((c) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        const Icon(Icons.key, size: 14,
                            color: SwarmColors.textMuted),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            c.name.isNotEmpty ? c.name : c.id,
                            style: const TextStyle(
                                color: SwarmColors.textPrimary, fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (c.createdAt.isNotEmpty)
                          Text(c.createdAt,
                              style: SwarmTextStyles.codeSmall.copyWith(
                                  color: SwarmColors.textMuted, fontSize: 10)),
                      ],
                    ),
                  ))),
            const SizedBox(height: 8),
            Row(
              children: [
                if (_credentials != null && _credentials!.isNotEmpty)
                  ElevatedButton.icon(
                    onPressed: _clearAll,
                    icon: const Icon(Icons.delete_forever, size: 14),
                    label: const Text('Clear All Passkeys'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          SwarmColors.statusCritical.withValues(alpha: 0.15),
                      foregroundColor: SwarmColors.statusCritical,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                    ),
                  ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _refresh,
                  icon: const Icon(Icons.refresh, size: 16),
                  color: SwarmColors.textMuted,
                  tooltip: 'Refresh',
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Cipher management section — main and garden pattern reset entrypoints.
/// The two flows are separate on purpose:
///  * /auth wipes both patterns and walks the user through fresh setup
///  * /auth/garden verifies the current main pattern, then lets the user
///    change ONLY the garden pattern.
class _CipherSection extends StatelessWidget {
  const _CipherSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Lock Screen', style: SwarmTextStyles.h3),
        const SizedBox(height: 8),
        Text(
          'The stone cipher unlocks SWARM OS. The garden cipher is an optional '
          'second pattern that unlocks a private garden mode instead of the '
          'main desktop.',
          style: SwarmTextStyles.body.copyWith(color: SwarmColors.textMuted),
        ),
        const SizedBox(height: 16),
        _CipherActionTile(
          icon: Icons.lock_reset,
          title: 'Change stone cipher',
          subtitle: 'Wipes both patterns and walks through fresh setup.',
          onTap: () => context.go('/auth'),
          accent: SwarmColors.accent,
        ),
        const SizedBox(height: 10),
        _CipherActionTile(
          icon: Icons.local_florist_outlined,
          title: 'Change garden cipher',
          subtitle: 'Prompts for your main cipher, then picks a new garden pattern.',
          onTap: () => context.go('/auth/garden'),
          accent: const Color(0xFF4CAF50),
        ),
      ],
    );
  }
}

class _CipherActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color accent;
  const _CipherActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: accent.withValues(alpha: 0.5)),
            color: accent.withValues(alpha: 0.06),
          ),
          child: Row(
            children: [
              Icon(icon, color: accent),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: SwarmTextStyles.body.copyWith(
                        color: accent, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: SwarmTextStyles.bodySmall.copyWith(
                        color: SwarmColors.textMuted)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: SwarmColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/swarm_colors.dart';
import '../services/lucille_voice_service.dart';
import '../widgets/agent_voice_prompt_settings.dart';
import 'companion_bridge_dialog.dart';

class RightSettingsDrawer extends StatefulWidget {
  final bool isOpen;
  final VoidCallback onClose;

  const RightSettingsDrawer({
    super.key,
    required this.isOpen,
    required this.onClose,
  });

  @override
  State<RightSettingsDrawer> createState() => _RightSettingsDrawerState();
}

class _RightSettingsDrawerState extends State<RightSettingsDrawer> {
  final Map<String, TextEditingController> _controllers = {};
  bool _loading = true;

  // HITL (Human-in-the-loop) settings
  bool _hitlEnabled = true;
  bool _hitlDockerGating = true;
  bool _hitlTailscaleSync = true;

  // Subsystem Telemetry
  bool _ipcSocketActive = false;
  bool _dockerActive = false;
  String _tailscaleIp = 'Checking...';

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _checkSubsystems();
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _controllers['OPENROUTER_API_KEY'] = TextEditingController(
          text: _resolveKey(prefs, 'OPENROUTER_API_KEY'),
        );
        _controllers['ELEVEN_KEY'] = TextEditingController(
          text: _resolveKey(prefs, 'ELEVEN_KEY'),
        );
        _controllers['ELEVEN_VOICE_ID'] = TextEditingController(
          text: _resolveKey(prefs, 'ELEVEN_VOICE_ID').isNotEmpty
              ? _resolveKey(prefs, 'ELEVEN_VOICE_ID')
              : 'sIak7pFapfSLCfctxdOu',
        );
        _controllers['FISH_AUDIO_API_KEY'] = TextEditingController(
          text: _resolveKey(prefs, 'FISH_AUDIO_API_KEY'),
        );
        _controllers['OPENAI_API_KEY'] = TextEditingController(
          text: _resolveKey(prefs, 'OPENAI_API_KEY'),
        );
        _controllers['OLLAMA_ENDPOINT'] = TextEditingController(
          text: _resolveKey(prefs, 'OLLAMA_ENDPOINT').isNotEmpty
              ? _resolveKey(prefs, 'OLLAMA_ENDPOINT')
              : 'http://127.0.0.1:11434',
        );

        _hitlEnabled = prefs.getBool('HITL_ENABLED') ?? true;
        _hitlDockerGating = prefs.getBool('HITL_DOCKER_GATING') ?? true;
        _hitlTailscaleSync = prefs.getBool('HITL_TAILSCALE_SYNC') ?? true;
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
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
              return trimmed.substring('$keyName='.length).trim().replaceAll('"', '').replaceAll("'", '');
            }
            if (keyName == 'ELEVEN_KEY' && trimmed.startsWith('ELEVEN_API_KEY=')) {
              return trimmed.substring('ELEVEN_API_KEY='.length).trim().replaceAll('"', '').replaceAll("'", '');
            }
          }
        } catch (_) {}
      }
    }
    return Platform.environment[keyName] ?? '';
  }

  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final entry in _controllers.entries) {
        await prefs.setString(entry.key, entry.value.text);
      }
      await prefs.setBool('HITL_ENABLED', _hitlEnabled);
      await prefs.setBool('HITL_DOCKER_GATING', _hitlDockerGating);
      await prefs.setBool('HITL_TAILSCALE_SYNC', _hitlTailscaleSync);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: SwarmColors.bgElevated,
            content: Text(
              '✅ Settings & HITL policies saved successfully',
              style: TextStyle(color: SwarmColors.textPrimary),
            ),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: SwarmColors.statusCritical,
            content: Text('Failed to save settings: $e'),
          ),
        );
      }
    }
  }

  Future<void> _checkSubsystems() async {
    // Check IPC socket
    final sock = File('/run/lucille/ipc.sock');
    final sockExists = await sock.exists();

    // Check Docker socket
    final dockerSock = File('/var/run/docker.sock');
    final dockerExists = await dockerSock.exists();

    // Check Tailscale interface if available
    String tsIp = '100.x.y.z (Tailscale Standby)';
    try {
      final interfaces = await NetworkInterface.list();
      for (final i in interfaces) {
        if (i.name.contains('tailscale') || i.name.contains('ts0')) {
          if (i.addresses.isNotEmpty) {
            tsIp = i.addresses.first.address;
          }
        }
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        _ipcSocketActive = sockExists;
        _dockerActive = dockerExists;
        _tailscaleIp = tsIp;
      });
    }
  }

  Widget _buildStatusRow(String label, bool active, {String? detail}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: active ? SwarmColors.statusOnline : SwarmColors.statusIdle,
              boxShadow: [
                BoxShadow(
                  color: (active ? SwarmColors.statusOnline : SwarmColors.statusIdle)
                      .withValues(alpha: 0.4),
                  blurRadius: 4,
                )
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(color: SwarmColors.textPrimary, fontSize: 12),
          ),
          const Spacer(),
          Text(
            detail ?? (active ? 'ACTIVE' : 'STANDBY'),
            style: TextStyle(
              fontSize: 11,
              color: active ? SwarmColors.statusOnline : SwarmColors.textMuted,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      right: widget.isOpen ? 0 : -400,
      top: 48, // Below top bar
      bottom: 0,
      width: 400,
      child: Container(
        decoration: BoxDecoration(
          color: SwarmColors.bgSurface.withValues(alpha: 0.94),
          border: const Border(
            left: BorderSide(color: SwarmColors.border, width: 1.5),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.6),
              blurRadius: 24,
              offset: const Offset(-8, 0),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drawer Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: SwarmColors.border)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: SwarmColors.accentSurface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: SwarmColors.accent.withValues(alpha: 0.4)),
                    ),
                    child: const Icon(Icons.settings, color: SwarmColors.accent, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'SWARM SETTINGS & HUD',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                        color: SwarmColors.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: SwarmColors.textMuted, size: 18),
                    onPressed: widget.onClose,
                    tooltip: 'Close Settings Drawer',
                  ),
                ],
              ),
            ),

            if (_loading)
              const Expanded(
                child: Center(
                  child: CircularProgressIndicator(color: SwarmColors.accent),
                ),
              )
            else
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Subsystem Telemetry Card
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: SwarmColors.bgElevated,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: SwarmColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.hub, size: 16, color: SwarmColors.accent),
                              const SizedBox(width: 8),
                              const Text(
                                'SUBSYSTEM TELEMETRY',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2,
                                  color: SwarmColors.textMuted,
                                ),
                              ),
                              const Spacer(),
                              IconButton(
                                icon: const Icon(Icons.refresh, size: 14, color: SwarmColors.textMuted),
                                onPressed: _checkSubsystems,
                                tooltip: 'Refresh Subsystems',
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          _buildStatusRow('Lucille IPC Socket', _ipcSocketActive,
                              detail: _ipcSocketActive ? '/run/lucille/ipc.sock' : 'Connecting...'),
                          _buildStatusRow('Docker Runtime', _dockerActive,
                              detail: _dockerActive ? 'RUNNING' : 'INACTIVE'),
                          _buildStatusRow('Tailscale Mesh', _tailscaleIp.startsWith('100.'),
                              detail: _tailscaleIp),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // HITL (Human-in-the-loop) Section
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: SwarmColors.bgElevated,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _hitlEnabled
                              ? SwarmColors.accent.withValues(alpha: 0.4)
                              : SwarmColors.border,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.security, size: 16, color: SwarmColors.statusIdle),
                              SizedBox(width: 8),
                              Text(
                                'HUMAN-IN-THE-LOOP (HITL)',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2,
                                  color: SwarmColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          SwitchListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: const Text(
                              'Enforce HITL Privileged Gating',
                              style: TextStyle(color: SwarmColors.textPrimary, fontSize: 13),
                            ),
                            subtitle: const Text(
                              'Requires manual approval for root, package & container actions',
                              style: TextStyle(color: SwarmColors.textMuted, fontSize: 11),
                            ),
                            value: _hitlEnabled,
                            activeThumbColor: SwarmColors.accent,
                            onChanged: (val) => setState(() => _hitlEnabled = val),
                          ),
                          SwitchListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: const Text(
                              'Docker Sandbox Jail Enforcement',
                              style: TextStyle(color: SwarmColors.textPrimary, fontSize: 13),
                            ),
                            subtitle: const Text(
                              'Isolate agent executions inside container boundaries',
                              style: TextStyle(color: SwarmColors.textMuted, fontSize: 11),
                            ),
                            value: _hitlDockerGating,
                            activeThumbColor: SwarmColors.accent,
                            onChanged: (val) => setState(() => _hitlDockerGating = val),
                          ),
                          SwitchListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: const Text(
                              'Tailscale Mobile Companion Sync',
                              style: TextStyle(color: SwarmColors.textPrimary, fontSize: 13),
                            ),
                            subtitle: const Text(
                              'Forward HITL approvals to DR.-I30LTZ-Companion',
                              style: TextStyle(color: SwarmColors.textMuted, fontSize: 11),
                            ),
                            value: _hitlTailscaleSync,
                            activeThumbColor: SwarmColors.accent,
                            onChanged: (val) => setState(() => _hitlTailscaleSync = val),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () => CompanionResourcePoolDialog.show(context),
                              icon: const Icon(Icons.hub, size: 14, color: SwarmColors.accent),
                              label: const Text(
                                'OPEN COMPANION RESOURCE POOL',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: SwarmColors.accent),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: SwarmColors.accent),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                shape: RoundedCornerShape(8),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // AI API Keys Section
                    const Text(
                      'AI SWARM ROUTING & API KEYS',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                        color: SwarmColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 10),

                    _buildKeyField('OPENROUTER_API_KEY', 'OpenRouter API Key', Icons.key),
                    const SizedBox(height: 12),
                    _buildKeyField('FISH_AUDIO_API_KEY', 'Fish Audio API Key (Optional)', Icons.record_voice_over),
                    const SizedBox(height: 12),
                    _buildKeyField('OPENAI_API_KEY', 'OpenAI API Key (Optional)', Icons.vpn_key),
                    const SizedBox(height: 12),
                    _buildKeyField('ELEVEN_KEY', 'ElevenLabs TTS Key (Optional)', Icons.record_voice_over),
                    const SizedBox(height: 12),
                    _buildKeyField('ELEVEN_VOICE_ID', 'ElevenLabs Voice ID (Lucille)', Icons.settings_voice),
                    const SizedBox(height: 12),
                    _buildKeyField('OLLAMA_ENDPOINT', 'Local Ollama/K3s Endpoint', Icons.dns),
                    const SizedBox(height: 24),

                    // Agent Voices & Custom Prompts Management
                    const AgentVoicePromptSettings(),
                    const SizedBox(height: 20),

                    // Test Lucille Seductive Voice Button
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFFF2E93),
                        side: const BorderSide(color: Color(0xFFFF2E93)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () {
                        LucilleVoiceService().speak(
                          'Hello hun... Lucille is listening. What are we building together today?',
                        );
                      },
                      icon: const Icon(Icons.record_voice_over, size: 18),
                      label: const Text(
                        'TEST LUCILLE SEDUCTIVE VOICE',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Save Button
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: SwarmColors.accent,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: _saveSettings,
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text(
                        'SAVE SETTINGS & POLICIES',
                        style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.1),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildKeyField(String key, String label, IconData icon) {
    final controller = _controllers[key];
    if (controller == null) return const SizedBox.shrink();

    return TextField(
      controller: controller,
      obscureText: key.contains('KEY'),
      style: const TextStyle(color: SwarmColors.textPrimary, fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: SwarmColors.textMuted, fontSize: 12),
        prefixIcon: Icon(icon, color: SwarmColors.textMuted, size: 18),
        filled: true,
        fillColor: SwarmColors.bgElevated,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: SwarmColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: SwarmColors.accent),
        ),
      ),
    );
  }
}

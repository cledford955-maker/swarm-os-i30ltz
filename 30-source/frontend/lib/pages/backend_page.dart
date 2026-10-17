import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/sentinel_providers.dart';
import '../services/swarm_health_service.dart';
import '../theme/swarm_colors.dart';
import '../theme/swarm_text_styles.dart';
import '../services/system_launcher.dart';

enum ServiceStatus { online, starting, offline, error }

class BackendServiceItem {
  final String id;
  final String name;
  final String role;
  final int port;
  final String socketPath;
  final String startCommand;
  final String stopCommand;
  final String healthUrl;
  ServiceStatus status;
  int? pid;
  String lastLog;
  Duration latency;

  BackendServiceItem({
    required this.id,
    required this.name,
    required this.role,
    required this.port,
    this.socketPath = '',
    required this.startCommand,
    required this.stopCommand,
    this.healthUrl = '',
    this.status = ServiceStatus.offline,
    this.pid,
    this.lastLog = '',
    this.latency = Duration.zero,
  });
}

class BackendPage extends ConsumerStatefulWidget {
  const BackendPage({super.key});

  @override
  ConsumerState<BackendPage> createState() => _BackendPageState();
}

class _BackendPageState extends ConsumerState<BackendPage> {
  Timer? _pollTimer;
  final List<String> _liveLogs = [];
  final ScrollController _logScrollController = ScrollController();
  bool _autoScroll = true;

  final List<BackendServiceItem> _services = [
    BackendServiceItem(
      id: 'lucille_core',
      name: 'Lucille Core C++20 Engine',
      role: 'Speculative pipeline (Kimi→DeepSeek→GLM), 2-of-2 consensus gate, HITL approval, checkpoint journal, epoll IPC, SHM telemetry',
      port: 9091,
      socketPath: '/run/lucille/ipc.sock',
      startCommand: 'systemctl start lucille-core || /usr/bin/lucille-core',
      stopCommand: 'systemctl stop lucille-core',
      healthUrl: 'http://127.0.0.1:5000/api/lucille/status',
      status: ServiceStatus.offline,
    ),
    BackendServiceItem(
      id: 'lucy_server',
      name: 'LucyServer (Go)',
      role: 'Primary API orchestrator, WebAuthn, Lucy chat, health & memory sync',
      port: 5000,
      startCommand: 'systemctl start lucy-server || /opt/swarm_os/LucyServer/lucy-server',
      stopCommand: 'systemctl stop lucy-server || pkill -f lucy-server',
      healthUrl: 'http://127.0.0.1:5000/health',
      status: ServiceStatus.offline,
    ),
    BackendServiceItem(
      id: 'gaming_agent',
      name: 'GamingAgent (Go)',
      role: 'Steam/GFN library, Lucille chat & eval, game pricing via CheapShark',
      port: 8401,
      startCommand: 'systemctl start gaming-agent || /opt/swarm_os/GamingAgent/gaming-agent',
      stopCommand: 'systemctl stop gaming-agent || pkill -f gaming-agent',
      healthUrl: 'http://127.0.0.1:8401/health',
      status: ServiceStatus.offline,
    ),
    BackendServiceItem(
      id: 'tailscale_mesh',
      name: 'Tailscale WireGuard Mesh',
      role: 'Encrypted peer-to-peer transport for DR.-I30LTZ-Companion mobile bridging',
      port: 0, // tailscaled manages its own tunnel; no fixed listening port
      startCommand: 'systemctl start tailscaled || tailscale up',
      stopCommand: 'tailscale down',
      healthUrl: '',
      status: ServiceStatus.offline,
    ),
    BackendServiceItem(
      id: 'ollama_inference',
      name: 'Ollama / GGUF Local Inference',
      role: 'Local LLM execution engine with CUDA and ROCm GPU offloading',
      port: 11434,
      startCommand: 'ollama serve',
      stopCommand: 'pkill -f "ollama serve"',
      healthUrl: 'http://127.0.0.1:11434/api/tags',
      status: ServiceStatus.offline,
    ),
    BackendServiceItem(
      id: 'pipewire_audio',
      name: 'PipeWire Low-Latency Audio',
      role: 'Real-time pro audio graph (48kHz / 64-128 quantum) for Lucille voice loop',
      port: 0,
      startCommand: 'systemctl --user start pipewire pipewire-pulse',
      stopCommand: 'systemctl --user stop pipewire',
      healthUrl: '',
      status: ServiceStatus.online,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _checkAllServices();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) => _checkAllServices());
    _addLog('INFO', 'Backend Service Manager initialized. Polling socket listeners & ports.');
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _logScrollController.dispose();
    super.dispose();
  }

  void _addLog(String level, String msg) {
    if (!mounted) return;
    final now = DateTime.now();
    final timeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
    setState(() {
      _liveLogs.add('[$timeStr] [$level] $msg');
      if (_liveLogs.length > 200) _liveLogs.removeAt(0);
    });
    if (_autoScroll && _logScrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 50), () {
        if (_logScrollController.hasClients) {
          _logScrollController.jumpTo(_logScrollController.position.maxScrollExtent);
        }
      });
    }
  }

  // Web demo (--dart-define=MOCK=true): no sockets/processes in a browser, so
  // services come up healthy once and Start/Stop just flip the state.
  static const bool _demo = bool.fromEnvironment('MOCK');
  bool _demoSeeded = false;

  Future<void> _checkAllServices() async {
    if (_demo) {
      if (_demoSeeded) return;
      _demoSeeded = true;
      var ms = 3;
      setState(() {
        for (final s in _services) {
          s.status = ServiceStatus.online;
          s.latency = Duration(milliseconds: ms++);
          s.lastLog = s.port > 0 ? 'Listening on 127.0.0.1:${s.port} (demo)' : 'Active (demo)';
        }
      });
      for (final s in _services) {
        _addLog('INFO', '${s.name} online${s.port > 0 ? ' on port ${s.port}' : ''}.');
      }
      return;
    }
    for (final service in _services) {
      if (service.socketPath.isNotEmpty) {
        final sock = File(service.socketPath);
        final exists = await sock.exists();
        if (exists && service.status != ServiceStatus.online) {
          setState(() {
            service.status = ServiceStatus.online;
            service.lastLog = 'UNIX domain socket active at ${service.socketPath}';
          });
          _addLog('INFO', '${service.name} socket confirmed active.');
        }
      }

      if (service.port > 0) {
        try {
          final stopwatch = Stopwatch()..start();
          final sock = await Socket.connect('127.0.0.1', service.port, timeout: const Duration(milliseconds: 500));
          stopwatch.stop();
          await sock.close();

          if (service.status != ServiceStatus.online) {
            setState(() {
              service.status = ServiceStatus.online;
              service.latency = stopwatch.elapsed;
              service.lastLog = 'Listening on 127.0.0.1:${service.port} (${stopwatch.elapsedMilliseconds}ms)';
            });
            _addLog('INFO', '${service.name} connected on port ${service.port} in ${stopwatch.elapsedMilliseconds}ms');
          } else {
            setState(() {
              service.latency = stopwatch.elapsed;
            });
          }
        } catch (_) {
          if (service.status == ServiceStatus.online && service.socketPath.isEmpty) {
            setState(() {
              service.status = ServiceStatus.offline;
              service.lastLog = 'Port ${service.port} unreachable';
            });
            _addLog('WARN', '${service.name} port ${service.port} unreachable.');
          }
        }
      }
    }
  }

  Future<void> _startService(BackendServiceItem service) async {
    setState(() => service.status = ServiceStatus.starting);
    _addLog('EXEC', 'Starting ${service.name} -> ${service.startCommand}');
    
    if (_demo) {
      await Future.delayed(const Duration(milliseconds: 1200));
      if (!mounted) return;
      setState(() => service.status = ServiceStatus.online);
      _addLog('INFO', '${service.name} started (demo).');
      return;
    }
    await SystemLauncher.launch(context, service.startCommand, displayName: service.name);
    await Future.delayed(const Duration(seconds: 2));
    _checkAllServices();
  }

  Future<void> _stopService(BackendServiceItem service) async {
    _addLog('EXEC', 'Stopping ${service.name} -> ${service.stopCommand}');
    if (_demo) {
      setState(() => service.status = ServiceStatus.offline);
      _addLog('INFO', '${service.name} stopped (demo).');
      return;
    }
    await Process.run('bash', ['-c', service.stopCommand]);
    
    if (service.socketPath.isNotEmpty) {
      try {
        final f = File(service.socketPath);
        if (await f.exists()) await f.delete();
      } catch (_) {}
    }

    setState(() => service.status = ServiceStatus.offline);
    _addLog('INFO', '${service.name} stopped.');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SwarmColors.bgBase,
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left Column: Services Grid & Port Controls
            Expanded(
              flex: 6,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: SwarmColors.accentCyan.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: SwarmColors.accentCyan.withValues(alpha: 0.3)),
                        ),
                        child: const Icon(Icons.dns_rounded, color: SwarmColors.accentCyan, size: 28),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'BACKEND ENGINE CONTROL',
                            style: SwarmTextStyles.headlineMedium.copyWith(
                              color: SwarmColors.textPrimary,
                              letterSpacing: 1.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Native daemons, RPC bridges, vector memory & inference microservices',
                            style: SwarmTextStyles.bodyMedium.copyWith(color: SwarmColors.textMuted),
                          ),
                        ],
                      ),
                      const Spacer(),
                      ElevatedButton.icon(
                        onPressed: _checkAllServices,
                        icon: const Icon(Icons.refresh_rounded, size: 16),
                        label: const Text('Probe Ports'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: SwarmColors.bgElevated,
                          foregroundColor: SwarmColors.accentCyan,
                          side: const BorderSide(color: SwarmColors.borderSubtle),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Health summary from /api/health
                  _HealthSummaryBar(),
                  const SizedBox(height: 16),

                  // Services List
                  Expanded(
                    child: ListView.separated(
                      itemCount: _services.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, idx) {
                        final s = _services[idx];
                        final isOnline = s.status == ServiceStatus.online;
                        final isStarting = s.status == ServiceStatus.starting;

                        return Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: SwarmColors.bgElevated,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isOnline
                                  ? SwarmColors.statusHealthy.withValues(alpha: 0.3)
                                  : SwarmColors.borderSubtle,
                            ),
                          ),
                          child: Row(
                            children: [
                              // Status Indicator Icon
                              Container(
                                width: 14,
                                height: 14,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isOnline
                                      ? SwarmColors.statusHealthy
                                      : isStarting
                                          ? SwarmColors.statusWarning
                                          : SwarmColors.statusCritical,
                                  boxShadow: isOnline
                                      ? [
                                          BoxShadow(
                                            color: SwarmColors.statusHealthy.withValues(alpha: 0.6),
                                            blurRadius: 8,
                                            spreadRadius: 2,
                                          )
                                        ]
                                      : null,
                                ),
                              ),
                              const SizedBox(width: 16),

                              // Info
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          s.name,
                                          style: const TextStyle(
                                            color: SwarmColors.textPrimary,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        if (s.port > 0)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: SwarmColors.bgBase,
                                              borderRadius: BorderRadius.circular(4),
                                              border: Border.all(color: SwarmColors.borderSubtle),
                                            ),
                                            child: Text(
                                              ':${s.port}',
                                              style: const TextStyle(
                                                color: SwarmColors.accentCyan,
                                                fontSize: 11,
                                                fontFamily: 'monospace',
                                              ),
                                            ),
                                          ),
                                        if (s.socketPath.isNotEmpty)
                                          Padding(
                                            padding: const EdgeInsets.only(left: 6),
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: SwarmColors.bgBase,
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: const Text(
                                                'UNIX SOCK',
                                                style: TextStyle(
                                                  color: SwarmColors.accent,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      s.role,
                                      style: const TextStyle(color: SwarmColors.textMuted, fontSize: 12),
                                    ),
                                    if (s.lastLog.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Text(
                                          'Status: ${s.lastLog}',
                                          style: TextStyle(
                                            color: isOnline ? SwarmColors.statusHealthy : SwarmColors.textMuted,
                                            fontSize: 11,
                                            fontFamily: 'monospace',
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),

                              // Controls
                              Row(
                                children: [
                                  if (!isOnline)
                                    ElevatedButton.icon(
                                      onPressed: isStarting ? null : () => _startService(s),
                                      icon: const Icon(Icons.play_arrow_rounded, size: 16),
                                      label: Text(isStarting ? 'Starting...' : 'Start'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: SwarmColors.statusHealthy.withValues(alpha: 0.15),
                                        foregroundColor: SwarmColors.statusHealthy,
                                        side: BorderSide(color: SwarmColors.statusHealthy.withValues(alpha: 0.3)),
                                      ),
                                    )
                                  else ...[
                                    OutlinedButton.icon(
                                      onPressed: () => _startService(s),
                                      icon: const Icon(Icons.restart_alt_rounded, size: 16),
                                      label: const Text('Restart'),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: SwarmColors.textPrimary,
                                        side: const BorderSide(color: SwarmColors.borderSubtle),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      tooltip: 'Stop Service',
                                      icon: const Icon(Icons.stop_circle_outlined, color: SwarmColors.statusCritical, size: 22),
                                      onPressed: () => _stopService(s),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 20),

            // Right Column: Live Logs Terminal
            Expanded(
              flex: 5,
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: SwarmColors.bgElevated,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: SwarmColors.borderSubtle),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.terminal_rounded, color: SwarmColors.accent, size: 20),
                        const SizedBox(width: 8),
                        const Text(
                          'LIVE BACKEND LOG STREAM',
                          style: TextStyle(
                            color: SwarmColors.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            letterSpacing: 1,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: Icon(
                            _autoScroll ? Icons.vertical_align_bottom_rounded : Icons.pause_circle_outline_rounded,
                            color: _autoScroll ? SwarmColors.accent : SwarmColors.textMuted,
                            size: 18,
                          ),
                          tooltip: _autoScroll ? 'Auto-scroll Enabled' : 'Auto-scroll Paused',
                          onPressed: () => setState(() => _autoScroll = !_autoScroll),
                        ),
                        IconButton(
                          icon: const Icon(Icons.clear_all_rounded, color: SwarmColors.textMuted, size: 18),
                          tooltip: 'Clear Console',
                          onPressed: () => setState(() => _liveLogs.clear()),
                        ),
                      ],
                    ),
                    const Divider(color: SwarmColors.borderSubtle, height: 20),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0D1117),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: ListView.builder(
                          controller: _logScrollController,
                          itemCount: _liveLogs.length,
                          itemBuilder: (context, idx) {
                            final line = _liveLogs[idx];
                            Color textColor = const Color(0xFFC9D1D9);
                            if (line.contains('[ERR]') || line.contains('[CRIT]')) {
                              textColor = SwarmColors.statusCritical;
                            } else if (line.contains('[WARN]')) {
                              textColor = SwarmColors.statusWarning;
                            } else if (line.contains('[EXEC]')) {
                              textColor = SwarmColors.accentCyan;
                            } else if (line.contains('[INFO]')) {
                              textColor = SwarmColors.statusHealthy;
                            }

                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2.0),
                              child: Text(
                                line,
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: 11,
                                  fontFamily: 'monospace',
                                  height: 1.4,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HealthSummaryBar extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final healthAsync = ref.watch(swarmHealthProvider);
    final health = healthAsync.valueOrNull ?? SwarmHealthSnapshot.empty;
    final bool live = !health.isStale();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: SwarmColors.bgElevated,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: live
              ? SwarmColors.statusHealthy.withValues(alpha: 0.2)
              : SwarmColors.borderSubtle,
        ),
      ),
      child: Row(
        children: [
          Icon(
            live ? Icons.check_circle_rounded : Icons.cloud_off_rounded,
            color: live ? SwarmColors.statusHealthy : SwarmColors.statusCritical,
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(
            live ? 'SYSTEM HEALTHY' : 'BACKEND OFFLINE',
            style: TextStyle(
              color: live ? SwarmColors.statusHealthy : SwarmColors.statusCritical,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
          if (live) ...[
            const SizedBox(width: 20),
            _chip('v${health.version}', SwarmColors.accentCyan),
            const SizedBox(width: 12),
            _chip('UP ${health.uptimeFormatted}', SwarmColors.textMuted),
            const SizedBox(width: 12),
            _chip(
              'DISK ${health.diskUsedGb.toStringAsFixed(0)}/${health.diskTotalGb.toStringAsFixed(0)} GB',
              health.diskPercent > 85
                  ? SwarmColors.statusCritical
                  : SwarmColors.textMuted,
            ),
            const SizedBox(width: 12),
            _chip(
              health.companionsConnected > 0
                  ? 'PHONES ${health.companionsConnected}'
                  : 'NO PHONES',
              health.companionsConnected > 0
                  ? SwarmColors.statusHealthy
                  : SwarmColors.textMuted,
            ),
          ],
        ],
      ),
    );
  }

  Widget _chip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w600,
          fontFamily: 'monospace',
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../services/advanced_ecosystem_service.dart';
import '../theme/swarm_text_styles.dart';

class CloudWorkspacesPage extends StatefulWidget {
  const CloudWorkspacesPage({super.key});

  @override
  State<CloudWorkspacesPage> createState() => _CloudWorkspacesPageState();
}

class _CloudWorkspacesPageState extends State<CloudWorkspacesPage> {
  final AdvancedEcosystemService _service = AdvancedEcosystemService();
  List<dynamic> _workspaces = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadWorkspaces();
  }

  Future<void> _loadWorkspaces() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final list = await _service.getCloudWorkspaces();
      if (!mounted) return;
      setState(() {
        _workspaces = list;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _workspaces = [];
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _syncWorkspace(String id) async {
    try {
      await _service.syncCloudWorkspace(id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Workspace $id synchronized with remote cloud node.')),
      );
      _loadWorkspaces();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sync failed: $e'), backgroundColor: const Color(0xFF7F1D1D)),
      );
    }
  }

  Widget _errorState() => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.cloud_off, color: Color(0xFFEF4444), size: 40),
              const SizedBox(height: 12),
              Text('Cannot reach LucyServer', style: SwarmTextStyles.title.copyWith(fontSize: 14)),
              const SizedBox(height: 6),
              Text(_error ?? '', textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadWorkspaces,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('RETRY'),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00E5FF), foregroundColor: Colors.black),
              ),
            ],
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF07090E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0C1018),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF00E5FF).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.cloud_sync, color: Color(0xFF00E5FF), size: 22),
            ),
            const SizedBox(width: 12),
            Text('CLOUD REMOTE WORKSPACES', style: SwarmTextStyles.title.copyWith(fontSize: 16)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF00E5FF)),
            onPressed: _loadWorkspaces,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF00E5FF)))
          : _error != null
          ? _errorState()
          : Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('MANAGED CLOUD DEV NODES & CONTAINERS', style: SwarmTextStyles.title.copyWith(fontSize: 14)),
                      const Spacer(),
                      ElevatedButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('CONNECT NEW REMOTE NODE'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00E5FF),
                          foregroundColor: Colors.black,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _workspaces.length,
                      itemBuilder: (context, index) {
                        final ws = _workspaces[index];
                        final isConnected = ws['status'] == 'Connected';

                        return Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F141F),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isConnected
                                  ? const Color(0xFF00E5FF).withValues(alpha: 0.4)
                                  : const Color(0xFF1E2838),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(
                                      color: isConnected ? const Color(0xFF00E676) : Colors.redAccent,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: (isConnected ? const Color(0xFF00E676) : Colors.redAccent).withValues(alpha: 0.5),
                                          blurRadius: 6,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(ws['name'] ?? '', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                                  const SizedBox(width: 10),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: Colors.white10,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text('${ws['latencyMs']} ms ping', style: const TextStyle(fontSize: 11, color: Colors.white70)),
                                  ),
                                  const Spacer(),
                                  OutlinedButton.icon(
                                    onPressed: () => _syncWorkspace(ws['workspaceId']),
                                    icon: const Icon(Icons.sync, size: 16, color: Color(0xFF00E5FF)),
                                    label: const Text('Sync Workspace', style: TextStyle(color: Color(0xFF00E5FF))),
                                    style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFF00E5FF))),
                                  ),
                                  const SizedBox(width: 10),
                                  ElevatedButton.icon(
                                    onPressed: () {},
                                    icon: const Icon(Icons.terminal, size: 16),
                                    label: const Text('Open Remote Terminal'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF00E5FF),
                                      foregroundColor: Colors.black,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text('SSH: ${ws['username']}@${ws['remoteHost']}:${ws['sshPort']}',
                                  style: const TextStyle(color: Colors.white60, fontSize: 13, fontFamily: 'monospace')),
                              const SizedBox(height: 14),
                              Row(
                                children: [
                                  _buildWorkspaceMetric('RAM Used', '${(ws['memoryUsedMb'] ?? 0) / 1024} GB / ${(ws['memoryTotalMb'] ?? 0) / 1024} GB'),
                                  const SizedBox(width: 24),
                                  _buildWorkspaceMetric('CPU Core Allocation', '${ws['cpuUsagePercent']}%'),
                                  const SizedBox(width: 24),
                                  _buildWorkspaceMetric('Auth Strategy', 'mTLS + Ed25519 Cert'),
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
    );
  }

  Widget _buildWorkspaceMetric(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white38, fontSize: 11)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

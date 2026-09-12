import 'package:flutter/material.dart';
import '../services/virtualization_service.dart';

class VmManagerPage extends StatefulWidget {
  const VmManagerPage({super.key});

  @override
  State<VmManagerPage> createState() => _VmManagerPageState();
}

class _VmManagerPageState extends State<VmManagerPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final VirtualizationService _vmService = VirtualizationService();

  List<VirtualMachineDto> _vms = [];
  List<Map<String, dynamic>> _templates = [];
  bool _isLoading = true;
  String? _selectedVmId;
  VmTelemetryDto? _currentTelemetry;

  // Sandbox form
  String _sandboxCode = '#!/bin/bash\necho "Hello from SWARM OS Ephemeral Sandbox!"\nuname -a\nfree -m';
  String _sandboxLang = 'bash';
  String _sandboxOutput = '';
  bool _isSandboxing = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final vms = await _vmService.getVms();
      final templates = await _vmService.getTemplates();
      setState(() {
        _vms = vms;
        _templates = templates;
        if (_vms.isNotEmpty && _selectedVmId == null) {
          _selectedVmId = _vms.first.id;
        }
      });
      if (_selectedVmId != null) {
        _loadTelemetry(_selectedVmId!);
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadTelemetry(String vmId) async {
    final t = await _vmService.getTelemetry(vmId);
    if (mounted) setState(() => _currentTelemetry = t);
  }

  Future<void> _runSandbox() async {
    setState(() {
      _isSandboxing = true;
      _sandboxOutput = 'Executing inside ephemeral cgroup & OverlayFS scratchpad...';
    });

    try {
      final res = await _vmService.executeSandbox(code: _sandboxCode, language: _sandboxLang);
      setState(() {
        _sandboxOutput = '[EXIT CODE: ${res['exitCode']}] (Execution: ${res['executionTimeMs']}ms | Memory: ${res['memoryPeakMb']}MB)\n\n'
            '=== STDOUT ===\n${res['stdout']}\n\n'
            '=== STDERR ===\n${res['stderr']}';
      });
    } catch (e) {
      setState(() => _sandboxOutput = 'Error: $e');
    } finally {
      setState(() => _isSandboxing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        elevation: 0,
        title: Row(
          children: [
            const Icon(Icons.developer_board, color: Color(0xFF00FF66)),
            const SizedBox(width: 12),
            const Text(
              'SWARM OS · Virtualization & Sandboxing Engine',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.refresh, color: Color(0xFF00E5FF)),
              onPressed: _loadData,
              tooltip: 'Refresh Status',
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF00FF66),
          labelColor: const Color(0xFF00FF66),
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(icon: Icon(Icons.computer), text: 'Virtual Machines'),
            Tab(icon: Icon(Icons.speed), text: 'Resource Telemetry'),
            Tab(icon: Icon(Icons.category), text: 'Prebuilt Templates'),
            Tab(icon: Icon(Icons.security), text: 'Code Sandbox'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF00FF66)))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildVmListTab(),
                _buildTelemetryTab(),
                _buildTemplatesTab(),
                _buildSandboxTab(),
              ],
            ),
    );
  }

  Widget _buildVmListTab() {
    if (_vms.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.laptop_chromebook, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('No Virtual Machines or Containers Provisioned', style: TextStyle(color: Colors.white, fontSize: 16)),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00FF66)),
              icon: const Icon(Icons.add, color: Colors.black),
              label: const Text('Provision from Template', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
              onPressed: () => _tabController.animateTo(2),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _vms.length,
      itemBuilder: (context, index) {
        final vm = _vms[index];
        final isRunning = vm.status == 'Running';

        return Card(
          color: const Color(0xFF161B22),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: isRunning ? const Color(0xFF00FF66).withValues(alpha: 0.5) : Colors.white12),
          ),
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: (isRunning ? const Color(0xFF00FF66) : Colors.grey).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        vm.osType == 'Windows'
                            ? Icons.window
                            : vm.osType == 'MacOS'
                                ? Icons.apple
                                : Icons.terminal,
                        color: isRunning ? const Color(0xFF00FF66) : Colors.grey,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(vm.name, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                          Text('${vm.osType} Guest • ${vm.cpuCores} Cores • ${vm.ramMb} MB RAM • ${vm.diskSizeGb} GB Disk',
                              style: const TextStyle(color: Colors.grey, fontSize: 13)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isRunning ? const Color(0xFF00FF66).withValues(alpha: 0.2) : Colors.red.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        vm.status.toUpperCase(),
                        style: TextStyle(
                          color: isRunning ? const Color(0xFF00FF66) : Colors.redAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Chip(label: Text('SSH: ${vm.sshPort}', style: const TextStyle(fontSize: 11, color: Colors.white70)), backgroundColor: const Color(0xFF21262D)),
                    const SizedBox(width: 6),
                    Chip(label: Text('HTTP: ${vm.httpPort}', style: const TextStyle(fontSize: 11, color: Colors.white70)), backgroundColor: const Color(0xFF21262D)),
                    const SizedBox(width: 6),
                    Chip(label: Text('VNC: ${vm.vncPort}', style: const TextStyle(fontSize: 11, color: Colors.white70)), backgroundColor: const Color(0xFF21262D)),
                    const Spacer(),
                    if (!isRunning)
                      IconButton(
                        icon: const Icon(Icons.play_arrow, color: Color(0xFF00FF66)),
                        tooltip: 'Start VM',
                        onPressed: () async {
                          await _vmService.startVm(vm.id);
                          _loadData();
                        },
                      )
                    else ...[
                      IconButton(
                        icon: const Icon(Icons.pause, color: Colors.amber),
                        tooltip: 'Pause VM',
                        onPressed: () async {
                          await _vmService.pauseVm(vm.id);
                          _loadData();
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.stop, color: Colors.redAccent),
                        tooltip: 'Stop VM',
                        onPressed: () async {
                          await _vmService.stopVm(vm.id);
                          _loadData();
                        },
                      ),
                    ],
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.grey),
                      tooltip: 'Delete VM',
                      onPressed: () async {
                        await _vmService.deleteVm(vm.id);
                        _loadData();
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTelemetryTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Live Hypervisor Resource Monitor', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Real-time procfs & cgroups v2 telemetry streaming from QEMU/KVM supervisor.', style: TextStyle(color: Colors.grey, fontSize: 13)),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _buildGaugeCard(
                  'CPU ALLOCATION',
                  '${_currentTelemetry?.cpuUsagePercent ?? 0.0}%',
                  Icons.memory,
                  const Color(0xFF00FF66),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildGaugeCard(
                  'RAM USAGE',
                  '${_currentTelemetry?.memoryUsedMb ?? 0} MB',
                  Icons.dns,
                  const Color(0xFF00E5FF),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildGaugeCard(
                  'DISK I/O RATE',
                  '${((_currentTelemetry?.diskWriteBytesPerSec ?? 0) / 1024).round()} KB/s',
                  Icons.storage,
                  const Color(0xFFD500F9),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGaugeCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(title, style: TextStyle(color: Colors.grey[400], fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 16),
          Text(value, style: TextStyle(color: color, fontSize: 28, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildTemplatesTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _templates.length,
      itemBuilder: (context, index) {
        final tmpl = _templates[index];

        return Card(
          color: const Color(0xFF161B22),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Colors.white12)),
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.cloud_download, color: Color(0xFF00FF66), size: 36),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tmpl['name'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(tmpl['description'] ?? '', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        children: ((tmpl['tags'] as List?) ?? [])
                            .map((tag) => Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(color: const Color(0xFF21262D), borderRadius: BorderRadius.circular(4)),
                                  child: Text(tag, style: const TextStyle(color: Color(0xFF00E5FF), fontSize: 11)),
                                ))
                            .toList(),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00FF66)),
                  icon: const Icon(Icons.add, color: Colors.black, size: 18),
                  label: const Text('Instantiate', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                  onPressed: () async {
                    await _vmService.instantiateTemplate(tmpl['id'], '${tmpl['name']} (Instance)');
                    _tabController.animateTo(0);
                    _loadData();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSandboxTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Isolated Ephemeral Sandbox', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const Spacer(),
              DropdownButton<String>(
                value: _sandboxLang,
                dropdownColor: const Color(0xFF161B22),
                style: const TextStyle(color: Color(0xFF00FF66)),
                items: const [
                  DropdownMenuItem(value: 'bash', child: Text('Bash Shell')),
                  DropdownMenuItem(value: 'python', child: Text('Python 3.12')),
                  DropdownMenuItem(value: 'dart', child: Text('Dart')),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _sandboxLang = v);
                },
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00FF66)),
                icon: _isSandboxing
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                    : const Icon(Icons.play_arrow, color: Colors.black),
                label: const Text('Execute in Sandbox', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                onPressed: _isSandboxing ? null : _runSandbox,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            flex: 2,
            child: TextField(
              controller: TextEditingController(text: _sandboxCode)..selection = TextSelection.collapsed(offset: _sandboxCode.length),
              onChanged: (v) => _sandboxCode = v,
              maxLines: null,
              expands: true,
              style: const TextStyle(fontFamily: 'monospace', color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFF161B22),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text('Sandboxed Output & Integrity Log', style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Expanded(
            flex: 2,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white12),
              ),
              child: SingleChildScrollView(
                child: Text(
                  _sandboxOutput.isEmpty ? 'Ready for isolated execution...' : _sandboxOutput,
                  style: const TextStyle(fontFamily: 'monospace', color: Color(0xFF00FF66), fontSize: 12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

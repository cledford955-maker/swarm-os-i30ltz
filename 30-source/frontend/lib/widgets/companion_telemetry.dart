// ═══════════════════════════════════════════════════════════════
// Swarm OS — Companion Telemetry Panel
// Real device telemetry for all 4 devices. No mocks.
// Shows CPU, RAM, GPU, disk, battery, network, temps, processes.
// Resource sharing: clipboard, files, notifications across mesh.
// ═══════════════════════════════════════════════════════════════

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../services/telemetry_service.dart';

class CompanionTelemetryPanel extends StatefulWidget {
  const CompanionTelemetryPanel({super.key});

  @override
  State<CompanionTelemetryPanel> createState() => _CompanionTelemetryPanelState();
}

class _CompanionTelemetryPanelState extends State<CompanionTelemetryPanel> with SingleTickerProviderStateMixin {
  final TelemetryService _tel = TelemetryService();
  Map<String, dynamic> _mesh = {}; // ignore: unused_field — set by telemetry fetch
  List<dynamic> _devices = [];
  String? _selectedDeviceId;
  Map<String, dynamic>? _selectedDetail;
  bool _loading = true;
  Timer? _refreshTimer;
  late final TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _loadMesh();
    _refreshTimer = Timer.periodic(const Duration(seconds: 3), (_) => _loadMesh());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadMesh() async {
    try {
      final mesh = await _tel.getMeshSummary();
      if (mounted) {
        setState(() {
          _mesh = mesh;
          _devices = mesh['devices'] ?? [];
          _loading = false;
        });
        if (_selectedDeviceId != null) _loadDeviceDetail(_selectedDeviceId!);
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadDeviceDetail(String id) async {
    final detail = await _tel.getDeviceTelemetry(id);
    if (mounted && detail != null) {
      setState(() => _selectedDetail = detail);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0A0A18),
      child: Column(children: [
        _header(),
        TabBar(
          controller: _tabCtrl,
          labelColor: const Color(0xFF00D4FF),
          unselectedLabelColor: Colors.white24,
          indicatorColor: const Color(0xFF00D4FF),
          indicatorSize: TabBarIndicatorSize.label,
          labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          tabs: const [
            Tab(text: 'DEVICES'),
            Tab(text: 'DETAIL'),
            Tab(text: 'SHARING'),
          ],
        ),
        Expanded(child: TabBarView(
          controller: _tabCtrl,
          children: [_devicesGrid(), _deviceDetail(), _sharingPanel()],
        )),
      ]),
    );
  }

  Widget _header() {
    final online = _devices.where((d) => d['online'] == true).length;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFF1E1E44))),
      ),
      child: Row(children: [
        const Icon(Icons.device_hub, color: Color(0xFF00D4FF), size: 20),
        const SizedBox(width: 10),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Companion · Telemetry', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
          Text('$online/${_devices.length} online', style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 10)),
        ]),
        const Spacer(),
        GestureDetector(
          onTap: () async {
            setState(() => _loading = true);
            final found = await _tel.scanNetwork();
            _loadMesh();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text('Found ${found.length} devices'),
                backgroundColor: const Color(0xFF1A3A5C),
              ));
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF00D4FF).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFF00D4FF).withValues(alpha: 0.2)),
            ),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.radar, color: Color(0xFF00D4FF), size: 13),
              SizedBox(width: 4),
              Text('Scan', style: TextStyle(color: Color(0xFF00D4FF), fontSize: 10, fontWeight: FontWeight.w600)),
            ]),
          ),
        ),
      ]),
    );
  }

  // ─── Tab 1: All Devices ───
  Widget _devicesGrid() {
    if (_loading) return const Center(child: CircularProgressIndicator(color: Color(0xFF00D4FF), strokeWidth: 2));
    if (_devices.isEmpty) {
      return Center(child: Text('No devices connected', style: TextStyle(color: Colors.white.withValues(alpha: 0.2))));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(10),
      itemCount: _devices.length,
      itemBuilder: (ctx, i) => _deviceCard(_devices[i]),
    );
  }

  Widget _deviceCard(Map<String, dynamic> dev) {
    final online = dev['online'] == true;
    final t = dev['telemetry'] as Map<String, dynamic>? ?? {};
    final cpuPct = (t['cpu_percent'] ?? t['percent_total'] ?? 0).toDouble();
    final ramPct = (t['ram_percent'] ?? 0).toDouble();
    final batPct = t['battery_percent'];
    final type = dev['device_type'] ?? 'unknown';
    final selected = _selectedDeviceId == dev['device_id'];

    IconData typeIcon;
    switch (type) {
      case 'phone': typeIcon = Icons.phone_android; break;
      case 'laptop': typeIcon = Icons.laptop; break;
      case 'tablet': typeIcon = Icons.tablet; break;
      case 'server': typeIcon = Icons.dns; break;
      default: typeIcon = Icons.computer;
    }

    return GestureDetector(
      onTap: () {
        setState(() => _selectedDeviceId = dev['device_id']);
        _loadDeviceDetail(dev['device_id']);
        _tabCtrl.animateTo(1);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF151535) : const Color(0xFF0E0E22),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? const Color(0xFF00D4FF).withValues(alpha: 0.3)
                : online ? Colors.white.withValues(alpha: 0.06) : Colors.white.withValues(alpha: 0.02),
          ),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(typeIcon, color: online ? const Color(0xFF00D4FF) : Colors.white12, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(dev['hostname'] ?? 'Unknown', style: TextStyle(
                color: online ? Colors.white : Colors.white30, fontSize: 13, fontWeight: FontWeight.w600)),
              Text('${dev['platform'] ?? ''} · ${dev['ip'] ?? ''}',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.2), fontSize: 10)),
            ])),
            Container(
              width: 8, height: 8,
              decoration: BoxDecoration(
                color: online ? const Color(0xFF51CF66) : const Color(0xFF555555),
                shape: BoxShape.circle,
              ),
            ),
          ]),
          if (online && t.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(children: [
              _miniGauge('CPU', cpuPct, const Color(0xFF00D4FF)),
              const SizedBox(width: 8),
              _miniGauge('RAM', ramPct, const Color(0xFFDA77F2)),
              if (batPct != null) ...[
                const SizedBox(width: 8),
                _miniGauge('BAT', batPct.toDouble(), const Color(0xFF51CF66)),
              ],
            ]),
          ],
        ]),
      ),
    );
  }

  Widget _miniGauge(String label, double pct, Color color) {
    return Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 9, fontWeight: FontWeight.w600)),
        const Spacer(),
        Text('${pct.toStringAsFixed(1)}%', style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w700)),
      ]),
      const SizedBox(height: 3),
      ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: LinearProgressIndicator(
          value: (pct / 100).clamp(0, 1),
          backgroundColor: color.withValues(alpha: 0.08),
          valueColor: AlwaysStoppedAnimation(color.withValues(alpha: 0.7)),
          minHeight: 4,
        ),
      ),
    ]));
  }

  // ─── Tab 2: Device Detail ───
  Widget _deviceDetail() {
    if (_selectedDeviceId == null) {
      return Center(child: Text('Select a device', style: TextStyle(color: Colors.white.withValues(alpha: 0.15))));
    }
    if (_selectedDetail == null) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF00D4FF), strokeWidth: 2));
    }

    final dev = _selectedDetail!;
    final t = dev['telemetry'] as Map<String, dynamic>? ?? {};

    return ListView(padding: const EdgeInsets.all(12), children: [
      // Header
      _sectionTitle('${dev['hostname']} · ${dev['device_type']}'),
      Text('IP: ${dev['ip']}  Platform: ${dev['platform']}',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.2), fontSize: 10)),
      const SizedBox(height: 12),

      // CPU
      if (t.containsKey('cpu_percent') || t.containsKey('cpu'))
        _buildCpuSection(t),

      // RAM
      if (t.containsKey('ram_percent') || t.containsKey('memory'))
        _buildRamSection(t),

      // GPU
      if (t.containsKey('gpu') && (t['gpu'] as List).isNotEmpty)
        _buildGpuSection(t['gpu'] as List),

      // Disk
      if (t.containsKey('disk') && (t['disk'] as List).isNotEmpty)
        _buildDiskSection(t['disk'] as List),

      // Battery
      if (t.containsKey('battery') || t.containsKey('battery_percent'))
        _buildBatterySection(t),

      // Network
      if (t.containsKey('network') || t.containsKey('net_sent_mb'))
        _buildNetSection(t),

      // Processes
      if (t.containsKey('processes') && (t['processes'] as List).isNotEmpty)
        _buildProcessSection(t['processes'] as List),
    ]);
  }

  Widget _sectionTitle(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8, top: 4),
    child: Text(text, style: const TextStyle(color: Color(0xFF00D4FF), fontSize: 13, fontWeight: FontWeight.w700)),
  );

  Widget _metric(String label, String value, {Color? color}) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(children: [
      Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: 11)),
      const Spacer(),
      Text(value, style: TextStyle(color: color ?? Colors.white.withValues(alpha: 0.7), fontSize: 11, fontWeight: FontWeight.w600, fontFamily: 'monospace')),
    ]),
  );

  Widget _bar(String label, double pct, Color color) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 10)),
        const Spacer(),
        Text('${pct.toStringAsFixed(1)}%', style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700)),
      ]),
      const SizedBox(height: 2),
      ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: LinearProgressIndicator(
          value: (pct / 100).clamp(0, 1),
          backgroundColor: color.withValues(alpha: 0.06),
          valueColor: AlwaysStoppedAnimation(color),
          minHeight: 6,
        ),
      ),
    ]),
  );

  Widget _buildCpuSection(Map<String, dynamic> t) {
    final cpu = t['cpu'] as Map<String, dynamic>? ?? t;
    final pct = (cpu['percent_total'] ?? cpu['cpu_percent'] ?? 0).toDouble();
    final perCore = (cpu['percent_per_core'] as List?)?.map((e) => (e as num).toDouble()).toList() ?? [];

    return _card([
      _sectionTitle('CPU'),
      if (cpu['model'] != null) _metric('Model', cpu['model']),
      _bar('Usage', pct, _pctColor(pct)),
      if (cpu['freq_current_mhz'] != null) _metric('Frequency', '${cpu['freq_current_mhz']} MHz'),
      if (cpu['physical_cores'] != null) _metric('Cores', '${cpu['physical_cores']}P / ${cpu['logical_cores'] ?? ''}L'),
      if (cpu['load_avg_1m'] != null) _metric('Load (1/5/15m)', '${_f(cpu['load_avg_1m'])} / ${_f(cpu['load_avg_5m'])} / ${_f(cpu['load_avg_15m'])}'),
      if (perCore.isNotEmpty) ...[
        const SizedBox(height: 4),
        SizedBox(height: 30, child: Row(
          children: perCore.asMap().entries.map((e) {
            return Expanded(child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 1),
              child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                Expanded(child: Align(
                  alignment: Alignment.bottomCenter,
                  child: FractionallySizedBox(
                    heightFactor: (e.value / 100).clamp(0, 1),
                    child: Container(
                      decoration: BoxDecoration(
                        color: _pctColor(e.value),
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ),
                )),
              ]),
            ));
          }).toList(),
        )),
      ],
    ]);
  }

  Widget _buildRamSection(Map<String, dynamic> t) {
    final mem = t['memory'] as Map<String, dynamic>? ?? t;
    final pct = (mem['ram_percent'] ?? 0).toDouble();
    return _card([
      _sectionTitle('Memory'),
      _bar('RAM', pct, const Color(0xFFDA77F2)),
      _metric('Used', '${mem['ram_used_gb'] ?? '?'} GB / ${mem['ram_total_gb'] ?? '?'} GB'),
      if (mem['swap_percent'] != null) _bar('Swap', (mem['swap_percent'] as num).toDouble(), const Color(0xFFFFD43B)),
    ]);
  }

  Widget _buildGpuSection(List gpus) {
    return _card([
      _sectionTitle('GPU'),
      ...gpus.map<Widget>((g) {
        final util = (g['gpu_util_percent'] ?? 0).toDouble();
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _metric(g['vendor']?.toString().toUpperCase() ?? 'GPU', g['name'] ?? ''),
          _bar('Utilization', util, const Color(0xFF51CF66)),
          if (g['mem_used_mb'] != null) _metric('VRAM', '${_f(g['mem_used_mb'])} / ${_f(g['mem_total_mb'])} MB'),
          if (g['temp_c'] != null) _metric('Temp', '${g['temp_c']}°C', color: _tempColor((g['temp_c'] as num).toDouble())),
          if (g['power_draw_w'] != null) _metric('Power', '${_f(g['power_draw_w'])} / ${_f(g['power_limit_w'])} W'),
          if (g['fan_speed_percent'] != null) _metric('Fan', '${_f(g['fan_speed_percent'])}%'),
          const SizedBox(height: 6),
        ]);
      }),
    ]);
  }

  Widget _buildDiskSection(List disks) {
    return _card([
      _sectionTitle('Disks'),
      ...disks.map<Widget>((d) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _metric(d['mountpoint'] ?? '', '${d['device'] ?? ''}  ${d['fstype'] ?? ''}'),
        _bar('${d['used_gb']}/${d['total_gb']} GB', (d['percent'] ?? 0).toDouble(), const Color(0xFFFFD43B)),
        const SizedBox(height: 4),
      ])),
    ]);
  }

  Widget _buildBatterySection(Map<String, dynamic> t) {
    final bat = t['battery'] as Map<String, dynamic>? ?? t;
    final pct = (bat['percent'] ?? bat['battery_percent'])?.toDouble();
    if (pct == null) return const SizedBox.shrink();
    final plugged = bat['plugged_in'] == true;
    return _card([
      _sectionTitle('Battery'),
      _bar(plugged ? 'Charging' : 'On battery', pct, pct > 20 ? const Color(0xFF51CF66) : const Color(0xFFFF6B6B)),
      if (bat['time_left_str'] != null) _metric('Remaining', bat['time_left_str']),
    ]);
  }

  Widget _buildNetSection(Map<String, dynamic> t) {
    final net = t['network'] as Map<String, dynamic>? ?? t;
    return _card([
      _sectionTitle('Network'),
      _metric('Sent', '${net['sent_mb'] ?? net['net_sent_mb'] ?? '?'} MB'),
      _metric('Received', '${net['recv_mb'] ?? net['net_recv_mb'] ?? '?'} MB'),
      if (net['local_ip'] != null) _metric('Local IP', net['local_ip']),
      if (net['connections_established'] != null) _metric('Connections', '${net['connections_established']}'),
    ]);
  }

  Widget _buildProcessSection(List procs) {
    return _card([
      _sectionTitle('Top Processes'),
      ...procs.take(8).map((p) => Padding(
        padding: const EdgeInsets.only(bottom: 3),
        child: Row(children: [
          SizedBox(width: 40, child: Text('${p['pid']}', style: TextStyle(color: Colors.white.withValues(alpha: 0.2), fontSize: 9, fontFamily: 'monospace'))),
          Expanded(child: Text(p['name'] ?? '', style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 10), overflow: TextOverflow.ellipsis)),
          SizedBox(width: 50, child: Text('${p['cpu_percent']}%', style: TextStyle(color: _pctColor((p['cpu_percent'] ?? 0).toDouble()), fontSize: 10, fontFamily: 'monospace'), textAlign: TextAlign.right)),
          SizedBox(width: 50, child: Text('${p['mem_percent']}%', style: TextStyle(color: const Color(0xFFDA77F2).withValues(alpha: 0.7), fontSize: 10, fontFamily: 'monospace'), textAlign: TextAlign.right)),
        ]),
      )),
    ]);
  }

  Widget _card(List<Widget> children) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFF0E0E22),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
  );

  // ─── Tab 3: Resource Sharing ───
  Widget _sharingPanel() {
    return ListView(padding: const EdgeInsets.all(12), children: [
      _sectionTitle('Shared Clipboard'),
      _card([
        GestureDetector(
          onTap: () async {
            final text = await _tel.getSharedClipboard();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(text.isEmpty ? 'Clipboard empty' : 'Clipboard: ${text.substring(0, min(50, text.length))}...'),
                backgroundColor: const Color(0xFF1A3A5C),
              ));
            }
          },
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: const Color(0xFF12122A), borderRadius: BorderRadius.circular(6)),
            child: const Row(children: [
              Icon(Icons.content_paste, color: Color(0xFF74C0FC), size: 16),
              SizedBox(width: 8),
              Expanded(child: Text('Tap to view shared clipboard', style: TextStyle(color: Colors.white38, fontSize: 11))),
              Icon(Icons.arrow_forward_ios, color: Colors.white12, size: 12),
            ]),
          ),
        ),
      ]),

      _sectionTitle('Shared Files'),
      FutureBuilder(
        future: _tel.getSharedFiles(),
        builder: (_, snap) {
          if (!snap.hasData || (snap.data as List).isEmpty) {
            return _card([Text('No shared files', style: TextStyle(color: Colors.white.withValues(alpha: 0.15), fontSize: 11))]);
          }
          return _card((snap.data as List).map((f) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(children: [
              const Icon(Icons.insert_drive_file, color: Color(0xFF74C0FC), size: 14),
              const SizedBox(width: 8),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(f['filename'] ?? '', style: const TextStyle(color: Colors.white70, fontSize: 11)),
                Text('From: ${f['from_device'] ?? ''}', style: TextStyle(color: Colors.white.withValues(alpha: 0.2), fontSize: 9)),
              ])),
            ]),
          )).toList());
        },
      ),

      _sectionTitle('Send Notification'),
      _card([
        ..._devices.where((d) => d['device_id'] != _devices.firstOrNull?['device_id']).map((d) =>
          GestureDetector(
            onTap: () => _tel.sendNotification(d['device_id'], 'Swarm OS', 'Ping from companion', _devices.first['device_id'] ?? ''),
            child: Container(
              margin: const EdgeInsets.only(bottom: 4),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: const Color(0xFF12122A), borderRadius: BorderRadius.circular(6)),
              child: Row(children: [
                const Icon(Icons.notifications_active, color: Color(0xFFFFD43B), size: 14),
                const SizedBox(width: 8),
                Text('Ping ${d['hostname']}', style: const TextStyle(color: Colors.white54, fontSize: 11)),
              ]),
            ),
          ),
        ),
      ]),
    ]);
  }

  Color _pctColor(double pct) {
    if (pct > 90) return const Color(0xFFFF6B6B);
    if (pct > 70) return const Color(0xFFFFD43B);
    if (pct > 50) return const Color(0xFF74C0FC);
    return const Color(0xFF51CF66);
  }

  Color _tempColor(double temp) {
    if (temp > 85) return const Color(0xFFFF6B6B);
    if (temp > 70) return const Color(0xFFFFD43B);
    return const Color(0xFF51CF66);
  }

  String _f(dynamic val) => val == null ? '?' : (val is double ? val.toStringAsFixed(1) : val.toString());
}
import 'package:flutter/material.dart';
import '../services/advanced_ecosystem_service.dart';
import '../theme/swarm_text_styles.dart';

class DeviceMirrorPage extends StatefulWidget {
  const DeviceMirrorPage({super.key});

  @override
  State<DeviceMirrorPage> createState() => _DeviceMirrorPageState();
}

class _DeviceMirrorPageState extends State<DeviceMirrorPage> {
  final AdvancedEcosystemService _service = AdvancedEcosystemService();
  Map<String, dynamic> _stats = {};
  bool _isMirroring = false;
  bool _isLoading = true;
  String? _error;
  // Real session id returned by the server. Previously the stop call used a
  // hardcoded 'mirror-session-1', which only ever matched because the mocked
  // start response always returned that literal.
  String? _sessionId;

  final TextEditingController _ipCtrl = TextEditingController(text: '192.168.1.105');
  final TextEditingController _portCtrl = TextEditingController(text: '5555');
  bool _isWireless = false;

  @override
  void initState() {
    super.initState();
    _loadHardwareStats();
  }

  Future<void> _loadHardwareStats() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final stats = await _service.getHardwarePerformanceStats();
      if (!mounted) return;
      setState(() {
        _stats = stats;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _stats = {};
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleMirror() async {
    try {
      if (_isMirroring) {
        final id = _sessionId;
        if (id == null) {
          setState(() => _isMirroring = false);
          return;
        }
        await _service.stopScreenMirror(id);
        if (!mounted) return;
        setState(() {
          _isMirroring = false;
          _sessionId = null;
        });
      } else {
        final res = await _service.startScreenMirror(
          deviceSerial: _isWireless ? '' : 'USB-DEVICE',
          isWireless: _isWireless,
          ipAddress: _ipCtrl.text,
          port: int.tryParse(_portCtrl.text) ?? 5555,
        );
        if (!mounted) return;
        setState(() {
          _isMirroring = true;
          _sessionId = res['sessionId'] as String?;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Mirroring session ${_sessionId ?? ''} started.')),
        );
      }
    } catch (e) {
      // Do not flip the toggle to "mirroring" when the call failed.
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Mirror action failed: $e'), backgroundColor: const Color(0xFF7F1D1D)),
      );
    }
  }

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
              child: const Icon(Icons.screen_share, color: Color(0xFF00E5FF), size: 22),
            ),
            const SizedBox(width: 12),
            Text('SCREEN MIRRORING & HARDWARE STATS', style: SwarmTextStyles.title.copyWith(fontSize: 16)),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh, color: Color(0xFF00E5FF)), onPressed: _loadHardwareStats),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF00E5FF)))
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.sensors_off, color: Color(0xFFEF4444), size: 40),
                    const SizedBox(height: 12),
                    const Text('Hardware stats unavailable', style: TextStyle(fontSize: 14, color: Colors.white)),
                    const SizedBox(height: 6),
                    Text(_error!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _loadHardwareStats,
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('RETRY'),
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00E5FF), foregroundColor: Colors.black),
                    ),
                  ],
                ),
              ),
            )
          : Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left side: Screen Mirror Controller
                  Expanded(
                    flex: 6,
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F141F),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFF1E2838)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text('scrcpy ULTRA LOW-LATENCY MIRRORING', style: SwarmTextStyles.title.copyWith(fontSize: 14)),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _isMirroring ? const Color(0xFF00E676).withValues(alpha: 0.15) : Colors.white10,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  _isMirroring ? '● STREAMING (60 FPS)' : 'STANDBY',
                                  style: TextStyle(
                                    color: _isMirroring ? const Color(0xFF00E676) : Colors.white60,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              ChoiceChip(
                                label: const Text('USB Direct'),
                                selected: !_isWireless,
                                onSelected: (val) => setState(() => _isWireless = !val),
                              ),
                              const SizedBox(width: 10),
                              ChoiceChip(
                                label: const Text('Wireless ADB (Wi-Fi)'),
                                selected: _isWireless,
                                onSelected: (val) => setState(() => _isWireless = val),
                              ),
                            ],
                          ),
                          if (_isWireless) ...[
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _ipCtrl,
                                    decoration: const InputDecoration(labelText: 'Device IP', isDense: true),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                SizedBox(
                                  width: 100,
                                  child: TextField(
                                    controller: _portCtrl,
                                    decoration: const InputDecoration(labelText: 'Port', isDense: true),
                                  ),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 20),
                          Center(
                            child: Container(
                              height: 380,
                              width: 240,
                              decoration: BoxDecoration(
                                color: Colors.black,
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.5), width: 2),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF00E5FF).withValues(alpha: 0.15),
                                    blurRadius: 20,
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      _isMirroring ? Icons.phone_android : Icons.mobile_off,
                                      size: 56,
                                      color: _isMirroring ? const Color(0xFF00E5FF) : Colors.white24,
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      _isMirroring ? 'Mirror Active\nAudio Forwarded' : 'No Active Session',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(color: _isMirroring ? Colors.white : Colors.white38),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const Spacer(),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _toggleMirror,
                              icon: Icon(_isMirroring ? Icons.stop : Icons.play_arrow),
                              label: Text(_isMirroring ? 'STOP MIRRORING' : 'LAUNCH LOW-LATENCY MIRROR'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _isMirroring ? Colors.redAccent : const Color(0xFF00E5FF),
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),

                  // Right side: Hardware Performance Stats
                  Expanded(
                    flex: 5,
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F141F),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFF1E2838)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('HARDWARE PERFORMANCE & SENSORS', style: SwarmTextStyles.title.copyWith(fontSize: 14)),
                          const SizedBox(height: 16),
                          _buildSensorTile('CPU Core Frequency', '${_stats['cpuFrequencyGhz']} GHz', Icons.speed, const Color(0xFF00E5FF)),
                          _buildSensorTile('CPU Package Temperature', '${_stats['cpuTemperatureCelsius']} °C', Icons.thermostat,
                              (_stats['isThermalThrottling'] == true) ? Colors.redAccent : const Color(0xFF00E676)),
                          _buildSensorTile('GPU / ROCm Core Usage', '${_stats['gpuCoreUsagePercent']}%', Icons.memory, const Color(0xFFD500F9)),
                          _buildSensorTile('NVIDIA Tensor Core Load', '${_stats['tensorCoreUtilization']}%', Icons.auto_awesome, Colors.amber),
                          _buildSensorTile('VRAM Allocation', '${_stats['gpuMemoryUsedGb']} GB / ${_stats['gpuMemoryTotalGb']} GB', Icons.storage, const Color(0xFF00E5FF)),
                          _buildSensorTile('Thermal Throttle Status', (_stats['isThermalThrottling'] == true) ? 'THROTTLING ACTIVE' : 'OPTIMAL COOLING', Icons.ac_unit,
                              (_stats['isThermalThrottling'] == true) ? Colors.redAccent : const Color(0xFF00E676)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSensorTile(String title, String value, IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0D14),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 12),
          Text(title, style: const TextStyle(color: Colors.white70, fontSize: 13)),
          const Spacer(),
          Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
        ],
      ),
    );
  }
}

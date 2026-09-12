import 'package:flutter/material.dart';
import '../services/advanced_ecosystem_service.dart';
import '../theme/swarm_text_styles.dart';

class SecurityAuditPage extends StatefulWidget {
  const SecurityAuditPage({super.key});

  @override
  State<SecurityAuditPage> createState() => _SecurityAuditPageState();
}

class _SecurityAuditPageState extends State<SecurityAuditPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final AdvancedEcosystemService _service = AdvancedEcosystemService();

  List<dynamic> _auditLogs = [];
  List<dynamic> _verifiedDevs = [];
  Map<String, dynamic>? _lastScan;
  bool _isScanning = false;
  bool _isLoading = true;
  String? _error;
  String? _scanError;

  final TextEditingController _packagePathCtrl = TextEditingController(text: '/opt/swarm_os/data/flutter_assets/app.apk');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadSecurityData();
  }

  Future<void> _loadSecurityData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final logs = await _service.getAuditLogs();
      final devs = await _service.getVerifiedDevelopers();
      if (!mounted) return;
      setState(() {
        _auditLogs = logs;
        _verifiedDevs = devs;
        _isLoading = false;
      });
    } catch (e) {
      // No invented audit trail and no invented "verified" developers: an
      // empty list with a visible error is the only honest outcome here.
      if (!mounted) return;
      setState(() {
        _auditLogs = [];
        _verifiedDevs = [];
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _runMalwareScan() async {
    setState(() {
      _isScanning = true;
      _scanError = null;
    });
    try {
      final result = await _service.scanPackage(_packagePathCtrl.text);
      if (!mounted) return;
      setState(() {
        _lastScan = result;
        _isScanning = false;
      });
      _loadSecurityData(); // Refresh audit logs
    } catch (e) {
      // Never present a verdict that wasn't produced by an actual scan.
      if (!mounted) return;
      setState(() {
        _lastScan = null;
        _scanError = 'Scan did not run: $e';
        _isScanning = false;
      });
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
                color: const Color(0xFF00E676).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.security, color: Color(0xFF00E676), size: 22),
            ),
            const SizedBox(width: 12),
            Text('SECURITY, AUDIT LOGS & MALWARE SCANNER', style: SwarmTextStyles.title.copyWith(fontSize: 16)),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF00E676),
          labelColor: const Color(0xFF00E676),
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(icon: Icon(Icons.bug_report), text: 'APK & Package Scanner'),
            Tab(icon: Icon(Icons.receipt_long), text: 'Chained Audit Logs'),
            Tab(icon: Icon(Icons.verified_user), text: 'Verified Developer Identities'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF00E676)))
          : Column(
            children: [
              if (_error != null)
                Container(
                  width: double.infinity,
                  color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Audit log and verified-developer lists are empty because LucyServer is unreachable — $_error',
                          style: const TextStyle(fontSize: 11, color: Color(0xFFFCA5A5)),
                        ),
                      ),
                      TextButton(onPressed: _loadSecurityData, child: const Text('RETRY', style: TextStyle(fontSize: 11))),
                    ],
                  ),
                ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildMalwareScannerTab(),
                    _buildAuditLogsTab(),
                    _buildVerifiedDevsTab(),
                  ],
                ),
              ),
            ],
          ),
    );
  }

  Widget _buildMalwareScannerTab() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('STATIC VULNERABILITY & DANGEROUS PERMISSION AUDITOR', style: SwarmTextStyles.title.copyWith(fontSize: 14)),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _packagePathCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Target Package Path (.apk or .swarmext archive)',
                    isDense: true,
                    prefixIcon: Icon(Icons.file_present),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              ElevatedButton.icon(
                onPressed: _isScanning ? null : _runMalwareScan,
                icon: _isScanning
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.search),
                label: const Text('SCAN PACKAGE'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00E676),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (_scanError != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.gpp_maybe, color: Color(0xFFEF4444), size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '$_scanError\n\nNo verdict is shown because no scan completed. Treat this package as unknown, not clean.',
                      style: const TextStyle(fontSize: 11, color: Color(0xFFFCA5A5)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
          if (_lastScan != null) ...[
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF0F141F),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF00E676).withValues(alpha: 0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.check_circle, color: Color(0xFF00E676), size: 24),
                      const SizedBox(width: 10),
                      Text('VERDICT: ${_lastScan!['verdict']}',
                          style: const TextStyle(color: Color(0xFF00E676), fontWeight: FontWeight.bold, fontSize: 16)),
                      const Spacer(),
                      Text('Threat Score: ${_lastScan!['threatScore']} / 100', style: const TextStyle(color: Colors.white70)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text('SHA-256 Digest: ${_lastScan!['sha256Hash']}',
                      style: const TextStyle(fontFamily: 'monospace', color: Colors.white60, fontSize: 12)),
                  const Divider(height: 24, color: Colors.white12),
                  const Text('Dangerous Android Permissions Audited:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: ((_lastScan!['dangerousPermissionsDetected'] as List?) ?? []).map((perm) {
                      return Chip(
                        backgroundColor: Colors.amber.withValues(alpha: 0.15),
                        label: Text(perm.toString(), style: const TextStyle(color: Colors.amber, fontSize: 11)),
                        side: const BorderSide(color: Colors.amber),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAuditLogsTab() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('IMMUTABLE CRYPTOGRAPHIC AUDIT TRAIL (SHA-256 CHAINED)', style: SwarmTextStyles.title.copyWith(fontSize: 14)),
              const Spacer(),
              const Icon(Icons.link, color: Color(0xFF00E5FF), size: 18),
              const SizedBox(width: 6),
              const Text('Chained Block Integrity Verified', style: TextStyle(color: Color(0xFF00E5FF), fontSize: 12)),
            ],
          ),
          const SizedBox(height: 14),
          Expanded(
            child: ListView.builder(
              itemCount: _auditLogs.length,
              itemBuilder: (context, index) {
                final log = _auditLogs[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F141F),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF1E2838)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00E5FF).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(log['action'] ?? '', style: const TextStyle(color: Color(0xFF00E5FF), fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${log['principal']} • ${log['resource']}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                            Text(log['details'] ?? '', style: const TextStyle(color: Colors.white60, fontSize: 12)),
                          ],
                        ),
                      ),
                      Text(log['entryHash']?.toString().substring(0, 12) ?? '', style: const TextStyle(fontFamily: 'monospace', color: Colors.white38, fontSize: 11)),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerifiedDevsTab() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: ListView.builder(
        itemCount: _verifiedDevs.length,
        itemBuilder: (context, index) {
          final dev = _verifiedDevs[index];
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF0F141F),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF1E2838)),
            ),
            child: Row(
              children: [
                const Icon(Icons.verified, color: Color(0xFF00E5FF), size: 28),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(dev['commonName'] ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                      Text('${dev['organization']} • Tier: ${dev['verificationTier']}', style: const TextStyle(color: Colors.white60, fontSize: 12)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00E676).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text('ACTIVE CERTIFICATE', style: TextStyle(color: Color(0xFF00E676), fontWeight: FontWeight.bold, fontSize: 11)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

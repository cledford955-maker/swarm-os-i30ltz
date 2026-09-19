import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../services/install_service.dart';
import '../services/swarm_config.dart';

enum _InstallPhase { pickDisk, running, success, failed }

class InstallSwarmOsPage extends StatefulWidget {
  const InstallSwarmOsPage({super.key});

  @override
  State<InstallSwarmOsPage> createState() => _InstallSwarmOsPageState();
}

class _InstallSwarmOsPageState extends State<InstallSwarmOsPage> {
  final InstallService _service = InstallService();
  final ScrollController _logScroll = ScrollController();
  final TextEditingController _confirmController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _password2Controller = TextEditingController();

  bool _loadingDisks = true;
  String? _loadError;
  List<InstallDisk> _disks = [];
  InstallDisk? _selected;

  _InstallPhase _phase = _InstallPhase.pickDisk;
  final List<String> _log = [];
  WebSocket? _socket;

  @override
  void initState() {
    super.initState();
    _loadDisks();
  }

  @override
  void dispose() {
    _socket?.close();
    _logScroll.dispose();
    _confirmController.dispose();
    _passwordController.dispose();
    _password2Controller.dispose();
    super.dispose();
  }

  Future<void> _loadDisks() async {
    setState(() {
      _loadingDisks = true;
      _loadError = null;
    });
    try {
      final disks = await _service.listDisks();
      setState(() {
        _disks = disks;
        _loadingDisks = false;
      });
    } catch (e) {
      setState(() {
        _loadError = '$e';
        _loadingDisks = false;
      });
    }
  }

  bool get _confirmMatches => _selected != null && _confirmController.text.trim() == _selected!.path;
  bool get _passwordsOk =>
      _passwordController.text.isNotEmpty && _passwordController.text == _password2Controller.text;
  bool get _canStart => _selected != null && _selected!.partitionsReady && _confirmMatches && _passwordsOk;

  void _appendLog(String chunk) {
    setState(() => _log.add(chunk));
    // Auto-scroll after the frame renders the new line.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_logScroll.hasClients) {
        _logScroll.animateTo(
          _logScroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _startInstall() async {
    if (!_canStart) return;
    setState(() {
      _phase = _InstallPhase.running;
      _log.clear();
    });

    final joined = StringBuffer();
    try {
      final socket = await _service.startInstall(
        disk: _selected!.path,
        password: _passwordController.text,
        onLine: (chunk) {
          joined.write(chunk);
          _appendLog(chunk);
        },
        onDone: () {
          if (!mounted) return;
          final full = joined.toString();
          setState(() {
            _phase = full.contains('INSTALLED SUCCESSFULLY') ? _InstallPhase.success : _InstallPhase.failed;
          });
        },
      );
      _socket = socket;
    } catch (e) {
      _appendLog('\nCould not start install session: $e\n');
      setState(() => _phase = _InstallPhase.failed);
    }
  }

  Future<void> _reboot() async {
    try {
      await http.post(
        Uri.parse('${SwarmConfig.httpBase}/api/run_command'),
        headers: SwarmConfig.authHeaders,
        body: jsonEncode({'command': 'systemctl reboot'}),
      );
    } catch (_) {
      // Best-effort — if this fails the operator can still reboot manually.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        elevation: 0,
        title: const Row(
          children: [
            Icon(Icons.install_desktop, color: Color(0xFFFFD54F)),
            SizedBox(width: 12),
            Text('Install SWARM OS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: switch (_phase) {
          _InstallPhase.pickDisk => _buildSetup(),
          _InstallPhase.running => _buildLog(running: true),
          _InstallPhase.success => _buildResult(success: true),
          _InstallPhase.failed => _buildResult(success: false),
        },
      ),
    );
  }

  Widget _buildSetup() {
    if (_loadingDisks) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFFFD54F)));
    }
    if (_loadError != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
            const SizedBox(height: 12),
            Text(_loadError!, style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _loadDisks, child: const Text('Retry')),
          ],
        ),
      );
    }
    if (_disks.isEmpty) {
      return const Center(
        child: Text('No candidate disks found.', style: TextStyle(color: Colors.white70)),
      );
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('1. Choose the target disk', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          const Text(
            'This is the same safety bar as the terminal installer — nothing is touched until you type the exact disk path below.',
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
          const SizedBox(height: 16),
          ..._disks.map(_buildDiskCard),
          if (_selected != null) ...[
            const SizedBox(height: 24),
            const Divider(color: Colors.white12),
            const SizedBox(height: 16),
            if (!_selected!.partitionsReady)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
                ),
                child: Text(
                  '${_selected!.path} has no EFI/ROOT partitions yet. Partition it first with your own '
                  'GUI partitioning tool (GPT: ~512MB FAT32 EFI + rest btrfs ROOT), then come back here.',
                  style: const TextStyle(color: Colors.orangeAccent, fontSize: 13),
                ),
              )
            else ...[
              Text('2. Type the disk path to confirm: ${_selected!.path}',
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextField(
                controller: _confirmController,
                onChanged: (_) => setState(() {}),
                style: const TextStyle(color: Colors.white, fontFamily: 'monospace'),
                decoration: InputDecoration(
                  hintText: _selected!.path,
                  hintStyle: const TextStyle(color: Colors.white24),
                  filled: true,
                  fillColor: const Color(0xFF161B22),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 24),
              const Text('3. Set a password for the "i30ltz" account',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              const Text('Used for sudo and terminal commands on the installed system.',
                  style: TextStyle(color: Colors.grey, fontSize: 13)),
              const SizedBox(height: 8),
              TextField(
                controller: _passwordController,
                obscureText: true,
                onChanged: (_) => setState(() {}),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Password',
                  hintStyle: const TextStyle(color: Colors.white24),
                  filled: true,
                  fillColor: const Color(0xFF161B22),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _password2Controller,
                obscureText: true,
                onChanged: (_) => setState(() {}),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Confirm password',
                  hintStyle: const TextStyle(color: Colors.white24),
                  filled: true,
                  fillColor: const Color(0xFF161B22),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                  errorText: _password2Controller.text.isNotEmpty && !_passwordsOk ? "Passwords don't match" : null,
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.4)),
                ),
                child: Text(
                  'WARNING: ALL DATA ON ${_selected!.path} WILL BE ERASED.',
                  style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _canStart ? Colors.redAccent : Colors.grey.shade800,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  icon: const Icon(Icons.warning_amber_rounded, color: Colors.white),
                  label: const Text('Erase & Install SWARM OS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  onPressed: _canStart ? _startInstall : null,
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildDiskCard(InstallDisk d) {
    final isSelected = _selected?.path == d.path;
    return Card(
      color: isSelected ? const Color(0xFF21262D) : const Color(0xFF161B22),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: isSelected ? const Color(0xFFFFD54F) : Colors.white12),
      ),
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(Icons.storage, color: d.hasLuks ? Colors.orangeAccent : Colors.white70),
        title: Text(d.path, style: const TextStyle(color: Colors.white, fontFamily: 'monospace', fontWeight: FontWeight.bold)),
        subtitle: Text(
          '${d.sizeHuman}${d.model.isNotEmpty ? ' • ${d.model}' : ''}'
          '${d.hasLuks ? ' • contains an encrypted partition' : ''}',
          style: TextStyle(color: d.hasLuks ? Colors.orangeAccent : Colors.grey, fontSize: 12),
        ),
        trailing: d.partitionsReady
            ? const Chip(label: Text('Ready', style: TextStyle(fontSize: 11)), backgroundColor: Color(0xFF1B4332))
            : const Chip(label: Text('Needs partitions', style: TextStyle(fontSize: 11)), backgroundColor: Color(0xFF4D3B0F)),
        onTap: () => setState(() {
          _selected = d;
          _confirmController.clear();
        }),
      ),
    );
  }

  Widget _buildLog({required bool running}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (running) const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFFFD54F))),
            if (running) const SizedBox(width: 12),
            Text(
              running ? 'Installing to ${_selected?.path}...' : 'Install log',
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.white12)),
            child: SingleChildScrollView(
              controller: _logScroll,
              child: SelectableText(
                _log.isEmpty ? 'Waiting for output...' : _log.join(),
                style: const TextStyle(fontFamily: 'monospace', color: Color(0xFF00FF66), fontSize: 12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildResult({required bool success}) {
    return Column(
      children: [
        Expanded(child: _buildLog(running: false)),
        const SizedBox(height: 16),
        Row(
          children: [
            Icon(success ? Icons.check_circle : Icons.error, color: success ? const Color(0xFF00FF66) : Colors.redAccent, size: 28),
            const SizedBox(width: 12),
            Text(
              success ? 'Installed successfully' : 'Install failed — see the log above',
              style: TextStyle(color: success ? const Color(0xFF00FF66) : Colors.redAccent, fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            if (success)
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00FF66)),
                icon: const Icon(Icons.restart_alt, color: Colors.black),
                label: const Text('Reboot Now', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                onPressed: _reboot,
              ),
            if (!success) ...[
              const SizedBox(width: 0),
              ElevatedButton(
                onPressed: () => setState(() {
                  _phase = _InstallPhase.pickDisk;
                  _confirmController.clear();
                }),
                child: const Text('Back to disk selection'),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

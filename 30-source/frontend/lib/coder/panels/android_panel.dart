import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import '../../theme/swarm_colors.dart';
import '../editor_model.dart';
import '../../services/android_sdk_service.dart';

class AndroidPanel extends StatefulWidget {
  final String? projectPath;
  const AndroidPanel({super.key, this.projectPath});

  @override
  State<AndroidPanel> createState() => _AndroidPanelState();
}

class _AndroidPanelState extends State<AndroidPanel> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  List<AndroidDevice> _devices = [];
  bool _loadingDevices = false;
  final List<String> _buildLog = [];
  bool _building = false;
  double _buildProgress = 0;
  final List<String> _logcatLines = [];
  StreamSubscription? _logcatSub;
  bool _logcatRunning = false;
  String _buildType = 'debug'; // debug, release

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 5, vsync: this);
    _refreshDevices();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _logcatSub?.cancel();
    super.dispose();
  }

  Future<void> _refreshDevices() async {
    setState(() => _loadingDevices = true);
    try {
      final r = await Process.run('adb', ['devices', '-l']);
      final lines = r.stdout.toString().split('\n').skip(1).where((l) => l.trim().isNotEmpty).toList();
      final devices = <AndroidDevice>[];
      for (final line in lines) {
        final parts = line.trim().split(RegExp(r'\s+'));
        if (parts.length >= 2) {
          final id = parts[0];
          final state = parts[1];
          final isEmu = id.startsWith('emulator');
          final model = parts.where((p) => p.startsWith('model:')).firstOrNull?.substring(6) ?? (isEmu ? 'Emulator' : 'Device');
          devices.add(AndroidDevice(id: id, name: model, state: state, isEmulator: isEmu));
        }
      }
      if (mounted) setState(() { _devices = devices; _loadingDevices = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingDevices = false);
    }
  }

  Future<void> _buildApk() async {
    if (widget.projectPath == null) return;
    setState(() { _building = true; _buildProgress = 0; _buildLog.clear(); });

    try {
      final gradlew = '${widget.projectPath}/android/gradlew';
      final task = _buildType == 'debug' ? 'assembleDebug' : 'assembleRelease';
      final exists = File(gradlew).existsSync();
      final cmd = exists ? gradlew : 'flutter';
      final args = exists ? [task] : ['build', 'apk', if (_buildType == 'release') '--release'];

      final process = await Process.start(cmd, args, workingDirectory: widget.projectPath);
      setState(() => _buildLog.add('> Starting $cmd ${args.join(' ')}'));

      int lineCount = 0;
      process.stdout.transform(const SystemEncoding().decoder).listen((data) {
        for (final line in data.split('\n')) {
          if (line.trim().isEmpty) continue;
          lineCount++;
          if (mounted) setState(() {
            _buildLog.add(line);
            _buildProgress = (lineCount / 100).clamp(0.1, 0.95);
          });
        }
      });
      process.stderr.transform(const SystemEncoding().decoder).listen((data) {
        if (mounted) setState(() => _buildLog.add('ERR: $data'));
      });

      final exitCode = await process.exitCode;
      if (mounted) setState(() {
        _buildProgress = exitCode == 0 ? 1.0 : _buildProgress;
        _buildLog.add(exitCode == 0 ? '\n✓ BUILD SUCCESSFUL' : '\n✗ BUILD FAILED (exit $exitCode)');
        _building = false;
      });
    } catch (e) {
      if (mounted) setState(() { _buildLog.add('Error: $e'); _building = false; });
    }
  }

  Future<void> _installApk(String deviceId) async {
    if (widget.projectPath == null) return;
    final candidates = [
      '${widget.projectPath}/build/app/outputs/flutter-apk/app-debug.apk',
      '${widget.projectPath}/build/app/outputs/apk/debug/app-debug.apk',
      '${widget.projectPath}/app/build/outputs/apk/debug/app-debug.apk',
    ];
    final apkPath = candidates.firstWhere((p) => File(p).existsSync(), orElse: () => '');
    if (apkPath.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('APK not found. Build first.')));
      return;
    }
    final res = await Process.run('adb', ['-s', deviceId, 'install', '-r', '-d', '--user', '0', apkPath]);
    if (res.exitCode != 0) {
      await Process.run('adb', ['-s', deviceId, 'install', '-r', '-d', apkPath]);
    }
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('APK installed.')));
  }

  Future<void> _startLogcat(String deviceId) async {
    await _logcatSub?.cancel();
    setState(() { _logcatLines.clear(); _logcatRunning = true; });
    final process = await Process.start('adb', ['-s', deviceId, 'logcat', '-v', 'time']);
    _logcatSub = process.stdout.transform(const SystemEncoding().decoder).listen((data) {
      if (mounted) setState(() {
        final newLines = data.split('\n').where((l) => l.trim().isNotEmpty);
        _logcatLines.addAll(newLines);
        if (_logcatLines.length > 2000) _logcatLines.removeRange(0, _logcatLines.length - 2000);
      });
    });
  }

  Future<void> _stopLogcat() async {
    await _logcatSub?.cancel();
    _logcatSub = null;
    if (mounted) setState(() => _logcatRunning = false);
  }

  Future<void> _launchEmulator() async {
    final r = await Process.run('emulator', ['-list-avds']);
    final avds = r.stdout.toString().split('\n').where((l) => l.trim().isNotEmpty).toList();
    if (avds.isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No AVDs found. Create one in Android Studio.')));
      return;
    }
    Process.start('emulator', ['-avd', avds.first]);
    Future.delayed(const Duration(seconds: 5), _refreshDevices);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Tab bar
        Container(
          color: SwarmColors.bgSurface,
          child: TabBar(
            controller: _tabCtrl,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
            labelColor: SwarmColors.accent,
            unselectedLabelColor: SwarmColors.textMuted,
            indicatorColor: SwarmColors.accent,
            indicatorWeight: 2,
            tabs: const [
              Tab(text: 'DEVICES', height: 32),
              Tab(text: 'BUILD', height: 32),
              Tab(text: 'LOGCAT', height: 32),
              Tab(text: 'SDK MANAGER', height: 32),
              Tab(text: 'AVD EMULATOR', height: 32),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabCtrl,
            children: [
              _DevicesTab(
                devices: _devices,
                loading: _loadingDevices,
                onRefresh: _refreshDevices,
                onInstall: _installApk,
                onLogcat: (id) { _tabCtrl.animateTo(2); _startLogcat(id); },
                onLaunchEmulator: _launchEmulator,
              ),
              _BuildTab(
                buildType: _buildType,
                onBuildTypeChanged: (t) => setState(() => _buildType = t),
                building: _building,
                progress: _buildProgress,
                log: _buildLog,
                onBuild: _buildApk,
                projectPath: widget.projectPath,
              ),
              _LogcatTab(
                lines: _logcatLines,
                running: _logcatRunning,
                devices: _devices,
                onStart: _startLogcat,
                onStop: _stopLogcat,
              ),
              const _SdkTab(),
              const _AvdTab(),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Devices Tab ─────────────────────────────────────────────────────────────
class _DevicesTab extends StatelessWidget {
  final List<AndroidDevice> devices;
  final bool loading;
  final VoidCallback onRefresh, onLaunchEmulator;
  final ValueChanged<String> onInstall;
  final ValueChanged<String> onLogcat;

  const _DevicesTab({required this.devices, required this.loading, required this.onRefresh, required this.onInstall, required this.onLogcat, required this.onLaunchEmulator});

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: SwarmColors.border))),
            child: Row(children: [
              const Icon(Icons.phone_android, size: 13, color: SwarmColors.agentCyan),
              const SizedBox(width: 6),
              Text('${devices.length} device(s)', style: const TextStyle(fontSize: 11, color: SwarmColors.textMuted)),
              const Spacer(),
              TextButton.icon(icon: const Icon(Icons.phonelink_setup, size: 12), label: const Text('Emulator', style: TextStyle(fontSize: 11)), onPressed: onLaunchEmulator, style: TextButton.styleFrom(foregroundColor: SwarmColors.agentPurple, padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4))),
              IconButton(iconSize: 14, icon: const Icon(Icons.refresh), color: SwarmColors.textMuted, onPressed: onRefresh, tooltip: 'Refresh ADB', padding: EdgeInsets.zero, constraints: const BoxConstraints()),
            ]),
          ),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator(strokeWidth: 1.5, color: SwarmColors.accent))
                : devices.isEmpty
                    ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.phone_android, size: 40, color: SwarmColors.textDisabled),
                        const SizedBox(height: 8),
                        const Text('No devices connected', style: TextStyle(color: SwarmColors.textMuted, fontSize: 12)),
                        const SizedBox(height: 4),
                        TextButton(onPressed: onRefresh, child: const Text('Refresh ADB', style: TextStyle(fontSize: 11))),
                      ]))
                    : ListView.builder(
                        padding: const EdgeInsets.all(8),
                        itemCount: devices.length,
                        itemBuilder: (_, i) {
                          final d = devices[i];
                          return Card(
                            color: SwarmColors.bgElevated,
                            margin: const EdgeInsets.only(bottom: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                              side: BorderSide(color: d.isOnline ? SwarmColors.agentEmerald.withValues(alpha: 0.3) : SwarmColors.border),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(10),
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Row(children: [
                                  Icon(d.isEmulator ? Icons.phonelink : Icons.phone_android, size: 16, color: d.isOnline ? SwarmColors.agentEmerald : SwarmColors.textMuted),
                                  const SizedBox(width: 8),
                                  Expanded(child: Text(d.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: SwarmColors.textPrimary))),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: (d.isOnline ? SwarmColors.agentEmerald : SwarmColors.agentRose).withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                    child: Text(d.state, style: TextStyle(fontSize: 9, color: d.isOnline ? SwarmColors.agentEmerald : SwarmColors.agentRose, fontWeight: FontWeight.bold)),
                                  ),
                                ]),
                                const SizedBox(height: 4),
                                Text(d.id, style: const TextStyle(fontSize: 10, fontFamily: 'monospace', color: SwarmColors.textMuted)),
                                if (d.isOnline) ...[
                                  const SizedBox(height: 8),
                                  Row(children: [
                                    _ActionChip('Install APK', Icons.install_mobile, SwarmColors.accent, () => onInstall(d.id)),
                                    const SizedBox(width: 6),
                                    _ActionChip('Logcat', Icons.list_alt, SwarmColors.agentCyan, () => onLogcat(d.id)),
                                  ]),
                                ],
                              ]),
                            ),
                          );
                        },
                      ),
          ),
        ],
      );
}

class _ActionChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _ActionChip(this.label, this.icon, this.color, this.onTap);

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: color.withValues(alpha: 0.35)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 11, color: color),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
          ]),
        ),
      );
}

// ─── Build Tab ───────────────────────────────────────────────────────────────
class _BuildTab extends StatelessWidget {
  final String buildType;
  final ValueChanged<String> onBuildTypeChanged;
  final bool building;
  final double progress;
  final List<String> log;
  final VoidCallback onBuild;
  final String? projectPath;

  const _BuildTab({required this.buildType, required this.onBuildTypeChanged, required this.building, required this.progress, required this.log, required this.onBuild, this.projectPath});

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: SwarmColors.border))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Text('Build type:', style: TextStyle(fontSize: 11, color: SwarmColors.textMuted)),
                const SizedBox(width: 8),
                _TypeBtn('Debug', buildType == 'debug', () => onBuildTypeChanged('debug')),
                const SizedBox(width: 4),
                _TypeBtn('Release', buildType == 'release', () => onBuildTypeChanged('release')),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: building || projectPath == null ? null : onBuild,
                  icon: building ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 1.5)) : const Icon(Icons.build_rounded, size: 13),
                  label: Text(building ? 'Building...' : 'Build APK', style: const TextStyle(fontSize: 11)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: SwarmColors.accent.withValues(alpha: 0.15),
                    foregroundColor: SwarmColors.accent,
                    side: BorderSide(color: SwarmColors.accent.withValues(alpha: 0.4)),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  ),
                ),
              ]),
              if (building) ...[
                const SizedBox(height: 8),
                LinearProgressIndicator(value: progress, backgroundColor: SwarmColors.bgElevated, color: SwarmColors.accent, borderRadius: BorderRadius.circular(2)),
              ],
            ]),
          ),
          Expanded(
            child: log.isEmpty
                ? Center(child: Text(projectPath == null ? 'No project open' : 'Press Build APK to start', style: const TextStyle(color: SwarmColors.textMuted, fontSize: 12)))
                : ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: log.length,
                    itemBuilder: (_, i) {
                      final line = log[i];
                      Color c = SwarmColors.textSecondary;
                      if (line.startsWith('ERR')) c = SwarmColors.agentRose;
                      if (line.startsWith('✓')) c = SwarmColors.agentEmerald;
                      if (line.startsWith('✗')) c = SwarmColors.agentRose;
                      if (line.startsWith('>')) c = SwarmColors.agentCyan;
                      return Text(line, style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: c));
                    },
                  ),
          ),
        ],
      );
}

class _TypeBtn extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _TypeBtn(this.label, this.active, this.onTap);

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: active ? SwarmColors.accent.withValues(alpha: 0.2) : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: active ? SwarmColors.accent : SwarmColors.border),
          ),
          child: Text(label, style: TextStyle(fontSize: 11, color: active ? SwarmColors.accent : SwarmColors.textMuted, fontWeight: active ? FontWeight.bold : FontWeight.normal)),
        ),
      );
}

// ─── Logcat Tab ───────────────────────────────────────────────────────────────
class _LogcatTab extends StatefulWidget {
  final List<String> lines;
  final bool running;
  final List<AndroidDevice> devices;
  final ValueChanged<String> onStart;
  final VoidCallback onStop;

  const _LogcatTab({required this.lines, required this.running, required this.devices, required this.onStart, required this.onStop});

  @override
  State<_LogcatTab> createState() => _LogcatTabState();
}

class _LogcatTabState extends State<_LogcatTab> {
  final _scroll = ScrollController();
  String _filter = '';
  String? _selectedDevice;

  @override
  void didUpdateWidget(_LogcatTab old) {
    super.didUpdateWidget(old);
    if (widget.lines.length != old.lines.length && _scroll.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
      });
    }
  }

  Color _lineColor(String line) {
    if (line.contains(' E/') || line.contains(' E ')) return SwarmColors.agentRose;
    if (line.contains(' W/') || line.contains(' W ')) return SwarmColors.agentAmber;
    if (line.contains(' I/') || line.contains(' I ')) return SwarmColors.textSecondary;
    if (line.contains(' D/') || line.contains(' D ')) return SwarmColors.textMuted;
    return SwarmColors.textDisabled;
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filter.isEmpty ? widget.lines : widget.lines.where((l) => l.toLowerCase().contains(_filter.toLowerCase())).toList();
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: SwarmColors.border))),
          child: Row(children: [
            if (!widget.running) ...[
              DropdownButton<String>(
                value: _selectedDevice ?? (widget.devices.isNotEmpty ? widget.devices.first.id : null),
                hint: const Text('Device', style: TextStyle(fontSize: 11)),
                isDense: true,
                dropdownColor: SwarmColors.bgElevated,
                style: const TextStyle(fontSize: 11, color: SwarmColors.textSecondary),
                items: widget.devices.map((d) => DropdownMenuItem(value: d.id, child: Text(d.name, style: const TextStyle(fontSize: 11)))).toList(),
                onChanged: (v) => setState(() => _selectedDevice = v),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: _selectedDevice != null ? () => widget.onStart(_selectedDevice!) : null,
                icon: const Icon(Icons.play_arrow, size: 12),
                label: const Text('Start', style: TextStyle(fontSize: 11)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: SwarmColors.agentEmerald.withValues(alpha: 0.15),
                  foregroundColor: SwarmColors.agentEmerald,
                  elevation: 0, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                ),
              ),
            ] else ...[
              const Icon(Icons.circle, size: 8, color: SwarmColors.agentEmerald),
              const SizedBox(width: 6),
              const Text('Recording', style: TextStyle(fontSize: 11, color: SwarmColors.agentEmerald)),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: widget.onStop,
                icon: const Icon(Icons.stop, size: 12),
                label: const Text('Stop', style: TextStyle(fontSize: 11)),
                style: ElevatedButton.styleFrom(backgroundColor: SwarmColors.agentRose.withValues(alpha: 0.15), foregroundColor: SwarmColors.agentRose, elevation: 0, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4))),
              ),
            ],
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                onChanged: (v) => setState(() => _filter = v),
                style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                decoration: InputDecoration(
                  hintText: 'Filter...',
                  hintStyle: const TextStyle(color: SwarmColors.textDisabled, fontSize: 11),
                  isDense: true,
                  filled: true,
                  fillColor: SwarmColors.bgElevated,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: SwarmColors.border)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Text('${filtered.length}', style: const TextStyle(fontSize: 10, color: SwarmColors.textMuted)),
          ]),
        ),
        Expanded(
          child: ListView.builder(
            controller: _scroll,
            padding: const EdgeInsets.all(4),
            itemCount: filtered.length,
            itemBuilder: (_, i) => Text(
              filtered[i],
              style: TextStyle(fontFamily: 'monospace', fontSize: 10.5, color: _lineColor(filtered[i])),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── SDK Manager Tab ─────────────────────────────────────────────────────────
class _SdkTab extends StatefulWidget {
  const _SdkTab();

  @override
  State<_SdkTab> createState() => _SdkTabState();
}

class _SdkTabState extends State<_SdkTab> {
  final AndroidSdkService _sdkService = AndroidSdkService.instance;

  @override
  void initState() {
    super.initState();
    _sdkService.addListener(_onChanged);
  }

  @override
  void dispose() {
    _sdkService.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final sdk = _sdkService;

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        // Status & Path Card
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: SwarmColors.bgSurface,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: sdk.isSdkFound ? SwarmColors.agentEmerald.withAlpha(80) : SwarmColors.agentAmber.withAlpha(80)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(sdk.isSdkFound ? Icons.check_circle_rounded : Icons.warning_amber_rounded, size: 16, color: sdk.isSdkFound ? SwarmColors.agentEmerald : SwarmColors.agentAmber),
                  const SizedBox(width: 8),
                  Text(
                    sdk.isSdkFound ? 'ANDROID SDK DETECTED' : 'SDK LOCATION NOT SPECIFIED',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: sdk.isSdkFound ? SwarmColors.agentEmerald : SwarmColors.agentAmber,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.refresh, size: 16),
                    color: SwarmColors.textSecondary,
                    onPressed: () => sdk.detectSdk(),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Root: ${sdk.sdkPath ?? "Set ANDROID_HOME or ANDROID_SDK_ROOT"}',
                style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: SwarmColors.textPrimary),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Installed Platforms & Build-Tools
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: SwarmColors.bgSurface, borderRadius: BorderRadius.circular(6), border: Border.all(color: SwarmColors.border)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('INSTALLED PLATFORMS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: SwarmColors.textMuted)),
                    const SizedBox(height: 6),
                    if (sdk.installedPlatforms.isEmpty)
                      const Text('None detected', style: TextStyle(fontSize: 11, color: SwarmColors.textDisabled))
                    else
                      ...sdk.installedPlatforms.map((p) => Text('• $p', style: const TextStyle(fontSize: 11, color: SwarmColors.accent, fontFamily: 'monospace'))),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: SwarmColors.bgSurface, borderRadius: BorderRadius.circular(6), border: Border.all(color: SwarmColors.border)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('BUILD-TOOLS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: SwarmColors.textMuted)),
                    const SizedBox(height: 6),
                    if (sdk.installedBuildTools.isEmpty)
                      const Text('None detected', style: TextStyle(fontSize: 11, color: SwarmColors.textDisabled))
                    else
                      ...sdk.installedBuildTools.map((b) => Text('• $b', style: const TextStyle(fontSize: 11, color: SwarmColors.agentCyan, fontFamily: 'monospace'))),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // SDK Packages Catalog
        const Text('AVAILABLE SDK PACKAGES & SYSTEM IMAGES', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: SwarmColors.textDisabled, letterSpacing: 1.1)),
        const SizedBox(height: 8),
        ...sdk.availablePackages.map((pkg) => Container(
              margin: const EdgeInsets.only(bottom: 6),
              decoration: BoxDecoration(
                color: SwarmColors.bgSurface,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: SwarmColors.border),
              ),
              child: ListTile(
                dense: true,
                leading: Icon(
                  pkg.isInstalled ? Icons.check_circle_outline : Icons.cloud_download_outlined,
                  size: 18,
                  color: pkg.isInstalled ? SwarmColors.agentEmerald : SwarmColors.accent,
                ),
                title: Text(pkg.description, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: SwarmColors.textPrimary)),
                subtitle: Text(pkg.path, style: const TextStyle(fontSize: 10, fontFamily: 'monospace', color: SwarmColors.textMuted)),
                trailing: pkg.isInstalled
                    ? Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: SwarmColors.agentEmerald.withAlpha(30), borderRadius: BorderRadius.circular(4)),
                        child: const Text('INSTALLED', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: SwarmColors.agentEmerald)),
                      )
                    : ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: SwarmColors.accent,
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                        ),
                        onPressed: sdk.isBusy ? null : () => sdk.installSdkPackage(pkg.path),
                        child: const Text('Install', style: TextStyle(fontSize: 10, color: Colors.black, fontWeight: FontWeight.bold)),
                      ),
              ),
            )),

        const SizedBox(height: 12),
        // SDK Execution Logs Console
        Container(
          height: 140,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: SwarmColors.bgBase, borderRadius: BorderRadius.circular(6), border: Border.all(color: SwarmColors.border)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('SDK COMMAND LOGS', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: SwarmColors.textMuted)),
                  const Spacer(),
                  if (sdk.isBusy) const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: SwarmColors.accent)),
                ],
              ),
              const SizedBox(height: 4),
              Expanded(
                child: ListView.builder(
                  reverse: true,
                  itemCount: sdk.sdkLogs.length,
                  itemBuilder: (context, index) {
                    final log = sdk.sdkLogs[sdk.sdkLogs.length - 1 - index];
                    return Text(log, style: const TextStyle(fontFamily: 'monospace', fontSize: 10, color: SwarmColors.textSecondary));
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── AVD Emulator Manager Tab ────────────────────────────────────────────────
class _AvdTab extends StatefulWidget {
  const _AvdTab();

  @override
  State<_AvdTab> createState() => _AvdTabState();
}

class _AvdTabState extends State<_AvdTab> {
  final AndroidSdkService _sdkService = AndroidSdkService.instance;

  @override
  void initState() {
    super.initState();
    _sdkService.addListener(_onChanged);
  }

  @override
  void dispose() {
    _sdkService.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  void _showCreateAvdDialog() {
    final nameCtrl = TextEditingController(text: 'Pixel_7_Pro_API_34');
    String sysImage = 'system-images;android-34;google_apis;x86_64';
    String profile = 'pixel_7';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDState) => AlertDialog(
          backgroundColor: SwarmColors.bgSurface,
          title: const Row(
            children: [
              Icon(Icons.add_to_queue_rounded, color: SwarmColors.accent, size: 18),
              SizedBox(width: 8),
              Text('Create New Virtual Device (AVD)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: SwarmColors.textPrimary)),
            ],
          ),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('AVD Name', style: TextStyle(fontSize: 11, color: SwarmColors.textSecondary)),
                const SizedBox(height: 4),
                TextField(
                  controller: nameCtrl,
                  style: const TextStyle(fontSize: 12, color: SwarmColors.textPrimary, fontFamily: 'monospace'),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: SwarmColors.bgBase,
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: SwarmColors.border)),
                  ),
                ),
                const SizedBox(height: 12),
                const Text('Device Profile', style: TextStyle(fontSize: 11, color: SwarmColors.textSecondary)),
                const SizedBox(height: 4),
                DropdownButton<String>(
                  value: profile,
                  isExpanded: true,
                  dropdownColor: SwarmColors.bgElevated,
                  style: const TextStyle(fontSize: 12, color: SwarmColors.textPrimary),
                  items: const [
                    DropdownMenuItem(value: 'pixel_7', child: Text('Google Pixel 7 (6.3" 1080x2400)')),
                    DropdownMenuItem(value: 'pixel_6_pro', child: Text('Google Pixel 6 Pro (6.7" 1440x3120)')),
                    DropdownMenuItem(value: 'pixel_tablet', child: Text('Google Pixel Tablet (10.95" 2560x1600)')),
                  ],
                  onChanged: (val) {
                    if (val != null) setDState(() => profile = val);
                  },
                ),
                const SizedBox(height: 12),
                const Text('System Image', style: TextStyle(fontSize: 11, color: SwarmColors.textSecondary)),
                const SizedBox(height: 4),
                DropdownButton<String>(
                  value: sysImage,
                  isExpanded: true,
                  dropdownColor: SwarmColors.bgElevated,
                  style: const TextStyle(fontSize: 11, color: SwarmColors.textPrimary),
                  items: const [
                    DropdownMenuItem(value: 'system-images;android-34;google_apis;x86_64', child: Text('Android 14 (API 34) Google APIs x86_64')),
                    DropdownMenuItem(value: 'system-images;android-33;google_apis;x86_64', child: Text('Android 13 (API 33) Google APIs x86_64')),
                  ],
                  onChanged: (val) {
                    if (val != null) setDState(() => sysImage = val);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: SwarmColors.textMuted)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: SwarmColors.accent),
              onPressed: () async {
                Navigator.pop(ctx);
                await _sdkService.createAvd(
                  name: nameCtrl.text.trim(),
                  packageImage: sysImage,
                  deviceProfile: profile,
                );
              },
              child: const Text('Create Device', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sdk = _sdkService;

    return Column(
      children: [
        // Action Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: SwarmColors.border))),
          child: Row(
            children: [
              const Icon(Icons.phone_android_rounded, size: 16, color: SwarmColors.accent),
              const SizedBox(width: 8),
              Text('AVD MANAGER (${sdk.avds.length})', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: SwarmColors.textPrimary)),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.refresh, size: 16),
                tooltip: 'Refresh AVDs',
                color: SwarmColors.textSecondary,
                onPressed: () => sdk.refreshAvds(),
              ),
              const SizedBox(width: 4),
              ElevatedButton.icon(
                icon: const Icon(Icons.add, size: 14, color: Colors.black),
                label: const Text('New AVD', style: TextStyle(fontSize: 11, color: Colors.black, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(backgroundColor: SwarmColors.accent, visualDensity: VisualDensity.compact),
                onPressed: _showCreateAvdDialog,
              ),
            ],
          ),
        ),

        // AVD List
        Expanded(
          child: sdk.avds.isEmpty
              ? const Center(child: Text('No Android Virtual Devices found', style: TextStyle(fontSize: 11, color: SwarmColors.textMuted)))
              : ListView.builder(
                  padding: const EdgeInsets.all(10),
                  itemCount: sdk.avds.length,
                  itemBuilder: (context, index) {
                    final avd = sdk.avds[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: SwarmColors.bgSurface,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: avd.isRunning ? SwarmColors.agentEmerald : SwarmColors.border),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Row(
                          children: [
                            Icon(
                              Icons.phone_android_rounded,
                              size: 28,
                              color: avd.isRunning ? SwarmColors.agentEmerald : SwarmColors.textSecondary,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(avd.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: SwarmColors.textPrimary)),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: avd.isRunning ? SwarmColors.agentEmerald.withAlpha(30) : SwarmColors.bgElevated,
                                          borderRadius: BorderRadius.circular(3),
                                        ),
                                        child: Text(
                                          avd.isRunning ? 'RUNNING' : 'STOPPED',
                                          style: TextStyle(
                                            fontSize: 8,
                                            fontWeight: FontWeight.bold,
                                            color: avd.isRunning ? SwarmColors.agentEmerald : SwarmColors.textDisabled,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  Text('${avd.device} • ${avd.target} • ${avd.basedOn}', style: const TextStyle(fontSize: 10, color: SwarmColors.textMuted)),
                                ],
                              ),
                            ),
                            // Launch / Cold Boot / Stop Buttons
                            if (!avd.isRunning) ...[
                              IconButton(
                                icon: const Icon(Icons.play_arrow_rounded, color: SwarmColors.agentEmerald, size: 22),
                                tooltip: 'Start Emulator',
                                onPressed: () => sdk.launchAvd(avd.name),
                              ),
                              IconButton(
                                icon: const Icon(Icons.cleaning_services_rounded, color: SwarmColors.agentAmber, size: 18),
                                tooltip: 'Wipe Data & Cold Boot',
                                onPressed: () => sdk.wipeAndColdBootAvd(avd.name),
                              ),
                            ] else ...[
                              IconButton(
                                icon: const Icon(Icons.stop_rounded, color: SwarmColors.agentRose, size: 22),
                                tooltip: 'Stop Emulator',
                                onPressed: () => sdk.killEmulator(avd.name),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

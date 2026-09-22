import 'dart:io';

import 'package:flutter/material.dart';

import '../services/app_installer_service.dart';
import '../services/system_launcher.dart';
import '../theme/swarm_colors.dart';
import '../theme/swarm_text_styles.dart';

/// SWARM OS — DROID Tool Marketplace
///
/// Professional-grade Android development toolchain, fully wired: every
/// entry detects its installed state on the system, installs from Arch
/// repos / AUR in a terminal window, and launches with native fallbacks.
/// Covers the full pipeline — IDE, SDK & build tools, every language,
/// adb device bridge, emulators, and APK tooling.

class DroidTool {
  final String id;
  final String name;
  final String description;
  final String category;
  final IconData icon;
  final Color color;
  final String checkCommand; // bash expression: exit 0 ⇒ installed
  final String? installPackage; // Arch repo / AUR package (null = preinstalled)
  final String? launchCommand; // null = CLI tool, no GUI to launch

  const DroidTool({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.icon,
    required this.color,
    required this.checkCommand,
    this.installPackage,
    this.launchCommand,
  });
}

class DroidMarketplacePage extends StatefulWidget {
  const DroidMarketplacePage({super.key});

  @override
  State<DroidMarketplacePage> createState() => _DroidMarketplacePageState();
}

class _DroidMarketplacePageState extends State<DroidMarketplacePage> {
  static const _studioLaunch = '/opt/android-studio/bin/studio.sh || android-studio || studio';
  static const _studioCheck = 'test -x /opt/android-studio/bin/studio.sh || command -v android-studio';

  static const List<DroidTool> _catalog = [
    // ── IDE ──────────────────────────────────────────────────────────
    DroidTool(
      id: 'android_studio',
      name: 'Android Studio',
      description: 'Official professional IDE — AVD manager, profilers, layout editor, Gradle integration',
      category: 'IDE',
      icon: Icons.android_rounded,
      color: Color(0xFF3DDC84),
      checkCommand: _studioCheck,
      installPackage: 'android-studio',
      launchCommand: _studioLaunch,
    ),
    DroidTool(
      id: 'vscode',
      name: 'VS Code',
      description: 'Lightweight polyglot IDE — Flutter/Dart and Kotlin extensions',
      category: 'IDE',
      icon: Icons.code_rounded,
      color: Color(0xFF007ACC),
      checkCommand: 'command -v code',
      installPackage: 'code',
      launchCommand: 'code',
    ),

    // ── SDK & BUILD ──────────────────────────────────────────────────
    DroidTool(
      id: 'openjdk',
      name: 'OpenJDK (Java)',
      description: 'Java runtime & compiler — required by Android Gradle builds',
      category: 'SDK & Build',
      icon: Icons.local_cafe_rounded,
      color: Color(0xFFE76F00),
      checkCommand: 'command -v java',
      installPackage: 'jdk-openjdk',
 launchCommand: null,
    ),
    DroidTool(
      id: 'gradle',
      name: 'Gradle',
      description: 'Build automation for Android projects & dependency resolution',
      category: 'SDK & Build',
      icon: Icons.account_tree_rounded,
      color: Color(0xFF02303A),
      checkCommand: 'command -v gradle',
      installPackage: 'gradle',
    ),
    DroidTool(
      id: 'maven',
      name: 'Apache Maven',
      description: 'Project management & comprehension tool for Java builds',
      category: 'SDK & Build',
      icon: Icons.schema_rounded,
      color: Color(0xFFC71A36),
      checkCommand: 'command -v mvn',
      installPackage: 'maven',
    ),
    DroidTool(
      id: 'sdk_cmdline_tools',
      name: 'Android SDK Cmdline Tools',
      description: 'sdkmanager, avdmanager — install platforms, build-tools & system images',
      category: 'SDK & Build',
      icon: Icons.build_circle_rounded,
      color: Color(0xFF4ADE80),
      checkCommand: 'command -v sdkmanager || test -d /opt/android-sdk/cmdline-tools',
      installPackage: 'android-sdk-cmdline-tools-latest',
    ),

    // ── LANGUAGES ────────────────────────────────────────────────────
    DroidTool(
      id: 'kotlin',
      name: 'Kotlin',
      description: 'First-class Android language — compiler, REPL & scripting',
      category: 'Languages',
      icon: Icons.abc_rounded,
      color: Color(0xFF7F52FF),
      checkCommand: 'command -v kotlinc',
      installPackage: 'kotlin',
    ),
    DroidTool(
      id: 'dart',
      name: 'Dart SDK',
      description: 'Language for Flutter apps — analyzer, AOT/JIT compilers',
      category: 'Languages',
      icon: Icons.bolt_rounded,
      color: Color(0xFF0175C2),
      checkCommand: 'command -v dart',
      installPackage: 'dart',
    ),
    DroidTool(
      id: 'flutter',
      name: 'Flutter',
      description: 'Cross-platform toolkit driving the SWARM Companion app itself',
      category: 'Languages',
      icon: Icons.flutter_dash_rounded,
      color: Color(0xFF027DFD),
      checkCommand: 'command -v flutter',
      installPackage: 'flutter',
    ),
    DroidTool(
      id: 'rust',
      name: 'Rust (rustup)',
      description: 'Systems language for NDK-native Android components',
      category: 'Languages',
      icon: Icons.settings_suggest_rounded,
      color: Color(0xFFDEA584),
      checkCommand: 'command -v rustc',
      installPackage: 'rustup',
    ),
    DroidTool(
      id: 'go',
      name: 'Go',
      description: 'Backend services & gomobile cross-compilation',
      category: 'Languages',
      icon: Icons.terminal_rounded,
      color: Color(0xFF00ADD8),
      checkCommand: 'command -v go',
      installPackage: 'go',
    ),
    DroidTool(
      id: 'cc_toolchain',
      name: 'C / C++ Toolchain',
      description: 'GCC, make & headers — NDK-class native builds',
      category: 'Languages',
      icon: Icons.memory_rounded,
      color: Color(0xFF8B5CF6),
      checkCommand: 'command -v gcc',
      installPackage: 'base-devel',
    ),
    DroidTool(
      id: 'python',
      name: 'Python',
      description: 'Automation, build scripts & Chaquopy-class app embedding',
      category: 'Languages',
      icon: Icons.data_object_rounded,
      color: Color(0xFF3776AB),
      checkCommand: 'command -v python',
      installPackage: 'python',
    ),

    // ── DEVICE BRIDGE ────────────────────────────────────────────────
    DroidTool(
      id: 'adb',
      name: 'ADB & Fastboot',
      description: 'Android device bridge — install, shell, logcat, flash',
      category: 'Device Bridge',
      icon: Icons.usb_rounded,
      color: Color(0xFF10B981),
      checkCommand: 'command -v adb',
      installPackage: 'android-tools',
    ),
    DroidTool(
      id: 'scrcpy',
      name: 'scrcpy',
      description: 'Ultra-low-latency device mirroring & control over USB/TCP',
      category: 'Device Bridge',
      icon: Icons.cast_connected_rounded,
      color: Color(0xFF06B6D4),
      checkCommand: 'command -v scrcpy',
      installPackage: 'scrcpy',
      launchCommand: 'scrcpy --stay-awake',
    ),

    // ── EMULATORS ────────────────────────────────────────────────────
    DroidTool(
      id: 'waydroid',
      name: 'Waydroid',
      description: 'Hardware-accelerated containerized full Android system',
      category: 'Emulators',
      icon: Icons.smart_screen_rounded,
      color: Color(0xFF22C55E),
      checkCommand: 'command -v waydroid',
      installPackage: 'waydroid',
      launchCommand: 'waydroid show-full-ui',
    ),
    DroidTool(
      id: 'avd_emulator',
      name: 'Android Emulator (AVD)',
      description: 'QEMU-based official emulator — run AVDs from Android Studio',
      category: 'Emulators',
      icon: Icons.smartphone_rounded,
      color: Color(0xFF3DDC84),
      checkCommand: 'command -v emulator',
      installPackage: 'android-emulator',
      launchCommand: 'emulator',
    ),
    DroidTool(
      id: 'qemu',
      name: 'QEMU',
      description: 'Full-system emulator for custom Android-x86 & test images',
      category: 'Emulators',
      icon: Icons.computer_rounded,
      color: Color(0xFFEF9A9A),
      checkCommand: 'command -v qemu-system-x86_64',
      installPackage: 'qemu-desktop',
    ),

    // ── APK TOOLS ────────────────────────────────────────────────────
    DroidTool(
      id: 'apktool',
      name: 'APKTool',
      description: 'Decode, inspect & rebuild APK resources and smali',
      category: 'APK Tools',
      icon: Icons.handyman_rounded,
      color: Color(0xFFF59E0B),
      checkCommand: 'command -v apktool',
      installPackage: 'apktool',
    ),
    DroidTool(
      id: 'jadx',
      name: 'JADX',
      description: 'Dex → Java decompiler with GUI for APK reverse engineering',
      category: 'APK Tools',
      icon: Icons.travel_explore_rounded,
      color: Color(0xFF8B5CF6),
      checkCommand: 'command -v jadx',
      installPackage: 'jadx',
      launchCommand: 'jadx-gui || jadx',
    ),
    DroidTool(
      id: 'apksigner',
      name: 'apksigner',
      description: 'Sign & verify APKs with v1–v4 signature schemes',
      category: 'APK Tools',
      icon: Icons.key_rounded,
      color: Color(0xFFEF4444),
      checkCommand: 'command -v apksigner',
      installPackage: 'android-apksigner',
    ),
  ];

  static const List<String> _categories = [
    'All', 'IDE', 'SDK & Build', 'Languages', 'Device Bridge', 'Emulators', 'APK Tools',
  ];

  // tool id → live state
  final Map<String, bool> _installed = {};
  final Map<String, String> _busy = {};
  final Map<String, bool> _launching = {};
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';
  String _selectedCategory = 'All';
  List<String> _adbDevices = [];
  bool _refreshingDevices = false;

  @override
  void initState() {
    super.initState();
    _checkAll();
    _refreshDevices();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkAll() async {
    for (final tool in _catalog) {
      final installed = await _isToolInstalled(tool);
      if (!mounted) return;
      setState(() => _installed[tool.id] = installed);
    }
  }

  Future<bool> _isToolInstalled(DroidTool tool) async {
    try {
      final r = await Process.run('bash', ['-c', tool.checkCommand]);
      return r.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  /// Live device list from `adb devices -l` (empty quietly when adb absent).
  Future<void> _refreshDevices() async {
    setState(() => _refreshingDevices = true);
    try {
      final r = await Process.run('adb', ['devices', '-l']);
      final devices = <String>[];
      for (final line in r.stdout.toString().split('\n')) {
        // Format: <serial>\tdevice <props...> — ignore the header & offline rows
        if (!line.contains('\tdevice')) continue;
        final serial = line.split('\t').first.trim();
        final model = RegExp(r'model:(\S+)').firstMatch(line)?.group(1);
        devices.add(model != null ? '$model ($serial)' : serial);
      }
      if (mounted) setState(() => _adbDevices = devices);
    } catch (_) {
      if (mounted) setState(() => _adbDevices = []);
    }
    if (mounted) setState(() => _refreshingDevices = false);
  }

  Future<void> _install(DroidTool tool) async {
    final pkg = tool.installPackage;
    if (pkg == null || _busy.containsKey(tool.id)) return;
    setState(() => _busy[tool.id] = 'Opening install terminal…');
    final ok = await AppInstallerService.instance.installAndRegister(
      pkg,
      onStatus: (s) {
        if (mounted) setState(() => _busy[tool.id] = s);
      },
    );
    if (!mounted) return;
    setState(() => _busy.remove(tool.id));
    _toast(ok
        ? '✅ Installed ${tool.name} — ready to use'
        : '⚠️ ${tool.name} install did not complete');
    if (ok) {
      _installed[tool.id] = await _isToolInstalled(tool);
      if (mounted) setState(() {});
    }
  }

  Future<void> _launch(DroidTool tool) async {
    final cmd = tool.launchCommand;
    if (cmd == null || _launching[tool.id] == true) return;
    setState(() => _launching[tool.id] = true);
    await SystemLauncher.launch(context, cmd, displayName: tool.name);
    if (mounted) {
      setState(() => _launching[tool.id] = false);
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: SwarmColors.bgElevated,
      content: Text(message,
          style: const TextStyle(color: SwarmColors.textPrimary, fontSize: 12)),
      duration: const Duration(seconds: 3),
    ));
  }

  List<DroidTool> get _filteredTools {
    final query = _searchQuery.toLowerCase();
    return _catalog.where((t) {
      final matchesCategory =
          _selectedCategory == 'All' || t.category == _selectedCategory;
      final matchesSearch = query.isEmpty ||
          t.name.toLowerCase().contains(query) ||
          t.description.toLowerCase().contains(query);
      return matchesCategory && matchesSearch;
    }).toList();
  }

  int get _installedCount =>
      _catalog.where((t) => _installed[t.id] == true).length;

  @override
  Widget build(BuildContext context) {
    final tools = _filteredTools;
    return Scaffold(
      backgroundColor: SwarmColors.bgBase,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 16),
            _buildDevicePanel(),
            const SizedBox(height: 16),
            _buildSearchAndFilters(),
            const SizedBox(height: 16),
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 420,
                  mainAxisExtent: 148,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: tools.length,
                itemBuilder: (_, i) => _buildToolCard(tools[i]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF3DDC84).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF3DDC84).withValues(alpha: 0.3)),
          ),
          child: const Icon(Icons.android_rounded, color: Color(0xFF3DDC84), size: 28),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'DROID TOOL MARKETPLACE',
              style: SwarmTextStyles.headlineMedium.copyWith(
                color: SwarmColors.textPrimary,
                letterSpacing: 1.5,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Professional Android IDE · SDK · emulators · adb · APK tools — all languages, fully wired',
              style: SwarmTextStyles.bodyMedium.copyWith(color: SwarmColors.textMuted),
            ),
          ],
        ),
        const Spacer(),
        Text(
          '$_installedCount / ${_catalog.length} installed',
          style: SwarmTextStyles.bodySmall.copyWith(color: SwarmColors.textSecondary),
        ),
        const SizedBox(width: 12),
        IconButton(
          onPressed: () {
            _checkAll();
            _refreshDevices();
          },
          tooltip: 'Re-scan toolchain & connected devices',
          icon: const Icon(Icons.refresh_rounded, color: SwarmColors.textMuted),
        ),
      ],
    );
  }

  Widget _buildDevicePanel() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: SwarmColors.bgElevated,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: SwarmColors.borderSubtle),
      ),
      child: Row(
        children: [
          Icon(Icons.usb_rounded,
              size: 18,
              color: _adbDevices.isEmpty ? SwarmColors.statusOffline : SwarmColors.statusOnline),
          const SizedBox(width: 10),
          Text(
            _refreshingDevices
                ? 'Scanning adb devices…'
                : _adbDevices.isEmpty
                    ? 'No devices connected — plug in USB or enable wireless debugging, then refresh'
                    : 'Connected: ${_adbDevices.join('  ·  ')}',
            style: SwarmTextStyles.bodySmall.copyWith(
              color: _adbDevices.isEmpty ? SwarmColors.textMuted : SwarmColors.statusOnline,
            ),
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: _refreshingDevices ? null : _refreshDevices,
            icon: _refreshingDevices
                ? const SizedBox(
                    width: 14, height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: SwarmColors.accent))
                : const Icon(Icons.sync_rounded, size: 16, color: SwarmColors.textMuted),
            label: const Text('ADB SCAN',
                style: TextStyle(fontSize: 11, color: SwarmColors.textMuted, letterSpacing: 1)),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilters() {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: Container(
            decoration: BoxDecoration(
              color: SwarmColors.bgElevated,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: SwarmColors.borderSubtle),
            ),
            child: TextField(
              controller: _searchCtrl,
              style: const TextStyle(color: SwarmColors.textPrimary),
              decoration: const InputDecoration(
                hintText: 'Search Android tools, SDKs, languages...',
                hintStyle: TextStyle(color: SwarmColors.textMuted, fontSize: 13),
                prefixIcon: Icon(Icons.search_rounded, color: SwarmColors.textMuted, size: 20),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 5,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _categories.map((cat) {
                final selected = _selectedCategory == cat;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(cat),
                    selected: selected,
                    onSelected: (_) => setState(() => _selectedCategory = cat),
                    selectedColor: SwarmColors.accent.withValues(alpha: 0.2),
                    backgroundColor: SwarmColors.bgElevated,
                    labelStyle: TextStyle(
                      color: selected ? SwarmColors.accent : SwarmColors.textMuted,
                      fontSize: 12,
                      fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                    ),
                    side: BorderSide(
                      color: selected ? SwarmColors.accent : SwarmColors.borderSubtle,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildToolCard(DroidTool tool) {
    final installed = _installed[tool.id] ?? false;
    final busyStatus = _busy[tool.id];
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: SwarmColors.bgElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: installed ? tool.color.withValues(alpha: 0.35) : SwarmColors.borderSubtle,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: tool.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(tool.icon, color: tool.color, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(tool.name,
                    overflow: TextOverflow.ellipsis,
                    style: SwarmTextStyles.h3.copyWith(color: SwarmColors.textPrimary)),
              ),
              _buildStateChip(tool, installed),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Text(
              tool.description,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: SwarmTextStyles.bodySmall.copyWith(
                color: SwarmColors.textSecondary,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (busyStatus != null)
                Expanded(
                  child: Text(
                    busyStatus,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: SwarmTextStyles.bodySmall.copyWith(color: SwarmColors.statusIdle),
                  ),
                )
              else ...[
                if (tool.installPackage != null && !installed)
                  _buildAction(
                    label: 'INSTALL',
                    icon: Icons.download_rounded,
                    color: SwarmColors.accent,
                    onPressed: () => _install(tool),
                  ),
                if (installed && tool.launchCommand != null)
                  _buildAction(
                    label: _launching[tool.id] == true ? 'LAUNCHING…' : 'LAUNCH',
                    icon: Icons.play_arrow_rounded,
                    color: tool.color,
                    onPressed: () => _launch(tool),
                  ),
                if (tool.installPackage == null || installed)
                  const Spacer(),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStateChip(DroidTool tool, bool installed) {
    final checking = !_installed.containsKey(tool.id);
    final label = checking ? '…' : (installed ? 'INSTALLED' : 'AVAILABLE');
    final color = checking
        ? SwarmColors.textMuted
        : (installed ? SwarmColors.statusOnline : SwarmColors.textMuted);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.8)),
    );
  }

  Widget _buildAction({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: TextButton.icon(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          foregroundColor: color,
          backgroundColor: color.withValues(alpha: 0.12),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        icon: Icon(icon, size: 15),
        label: Text(label,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.6)),
      ),
    );
  }
}

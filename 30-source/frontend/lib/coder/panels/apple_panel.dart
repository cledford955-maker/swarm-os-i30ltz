import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/swarm_colors.dart';
import '../../theme/swarm_text_styles.dart';
import '../services/apple_build_service.dart';

// Apple icon color
const _appleGray = Color(0xFFBCC0C7);
const _appleSilver = Color(0xFFE8E8E8);
const _appleBlue = Color(0xFF0A84FF);
const _appleGreen = Color(0xFF34C759);
const _appleRed = Color(0xFFFF3B30);
const _appleAmber = Color(0xFFFF9500);

class ApplePanel extends StatefulWidget {
  final String? projectPath;
  const ApplePanel({super.key, this.projectPath});

  @override
  State<ApplePanel> createState() => _ApplePanelState();
}

class _ApplePanelState extends State<ApplePanel> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  final _svc = AppleBuildService.instance;
  late List<AppleCapability> _capabilities;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 5, vsync: this);
    _capabilities = AppleBuildService.defaultCapabilities();
    _svc.addListener(_onSvcChanged);
    _svc.load();
    _svc.refreshDevices();
    _svc.refreshCertificates();
    _svc.refreshProfiles();
  }

  @override
  void dispose() {
    _svc.removeListener(_onSvcChanged);
    _tabCtrl.dispose();
    super.dispose();
  }

  void _onSvcChanged() { if (mounted) setState(() {}); }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // Header
      Container(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        decoration: const BoxDecoration(
          color: Color(0xFF0F0C1F),
          border: Border(bottom: BorderSide(color: SwarmColors.border)),
        ),
        child: Row(children: [
          const _AppleLogo(),
          const SizedBox(width: 8),
          Text('Apple App Suite', style: SwarmTextStyles.h2.copyWith(fontSize: 13, color: _appleSilver)),
          const Spacer(),
          _StatusPill(svc: _svc),
        ]),
      ),
      // Tab bar
      Container(
        color: const Color(0xFF0A0818),
        child: TabBar(
          controller: _tabCtrl,
          labelStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
          labelColor: _appleBlue,
          unselectedLabelColor: SwarmColors.textMuted,
          indicatorColor: _appleBlue,
          indicatorWeight: 2,
          tabs: const [
            Tab(text: 'DEVICES',      height: 30, icon: Icon(Icons.phone_iphone_rounded, size: 13)),
            Tab(text: 'BUILD',        height: 30, icon: Icon(Icons.build_circle_rounded, size: 13)),
            Tab(text: 'SIGNING',      height: 30, icon: Icon(Icons.lock_rounded, size: 13)),
            Tab(text: 'APP STORE',    height: 30, icon: Icon(Icons.store_rounded, size: 13)),
            Tab(text: 'CAPABILITIES', height: 30, icon: Icon(Icons.toggle_on_rounded, size: 13)),
          ],
        ),
      ),
      // Tabs
      Expanded(
        child: TabBarView(controller: _tabCtrl, children: [
          _DevicesTab(svc: _svc, projectPath: widget.projectPath),
          _BuildTab(svc: _svc, projectPath: widget.projectPath),
          _SigningTab(svc: _svc),
          _AppStoreTab(svc: _svc),
          _CapabilitiesTab(svc: _svc, capabilities: _capabilities, projectPath: widget.projectPath),
        ]),
      ),
    ]);
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// TAB 1 — DEVICES
// ══════════════════════════════════════════════════════════════════════════════
class _DevicesTab extends StatefulWidget {
  final AppleBuildService svc;
  final String? projectPath;
  const _DevicesTab({required this.svc, this.projectPath});

  @override
  State<_DevicesTab> createState() => _DevicesTabState();
}

class _DevicesTabState extends State<_DevicesTab> {
  String _filter = 'all'; // 'all', 'real', 'sim'

  List<IosDevice> get _shown => widget.svc.devices.where((d) {
    return _filter == 'all' || (_filter == 'real' && !d.isSimulator) || (_filter == 'sim' && d.isSimulator);
  }).toList();

  @override
  Widget build(BuildContext context) {
    final svc = widget.svc;
    return Column(children: [
      // SSH config strip
      _SshStrip(svc: svc),
      const Divider(height: 1, color: SwarmColors.border),
      // Filter + refresh
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(children: [
          ...[('all', 'All'), ('real', 'Devices'), ('sim', 'Simulators')].map((t) => Padding(
            padding: const EdgeInsets.only(right: 4),
            child: _FilterChip(label: t.$2, selected: _filter == t.$1, onTap: () => setState(() => _filter = t.$1)),
          )),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 16, color: SwarmColors.textMuted),
            tooltip: 'Refresh devices',
            onPressed: svc.refreshDevices,
            constraints: const BoxConstraints(), padding: const EdgeInsets.all(4),
          ),
        ]),
      ),
      const Divider(height: 1, color: SwarmColors.border),
      // Device list
      Expanded(
        child: _shown.isEmpty
            ? _EmptyState(icon: Icons.phone_iphone_rounded, text: 'No devices found.\nConnect an iPhone/iPad or start a simulator.')
            : ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 4),
                itemCount: _shown.length,
                itemBuilder: (_, i) => _DeviceRow(device: _shown[i], svc: svc, projectPath: widget.projectPath),
              ),
      ),
    ]);
  }
}

class _DeviceRow extends StatelessWidget {
  final IosDevice device;
  final AppleBuildService svc;
  final String? projectPath;
  const _DeviceRow({required this.device, required this.svc, this.projectPath});

  @override
  Widget build(BuildContext context) {
    final isOnline = device.isOnline;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: SwarmColors.bgElevated,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: isOnline ? _appleGreen.withValues(alpha: 0.3) : SwarmColors.border),
      ),
      child: Row(children: [
        Icon(device.isSimulator ? Icons.computer_rounded : Icons.phone_iphone_rounded, size: 22, color: isOnline ? _appleGreen : SwarmColors.textDisabled),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(device.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: SwarmColors.textPrimary)),
          Text('${device.iosVersion} · ${device.productType} · ${device.udid.substring(0, device.udid.length.clamp(0, 12))}…',
              style: const TextStyle(fontSize: 10, color: SwarmColors.textMuted, fontFamily: 'monospace')),
        ])),
        // State badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: (isOnline ? _appleGreen : SwarmColors.textDisabled).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(3),
          ),
          child: Text(device.state, style: TextStyle(fontSize: 9, color: isOnline ? _appleGreen : SwarmColors.textDisabled, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(width: 8),
        // Actions
        if (device.isSimulator && device.state == 'Shutdown')
          _SmallBtn('Boot', _appleBlue, () => svc.bootSimulator(device.udid))
        else if (device.isSimulator && device.isOnline) ...[
          _SmallBtn('Open', _appleBlue, svc.openSimulatorApp),
          const SizedBox(width: 4),
          _SmallBtn('Launch', _appleGreen, () => svc.launchAppOnSimulator(device.udid)),
        ] else if (!device.isSimulator && isOnline) ...[
          _SmallBtn('Install IPA', _appleBlue, () async {
            final f = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: ['ipa']);
            if (f?.path != null) svc.installIpaOnDevice(device.udid, f!.path!);
          }),
        ],
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// TAB 2 — BUILD
// ══════════════════════════════════════════════════════════════════════════════
class _BuildTab extends StatefulWidget {
  final AppleBuildService svc;
  final String? projectPath;
  const _BuildTab({required this.svc, this.projectPath});

  @override
  State<_BuildTab> createState() => _BuildTabState();
}

class _BuildTabState extends State<_BuildTab> {
  AppleBuildTarget _selected = AppleBuildTarget.iosDebug;
  final _logScroll = ScrollController();

  static const _targets = [
    (AppleBuildTarget.iosDebug,     '📱 iOS Debug (Simulator)',    'flutter build ios --debug --simulator'),
    (AppleBuildTarget.iosRelease,   '📱 iOS Release',              'flutter build ios --release'),
    (AppleBuildTarget.ipaRelease,   '📦 IPA Export',               'flutter build ipa --release'),
    (AppleBuildTarget.iosArchive,   '🗄  iOS Archive (Xcode)',      'xcodebuild archive ...'),
    (AppleBuildTarget.macosDebug,   '🖥  macOS Debug',              'flutter build macos --debug'),
    (AppleBuildTarget.macosRelease, '🖥  macOS Release',            'flutter build macos --release'),
    (AppleBuildTarget.macosArchive, '🗄  macOS Archive',            'xcodebuild archive ...'),
  ];

  @override
  void initState() {
    super.initState();
    widget.svc.addListener(_onLog);
  }

  @override
  void dispose() {
    widget.svc.removeListener(_onLog);
    _logScroll.dispose();
    super.dispose();
  }

  void _onLog() {
    if (mounted) {
      setState(() {});
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_logScroll.hasClients) _logScroll.jumpTo(_logScroll.position.maxScrollExtent);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final svc = widget.svc;
    final isBuilding = svc.isBuilding;

    return Column(children: [
      // Target selector
      Container(
        height: 40,
        color: SwarmColors.bgSurface,
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          scrollDirection: Axis.horizontal,
          itemCount: _targets.length,
          separatorBuilder: (_, __) => const SizedBox(width: 4),
          itemBuilder: (_, i) {
            final t = _targets[i];
            final sel = _selected == t.$1;
            return GestureDetector(
              onTap: () => setState(() => _selected = t.$1),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: sel ? _appleBlue.withValues(alpha: 0.2) : SwarmColors.bgElevated,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: sel ? _appleBlue : SwarmColors.border),
                ),
                child: Text(t.$2, style: TextStyle(fontSize: 10, color: sel ? _appleBlue : SwarmColors.textMuted, fontWeight: sel ? FontWeight.bold : FontWeight.normal)),
              ),
            );
          },
        ),
      ),
      const Divider(height: 1, color: SwarmColors.border),
      // Build controls
      Padding(
        padding: const EdgeInsets.all(10),
        child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Target: ${_targets.firstWhere((t) => t.$1 == _selected).$2}', style: const TextStyle(fontSize: 12, color: SwarmColors.textPrimary, fontWeight: FontWeight.w600)),
            Text('CMD: ${_targets.firstWhere((t) => t.$1 == _selected).$3}', style: const TextStyle(fontFamily: 'monospace', fontSize: 10, color: SwarmColors.textMuted)),
          ])),
          const SizedBox(width: 10),
          if (isBuilding)
            _ActionBtn('Stop', _appleRed, Icons.stop_circle_rounded, svc.cancelBuild)
          else
            _ActionBtn('Build', _appleGreen, Icons.play_circle_rounded, () => svc.build(_selected, projectPath: widget.projectPath)),
          const SizedBox(width: 6),
          _IconBtn(Icons.cleaning_services_rounded, 'Clean', () async {
            svc.build(AppleBuildTarget.iosDebug, projectPath: widget.projectPath); // placeholder
          }),
        ]),
      ),
      // Status
      if (svc.buildStatus != AppleBuildStatus.idle)
        _BuildStatusBar(status: svc.buildStatus, artifactPath: svc.artifactPath),
      const Divider(height: 1, color: SwarmColors.border),
      // Log output
      Expanded(
        child: Container(
          color: const Color(0xFF050310),
          child: svc.buildLog.isEmpty
              ? const Center(child: Text('Build output appears here.', style: TextStyle(fontSize: 11, color: SwarmColors.textDisabled)))
              : ListView.builder(
                  controller: _logScroll,
                  padding: const EdgeInsets.all(8),
                  itemCount: svc.buildLog.length,
                  itemBuilder: (_, i) {
                    final line = svc.buildLog[i];
                    final color = line.startsWith('⚠') ? _appleAmber
                        : line.startsWith('[') && line.contains('✓') ? _appleGreen
                        : line.startsWith('[') && line.contains('✗') ? _appleRed
                        : const Color(0xFFCDD6F4);
                    return Text(line, style: TextStyle(fontFamily: 'monospace', fontSize: 10, color: color, height: 1.5));
                  },
                ),
        ),
      ),
    ]);
  }
}

class _BuildStatusBar extends StatelessWidget {
  final AppleBuildStatus status;
  final String? artifactPath;
  const _BuildStatusBar({required this.status, this.artifactPath});

  @override
  Widget build(BuildContext context) {
    final (color, icon, label) = switch (status) {
      AppleBuildStatus.running   => (_appleBlue, Icons.sync_rounded, 'Building…'),
      AppleBuildStatus.succeeded => (_appleGreen, Icons.check_circle_rounded, 'Build succeeded'),
      AppleBuildStatus.failed    => (_appleRed, Icons.error_rounded, 'Build failed'),
      _                          => (SwarmColors.textDisabled, Icons.circle_outlined, 'Idle'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      color: color.withValues(alpha: 0.08),
      child: Row(children: [
        status == AppleBuildStatus.running
            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 1.5, color: _appleBlue))
            : Icon(icon, size: 14, color: color),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold)),
        if (artifactPath != null) ...[
          const SizedBox(width: 8),
          Expanded(child: Text(artifactPath!, style: const TextStyle(fontFamily: 'monospace', fontSize: 10, color: SwarmColors.textMuted), overflow: TextOverflow.ellipsis)),
          IconButton(
            icon: const Icon(Icons.copy_rounded, size: 12, color: SwarmColors.textMuted),
            tooltip: 'Copy path',
            onPressed: () => Clipboard.setData(ClipboardData(text: artifactPath!)),
            constraints: const BoxConstraints(), padding: const EdgeInsets.all(4),
          ),
        ],
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// TAB 3 — SIGNING
// ══════════════════════════════════════════════════════════════════════════════
class _SigningTab extends StatefulWidget {
  final AppleBuildService svc;
  const _SigningTab({required this.svc});

  @override
  State<_SigningTab> createState() => _SigningTabState();
}

class _SigningTabState extends State<_SigningTab> {
  late TextEditingController _bundleCtrl;
  late TextEditingController _teamCtrl;

  static const _exportMethods = ['development', 'ad-hoc', 'app-store', 'enterprise'];

  @override
  void initState() {
    super.initState();
    _bundleCtrl = TextEditingController(text: widget.svc.bundleId);
    _teamCtrl   = TextEditingController(text: widget.svc.teamId);
  }

  @override
  void dispose() {
    _bundleCtrl.dispose();
    _teamCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final svc = widget.svc;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── App Identity ────────────────────────────────────────────────────
        const _SLabel('APP IDENTITY'),
        _Field('Bundle Identifier', _bundleCtrl, 'com.example.myapp', onChanged: (v) { svc.bundleId = v; svc.saveConfig(); }),
        const SizedBox(height: 8),
        _Field('Team ID', _teamCtrl, 'ABCD123456', onChanged: (v) { svc.teamId = v; svc.saveConfig(); }),
        const SizedBox(height: 14),

        // ── Code Signing Identity ──────────────────────────────────────────
        const _SLabel('CODE SIGNING IDENTITY'),
        if (svc.certificates.isEmpty)
          _InfoCard(Icons.info_outline_rounded, 'No certificates found.\nConnect to a Mac via SSH or run on macOS.', _appleAmber)
        else
          ...svc.certificates.map((cert) => _CertRow(cert: cert, isSelected: svc.codeSignIdentity == cert.sha1, onSelect: () {
            setState(() => svc.codeSignIdentity = cert.sha1);
          })),
        const SizedBox(height: 6),
        Row(children: [
          _SmallBtn('Refresh', _appleBlue, svc.refreshCertificates),
          const SizedBox(width: 6),
          _SmallBtn('Open Keychain', _appleGray, () async {
            await Process.run('open', ['/Applications/Utilities/Keychain Access.app']);
          }),
        ]),
        const SizedBox(height: 14),

        // ── Provisioning Profile ───────────────────────────────────────────
        const _SLabel('PROVISIONING PROFILE'),
        if (svc.profiles.isEmpty)
          _InfoCard(Icons.info_outline_rounded, 'No profiles found in ~/Library/MobileDevice/Provisioning Profiles', _appleAmber)
        else
          ...svc.profiles.map((p) => _ProfileRow(profile: p, isSelected: svc.selectedProfileUuid == p.uuid, onSelect: () {
            setState(() => svc.selectedProfileUuid = p.uuid);
          })),
        const SizedBox(height: 6),
        Row(children: [
          _SmallBtn('Refresh', _appleBlue, svc.refreshProfiles),
          const SizedBox(width: 6),
          _SmallBtn('Download from Portal', _appleGray, () {}),
        ]),
        const SizedBox(height: 14),

        // ── Export Method ──────────────────────────────────────────────────
        const _SLabel('EXPORT METHOD'),
        Wrap(spacing: 6, children: _exportMethods.map((m) => ChoiceChip(
          label: Text(m, style: const TextStyle(fontSize: 10)),
          selected: svc.exportMethod == m,
          onSelected: (_) => setState(() => svc.exportMethod = m),
          selectedColor: _appleBlue.withValues(alpha: 0.2),
          backgroundColor: SwarmColors.bgElevated,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4), side: BorderSide(color: svc.exportMethod == m ? _appleBlue : SwarmColors.border)),
          labelStyle: TextStyle(color: svc.exportMethod == m ? _appleBlue : SwarmColors.textMuted),
        )).toList()),
        const SizedBox(height: 14),

        // ── Export Options Plist ───────────────────────────────────────────
        const _SLabel('EXPORT OPTIONS'),
        _ExportOptionsPlistCard(svc: svc),
      ]),
    );
  }
}

class _CertRow extends StatelessWidget {
  final AppleCertificate cert;
  final bool isSelected;
  final VoidCallback onSelect;
  const _CertRow({required this.cert, required this.isSelected, required this.onSelect});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onSelect,
        child: Container(
          margin: const EdgeInsets.only(bottom: 4),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? _appleBlue.withValues(alpha: 0.1) : SwarmColors.bgElevated,
            borderRadius: BorderRadius.circular(5),
            border: Border.all(color: isSelected ? _appleBlue : SwarmColors.border),
          ),
          child: Row(children: [
            Icon(cert.type == 'Distribution' ? Icons.verified_rounded : Icons.developer_mode_rounded, size: 14, color: isSelected ? _appleBlue : SwarmColors.textMuted),
            const SizedBox(width: 8),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(cert.name, style: const TextStyle(fontSize: 11, color: SwarmColors.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
              Text(cert.sha1.substring(0, 20), style: const TextStyle(fontFamily: 'monospace', fontSize: 9, color: SwarmColors.textDisabled)),
            ])),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(color: (cert.type == 'Distribution' ? _appleBlue : _appleGreen).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(3)),
              child: Text(cert.type, style: TextStyle(fontSize: 9, color: cert.type == 'Distribution' ? _appleBlue : _appleGreen, fontWeight: FontWeight.bold)),
            ),
          ]),
        ),
      );
}

class _ProfileRow extends StatelessWidget {
  final ProvisioningProfile profile;
  final bool isSelected;
  final VoidCallback onSelect;
  const _ProfileRow({required this.profile, required this.isSelected, required this.onSelect});

  Color get _typeColor => switch (profile.type) {
    'appstore'    => _appleBlue,
    'ad-hoc'      => _appleAmber,
    'enterprise'  => _appleRed,
    _             => _appleGreen,
  };

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onSelect,
        child: Container(
          margin: const EdgeInsets.only(bottom: 4),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? _appleBlue.withValues(alpha: 0.1) : SwarmColors.bgElevated,
            borderRadius: BorderRadius.circular(5),
            border: Border.all(color: isSelected ? _appleBlue : SwarmColors.border),
          ),
          child: Row(children: [
            Icon(Icons.description_rounded, size: 14, color: isSelected ? _appleBlue : SwarmColors.textMuted),
            const SizedBox(width: 8),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(profile.name, style: const TextStyle(fontSize: 11, color: SwarmColors.textPrimary)),
              Text('${profile.bundleId} · ${profile.uuid.substring(0, 8)}…', style: const TextStyle(fontFamily: 'monospace', fontSize: 9, color: SwarmColors.textDisabled)),
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(color: _typeColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(3)),
                child: Text(profile.type, style: TextStyle(fontSize: 9, color: _typeColor, fontWeight: FontWeight.bold)),
              ),
              if (profile.expiry != null)
                Text(_daysUntil(profile.expiry!), style: TextStyle(fontSize: 9, color: profile.isExpired ? _appleRed : SwarmColors.textDisabled)),
            ]),
          ]),
        ),
      );

  static String _daysUntil(DateTime d) {
    final diff = d.difference(DateTime.now()).inDays;
    if (diff < 0) return 'Expired';
    if (diff < 30) return 'Expires in $diff days';
    return 'Expires ${d.month}/${d.year}';
  }
}

class _ExportOptionsPlistCard extends StatelessWidget {
  final AppleBuildService svc;
  const _ExportOptionsPlistCard({required this.svc});

  @override
  Widget build(BuildContext context) {
    final plist = '''<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
 "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key>
  <string>${svc.exportMethod}</string>
  <key>teamID</key>
  <string>${svc.teamId.isEmpty ? 'YOUR_TEAM_ID' : svc.teamId}</string>
  <key>provisioningProfiles</key>
  <dict>
    <key>${svc.bundleId}</key>
    <string>${svc.selectedProfileUuid.isEmpty ? 'YOUR_PROFILE_UUID' : svc.selectedProfileUuid}</string>
  </dict>
  <key>compileBitcode</key>
  <false/>
</dict>
</plist>''';
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: const Color(0xFF050310), borderRadius: BorderRadius.circular(6), border: Border.all(color: SwarmColors.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('ExportOptions.plist', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: SwarmColors.textMuted)),
          const Spacer(),
          IconButton(icon: const Icon(Icons.copy_rounded, size: 12, color: SwarmColors.textMuted), onPressed: () => Clipboard.setData(ClipboardData(text: plist)), constraints: const BoxConstraints(), padding: const EdgeInsets.all(4)),
          IconButton(icon: const Icon(Icons.save_rounded, size: 12, color: _appleBlue), tooltip: 'Save to project', onPressed: () async {
            // Save to project root
          }, constraints: const BoxConstraints(), padding: const EdgeInsets.all(4)),
        ]),
        const SizedBox(height: 4),
        Text(plist, style: const TextStyle(fontFamily: 'monospace', fontSize: 10, color: Color(0xFFCDD6F4), height: 1.5)),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// TAB 4 — APP STORE
// ══════════════════════════════════════════════════════════════════════════════
class _AppStoreTab extends StatefulWidget {
  final AppleBuildService svc;
  const _AppStoreTab({required this.svc});

  @override
  State<_AppStoreTab> createState() => _AppStoreTabState();
}

class _AppStoreTabState extends State<_AppStoreTab> {
  late TextEditingController _appleIdCtrl;
  late TextEditingController _passCtrl;
  late TextEditingController _ipaCtrl;
  bool _obscurePass = true;

  @override
  void initState() {
    super.initState();
    _appleIdCtrl = TextEditingController(text: widget.svc.appleId);
    _passCtrl    = TextEditingController(text: widget.svc.appSpecificPassword);
    _ipaCtrl     = TextEditingController(text: widget.svc.ipaPath);
  }

  @override
  void dispose() {
    _appleIdCtrl.dispose();
    _passCtrl.dispose();
    _ipaCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final svc = widget.svc;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── App Store Connect Auth ──────────────────────────────────────────
        const _SLabel('APP STORE CONNECT CREDENTIALS'),
        _Field('Apple ID (email)', _appleIdCtrl, 'you@example.com', onChanged: (v) { svc.appleId = v; svc.saveConfig(); }),
        const SizedBox(height: 8),
        // App-specific password field with toggle
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const _SLabel('APP-SPECIFIC PASSWORD'),
          TextField(
            controller: _passCtrl,
            obscureText: _obscurePass,
            onChanged: (v) => svc.appSpecificPassword = v,
            style: const TextStyle(fontSize: 12, color: SwarmColors.textPrimary, fontFamily: 'monospace'),
            decoration: InputDecoration(
              hintText: 'xxxx-xxxx-xxxx-xxxx',
              hintStyle: const TextStyle(color: SwarmColors.textDisabled, fontSize: 11),
              isDense: true, filled: true, fillColor: SwarmColors.bgElevated,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: SwarmColors.border)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              suffixIcon: IconButton(icon: Icon(_obscurePass ? Icons.visibility_rounded : Icons.visibility_off_rounded, size: 16, color: SwarmColors.textMuted), onPressed: () => setState(() => _obscurePass = !_obscurePass)),
            ),
          ),
        ]),
        const SizedBox(height: 4),
        const Text('Generate at appleid.apple.com → Security → App-Specific Passwords', style: TextStyle(fontSize: 10, color: SwarmColors.textDisabled)),
        const SizedBox(height: 14),

        // ── IPA Selection ──────────────────────────────────────────────────
        const _SLabel('IPA FILE'),
        Row(children: [
          Expanded(child: TextField(
            controller: _ipaCtrl,
            onChanged: (v) => svc.ipaPath = v,
            style: const TextStyle(fontSize: 11, color: SwarmColors.textPrimary, fontFamily: 'monospace'),
            decoration: const InputDecoration(
              hintText: 'build/ios/ipa/Runner.ipa',
              hintStyle: TextStyle(color: SwarmColors.textDisabled, fontSize: 11),
              isDense: true, filled: true, fillColor: SwarmColors.bgElevated,
              border: OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: BorderSide(color: SwarmColors.border)),
              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            ),
          )),
          const SizedBox(width: 4),
          ElevatedButton(
            onPressed: () async {
              final f = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: ['ipa']);
              if (f?.path != null) { _ipaCtrl.text = f!.path!; svc.ipaPath = f.path!; }
            },
            style: ElevatedButton.styleFrom(backgroundColor: SwarmColors.bgElevated, foregroundColor: SwarmColors.textSecondary, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10), shape: const RoundedRectangleBorder()),
            child: const Icon(Icons.folder_open_rounded, size: 16),
          ),
        ]),
        const SizedBox(height: 14),

        // ── Upload ─────────────────────────────────────────────────────────
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: svc.isBuilding ? null : () => svc.uploadToAppStore(_ipaCtrl.text),
            icon: svc.isBuilding ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black)) : const Icon(Icons.upload_rounded, size: 16),
            label: Text(svc.isBuilding ? 'Uploading…' : 'Upload to App Store Connect', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(backgroundColor: _appleBlue, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6))),
          ),
        ),
        const SizedBox(height: 14),

        // ── TestFlight ─────────────────────────────────────────────────────
        const _SLabel('TESTFLIGHT'),
        _InfoCard(Icons.bug_report_rounded, 'After uploading, the build appears in App Store Connect → TestFlight within 15 min.\nAdd testers, set build notes, and send invitations from the web portal.', _appleBlue),
        const SizedBox(height: 10),
        Row(children: [
          _SmallBtn('Open App Store Connect', _appleBlue, () async {
            // Would open the browser — just log for now
          }),
          const SizedBox(width: 6),
          _SmallBtn('Validate Before Upload', _appleGray, () => svc.uploadToAppStore(_ipaCtrl.text)),
        ]),
        const SizedBox(height: 14),

        // ── Notarization (macOS) ───────────────────────────────────────────
        const _SLabel('MACOS NOTARIZATION'),
        _InfoCard(Icons.verified_user_rounded, 'For macOS apps, run notarytool after building:\n\nxcrun notarytool submit Runner.app.zip --apple-id \$APPLE_ID --password \$PASS --team-id \$TEAM_ID --wait', _appleGray),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: const Color(0xFF050310), borderRadius: BorderRadius.circular(6), border: Border.all(color: SwarmColors.border)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Notarization checklist', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: SwarmColors.textMuted)),
            const SizedBox(height: 6),
            ...[
              '✓ Hardened Runtime enabled in Xcode',
              '✓ Code signed with Developer ID certificate',
              '✓ No restricted entitlements without justification',
              '✓ All embedded binaries are signed',
              '✓ App bundle zipped before submission',
            ].map((s) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 1),
              child: Text(s, style: const TextStyle(fontSize: 10, color: SwarmColors.textSecondary, fontFamily: 'monospace')),
            )),
          ]),
        ),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// TAB 5 — CAPABILITIES
// ══════════════════════════════════════════════════════════════════════════════
class _CapabilitiesTab extends StatefulWidget {
  final AppleBuildService svc;
  final List<AppleCapability> capabilities;
  final String? projectPath;
  const _CapabilitiesTab({required this.svc, required this.capabilities, this.projectPath});

  @override
  State<_CapabilitiesTab> createState() => _CapabilitiesTabState();
}

class _CapabilitiesTabState extends State<_CapabilitiesTab> {
  bool _saved = false;

  @override
  Widget build(BuildContext context) {
    final caps = widget.capabilities;
    final enabledCount = caps.where((c) => c.enabled).length;

    return Column(children: [
      // Header strip
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        color: SwarmColors.bgSurface,
        child: Row(children: [
          Text('$enabledCount of ${caps.length} capabilities enabled', style: const TextStyle(fontSize: 11, color: SwarmColors.textMuted)),
          const Spacer(),
          if (_saved)
            const Row(children: [
              Icon(Icons.check_circle_rounded, size: 13, color: _appleGreen),
              SizedBox(width: 4),
              Text('Saved', style: TextStyle(fontSize: 10, color: _appleGreen)),
              SizedBox(width: 8),
            ]),
          ElevatedButton.icon(
            onPressed: () async {
              if (widget.projectPath != null) {
                await widget.svc.writeEntitlementsFile(widget.projectPath!, caps);
                setState(() => _saved = true);
                Future.delayed(const Duration(seconds: 2), () { if (mounted) setState(() => _saved = false); });
              }
            },
            icon: const Icon(Icons.save_rounded, size: 13),
            label: const Text('Write .entitlements', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(backgroundColor: _appleBlue, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4))),
          ),
        ]),
      ),
      const Divider(height: 1, color: SwarmColors.border),
      // Capabilities list
      Expanded(
        child: ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 6),
          itemCount: caps.length,
          itemBuilder: (_, i) => _CapabilityRow(
            cap: caps[i],
            onToggle: (v) => setState(() => caps[i].enabled = v),
          ),
        ),
      ),
      // Entitlements preview
      if (enabledCount > 0)
        _EntitlementsPreview(caps: caps.where((c) => c.enabled).toList(), svc: widget.svc),
    ]);
  }
}

class _CapabilityRow extends StatelessWidget {
  final AppleCapability cap;
  final ValueChanged<bool> onToggle;
  const _CapabilityRow({required this.cap, required this.onToggle});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: cap.enabled ? _appleBlue.withValues(alpha: 0.07) : SwarmColors.bgElevated,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: cap.enabled ? _appleBlue.withValues(alpha: 0.4) : SwarmColors.border),
        ),
        child: Row(children: [
          Text(cap.icon, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(cap.name, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: cap.enabled ? SwarmColors.textPrimary : SwarmColors.textSecondary)),
            Text(cap.description, style: const TextStyle(fontSize: 10, color: SwarmColors.textMuted), maxLines: 1, overflow: TextOverflow.ellipsis),
          ])),
          Switch(
            value: cap.enabled,
            onChanged: onToggle,
            activeThumbColor: _appleBlue,
            trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? _appleBlue.withValues(alpha: 0.35) : SwarmColors.bgElevated),
          ),
        ]),
      );
}

class _EntitlementsPreview extends StatelessWidget {
  final List<AppleCapability> caps;
  final AppleBuildService svc;
  const _EntitlementsPreview({required this.caps, required this.svc});

  @override
  Widget build(BuildContext context) => Container(
        decoration: const BoxDecoration(border: Border(top: BorderSide(color: SwarmColors.border))),
        padding: const EdgeInsets.all(10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Runner.entitlements preview', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: SwarmColors.textMuted)),
          const SizedBox(height: 6),
          Container(
            height: 100,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: const Color(0xFF050310), borderRadius: BorderRadius.circular(4)),
            child: SingleChildScrollView(
              child: Text(
                caps.map((c) => '  <key>${c.entitlementKey}</key>\n  <true/>').join('\n'),
                style: const TextStyle(fontFamily: 'monospace', fontSize: 9, color: Color(0xFF89DCEB), height: 1.6),
              ),
            ),
          ),
        ]),
      );
}

// ══════════════════════════════════════════════════════════════════════════════
// SSH CONFIG STRIP
// ══════════════════════════════════════════════════════════════════════════════
class _SshStrip extends StatefulWidget {
  final AppleBuildService svc;
  const _SshStrip({required this.svc});

  @override
  State<_SshStrip> createState() => _SshStripState();
}

class _SshStripState extends State<_SshStrip> {
  bool _expanded = false;
  late TextEditingController _hostCtrl, _userCtrl, _keyCtrl;

  @override
  void initState() {
    super.initState();
    _hostCtrl = TextEditingController(text: widget.svc.sshHost);
    _userCtrl = TextEditingController(text: widget.svc.sshUser);
    _keyCtrl  = TextEditingController(text: widget.svc.sshKeyPath);
  }

  @override
  void dispose() {
    _hostCtrl.dispose(); _userCtrl.dispose(); _keyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasSsh = widget.svc.sshHost.isNotEmpty;
    return Column(children: [
      InkWell(
        onTap: () => setState(() => _expanded = !_expanded),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          color: hasSsh ? _appleGreen.withValues(alpha: 0.06) : SwarmColors.bgSurface,
          child: Row(children: [
            Icon(Icons.computer_rounded, size: 13, color: hasSsh ? _appleGreen : SwarmColors.textMuted),
            const SizedBox(width: 6),
            Text(hasSsh ? 'Mac Build Machine: ${widget.svc.sshUser}@${widget.svc.sshHost}' : 'Mac Build Machine: not configured (local Flutter only)',
                style: TextStyle(fontSize: 10, color: hasSsh ? _appleGreen : SwarmColors.textMuted)),
            const Spacer(),
            Icon(_expanded ? Icons.expand_less : Icons.expand_more, size: 14, color: SwarmColors.textMuted),
          ]),
        ),
      ),
      if (_expanded)
        Container(
          padding: const EdgeInsets.all(10),
          color: SwarmColors.bgSurface,
          child: Column(children: [
            Row(children: [
              Expanded(child: _TinyField('Host', _hostCtrl)),
              const SizedBox(width: 6),
              Expanded(child: _TinyField('User', _userCtrl)),
            ]),
            const SizedBox(height: 6),
            _TinyField('SSH Key Path (optional)', _keyCtrl),
            const SizedBox(height: 8),
            Row(children: [
              _SmallBtn('Save', _appleBlue, () {
                widget.svc.sshHost = _hostCtrl.text;
                widget.svc.sshUser = _userCtrl.text;
                widget.svc.sshKeyPath = _keyCtrl.text;
                widget.svc.saveConfig();
                setState(() => _expanded = false);
              }),
              const SizedBox(width: 6),
              _SmallBtn('Test Connection', _appleGray, () async {
                if (widget.svc.sshHost.isEmpty) return;
                final r = await Process.run('ssh', [
                  if (widget.svc.sshKeyPath.isNotEmpty) ...['-i', widget.svc.sshKeyPath],
                  '${widget.svc.sshUser}@${widget.svc.sshHost}',
                  'sw_vers -productVersion',
                ]);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(r.exitCode == 0 ? 'Connected! macOS ${(r.stdout as String).trim()}' : 'Connection failed: ${r.stderr}'),
                    backgroundColor: r.exitCode == 0 ? _appleGreen.withValues(alpha: 0.8) : _appleRed.withValues(alpha: 0.8),
                    duration: const Duration(seconds: 3),
                  ));
                }
              }),
            ]),
          ]),
        ),
    ]);
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// SHARED WIDGETS
// ══════════════════════════════════════════════════════════════════════════════
class _AppleLogo extends StatelessWidget {
  const _AppleLogo();
  @override
  Widget build(BuildContext context) => const Text('', style: TextStyle(fontSize: 20)); // Apple emoji SF Symbol fallback
}

class _StatusPill extends StatelessWidget {
  final AppleBuildService svc;
  const _StatusPill({required this.svc});

  @override
  Widget build(BuildContext context) {
    if (!svc.isBuilding) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: _appleBlue.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
      child: const Row(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(width: 10, height: 10, child: CircularProgressIndicator(strokeWidth: 1.5, color: _appleBlue)),
        SizedBox(width: 5),
        Text('Building', style: TextStyle(fontSize: 10, color: _appleBlue, fontWeight: FontWeight.bold)),
      ]),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: selected ? _appleBlue.withValues(alpha: 0.2) : SwarmColors.bgElevated,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: selected ? _appleBlue : SwarmColors.border),
          ),
          child: Text(label, style: TextStyle(fontSize: 10, color: selected ? _appleBlue : SwarmColors.textMuted, fontWeight: selected ? FontWeight.bold : FontWeight.normal)),
        ),
      );
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String text;
  const _EmptyState({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 40, color: SwarmColors.textDisabled),
          const SizedBox(height: 10),
          Text(text, style: const TextStyle(fontSize: 11, color: SwarmColors.textMuted, height: 1.5), textAlign: TextAlign.center),
        ]),
      );
}

class _SLabel extends StatelessWidget {
  final String text;
  const _SLabel(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 5),
        child: Text(text, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: SwarmColors.textMuted, letterSpacing: 1.2)),
      );
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  const _InfoCard(this.icon, this.text, this.color);

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.07), borderRadius: BorderRadius.circular(6), border: Border.all(color: color.withValues(alpha: 0.3))),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: TextStyle(fontSize: 10, color: color, height: 1.5, fontFamily: text.contains('\n') ? 'monospace' : null))),
        ]),
      );
}

class _SmallBtn extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _SmallBtn(this.label, this.color, this.onTap);

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(4), border: Border.all(color: color.withValues(alpha: 0.4))),
          child: Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold)),
        ),
      );
}

class _ActionBtn extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;
  const _ActionBtn(this.label, this.color, this.icon, this.onTap);

  @override
  Widget build(BuildContext context) => ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 14),
        label: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
        style: ElevatedButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5))),
      );
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  const _IconBtn(this.icon, this.tooltip, this.onTap);

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(5),
          child: Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(color: SwarmColors.bgElevated, borderRadius: BorderRadius.circular(5), border: Border.all(color: SwarmColors.border)),
            child: Icon(icon, size: 16, color: SwarmColors.textMuted),
          ),
        ),
      );
}

class _Field extends StatelessWidget {
  final String label, hint;
  final TextEditingController ctrl;
  final ValueChanged<String>? onChanged;
  const _Field(this.label, this.ctrl, this.hint, {this.onChanged});

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    _SLabel(label.toUpperCase()),
    TextField(
      controller: ctrl,
      onChanged: onChanged,
      style: const TextStyle(fontSize: 12, color: SwarmColors.textPrimary, fontFamily: 'monospace'),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: SwarmColors.textDisabled, fontSize: 11),
        isDense: true, filled: true, fillColor: SwarmColors.bgElevated,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: SwarmColors.border)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      ),
    ),
  ]);
}

class _TinyField extends StatelessWidget {
  final String label;
  final TextEditingController ctrl;
  const _TinyField(this.label, this.ctrl);

  @override
  Widget build(BuildContext context) => TextField(
        controller: ctrl,
        style: const TextStyle(fontSize: 11, color: SwarmColors.textPrimary, fontFamily: 'monospace'),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(fontSize: 10, color: SwarmColors.textMuted),
          isDense: true, filled: true, fillColor: const Color(0xFF0A0818),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(3), borderSide: const BorderSide(color: SwarmColors.border)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        ),
      );
}

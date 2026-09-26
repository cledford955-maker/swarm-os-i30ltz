import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../theme/swarm_colors.dart';

// ─── Keystore Config ─────────────────────────────────────────────────────────
class KeystoreConfig {
  final String path;
  final String alias;
  final String storePassword;
  final String keyPassword;

  const KeystoreConfig({required this.path, required this.alias, required this.storePassword, required this.keyPassword});

  Map<String, String> toGradleProps() => {
    'KEYSTORE_PATH': path,
    'KEY_ALIAS': alias,
    'KEY_STORE_PASSWORD': storePassword,
    'KEY_PASSWORD': keyPassword,
  };
}

// ─── Signing & AAB Panel ─────────────────────────────────────────────────────
class SigningPanel extends StatefulWidget {
  final String? projectPath;
  const SigningPanel({super.key, this.projectPath});

  @override
  State<SigningPanel> createState() => _SigningPanelState();
}

class _SigningPanelState extends State<SigningPanel> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  // Bundletool validation
  String? _validateAabPath;
  bool _validating = false;
  String? _validateResult;

  // Keystore creation fields
  final _ksPathCtrl = TextEditingController();
  final _ksAliaCtrl = TextEditingController(text: 'upload');
  final _ksPwdCtrl = TextEditingController();
  final _keyPwdCtrl = TextEditingController();
  final _orgCtrl = TextEditingController();
  final _countryCtrl = TextEditingController(text: 'US');
  bool _ksPwdVisible = false, _keyPwdVisible = false;
  String? _keystoreStatus;

  // AAB build
  String _aabBuildType = 'release';
  bool _aabBuilding = false;
  double _aabProgress = 0;
  final List<String> _aabLog = [];
  String? _aabOutputPath;

  // Play Console
  final _packageCtrl = TextEditingController();
  final _serviceAccCtrl = TextEditingController();
  String _trackName = 'internal';
  bool _uploading = false;
  String? _uploadStatus;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 4, vsync: this);
    _ksPathCtrl.text = '${Platform.environment['HOME'] ?? ''}/upload-keystore.jks';
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    for (final c in [_ksPathCtrl, _ksAliaCtrl, _ksPwdCtrl, _keyPwdCtrl, _orgCtrl, _countryCtrl, _packageCtrl, _serviceAccCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  // ── Keystore operations ───────────────────────────────────────────────────

  Future<void> _generateKeystore() async {
    if (_ksPwdCtrl.text.isEmpty || _keyPwdCtrl.text.isEmpty) {
      setState(() => _keystoreStatus = 'ERROR: Fill in all password fields.');
      return;
    }
    setState(() => _keystoreStatus = 'Generating keystore...');
    try {
      final args = [
        '-genkeypair',
        '-v',
        '-keystore', _ksPathCtrl.text,
        '-alias', _ksAliaCtrl.text,
        '-keyalg', 'RSA',
        '-keysize', '2048',
        '-validity', '10000',
        '-storepass', _ksPwdCtrl.text,
        '-keypass', _keyPwdCtrl.text,
        '-dname', 'CN=${_orgCtrl.text.isEmpty ? 'Unknown' : _orgCtrl.text},C=${_countryCtrl.text}',
      ];
      final r = await Process.run('keytool', args);
      if (r.exitCode == 0) {
        setState(() => _keystoreStatus = '✓ Keystore created at ${_ksPathCtrl.text}');
        _writeKeyProperties();
      } else {
        setState(() => _keystoreStatus = 'ERROR: ${r.stderr}');
      }
    } catch (e) {
      setState(() => _keystoreStatus = 'ERROR: keytool not found. Install JDK.\n$e');
    }
  }

  void _writeKeyProperties() {
    if (widget.projectPath == null) return;
    final propsPath = '${widget.projectPath}/android/key.properties';
    final content = '''storePassword=${_ksPwdCtrl.text}
keyPassword=${_keyPwdCtrl.text}
keyAlias=${_ksAliaCtrl.text}
storeFile=${_ksPathCtrl.text}
''';
    File(propsPath).writeAsStringSync(content);
  }

  Future<void> _browseKeystore() async {
    final r = await FilePicker.pickFile(type: FileType.any);
    if (r != null && r.path != null) setState(() => _ksPathCtrl.text = r.path!);
  }

  Future<void> _showKeystoreInfo() async {
    if (_ksPathCtrl.text.isEmpty) return;
    try {
      final r = await Process.run('keytool', ['-list', '-v', '-keystore', _ksPathCtrl.text, '-storepass', _ksPwdCtrl.text]);
      setState(() => _keystoreStatus = r.stdout.toString().isEmpty ? r.stderr.toString() : r.stdout.toString());
    } catch (e) {
      setState(() => _keystoreStatus = 'ERROR: $e');
    }
  }

  // ── AAB build ─────────────────────────────────────────────────────────────

  Future<void> _buildAab() async {
    if (widget.projectPath == null) return;
    setState(() { _aabBuilding = true; _aabProgress = 0.05; _aabLog.clear(); _aabOutputPath = null; });

    try {
      final gradlew = '${widget.projectPath}/android/gradlew';
      final hasGradle = File(gradlew).existsSync();
      final cmd = hasGradle ? gradlew : 'flutter';
      final args = hasGradle
          ? ['bundle${_aabBuildType == 'debug' ? 'Debug' : 'Release'}']
          : ['build', 'appbundle', if (_aabBuildType == 'release') '--release'];

      _log('> $cmd ${args.join(' ')}');

      final process = await Process.start(cmd, args, workingDirectory: widget.projectPath);
      int lineCount = 0;
      process.stdout.transform(const SystemEncoding().decoder).listen((data) {
        for (final line in data.split('\n')) {
          if (line.trim().isEmpty) continue;
          lineCount++;
          if (mounted) {
            setState(() {
            _aabLog.add(line);
            _aabProgress = (lineCount / 120).clamp(0.05, 0.9);
          });
          }
        }
      });
      process.stderr.transform(const SystemEncoding().decoder).listen((data) {
        if (mounted) setState(() => _aabLog.add('ERR: $data'));
      });

      final exit = await process.exitCode;
      // Find output
      final candidates = [
        '${widget.projectPath}/build/app/outputs/bundle/release/app-release.aab',
        '${widget.projectPath}/build/app/outputs/bundle/debug/app-debug.aab',
        '${widget.projectPath}/build/app/outputs/bundle/$_aabBuildType/app-$_aabBuildType.aab',
      ];
      final found = candidates.firstWhere((p) => File(p).existsSync(), orElse: () => '');

      if (mounted) {
        setState(() {
        _aabBuilding = false;
        _aabProgress = exit == 0 ? 1.0 : _aabProgress;
        _aabOutputPath = found.isNotEmpty ? found : null;
        _aabLog.add(exit == 0 ? '\n✓ AAB BUILD SUCCESSFUL' : '\n✗ AAB BUILD FAILED (exit $exit)');
        if (found.isNotEmpty) _aabLog.add('Output: $found');
      });
      }
    } catch (e) {
      if (mounted) setState(() { _aabBuilding = false; _aabLog.add('ERROR: $e'); });
    }
  }

  void _log(String msg) => setState(() => _aabLog.add(msg));

  // ── Play Console upload ───────────────────────────────────────────────────

  Future<void> _uploadToPlay() async {
    if (_aabOutputPath == null) {
      setState(() => _uploadStatus = 'ERROR: Build an AAB first.');
      return;
    }
    if (_packageCtrl.text.isEmpty || _serviceAccCtrl.text.isEmpty) {
      setState(() => _uploadStatus = 'ERROR: Fill in package name and service account key path.');
      return;
    }
    setState(() { _uploading = true; _uploadStatus = 'Uploading to Google Play Console...'; });

    // Use bundletool or gcloud if available, otherwise guide user
    try {
      // Try using google cloud CLI
      final r = await Process.run('gcloud', ['--version']);
      if (r.exitCode == 0) {
        // gcloud is available
        final upload = await Process.run('gcloud', [
          'alpha', 'apigee', 'archives', 'upload',
          '--bundle', _aabOutputPath!,
        ]);
        setState(() {
          _uploading = false;
          _uploadStatus = upload.exitCode == 0 ? '✓ Upload successful!' : 'ERROR: ${upload.stderr}';
        });
      } else {
        setState(() {
          _uploading = false;
          _uploadStatus = 'Tip: Use Google Play Console web UI at play.google.com/console to upload:\n${_aabOutputPath!}';
        });
      }
    } catch (_) {
      setState(() {
        _uploading = false;
        _uploadStatus = 'Manual upload: Open play.google.com/console\n→ Select app → Production/Internal\n→ Create new release → Upload AAB:\n${_aabOutputPath ?? 'Build AAB first'}';
      });
    }
  }

  // ── Bundletool validation ──────────────────────────────────────────────────

  Future<void> _browseAab() async {
    final r = await FilePicker.pickFile(type: FileType.any);
    if (r?.path != null) setState(() { _validateAabPath = r!.path; _validateResult = null; });
  }

  Future<void> _validateBundle() async {
    if (_validateAabPath == null) { setState(() => _validateResult = 'ERROR: Pick an AAB file first.'); return; }
    setState(() { _validating = true; _validateResult = 'Running bundletool validate…'; });
    try {
      // Try bundletool on PATH first, then java -jar bundletool.jar
      final r = await Process.run('bundletool', ['validate', '--bundle=$_validateAabPath']);
      if (r.exitCode == 0) {
        setState(() { _validating = false; _validateResult = '✓ Bundle is VALID\n\n${r.stdout}'; });
      } else {
        setState(() { _validating = false; _validateResult = 'INVALID BUNDLE\n${r.stderr}\n${r.stdout}'; });
      }
    } catch (_) {
      // bundletool not on PATH — try java -jar approach
      try {
        final homeDir = Platform.environment['HOME'] ?? '';
        final jarPaths = ['$homeDir/bundletool.jar', '$homeDir/.local/bin/bundletool.jar', '/usr/local/lib/bundletool.jar'];
        final jar = jarPaths.firstWhere((p) => File(p).existsSync(), orElse: () => '');
        if (jar.isEmpty) {
          setState(() { _validating = false; _validateResult = 'bundletool not found.\n\nInstall with:\n  brew install bundletool\nor download from:\n  github.com/google/bundletool/releases\nand place bundletool.jar in your HOME directory.'; });
          return;
        }
        final r = await Process.run('java', ['-jar', jar, 'validate', '--bundle=$_validateAabPath']);
        setState(() {
          _validating = false;
          _validateResult = r.exitCode == 0 ? '✓ Bundle is VALID\n\n${r.stdout}' : 'INVALID BUNDLE\n${r.stderr}\n${r.stdout}';
        });
      } catch (e) {
        setState(() { _validating = false; _validateResult = 'ERROR: $e'; });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Column(children: [
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
              Tab(text: 'KEYSTORE', height: 32),
              Tab(text: 'BUILD AAB', height: 32),
              Tab(text: 'VALIDATE', height: 32),
              Tab(text: 'PLAY CONSOLE', height: 32),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabCtrl,
            children: [
              _KeystoreTab(
                pathCtrl: _ksPathCtrl, aliasCtrl: _ksAliaCtrl,
                storePwdCtrl: _ksPwdCtrl, keyPwdCtrl: _keyPwdCtrl,
                orgCtrl: _orgCtrl, countryCtrl: _countryCtrl,
                ksPwdVisible: _ksPwdVisible, keyPwdVisible: _keyPwdVisible,
                onToggleKsPwd: () => setState(() => _ksPwdVisible = !_ksPwdVisible),
                onToggleKeyPwd: () => setState(() => _keyPwdVisible = !_keyPwdVisible),
                onGenerate: _generateKeystore, onBrowse: _browseKeystore, onInfo: _showKeystoreInfo,
                status: _keystoreStatus,
              ),
              _AabTab(
                buildType: _aabBuildType, building: _aabBuilding, progress: _aabProgress,
                log: _aabLog, outputPath: _aabOutputPath,
                projectPath: widget.projectPath,
                onBuildTypeChanged: (t) => setState(() => _aabBuildType = t),
                onBuild: _buildAab,
              ),
              _ValidateTab(
                aabPath: _validateAabPath,
                validating: _validating,
                result: _validateResult,
                onBrowse: _browseAab,
                onValidate: _validateBundle,
              ),
              _PlayConsoleTab(
                packageCtrl: _packageCtrl, serviceAccCtrl: _serviceAccCtrl,
                trackName: _trackName, uploading: _uploading, status: _uploadStatus,
                aabPath: _aabOutputPath,
                onTrackChanged: (t) => setState(() => _trackName = t),
                onUpload: _uploadToPlay,
              ),
            ],
          ),
        ),
      ]);
}

// ─── Keystore Tab ─────────────────────────────────────────────────────────────
class _KeystoreTab extends StatelessWidget {
  final TextEditingController pathCtrl, aliasCtrl, storePwdCtrl, keyPwdCtrl, orgCtrl, countryCtrl;
  final bool ksPwdVisible, keyPwdVisible;
  final VoidCallback onToggleKsPwd, onToggleKeyPwd, onGenerate, onBrowse, onInfo;
  final String? status;

  const _KeystoreTab({required this.pathCtrl, required this.aliasCtrl, required this.storePwdCtrl, required this.keyPwdCtrl, required this.orgCtrl, required this.countryCtrl, required this.ksPwdVisible, required this.keyPwdVisible, required this.onToggleKsPwd, required this.onToggleKeyPwd, required this.onGenerate, required this.onBrowse, required this.onInfo, this.status});

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const _SectionLabel('Keystore File'),
          Row(children: [
            Expanded(child: _Field(pathCtrl, 'Path (e.g. ~/upload-keystore.jks)')),
            const SizedBox(width: 6),
            _SmallBtn('Browse', Icons.folder_open, SwarmColors.agentCyan, onBrowse),
          ]),
          const SizedBox(height: 8),
          _Field(aliasCtrl, 'Key alias (e.g. upload)'),
          const SizedBox(height: 8),
          _PwdField(storePwdCtrl, 'Store password', ksPwdVisible, onToggleKsPwd),
          const SizedBox(height: 8),
          _PwdField(keyPwdCtrl, 'Key password', keyPwdVisible, onToggleKeyPwd),
          const SizedBox(height: 16),
          const _SectionLabel('Certificate Info (optional)'),
          Row(children: [
            Expanded(child: _Field(orgCtrl, 'Organization / Name')),
            const SizedBox(width: 6),
            SizedBox(width: 70, child: _Field(countryCtrl, 'Country')),
          ]),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: _ActionBtn('Generate Keystore', Icons.vpn_key_rounded, SwarmColors.accent, onGenerate)),
            const SizedBox(width: 8),
            Expanded(child: _ActionBtn('Show Info', Icons.info_outline, SwarmColors.agentCyan, onInfo)),
          ]),
          if (status != null) ...[
            const SizedBox(height: 12),
            _StatusBox(status!),
          ],
          const SizedBox(height: 16),
          const _InfoCard(),
        ]),
      );
}

class _InfoCard extends StatelessWidget {
  const _InfoCard();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: SwarmColors.agentCyan.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(6), border: Border.all(color: SwarmColors.agentCyan.withValues(alpha: 0.2))),
        child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Icon(Icons.info_outline, size: 13, color: SwarmColors.agentCyan), SizedBox(width: 6), Text('key.properties', style: TextStyle(fontSize: 11, color: SwarmColors.agentCyan, fontWeight: FontWeight.bold))]),
          SizedBox(height: 6),
          Text('After generating, add to android/app/build.gradle:\n\ndef keystoreProperties = new Properties()\nkeystoreProperties.load(new FileInputStream(\n  rootProject.file(\'key.properties\')))\n\nandroid { signingConfigs { release {\n  keyAlias keystoreProperties[\'keyAlias\']\n  keyPassword keystoreProperties[\'keyPassword\']\n  storeFile file(keystoreProperties[\'storeFile\'])\n  storePassword keystoreProperties[\'storePassword\']\n}}}', style: TextStyle(fontFamily: 'monospace', fontSize: 10, color: SwarmColors.textMuted)),
        ]),
      );
}

// ─── AAB Tab ─────────────────────────────────────────────────────────────────
class _AabTab extends StatelessWidget {
  final String buildType;
  final bool building;
  final double progress;
  final List<String> log;
  final String? outputPath, projectPath;
  final ValueChanged<String> onBuildTypeChanged;
  final VoidCallback onBuild;

  const _AabTab({required this.buildType, required this.building, required this.progress, required this.log, this.outputPath, this.projectPath, required this.onBuildTypeChanged, required this.onBuild});

  @override
  Widget build(BuildContext context) => Column(children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: SwarmColors.border))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Text('Type:', style: TextStyle(fontSize: 11, color: SwarmColors.textMuted)),
              const SizedBox(width: 8),
              _TypeChip('Debug', buildType == 'debug', () => onBuildTypeChanged('debug')),
              const SizedBox(width: 4),
              _TypeChip('Release', buildType == 'release', () => onBuildTypeChanged('release')),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: building || projectPath == null ? null : onBuild,
                icon: building ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 1.5)) : const Icon(Icons.archive_rounded, size: 13),
                label: Text(building ? 'Building…' : 'Build AAB', style: const TextStyle(fontSize: 11)),
                style: ElevatedButton.styleFrom(backgroundColor: SwarmColors.agentPurple.withValues(alpha: 0.15), foregroundColor: SwarmColors.agentPurple, side: BorderSide(color: SwarmColors.agentPurple.withValues(alpha: 0.4)), elevation: 0, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4))),
              ),
            ]),
            if (building) ...[
              const SizedBox(height: 8),
              LinearProgressIndicator(value: progress, backgroundColor: SwarmColors.bgElevated, color: SwarmColors.agentPurple, borderRadius: BorderRadius.circular(2)),
            ],
            if (outputPath != null) ...[
              const SizedBox(height: 8),
              Row(children: [
                const Icon(Icons.check_circle_outline, size: 13, color: SwarmColors.agentEmerald),
                const SizedBox(width: 6),
                Expanded(child: Text(outputPath!, style: const TextStyle(fontFamily: 'monospace', fontSize: 10.5, color: SwarmColors.agentEmerald), overflow: TextOverflow.ellipsis)),
              ]),
            ],
          ]),
        ),
        Expanded(child: log.isEmpty
            ? Center(child: Text(projectPath == null ? 'No project open' : 'Press Build AAB to start', style: const TextStyle(color: SwarmColors.textMuted, fontSize: 12)))
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
              )),
      ]);
}

// ─── Play Console Tab ─────────────────────────────────────────────────────────
class _PlayConsoleTab extends StatelessWidget {
  final TextEditingController packageCtrl, serviceAccCtrl;
  final String trackName;
  final bool uploading;
  final String? status, aabPath;
  final ValueChanged<String> onTrackChanged;
  final VoidCallback onUpload;

  const _PlayConsoleTab({required this.packageCtrl, required this.serviceAccCtrl, required this.trackName, required this.uploading, this.status, this.aabPath, required this.onTrackChanged, required this.onUpload});

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const _SectionLabel('App Details'),
          _Field(packageCtrl, 'Package name (e.g. com.example.app)'),
          const SizedBox(height: 8),
          _Field(serviceAccCtrl, 'Service account JSON key path'),
          const SizedBox(height: 16),
          const _SectionLabel('Release Track'),
          Row(children: [
            for (final t in ['internal', 'alpha', 'beta', 'production']) ...[
              _TypeChip(t[0].toUpperCase() + t.substring(1), trackName == t, () => onTrackChanged(t)),
              const SizedBox(width: 4),
            ],
          ]),
          const SizedBox(height: 16),
          if (aabPath != null) ...[
            const _SectionLabel('AAB File'),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: SwarmColors.bgElevated, borderRadius: BorderRadius.circular(4), border: Border.all(color: SwarmColors.border)),
              child: Row(children: [
                const Icon(Icons.archive_rounded, size: 13, color: SwarmColors.agentPurple),
                const SizedBox(width: 8),
                Expanded(child: Text(aabPath!, style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: SwarmColors.textSecondary), overflow: TextOverflow.ellipsis)),
              ]),
            ),
            const SizedBox(height: 12),
          ],
          ElevatedButton.icon(
            onPressed: uploading ? null : onUpload,
            icon: uploading ? const SizedBox(width: 13, height: 13, child: CircularProgressIndicator(strokeWidth: 1.5)) : const Icon(Icons.upload_rounded, size: 13),
            label: Text(uploading ? 'Uploading…' : 'Upload to Play Console', style: const TextStyle(fontSize: 11)),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3DDC84).withValues(alpha: 0.15), foregroundColor: const Color(0xFF3DDC84), side: BorderSide(color: const Color(0xFF3DDC84).withValues(alpha: 0.4)), elevation: 0, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4))),
          ),
          if (status != null) ...[
            const SizedBox(height: 12),
            _StatusBox(status!),
          ],
        ]),
      );
}

// ─── Validate Tab ────────────────────────────────────────────────────────────
class _ValidateTab extends StatelessWidget {
  final String? aabPath;
  final bool validating;
  final String? result;
  final VoidCallback onBrowse, onValidate;

  const _ValidateTab({this.aabPath, required this.validating, this.result, required this.onBrowse, required this.onValidate});

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const _SectionLabel('AAB File'),
          Row(children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                decoration: BoxDecoration(color: SwarmColors.bgElevated, borderRadius: BorderRadius.circular(4), border: Border.all(color: SwarmColors.border)),
                child: Text(aabPath ?? 'No file selected', style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: aabPath != null ? SwarmColors.textSecondary : SwarmColors.textDisabled), overflow: TextOverflow.ellipsis),
              ),
            ),
            const SizedBox(width: 6),
            InkWell(
              onTap: onBrowse,
              borderRadius: BorderRadius.circular(4),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(color: SwarmColors.agentCyan.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(4), border: Border.all(color: SwarmColors.agentCyan.withValues(alpha: 0.4))),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.folder_open, size: 13, color: SwarmColors.agentCyan), SizedBox(width: 4), Text('Browse', style: TextStyle(fontSize: 11, color: SwarmColors.agentCyan, fontWeight: FontWeight.bold))]),
              ),
            ),
          ]),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: validating ? null : onValidate,
            icon: validating ? const SizedBox(width: 13, height: 13, child: CircularProgressIndicator(strokeWidth: 1.5)) : const Icon(Icons.verified_rounded, size: 13),
            label: Text(validating ? 'Validating…' : 'Validate Bundle', style: const TextStyle(fontSize: 11)),
            style: ElevatedButton.styleFrom(backgroundColor: SwarmColors.agentPurple.withValues(alpha: 0.15), foregroundColor: SwarmColors.agentPurple, side: BorderSide(color: SwarmColors.agentPurple.withValues(alpha: 0.4)), elevation: 0, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4))),
          ),
          if (result != null) ...[
            const SizedBox(height: 16),
            _StatusBox(result!),
          ],
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: SwarmColors.bgElevated, borderRadius: BorderRadius.circular(6), border: Border.all(color: SwarmColors.border)),
            child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [Icon(Icons.info_outline, size: 13, color: SwarmColors.agentCyan), SizedBox(width: 6), Text('bundletool', style: TextStyle(fontSize: 11, color: SwarmColors.agentCyan, fontWeight: FontWeight.bold))]),
              SizedBox(height: 6),
              Text('Validates the bundle structure, resources, and signing config.\n\nInstall bundletool:\n  brew install bundletool\n  — or —\n  Download bundletool.jar from github.com/google/bundletool\n  and place it in your HOME directory.', style: TextStyle(fontSize: 10.5, color: SwarmColors.textMuted)),
            ]),
          ),
        ]),
      );
}

// ─── Shared helpers ───────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text, style: const TextStyle(fontSize: 10, color: SwarmColors.textMuted, fontWeight: FontWeight.bold, letterSpacing: 1)),
      );
}

class _Field extends StatelessWidget {
  final TextEditingController ctrl;
  final String hint;
  const _Field(this.ctrl, this.hint);

  @override
  Widget build(BuildContext context) => TextField(
        controller: ctrl,
        style: const TextStyle(fontSize: 12, fontFamily: 'monospace', color: SwarmColors.textPrimary),
        decoration: InputDecoration(hintText: hint, hintStyle: const TextStyle(color: SwarmColors.textDisabled, fontSize: 11), isDense: true, filled: true, fillColor: SwarmColors.bgElevated, border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: SwarmColors.border)), contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8)),
      );
}

class _PwdField extends StatelessWidget {
  final TextEditingController ctrl;
  final String hint;
  final bool visible;
  final VoidCallback onToggle;
  const _PwdField(this.ctrl, this.hint, this.visible, this.onToggle);

  @override
  Widget build(BuildContext context) => TextField(
        controller: ctrl,
        obscureText: !visible,
        style: const TextStyle(fontSize: 12, fontFamily: 'monospace', color: SwarmColors.textPrimary),
        decoration: InputDecoration(
          hintText: hint, hintStyle: const TextStyle(color: SwarmColors.textDisabled, fontSize: 11),
          isDense: true, filled: true, fillColor: SwarmColors.bgElevated,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: SwarmColors.border)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          suffixIcon: IconButton(icon: Icon(visible ? Icons.visibility_off : Icons.visibility, size: 15), onPressed: onToggle, color: SwarmColors.textMuted, padding: EdgeInsets.zero, constraints: const BoxConstraints()),
        ),
      );
}

class _SmallBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _SmallBtn(this.label, this.icon, this.color, this.onTap);

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(4), border: Border.all(color: color.withValues(alpha: 0.4))),
          child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 13, color: color), const SizedBox(width: 4), Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold))]),
        ),
      );
}

class _ActionBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _ActionBtn(this.label, this.icon, this.color, this.onTap);

  @override
  Widget build(BuildContext context) => ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 13),
        label: Text(label, style: const TextStyle(fontSize: 11)),
        style: ElevatedButton.styleFrom(backgroundColor: color.withValues(alpha: 0.15), foregroundColor: color, side: BorderSide(color: color.withValues(alpha: 0.4)), elevation: 0, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4))),
      );
}

class _TypeChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _TypeChip(this.label, this.active, this.onTap);

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(color: active ? SwarmColors.accent.withValues(alpha: 0.2) : Colors.transparent, borderRadius: BorderRadius.circular(4), border: Border.all(color: active ? SwarmColors.accent : SwarmColors.border)),
          child: Text(label, style: TextStyle(fontSize: 11, color: active ? SwarmColors.accent : SwarmColors.textMuted, fontWeight: active ? FontWeight.bold : FontWeight.normal)),
        ),
      );
}

class _StatusBox extends StatelessWidget {
  final String status;
  const _StatusBox(this.status);

  @override
  Widget build(BuildContext context) {
    final isError = status.startsWith('ERROR');
    final isOk = status.startsWith('✓');
    final color = isError ? SwarmColors.agentRose : isOk ? SwarmColors.agentEmerald : SwarmColors.agentCyan;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(4), border: Border.all(color: color.withValues(alpha: 0.3))),
      child: Text(status, style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: color)),
    );
  }
}

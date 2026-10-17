import 'dart:async';
import 'dart:convert';
import 'dart:io' hide Platform;
import '../../platform/platform.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─── Data models ─────────────────────────────────────────────────────────────

class IosDevice {
  final String udid;
  final String name;
  final String iosVersion;
  final String productType;
  final bool isSimulator;
  final String state; // 'Booted', 'Shutdown', 'connected', 'offline'

  const IosDevice({
    required this.udid,
    required this.name,
    required this.iosVersion,
    required this.productType,
    required this.isSimulator,
    required this.state,
  });

  bool get isOnline => state == 'Booted' || state == 'connected';
}

class AppleCertificate {
  final String name;
  final String sha1;
  final String type; // 'Development', 'Distribution'
  final DateTime? expiry;
  final bool isValid;

  const AppleCertificate({
    required this.name,
    required this.sha1,
    required this.type,
    this.expiry,
    required this.isValid,
  });
}

class ProvisioningProfile {
  final String name;
  final String uuid;
  final String bundleId;
  final String type; // 'development', 'adhoc', 'appstore', 'enterprise'
  final DateTime? expiry;
  final List<String> deviceUdids;
  final bool isExpired;

  const ProvisioningProfile({
    required this.name,
    required this.uuid,
    required this.bundleId,
    required this.type,
    this.expiry,
    this.deviceUdids = const [],
    required this.isExpired,
  });
}

class AppleCapability {
  final String id;
  final String name;
  final String entitlementKey;
  final String description;
  final String icon;
  bool enabled;

  AppleCapability({
    required this.id,
    required this.name,
    required this.entitlementKey,
    required this.description,
    required this.icon,
    this.enabled = false,
  });
}

enum AppleBuildTarget { iosDebug, iosRelease, iosArchive, ipaRelease, macosDebug, macosRelease, macosArchive }
enum AppleBuildStatus { idle, running, succeeded, failed }

// ─── Singleton build service ──────────────────────────────────────────────────
class AppleBuildService extends ChangeNotifier {
  static final AppleBuildService instance = AppleBuildService._();
  AppleBuildService._();

  // SSH Mac config
  String sshHost = '';
  String sshUser = '';
  String sshKeyPath = '';
  bool useLocalFlutter = true; // run flutter commands locally, xcode via SSH

  // State
  List<IosDevice> _devices = [];
  List<AppleCertificate> _certificates = [];
  List<ProvisioningProfile> _profiles = [];
  List<String> _buildLog = [];
  AppleBuildStatus _buildStatus = AppleBuildStatus.idle;
  AppleBuildTarget _currentTarget = AppleBuildTarget.iosDebug;
  String? _artifactPath;
  Process? _buildProcess;

  // Signing config
  String bundleId = 'com.example.app';
  String teamId = '';
  String codeSignIdentity = '';
  String selectedProfileUuid = '';
  String exportMethod = 'development'; // development, ad-hoc, app-store, enterprise

  // App Store Connect config
  String appleId = '';
  String appSpecificPassword = '';
  String ipaPath = '';

  List<IosDevice> get devices => List.unmodifiable(_devices);
  List<AppleCertificate> get certificates => List.unmodifiable(_certificates);
  List<ProvisioningProfile> get profiles => List.unmodifiable(_profiles);
  List<String> get buildLog => List.unmodifiable(_buildLog);
  AppleBuildStatus get buildStatus => _buildStatus;
  AppleBuildTarget get currentTarget => _currentTarget;
  String? get artifactPath => _artifactPath;
  bool get isBuilding => _buildStatus == AppleBuildStatus.running;

  static const _kSshHost   = 'apple_ssh_host';
  static const _kSshUser   = 'apple_ssh_user';
  static const _kSshKey    = 'apple_ssh_key';
  static const _kBundleId  = 'apple_bundle_id';
  static const _kTeamId    = 'apple_team_id';
  static const _kAppleId   = 'apple_apple_id';

  // ── Persistence ─────────────────────────────────────────────────────────────

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    sshHost = p.getString(_kSshHost) ?? '';
    sshUser = p.getString(_kSshUser) ?? '';
    sshKeyPath = p.getString(_kSshKey) ?? '';
    bundleId = p.getString(_kBundleId) ?? 'com.example.app';
    teamId = p.getString(_kTeamId) ?? '';
    appleId = p.getString(_kAppleId) ?? '';
    notifyListeners();
  }

  Future<void> saveConfig() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kSshHost, sshHost);
    await p.setString(_kSshUser, sshUser);
    await p.setString(_kSshKey, sshKeyPath);
    await p.setString(_kBundleId, bundleId);
    await p.setString(_kTeamId, teamId);
    await p.setString(_kAppleId, appleId);
  }

  // ── Device discovery ─────────────────────────────────────────────────────────

  Future<void> refreshDevices() async {
    _devices = [];
    notifyListeners();

    // Real devices via libimobiledevice (Linux-native)
    await _discoverRealDevices();
    // Simulators via xcrun simctl (SSH to Mac, or local if on Mac)
    await _discoverSimulators();
    notifyListeners();
  }

  Future<void> _discoverRealDevices() async {
    try {
      final r = await Process.run('idevice_id', ['-l']);
      if (r.exitCode != 0) return;
      final udids = (r.stdout as String).trim().split('\n').where((u) => u.isNotEmpty).toList();
      for (final udid in udids) {
        try {
          final info = await Process.run('ideviceinfo', ['-u', udid, '-k', 'ProductVersion,ProductType,DeviceName']);
          final lines = (info.stdout as String).trim().split('\n');
          String deviceName = 'iPhone';
          String iosVer = 'Unknown';
          String productType = 'iPhone';
          for (final line in lines) {
            if (line.startsWith('ProductVersion:')) iosVer = line.split(':').last.trim();
            if (line.startsWith('ProductType:')) productType = line.split(':').last.trim();
            if (line.startsWith('DeviceName:')) deviceName = line.split(':').last.trim();
          }
          _devices.add(IosDevice(udid: udid, name: deviceName, iosVersion: iosVer, productType: productType, isSimulator: false, state: 'connected'));
        } catch (_) {}
      }
    } catch (_) {}
  }

  Future<void> _discoverSimulators() async {
    try {
      final cmd = useLocalFlutter && sshHost.isEmpty
          ? ['xcrun', 'simctl', 'list', 'devices', '--json']
          : _sshCmd('xcrun simctl list devices --json');

      final r = await Process.run(cmd.first, cmd.sublist(1));
      if (r.exitCode != 0) return;

      final json = jsonDecode(r.stdout as String) as Map<String, dynamic>;
      final devicesByRuntime = json['devices'] as Map<String, dynamic>? ?? {};
      for (final entry in devicesByRuntime.entries) {
        final runtimeKey = entry.key; // e.g. "com.apple.CoreSimulator.SimRuntime.iOS-17-4"
        if (!runtimeKey.contains('iOS') && !runtimeKey.contains('watchOS') && !runtimeKey.contains('tvOS')) continue;
        final iosVer = runtimeKey.replaceAll(RegExp(r'.*iOS-'), '').replaceAll('-', '.');
        final deviceList = entry.value as List<dynamic>;
        for (final d in deviceList) {
          final dm = d as Map<String, dynamic>;
          _devices.add(IosDevice(
            udid: dm['udid'] as String? ?? '',
            name: dm['name'] as String? ?? 'Simulator',
            iosVersion: 'iOS $iosVer',
            productType: 'Simulator',
            isSimulator: true,
            state: dm['state'] as String? ?? 'Shutdown',
          ));
        }
      }
    } catch (_) {}
  }

  // ── Simulator control ────────────────────────────────────────────────────────

  Future<void> bootSimulator(String udid) async {
    await _runSimctl(['boot', udid]);
    await _runSimctl(['bootstatus', udid]);
    await refreshDevices();
  }

  Future<void> openSimulatorApp() async {
    try { await Process.run('open', ['-a', 'Simulator']); } catch (_) {}
  }

  Future<void> shutdownSimulator(String udid) async {
    await _runSimctl(['shutdown', udid]);
    await refreshDevices();
  }

  Future<void> installAppOnSimulator(String udid, String appPath) async {
    await _runSimctl(['install', udid, appPath]);
  }

  Future<void> launchAppOnSimulator(String udid) async {
    if (bundleId.isNotEmpty) await _runSimctl(['launch', udid, bundleId]);
  }

  Future<void> installIpaOnDevice(String udid, String ipaFilePath) async {
    _log('Installing IPA on device $udid...');
    try {
      final r = await Process.run('ideviceinstaller', ['-u', udid, '-i', ipaFilePath]);
      _log(r.stdout as String);
      if (r.exitCode != 0) _log('Error: ${r.stderr}');
    } catch (e) {
      _log('ideviceinstaller not found. Install with: sudo pacman -S libimobiledevice');
    }
  }

  Future<void> _runSimctl(List<String> args) async {
    final cmd = useLocalFlutter && sshHost.isEmpty
        ? ['xcrun', 'simctl', ...args]
        : _sshCmd('xcrun simctl ${args.join(' ')}');
    await Process.run(cmd.first, cmd.sublist(1));
  }

  // ── Certificate & profile discovery ─────────────────────────────────────────

  Future<void> refreshCertificates() async {
    _certificates = [];
    try {
      final cmd = sshHost.isNotEmpty
          ? _sshCmd('security find-identity -v -p codesigning')
          : ['security', 'find-identity', '-v', '-p', 'codesigning'];
      final r = await Process.run(cmd.first, cmd.sublist(1));
      final lines = (r.stdout as String).split('\n');
      for (final line in lines) {
        final m = RegExp(r'(\w{40})\s+"([^"]+)"').firstMatch(line);
        if (m == null) continue;
        final sha = m.group(1)!;
        final name = m.group(2)!;
        final type = name.contains('Distribution') ? 'Distribution' : 'Development';
        _certificates.add(AppleCertificate(name: name, sha1: sha, type: type, isValid: true));
      }
    } catch (_) {
      // On Linux without a Mac, show demo certs
      _certificates = [
        const AppleCertificate(name: 'Apple Development: dev@example.com (ABCD1234)', sha1: 'ABCDEF1234567890ABCDEF1234567890ABCDEF12', type: 'Development', isValid: true),
        const AppleCertificate(name: 'Apple Distribution: Example Corp (WXYZ5678)', sha1: 'FEDCBA9876543210FEDCBA9876543210FEDCBA98', type: 'Distribution', isValid: true),
      ];
    }
    notifyListeners();
  }

  Future<void> refreshProfiles() async {
    _profiles = [];
    // On Linux, check ~/.local/share/mobileprovision/ or via SSH to Mac
    final localDir = Directory('${Platform.environment['HOME'] ?? ''}/.local/share/mobileprovision');
    final macDir = Directory('${Platform.environment['HOME'] ?? ''}/Library/MobileDevice/Provisioning Profiles');

    final searchDir = macDir.existsSync() ? macDir : (localDir.existsSync() ? localDir : null);
    if (searchDir == null) {
      // Demo profiles
      _profiles = [
        ProvisioningProfile(name: 'Development Profile', uuid: 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx', bundleId: bundleId, type: 'development', isExpired: false, expiry: DateTime.now().add(const Duration(days: 270))),
        ProvisioningProfile(name: 'App Store Distribution', uuid: 'yyyyyyyy-yyyy-yyyy-yyyy-yyyyyyyyyyyy', bundleId: bundleId, type: 'appstore', isExpired: false, expiry: DateTime.now().add(const Duration(days: 340))),
      ];
      notifyListeners();
      return;
    }

    try {
      await for (final f in searchDir.list()) {
        if (!f.path.endsWith('.mobileprovision')) continue;
        final r = await Process.run('openssl', ['smime', '-inform', 'der', '-verify', '-in', f.path, '-noverify']);
        try {
          final text = r.stdout as String;
          final nameM = RegExp(r'<key>Name</key>\s*<string>([^<]+)</string>').firstMatch(text);
          final uuidM = RegExp(r'<key>UUID</key>\s*<string>([^<]+)</string>').firstMatch(text);
          final bundleM = RegExp(r'<key>application-identifier</key>\s*<string>[^.]+\.([^<]+)</string>').firstMatch(text);
          if (nameM != null && uuidM != null) {
            _profiles.add(ProvisioningProfile(
              name: nameM.group(1)!,
              uuid: uuidM.group(1)!,
              bundleId: bundleM?.group(1) ?? '*',
              type: 'development',
              isExpired: false,
            ));
          }
        } catch (_) {}
      }
    } catch (_) {}
    notifyListeners();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  Future<void> build(AppleBuildTarget target, {String? projectPath}) async {
    if (isBuilding) return;
    _currentTarget = target;
    _buildStatus = AppleBuildStatus.running;
    _buildLog = ['[${_ts()}] Starting ${_targetLabel(target)} build...'];
    _artifactPath = null;
    notifyListeners();

    try {
      final cmd = _buildCommand(target, projectPath);
      _log('Running: ${cmd.join(' ')}');
      _buildProcess = await Process.start(cmd.first, cmd.sublist(1), workingDirectory: projectPath);

      _buildProcess!.stdout.transform(utf8.decoder).listen((data) {
        for (final line in data.split('\n')) {
          if (line.isNotEmpty) _log(line);
        }
      });
      _buildProcess!.stderr.transform(utf8.decoder).listen((data) {
        for (final line in data.split('\n')) {
          if (line.isNotEmpty) _log('⚠ $line');
        }
      });

      final exitCode = await _buildProcess!.exitCode;
      if (exitCode == 0) {
        _buildStatus = AppleBuildStatus.succeeded;
        _artifactPath = _inferArtifactPath(target, projectPath);
        _log('[${_ts()}] ✓ Build succeeded!');
        if (_artifactPath != null) _log('Artifact: $_artifactPath');
      } else {
        _buildStatus = AppleBuildStatus.failed;
        _log('[${_ts()}] ✗ Build failed with exit code $exitCode');
      }
    } catch (e) {
      _buildStatus = AppleBuildStatus.failed;
      _log('[${_ts()}] ✗ Error: $e');
    }
    _buildProcess = null;
    notifyListeners();
  }

  void cancelBuild() {
    _buildProcess?.kill();
    _buildStatus = AppleBuildStatus.idle;
    _log('[${_ts()}] Build cancelled.');
    notifyListeners();
  }

  List<String> _buildCommand(AppleBuildTarget target, String? projectPath) {
    switch (target) {
      case AppleBuildTarget.iosDebug:
        return ['flutter', 'build', 'ios', '--debug', '--simulator'];
      case AppleBuildTarget.iosRelease:
        return ['flutter', 'build', 'ios', '--release', if (teamId.isNotEmpty) '--export-options-plist=ExportOptions.plist'];
      case AppleBuildTarget.iosArchive:
        if (sshHost.isNotEmpty) return _sshCmd('cd ${projectPath ?? '.'} && flutter build ios --release && xcodebuild -workspace ios/Runner.xcworkspace -scheme Runner -configuration Release -archivePath build/Runner.xcarchive archive');
        return ['flutter', 'build', 'ios', '--release'];
      case AppleBuildTarget.ipaRelease:
        return ['flutter', 'build', 'ipa', '--release', if (bundleId.isNotEmpty) '--export-method=$exportMethod'];
      case AppleBuildTarget.macosDebug:
        return ['flutter', 'build', 'macos', '--debug'];
      case AppleBuildTarget.macosRelease:
        return ['flutter', 'build', 'macos', '--release'];
      case AppleBuildTarget.macosArchive:
        if (sshHost.isNotEmpty) return _sshCmd('cd ${projectPath ?? '.'} && flutter build macos --release');
        return ['flutter', 'build', 'macos', '--release'];
    }
  }

  String? _inferArtifactPath(AppleBuildTarget target, String? projectPath) {
    final base = projectPath ?? '.';
    return switch (target) {
      AppleBuildTarget.iosDebug     => '$base/build/ios/iphonesimulator/Runner.app',
      AppleBuildTarget.iosRelease   => '$base/build/ios/iphoneos/Runner.app',
      AppleBuildTarget.iosArchive   => '$base/build/Runner.xcarchive',
      AppleBuildTarget.ipaRelease   => '$base/build/ios/ipa/Runner.ipa',
      AppleBuildTarget.macosDebug   => '$base/build/macos/Build/Products/Debug/Runner.app',
      AppleBuildTarget.macosRelease => '$base/build/macos/Build/Products/Release/Runner.app',
      AppleBuildTarget.macosArchive => '$base/build/Runner.xcarchive',
    };
  }

  // ── App Store Connect upload ─────────────────────────────────────────────────

  Future<void> uploadToAppStore(String ipaFilePath) async {
    if (appleId.isEmpty || appSpecificPassword.isEmpty) {
      _log('Error: Apple ID and app-specific password required.');
      return;
    }
    _buildStatus = AppleBuildStatus.running;
    _buildLog = ['[${_ts()}] Uploading to App Store Connect...'];
    notifyListeners();
    try {
      final cmd = ['xcrun', 'altool', '--upload-app', '-t', 'ios', '-f', ipaFilePath, '-u', appleId, '-p', appSpecificPassword, '--output-format', 'xml'];
      _log('Running: xcrun altool --upload-app ...');
      final process = await Process.start(cmd.first, cmd.sublist(1));
      process.stdout.transform(utf8.decoder).listen((d) { for (final l in d.split('\n')) {
        if (l.isNotEmpty) _log(l);
      } });
      process.stderr.transform(utf8.decoder).listen((d) { for (final l in d.split('\n')) {
        if (l.isNotEmpty) _log('⚠ $l');
      } });
      final code = await process.exitCode;
      _buildStatus = code == 0 ? AppleBuildStatus.succeeded : AppleBuildStatus.failed;
      _log(code == 0 ? '[${_ts()}] ✓ Upload succeeded!' : '[${_ts()}] ✗ Upload failed.');
    } catch (e) {
      _buildStatus = AppleBuildStatus.failed;
      _log('[${_ts()}] ✗ Error: $e\n(Make sure xcrun altool is available on your Mac via SSH)');
    }
    notifyListeners();
  }

  // ── Entitlements file generation ─────────────────────────────────────────────

  Future<void> writeEntitlementsFile(String projectPath, List<AppleCapability> capabilities) async {
    final enabled = capabilities.where((c) => c.enabled).toList();
    final sb = StringBuffer();
    sb.writeln('<?xml version="1.0" encoding="UTF-8"?>');
    sb.writeln('<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">');
    sb.writeln('<plist version="1.0">');
    sb.writeln('<dict>');
    for (final cap in enabled) {
      sb.writeln('\t<key>${cap.entitlementKey}</key>');
      sb.writeln('\t<true/>');
    }
    sb.writeln('\t<key>com.apple.developer.team-identifier</key>');
    sb.writeln('\t<string>$teamId</string>');
    sb.writeln('</dict>');
    sb.writeln('</plist>');

    final path = '$projectPath/ios/Runner/Runner.entitlements';
    await File(path).writeAsString(sb.toString());
    _log('Wrote entitlements to $path');
    notifyListeners();
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  List<String> _sshCmd(String remoteCmd) {
    return [
      'ssh',
      if (sshKeyPath.isNotEmpty) ...['-i', sshKeyPath],
      '$sshUser@$sshHost',
      remoteCmd,
    ];
  }

  void _log(String msg) {
    _buildLog = [..._buildLog, msg];
    notifyListeners();
  }

  static String _ts() => DateTime.now().toIso8601String().substring(11, 19);

  static String _targetLabel(AppleBuildTarget t) => switch (t) {
    AppleBuildTarget.iosDebug     => 'iOS Debug (Simulator)',
    AppleBuildTarget.iosRelease   => 'iOS Release',
    AppleBuildTarget.iosArchive   => 'iOS Archive',
    AppleBuildTarget.ipaRelease   => 'IPA Export',
    AppleBuildTarget.macosDebug   => 'macOS Debug',
    AppleBuildTarget.macosRelease => 'macOS Release',
    AppleBuildTarget.macosArchive => 'macOS Archive',
  };

  static List<AppleCapability> defaultCapabilities() => [
    AppleCapability(id: 'push',         name: 'Push Notifications',    entitlementKey: 'aps-environment',                                    description: 'Receive remote push notifications via APNs', icon: '🔔'),
    AppleCapability(id: 'signin',       name: 'Sign In with Apple',    entitlementKey: 'com.apple.developer.applesignin',                    description: 'Let users sign in with their Apple ID', icon: '🍎'),
    AppleCapability(id: 'icloud',       name: 'iCloud',                entitlementKey: 'com.apple.developer.icloud-container-environment',   description: 'Sync data across devices via iCloud', icon: '☁️'),
    AppleCapability(id: 'iap',          name: 'In-App Purchases',      entitlementKey: 'com.apple.developer.in-app-payments',                description: 'Sell digital content and subscriptions', icon: '💰'),
    AppleCapability(id: 'gamecenter',   name: 'Game Center',           entitlementKey: 'com.apple.developer.game-center',                    description: 'Leaderboards, achievements and multiplayer', icon: '🎮'),
    AppleCapability(id: 'healthkit',    name: 'HealthKit',             entitlementKey: 'com.apple.developer.healthkit',                      description: 'Read and write health data', icon: '❤️'),
    AppleCapability(id: 'homekit',      name: 'HomeKit',               entitlementKey: 'com.apple.developer.homekit',                        description: 'Control smart home accessories', icon: '🏠'),
    AppleCapability(id: 'nfc',          name: 'NFC Tag Reading',       entitlementKey: 'com.apple.developer.nfc.readersession.formats',       description: 'Read NFC tags', icon: '📡'),
    AppleCapability(id: 'wallet',       name: 'Wallet',                entitlementKey: 'com.apple.developer.pass-type-identifiers',          description: 'Add boarding passes, tickets and cards to Wallet', icon: '💳'),
    AppleCapability(id: 'siri',         name: 'Siri',                  entitlementKey: 'com.apple.developer.siri',                           description: 'Integrate with Siri voice commands', icon: '🎙️'),
    AppleCapability(id: 'maps',         name: 'Maps',                  entitlementKey: 'com.apple.developer.maps',                           description: 'Provide custom map overlays', icon: '🗺️'),
    AppleCapability(id: 'bgfetch',      name: 'Background Fetch',      entitlementKey: 'com.apple.developer.background-modes',               description: 'Fetch content in the background', icon: '🔄'),
    AppleCapability(id: 'multipeer',    name: 'Multipeer Connectivity', entitlementKey: 'com.apple.developer.networking.multipath',           description: 'Peer-to-peer networking', icon: '📶'),
    AppleCapability(id: 'keychain',     name: 'Keychain Sharing',      entitlementKey: 'keychain-access-groups',                             description: 'Share keychain items between apps', icon: '🔑'),
    AppleCapability(id: 'appgroups',    name: 'App Groups',            entitlementKey: 'com.apple.security.application-groups',              description: 'Share data between apps and extensions', icon: '👥'),
    AppleCapability(id: 'assocdomains', name: 'Associated Domains',    entitlementKey: 'com.apple.developer.associated-domains',             description: 'Universal links and Handoff support', icon: '🔗'),
  ];
}


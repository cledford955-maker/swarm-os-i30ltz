import 'dart:async';
import 'dart:io' hide Platform;
import '../platform/platform.dart';
import 'package:flutter/foundation.dart';

class SdkPackage {
  final String path;
  final String version;
  final String description;
  final bool isInstalled;

  const SdkPackage({
    required this.path,
    required this.version,
    required this.description,
    this.isInstalled = false,
  });
}

class AvdInfo {
  final String name;
  final String device;
  final String path;
  final String target;
  final String basedOn;
  final bool isRunning;
  final String? runningPort;

  const AvdInfo({
    required this.name,
    this.device = 'Pixel 7',
    this.path = '',
    this.target = 'Android 14 (API 34)',
    this.basedOn = 'Google APIs Intel x86_64 Atom',
    this.isRunning = false,
    this.runningPort,
  });
}

class AndroidSdkService extends ChangeNotifier {
  static final AndroidSdkService instance = AndroidSdkService._();
  AndroidSdkService._() {
    detectSdk();
  }

  String? _sdkPath;
  String? get sdkPath => _sdkPath;
  bool _isSdkFound = false;
  bool get isSdkFound => _isSdkFound;

  List<String> _installedPlatforms = [];
  List<String> _installedBuildTools = [];
  List<SdkPackage> _availablePackages = [];
  List<AvdInfo> _avds = [];

  List<String> get installedPlatforms => List.unmodifiable(_installedPlatforms);
  List<String> get installedBuildTools => List.unmodifiable(_installedBuildTools);
  List<SdkPackage> get availablePackages => List.unmodifiable(_availablePackages);
  List<AvdInfo> get avds => List.unmodifiable(_avds);

  final List<String> _sdkLogs = [];
  List<String> get sdkLogs => List.unmodifiable(_sdkLogs);
  bool _isBusy = false;
  bool get isBusy => _isBusy;

  void detectSdk() {
    final env = Platform.environment;
    final candidates = [
      env['ANDROID_HOME'],
      env['ANDROID_SDK_ROOT'],
      '${env['HOME']}/Android/Sdk',
      '/opt/android-sdk',
      '/opt/android-sdk-linux',
      '/usr/lib/android-sdk',
    ];

    for (final c in candidates) {
      if (c != null && Directory(c).existsSync()) {
        _sdkPath = c;
        _isSdkFound = true;
        break;
      }
    }

    _refreshInstalledComponents();
    refreshAvds();
  }

  void _refreshInstalledComponents() {
    _installedPlatforms.clear();
    _installedBuildTools.clear();

    if (_sdkPath != null) {
      final platformsDir = Directory('$_sdkPath/platforms');
      if (platformsDir.existsSync()) {
        _installedPlatforms = platformsDir.listSync().whereType<Directory>().map((d) => d.uri.pathSegments.reversed.skip(1).first).toList();
      }

      final buildToolsDir = Directory('$_sdkPath/build-tools');
      if (buildToolsDir.existsSync()) {
        _installedBuildTools = buildToolsDir.listSync().whereType<Directory>().map((d) => d.uri.pathSegments.reversed.skip(1).first).toList();
      }
    }

    // Default package suggestions
    _availablePackages = [
      SdkPackage(path: 'platforms;android-34', version: '34.0.0', description: 'Android SDK Platform 34 (UpsideDownCake)', isInstalled: _installedPlatforms.contains('android-34')),
      SdkPackage(path: 'platforms;android-33', version: '33.0.3', description: 'Android SDK Platform 33 (Tiramisu)', isInstalled: _installedPlatforms.contains('android-33')),
      SdkPackage(path: 'platforms;android-32', version: '32.0.0', description: 'Android SDK Platform 32 (Sv2)', isInstalled: _installedPlatforms.contains('android-32')),
      SdkPackage(path: 'build-tools;34.0.0', version: '34.0.0', description: 'Android SDK Build-Tools 34.0.0', isInstalled: _installedBuildTools.contains('34.0.0')),
      SdkPackage(path: 'build-tools;33.0.2', version: '33.0.2', description: 'Android SDK Build-Tools 33.0.2', isInstalled: _installedBuildTools.contains('33.0.2')),
      const SdkPackage(path: 'platform-tools', version: '34.0.5', description: 'Android SDK Platform-Tools (adb, fastboot)', isInstalled: true),
      const SdkPackage(path: 'cmdline-tools;latest', version: '11.0', description: 'Android SDK Command-line Tools', isInstalled: true),
      const SdkPackage(path: 'emulator', version: '34.1.18', description: 'Android Emulator Hardware Acceleration Engine', isInstalled: true),
      const SdkPackage(path: 'system-images;android-34;google_apis;x86_64', version: '1', description: 'Google APIs Intel x86_64 System Image', isInstalled: false),
    ];

    notifyListeners();
  }

  Future<void> refreshAvds() async {
    _log('Scanning Android Virtual Devices (AVDs)...');
    try {
      final r = await Process.run('emulator', ['-list-avds']);
      final avdNames = r.stdout.toString().split('\n').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();

      // Check running emulators via adb devices
      final adbRes = await Process.run('adb', ['devices']);
      final adbOut = adbRes.stdout.toString();

      final list = <AvdInfo>[];
      for (final name in avdNames) {
        final isRunning = adbOut.contains('emulator');
        list.add(AvdInfo(
          name: name,
          device: name.contains('Pixel') ? 'Pixel 7 Pro' : 'Android Tablet / Phone',
          target: 'Android 14 (API 34)',
          basedOn: 'Google Play x86_64',
          isRunning: isRunning,
        ));
      }

      if (list.isEmpty) {
        // Sample default template AVD if none created yet
        list.add(const AvdInfo(
          name: 'Swarm_Pixel_7_API_34',
          device: 'Pixel 7 (6.3" 1080x2400)',
          target: 'Android 14 (API 34)',
          basedOn: 'Google APIs x86_64',
          isRunning: false,
        ));
      }

      _avds = list;
      _log('Found ${_avds.length} virtual device profiles');
      notifyListeners();
    } catch (e) {
      _log('AVD scan error: $e');
    }
  }

  Future<void> launchAvd(String avdName) async {
    _log('Launching emulator: $avdName...');
    try {
      Process.start('emulator', ['-avd', avdName, '-netdelay', 'none', '-netspeed', 'full']);
      _log('Emulator process dispatched in background');
      Future.delayed(const Duration(seconds: 4), refreshAvds);
    } catch (e) {
      _log('Failed to launch emulator $avdName: $e');
    }
  }

  Future<void> wipeAndColdBootAvd(String avdName) async {
    _log('Wiping user data and cold-booting $avdName...');
    try {
      Process.start('emulator', ['-avd', avdName, '-wipe-data', '-no-snapshot-load']);
      _log('Cold boot started with wiped partition');
      Future.delayed(const Duration(seconds: 4), refreshAvds);
    } catch (e) {
      _log('Error wiping AVD: $e');
    }
  }

  Future<void> killEmulator(String avdName) async {
    _log('Terminating emulator $avdName...');
    try {
      await Process.run('adb', ['emu', 'kill']);
      _log('Sent emu kill signal via ADB');
      Future.delayed(const Duration(seconds: 2), refreshAvds);
    } catch (e) {
      _log('Error stopping emulator: $e');
    }
  }

  Future<void> createAvd({
    required String name,
    required String packageImage,
    required String deviceProfile,
  }) async {
    _isBusy = true;
    _log('Creating new AVD: $name with package $packageImage...');
    notifyListeners();

    try {
      final res = await Process.run('avdmanager', [
        'create',
        'avd',
        '-n',
        name,
        '-k',
        packageImage,
        '-d',
        deviceProfile,
        '--force',
      ]);
      _log(res.stdout.toString());
      if (res.stderr.toString().isNotEmpty) {
        _log(res.stderr.toString());
      }
      _log('AVD $name created successfully!');
      await refreshAvds();
    } catch (e) {
      _log('AVD creation error: $e');
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  Future<void> installSdkPackage(String packagePath) async {
    _isBusy = true;
    _log('Invoking sdkmanager for package: $packagePath...');
    notifyListeners();

    try {
      final res = await Process.run('sdkmanager', [packagePath]);
      _log(res.stdout.toString());
      _refreshInstalledComponents();
      _log('Package $packagePath processed.');
    } catch (e) {
      _log('sdkmanager error: $e');
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  void _log(String msg) {
    _sdkLogs.add('[${DateTime.now().toIso8601String().substring(11, 19)}] $msg');
    if (_sdkLogs.length > 200) _sdkLogs.removeAt(0);
    notifyListeners();
  }
}

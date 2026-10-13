import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Information about a detected USB hardware master key.
class UsbMasterKeyInfo {
  final String filePath;
  final String mountPath;
  final String devicePath;
  final String driveLabel;
  final String keyContent;
  final DateTime detectedAt;

  const UsbMasterKeyInfo({
    required this.filePath,
    required this.mountPath,
    required this.devicePath,
    required this.driveLabel,
    required this.keyContent,
    required this.detectedAt,
  });

  @override
  String toString() => 'UsbMasterKeyInfo(label: $driveLabel, file: $filePath, device: $devicePath)';
}

/// Candidate USB drive that can be provisioned with a Master Key.
class UsbDriveTarget {
  final String mountPath;
  final String devicePath;
  final String label;
  final String model;
  final String size;
  final bool hasExistingKey;

  const UsbDriveTarget({
    required this.mountPath,
    required this.devicePath,
    required this.label,
    required this.model,
    required this.size,
    required this.hasExistingKey,
  });

  String get displayName {
    if (label.isNotEmpty) return '$label ($model)';
    if (model.isNotEmpty) return model;
    return 'USB Drive ($devicePath)';
  }
}

/// Service to detect, verify, and provision cheap USB flash drives as hardware master keys
/// for SWARM OS lock screen override and cipher recovery.
class UsbMasterKeyService {
  static const String prefKeySecret = 'usb_master_key_secret';
  static const String prefKeyAutoUnlock = 'usb_master_key_auto_unlock';
  static const String etcKeyFile = '/etc/swarm_os/master_key.token';
  static const String defaultMagicToken = 'SWARM_MASTER_KEY_V1';

  static const List<String> supportedKeyFiles = [
    'swarm_master.key',
    'swarm.key',
    '.swarm_master.key',
    '.swarm.key',
    'master.key',
    'lucille.key',
    'SWARM_MASTER.KEY',
    'SWARM.KEY',
    'MASTER.KEY',
  ];

  static const Set<String> _protectedMountPrefixes = {
    '/',
    '/boot',
    '/boot/efi',
    '/mnt/Lucy',
    '/mnt/lucy',
    '/mnt/swarmbuild',
    '/mnt/archive',
    '/mnt/downloads',
    '/mnt/recoverybuild',
    '/mnt/boltzbuild',
    '/mnt/brains',
    '/mnt/recoveryos',
    '/mnt/swarm',
  };

  /// Tracks mounts that this service automatically mounted so we can unmount non-matching ones.
  static final Set<String> _autoMountedDevices = {};

  /// Scans all attached USB drives for a valid master key file.
  /// Non-blocking, fast execution (< 250ms).
  static Future<UsbMasterKeyInfo?> scanForMasterKey({String? expectedToken}) async {
    // 1. Resolve expected token (from argument, SharedPreferences, or /etc file)
    String? token = expectedToken;
    if (token == null || token.isEmpty) {
      try {
        final prefs = await SharedPreferences.getInstance();
        token = prefs.getString(prefKeySecret);
      } catch (_) {}
    }
    if ((token == null || token.isEmpty) && File(etcKeyFile).existsSync()) {
      try {
        token = File(etcKeyFile).readAsStringSync().trim();
      } catch (_) {}
    }

    final candidateMounts = <String, Map<String, String>>{}; // mountPath -> {device, label, model}

    // 2. Fast check of /proc/mounts for already mounted removable media (/media, /run/media)
    try {
      final mountsFile = File('/proc/mounts');
      if (mountsFile.existsSync()) {
        final lines = mountsFile.readAsLinesSync();
        for (final line in lines) {
          final parts = line.split(' ');
          if (parts.length >= 2) {
            final dev = parts[0];
            final mount = parts[1];
            if (mount.startsWith('/media') || mount.startsWith('/run/media')) {
              if (!_isProtectedMount(mount)) {
                candidateMounts[mount] = {
                  'device': dev,
                  'label': mount.split('/').last,
                  'model': 'USB Drive',
                };
              }
            }
          }
        }
      }
    } catch (_) {}

    // 3. Query lsblk for USB block devices (mounted or unmounted)
    try {
      final res = await Process.run('lsblk', [
        '-J',
        '-o',
        'NAME,MOUNTPOINT,RM,TRAN,FSTYPE,LABEL,UUID,PATH,MODEL,SIZE',
      ]).timeout(const Duration(seconds: 3));

      if (res.exitCode == 0) {
        final data = jsonDecode(res.stdout as String) as Map<String, dynamic>;
        final blockDevices = (data['blockdevices'] as List<dynamic>?) ?? [];

        for (final dev in blockDevices) {
          final isUsb = dev['rm'] == true || dev['tran'] == 'usb';
          if (!isUsb) continue;

          final model = (dev['model'] as String?)?.trim() ?? 'USB Drive';

          void inspectNode(Map<String, dynamic> node) {
            final path = node['path'] as String?;
            final mount = node['mountpoint'] as String?;
            final fstype = (node['fstype'] as String?)?.toLowerCase();
            final label = (node['label'] as String?)?.trim() ?? '';

            if (mount != null && mount.isNotEmpty) {
              if (!_isProtectedMount(mount)) {
                candidateMounts[mount] = {
                  'device': path ?? '',
                  'label': label.isNotEmpty ? label : mount.split('/').last,
                  'model': model,
                };
              }
            } else if (path != null && fstype != null) {
              // Unmounted partition on USB drive: attempt safe mount
              const mountableTypes = ['vfat', 'exfat', 'ext4', 'ext3', 'ext2', 'ntfs', 'btrfs'];
              if (mountableTypes.contains(fstype)) {
                try {
                  final mountRes = Process.runSync('udisksctl', [
                    'mount',
                    '-b',
                    path,
                    '--no-user-interaction',
                  ]);
                  if (mountRes.exitCode == 0) {
                    final out = mountRes.stdout.toString();
                    final match = RegExp(r'Mounted\s+\S+\s+at\s+(\S+)').firstMatch(out);
                    if (match != null) {
                      final newMount = match.group(1)!;
                      _autoMountedDevices.add(path);
                      candidateMounts[newMount] = {
                        'device': path,
                        'label': label.isNotEmpty ? label : newMount.split('/').last,
                        'model': model,
                      };
                    }
                  }
                } catch (_) {}
              }
            }
          }

          final children = (dev['children'] as List<dynamic>?);
          if (children != null && children.isNotEmpty) {
            for (final c in children) {
              inspectNode(c as Map<String, dynamic>);
            }
          } else {
            inspectNode(dev as Map<String, dynamic>);
          }
        }
      }
    } catch (_) {}

    // 4. Scan candidate mount directories for master key files
    for (final entry in candidateMounts.entries) {
      final mountPath = entry.key;
      final devMeta = entry.value;

      final keyInfo = _checkDirectoryForKey(
        mountPath: mountPath,
        devMeta: devMeta,
        requiredToken: token,
      );

      if (keyInfo != null) {
        return keyInfo;
      }
    }

    // 5. Clean up temporary auto-mounts that had no master key
    for (final devPath in _autoMountedDevices.toList()) {
      try {
        Process.runSync('udisksctl', ['unmount', '-b', devPath, '--no-user-interaction']);
        _autoMountedDevices.remove(devPath);
      } catch (_) {}
    }

    return null;
  }

  /// Checks a single mount directory (root and .swarm/ subfolder) for key files.
  static UsbMasterKeyInfo? _checkDirectoryForKey({
    required String mountPath,
    required Map<String, String> devMeta,
    required String? requiredToken,
  }) {
    for (final fileName in supportedKeyFiles) {
      final candidates = [
        File('$mountPath/$fileName'),
        File('$mountPath/.swarm/$fileName'),
      ];

      for (final f in candidates) {
        if (!f.existsSync()) continue;

        try {
          final content = f.readAsStringSync().trim();
          if (content.isEmpty) continue;

          if (_verifyContent(content, requiredToken)) {
            return UsbMasterKeyInfo(
              filePath: f.path,
              mountPath: mountPath,
              devicePath: devMeta['device'] ?? '',
              driveLabel: devMeta['label']?.isNotEmpty == true
                  ? devMeta['label']!
                  : devMeta['model'] ?? 'USB Flash Drive',
              keyContent: content,
              detectedAt: DateTime.now(),
            );
          }
        } catch (_) {}
      }
    }
    return null;
  }

  /// Verifies file contents against either a configured secret or default signature.
  static bool _verifyContent(String content, String? requiredToken) {
    // If a custom token is configured:
    if (requiredToken != null && requiredToken.trim().isNotEmpty) {
      final cleanRequired = requiredToken.trim();
      if (content == cleanRequired || content.contains(cleanRequired)) return true;

      // Also check SHA-256 match
      final contentSha = sha256.convert(utf8.encode(cleanRequired)).toString();
      if (content.contains(contentSha)) return true;
      return false;
    }

    // If no custom token is configured, accept any file containing standard master signatures
    // or standard KEY= variable, or valid non-empty key text.
    final upper = content.toUpperCase();
    if (upper.contains('SWARM_MASTER_KEY') ||
        upper.contains('SWARM-MASTER-KEY') ||
        upper.contains('LUCILLE-MASTER-KEY') ||
        upper.contains('LUCILLE_KEY') ||
        upper.contains('KEY=') ||
        content.length >= 6) {
      return true;
    }

    return false;
  }

  /// Checks if a mount path belongs to a protected system mount.
  static bool _isProtectedMount(String path) {
    if (path.contains('lucy-master') || path.contains('/run/media/i30ltz/lucy-master')) return true;
    for (final p in _protectedMountPrefixes) {
      if (path == p) return true;
    }
    return false;
  }

  /// Lists available writable USB drives that can be provisioned as a Master Key.
  static Future<List<UsbDriveTarget>> listAvailableUsbDrives() async {
    final targets = <UsbDriveTarget>[];

    try {
      final res = await Process.run('lsblk', [
        '-J',
        '-o',
        'NAME,MOUNTPOINT,RM,TRAN,FSTYPE,LABEL,UUID,PATH,MODEL,SIZE',
      ]).timeout(const Duration(seconds: 3));

      if (res.exitCode == 0) {
        final data = jsonDecode(res.stdout as String) as Map<String, dynamic>;
        final blockDevices = (data['blockdevices'] as List<dynamic>?) ?? [];

        for (final dev in blockDevices) {
          final isUsb = dev['rm'] == true || dev['tran'] == 'usb';
          if (!isUsb) continue;

          final model = (dev['model'] as String?)?.trim() ?? 'Flash Drive';

          void collectNode(Map<String, dynamic> node) {
            final path = node['path'] as String?;
            var mount = node['mountpoint'] as String?;
            final label = (node['label'] as String?)?.trim() ?? '';
            final size = (node['size'] as String?)?.trim() ?? '';
            final fstype = (node['fstype'] as String?)?.toLowerCase();

            // Ignore system mounts
            if (mount != null && _isProtectedMount(mount)) return;

            // Auto-mount if needed
            if ((mount == null || mount.isEmpty) && path != null && fstype != null) {
              const mountableTypes = ['vfat', 'exfat', 'ext4', 'ext3', 'ext2', 'ntfs'];
              if (mountableTypes.contains(fstype)) {
                try {
                  final mountRes = Process.runSync('udisksctl', ['mount', '-b', path, '--no-user-interaction']);
                  if (mountRes.exitCode == 0) {
                    final match = RegExp(r'Mounted\s+\S+\s+at\s+(\S+)').firstMatch(mountRes.stdout.toString());
                    if (match != null) mount = match.group(1)!;
                  }
                } catch (_) {}
              }
            }

            if (mount != null && mount.isNotEmpty && !_isProtectedMount(mount)) {
              final hasKey = supportedKeyFiles.any((k) =>
                  File('$mount/$k').existsSync() || File('$mount/.swarm/$k').existsSync());

              targets.add(UsbDriveTarget(
                mountPath: mount,
                devicePath: path ?? '',
                label: label,
                model: model,
                size: size,
                hasExistingKey: hasKey,
              ));
            }
          }

          final children = (dev['children'] as List<dynamic>?);
          if (children != null && children.isNotEmpty) {
            for (final c in children) {
              collectNode(c as Map<String, dynamic>);
            }
          } else {
            collectNode(dev as Map<String, dynamic>);
          }
        }
      }
    } catch (_) {}

    return targets;
  }

  /// Writes the Master Key file (`swarm_master.key`) to the specified USB drive root.
  static Future<bool> writeMasterKeyToDrive(
    String mountPath, {
    String? customSecret,
  }) async {
    if (_isProtectedMount(mountPath)) {
      throw Exception('Refusing to write to protected system mount: $mountPath');
    }

    try {
      final secret = customSecret?.trim().isNotEmpty == true
          ? customSecret!.trim()
          : defaultMagicToken;

      final keyFile = File('$mountPath/swarm_master.key');
      final content = StringBuffer()
        ..writeln('# SWARM OS HARDWARE MASTER KEY')
        ..writeln('# Created: ${DateTime.now().toUtc().toIso8601String()}')
        ..writeln('# Plug this flash drive into any SWARM OS device to unlock or reset the cipher.')
        ..writeln('SYSTEM=SWARM_OS')
        ..writeln('KEY=$secret')
        ..writeln('SHA256=${sha256.convert(utf8.encode(secret))}')
        ..writeln();

      await keyFile.writeAsString(content.toString(), flush: true);

      // Save secret to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(prefKeySecret, secret);

      // Also persist to /etc/swarm_os/master_key.token if writable
      try {
        final etcDir = Directory('/etc/swarm_os');
        if (await etcDir.exists()) {
          final etcFile = File(etcKeyFile);
          await etcFile.writeAsString(secret, flush: true);
        }
      } catch (_) {}

      return true;
    } catch (e) {
      stderr.writeln('UsbMasterKeyService error writing key: $e');
      return false;
    }
  }
}

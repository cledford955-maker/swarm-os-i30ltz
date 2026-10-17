import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
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
  /// Old plaintext secret pref (before 2026-10-14). Moved to [keyHashFile] as a hash on first read.
  static const String prefKeySecret = 'usb_master_key_secret';
  static const String prefKeyAutoUnlock = 'usb_master_key_auto_unlock';

  /// Published in this source and written by the old one-click "make key", so it never unlocks.
  static const String defaultMagicToken = 'SWARM_MASTER_KEY_V1';

  /// SHA-256 (hex) of the one registered key-file secret, shared with `swarm-usb-key create`.
  /// Only the hash is kept here, and a hash is never accepted as a key, so reading this file does
  /// not give anyone a working stick. No file = no USB key file can unlock this machine.
  static String get keyHashFile {
    if (keyHashFileOverride != null) return keyHashFileOverride!;
    final xdg = Platform.environment['XDG_CONFIG_HOME'];
    final base = (xdg != null && xdg.isNotEmpty) ? xdg : '${Platform.environment['HOME'] ?? ''}/.config';
    return '$base/swarm_os/usb_master_key.sha256';
  }

  @visibleForTesting
  static String? keyHashFileOverride;

  static final RegExp _sha256Hex = RegExp(r'^[0-9a-f]{64}$');
  static const int _maxKeyFileBytes = 4096;
  static const int _minCustomSecretLength = 16;

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

  /// Written by the root service `swarm-key-status` when a registered SWARM hardware key (the
  /// stick made by provision_swarm_key.sh) is plugged in. The app cannot read that stick's raw
  /// secret partition itself, and cannot forge this root-written file; it holds no secret.
  static const String swarmKeyStatusFile = '/run/swarm_key/status';

  /// Reads [swarmKeyStatusFile]: info when a SWARM hardware key is present, else null.
  static UsbMasterKeyInfo? readSwarmKeyStatus({String path = swarmKeyStatusFile}) {
    try {
      final f = File(path);
      if (!f.existsSync()) return null;
      final j = jsonDecode(f.readAsStringSync());
      if (j is! Map || j['present'] != true) return null;
      final serial = j['serial'];
      if (serial is! String || !RegExp(r'^[A-Za-z0-9-]{1,64}$').hasMatch(serial)) return null;
      return UsbMasterKeyInfo(
        filePath: path,
        mountPath: '',
        devicePath: '',
        driveLabel: 'SWARM key $serial',
        keyContent: '',
        detectedAt: DateTime.now(),
      );
    } catch (_) {
      return null;
    }
  }

  /// The registered key-file hash, or null when no USB key file has been made on this machine.
  static Future<String?> readKeyHash() async {
    await _migrateLegacySecret();
    try {
      final f = File(keyHashFile);
      if (!f.existsSync()) return null;
      final h = f.readAsStringSync().trim().toLowerCase();
      return _sha256Hex.hasMatch(h) ? h : null;
    } catch (_) {
      return null;
    }
  }

  /// The old code kept the secret itself in prefs. Hash it into [keyHashFile] (unless it is the
  /// public default token) and drop the plaintext. The pref is only removed once that worked.
  static Future<void> _migrateLegacySecret() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final old = prefs.getString(prefKeySecret)?.trim();
      if (old == null) return;
      if (old.isNotEmpty && old != defaultMagicToken && !File(keyHashFile).existsSync()) {
        if (!_writeKeyHash(_sha256(old))) return;
      }
      await prefs.remove(prefKeySecret);
    } catch (_) {}
  }

  static bool _writeKeyHash(String hash) {
    try {
      final f = File(keyHashFile);
      f.parent.createSync(recursive: true);
      final tmp = File('${f.path}.tmp');
      tmp.writeAsStringSync('$hash\n', flush: true);
      tmp.renameSync(f.path);
      return true;
    } catch (_) {
      return false;
    }
  }

  static String _sha256(String s) => sha256.convert(utf8.encode(s)).toString();

  static bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }

  static String _randomSecret() {
    final rnd = Random.secure();
    return List<int>.generate(32, (_) => rnd.nextInt(256))
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
  }

  /// True only when [content] has a `KEY=<secret>` line whose SHA-256 equals [storedHash].
  /// With no registered hash nothing passes; the public default token, the hash itself, or the
  /// secret buried in other text never pass either.
  static bool verifyKeyFile(String content, String? storedHash) {
    final want = storedHash?.trim().toLowerCase();
    if (want == null || !_sha256Hex.hasMatch(want)) return false;
    for (final raw in const LineSplitter().convert(content)) {
      final line = raw.trim();
      if (!line.startsWith('KEY=')) continue;
      final secret = line.substring(4).trim();
      if (secret.isEmpty || secret == defaultMagicToken) continue;
      if (_constantTimeEquals(_sha256(secret), want)) return true;
    }
    return false;
  }

  /// Scans all attached USB drives for a valid master key file.
  /// Non-blocking, fast execution (< 250ms).
  static Future<UsbMasterKeyInfo?> scanForMasterKey({String? expectedKeyHash}) async {
    // The SWARM hardware key (root-verified) wins over any loose key file on other drives.
    final hw = readSwarmKeyStatus();
    if (hw != null) return hw;

    // 1. A loose key file can only unlock once a key was made here (its hash is registered).
    // Without one, leave the USB drives alone: no lsblk, no auto-mounting from the lock screen.
    final token = expectedKeyHash ?? await readKeyHash();
    if (token == null) return null;

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
  @visibleForTesting
  static UsbMasterKeyInfo? checkDirectoryForKey(String mountPath, String keyHash) =>
      _checkDirectoryForKey(mountPath: mountPath, devMeta: const {}, requiredToken: keyHash);

  static UsbMasterKeyInfo? _checkDirectoryForKey({
    required String mountPath,
    required Map<String, String> devMeta,
    required String requiredToken,
  }) {
    for (final fileName in supportedKeyFiles) {
      for (final p in ['$mountPath/$fileName', '$mountPath/.swarm/$fileName']) {
        if (!_isRealFileUnder(mountPath, p)) continue;

        try {
          final f = File(p);
          if (f.lengthSync() > _maxKeyFileBytes) continue;
          if (verifyKeyFile(f.readAsStringSync(), requiredToken)) {
            return UsbMasterKeyInfo(
              filePath: f.path,
              mountPath: mountPath,
              devicePath: devMeta['device'] ?? '',
              driveLabel: devMeta['label']?.isNotEmpty == true
                  ? devMeta['label']!
                  : devMeta['model'] ?? 'USB Flash Drive',
              keyContent: '', // the secret stays on the stick
              detectedAt: DateTime.now(),
            );
          }
        } catch (_) {}
      }
    }
    return null;
  }

  /// [path] and every folder between it and [mountPath] must be real, not symlinks, so a stick
  /// (ext4/btrfs can hold links) cannot point the lock screen at a file elsewhere on this machine.
  static bool _isRealFileUnder(String mountPath, String path) {
    if (FileSystemEntity.typeSync(path, followLinks: false) != FileSystemEntityType.file) return false;
    var dir = File(path).parent.path;
    while (dir.length > mountPath.length) {
      if (FileSystemEntity.typeSync(dir, followLinks: false) != FileSystemEntityType.directory) return false;
      dir = Directory(dir).parent.path;
    }
    return true;
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

  /// Writes `swarm_master.key` with a fresh random secret (or [customSecret], at least 16 chars)
  /// and registers its hash. One USB key file is valid at a time: making a new stick retires the
  /// previous one. Callers must only offer this to someone already authenticated.
  static Future<bool> writeMasterKeyToDrive(
    String mountPath, {
    String? customSecret,
  }) async {
    if (_isProtectedMount(mountPath)) {
      throw Exception('Refusing to write to protected system mount: $mountPath');
    }
    final custom = customSecret?.trim() ?? '';
    if (custom == defaultMagicToken || (custom.isNotEmpty && custom.length < _minCustomSecretLength)) {
      throw ArgumentError('Key secret must be private and at least $_minCustomSecretLength characters');
    }

    try {
      final secret = custom.isNotEmpty ? custom : _randomSecret();
      final hash = _sha256(secret);

      final keyFile = File('$mountPath/swarm_master.key');
      // Never write through a link that already sits on the stick.
      final existing = FileSystemEntity.typeSync(keyFile.path, followLinks: false);
      if (existing != FileSystemEntityType.notFound && existing != FileSystemEntityType.file) {
        throw Exception('Refusing to write: ${keyFile.path} is not a regular file');
      }
      final content = StringBuffer()
        ..writeln('# SWARM OS HARDWARE MASTER KEY')
        ..writeln('# Created: ${DateTime.now().toUtc().toIso8601String()}')
        ..writeln('# Unlocks the lock screen of the SWARM OS machine that made it. Keep it private.')
        ..writeln('SYSTEM=SWARM_OS')
        ..writeln('KEY=$secret')
        ..writeln();

      await keyFile.writeAsString(content.toString(), flush: true);

      // Read it back so a full or failing stick is caught before the old key is retired.
      if (!verifyKeyFile(await keyFile.readAsString(), hash)) {
        throw Exception('Key file did not read back correctly');
      }
      if (!_writeKeyHash(hash)) throw Exception('Could not save the key hash to $keyHashFile');

      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(prefKeySecret);
      } catch (_) {}

      return true;
    } catch (e) {
      stderr.writeln('UsbMasterKeyService error writing key: $e');
      return false;
    }
  }
}

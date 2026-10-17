// Desktop wallpaper rotation.
//
// The shell shows a random picture from a folder and swaps to another one on a
// timer. The folder is read again on every swap, so pictures dropped in while
// the shell is running join the rotation without a restart. Only the folder
// itself is read, not its subfolders, so parking a picture in a subfolder takes
// it out of the rotation.
//
// Folder: /mnt/Lucy/images/websitebackgrounds. When it has no usable image
// (live ISO, drive not mounted) the caller keeps the wallpaper bundled in
// assets.
//
// SWARM_WALLPAPER_DIR overrides the folder (used by tests).
// SWARM_WALLPAPER_INTERVAL_SECS overrides the swap interval: default 600,
// minimum 15.
// SWARM_WALLPAPER_BLUNT=0 turns off the burning blunt and rising smoke that
// sit over every wallpaper (on by default).

import 'dart:io' hide Platform;
import 'dart:math';
import '../platform/platform.dart';

class WallpaperRotationService {
  WallpaperRotationService._();

  static const String defaultDir = '/mnt/Lucy/images/websitebackgrounds';
  static const List<String> extensions = ['jpg', 'jpeg', 'png', 'webp'];
  static const int defaultIntervalSecs = 600;
  static const int minIntervalSecs = 15;

  static String get dir => Platform.environment['SWARM_WALLPAPER_DIR'] ?? defaultDir;

  static Duration get interval =>
      parseInterval(Platform.environment['SWARM_WALLPAPER_INTERVAL_SECS']);

  /// Whether the blunt and its smoke are drawn over the wallpaper.
  static bool get blunt => parseFlag(Platform.environment['SWARM_WALLPAPER_BLUNT'], defaultValue: true);

  /// "0", "false", "off" or "no" (any case) is off; anything else non-empty is
  /// on; missing or empty gives [defaultValue].
  static bool parseFlag(String? raw, {required bool defaultValue}) {
    final v = raw?.trim().toLowerCase() ?? '';
    if (v.isEmpty) return defaultValue;
    return !const {'0', 'false', 'off', 'no'}.contains(v);
  }

  /// Seconds string → swap interval. Missing or unparsable gives the default;
  /// anything under the minimum is raised to it so a typo can't spin the disk.
  static Duration parseInterval(String? raw) {
    final secs = int.tryParse(raw?.trim() ?? '') ?? defaultIntervalSecs;
    return Duration(seconds: max(secs, minIntervalSecs));
  }

  /// Image files directly inside [folder], sorted by path. Empty when the
  /// folder is missing or unreadable — never throws into the UI.
  static Future<List<String>> listImages(String folder) async {
    final out = <String>[];
    try {
      await for (final entry in Directory(folder).list()) {
        if (entry is! File) continue;
        final name = entry.path.split('/').last;
        final dot = name.lastIndexOf('.');
        if (name.startsWith('.') || dot < 0) continue;
        if (!extensions.contains(name.substring(dot + 1).toLowerCase())) continue;
        out.add(entry.path);
      }
    } on FileSystemException {
      return const [];
    } on UnsupportedError {
      return const []; // web build: no file system
    }
    out.sort();
    return out;
  }

  /// True for the picture the shell's aura bolt glows were drawn for. The
  /// glows are placed by fractions of that artwork, so they only make sense
  /// on it. Matches `FALLENSOLDIER.jpeg`, `fallen_soldier.jpg`, etc.
  static bool isFallenSoldier(String path) {
    final stem = path.split('/').last.split('.').first;
    return stem.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '') == 'fallensoldier';
  }
}

/// Random order without repeats: every picture is shown once before any is
/// shown again, and the first of a new round is never the one just shown.
class WallpaperPicker {
  WallpaperPicker({Random? random}) : _random = random ?? Random();

  final Random _random;
  final Set<String> _shown = {};
  final Set<String> _rejected = {};
  String? _current;

  /// Next picture from [pool], or null when nothing usable is left.
  String? next(List<String> pool) {
    final usable = [for (final p in pool) if (!_rejected.contains(p)) p];
    if (usable.isEmpty) return _current = null;

    var fresh = [for (final p in usable) if (!_shown.contains(p)) p];
    if (fresh.isEmpty) {
      _shown.clear();
      if (_current != null) _shown.add(_current!);
      fresh = [for (final p in usable) if (!_shown.contains(p)) p];
      if (fresh.isEmpty) fresh = usable; // a pool of one
    }
    final pick = fresh[_random.nextInt(fresh.length)];
    _shown.add(pick);
    return _current = pick;
  }

  /// Drop a picture that failed to decode so it is not picked again.
  void reject(String path) => _rejected.add(path);
}

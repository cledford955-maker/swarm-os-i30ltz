// Garden background photos.
//
// Garden mode cycles full-screen photos of real plants and buds behind the
// strain card. They come from the first of these folders that has an image:
//   /opt/swarm_os/garden/backgrounds   (installed system, filled by the garden
//                                       content updater)
//   /mnt/Lucy/images/weedbackgrounds   (dev drive)
// When neither has one, the garden keeps its painted grow-room.
//
// A photo is only labelled with a strain when the file says so, never guessed:
//   blue_dream__01.jpg        → "Blue Dream"   (text before the first "__")
//   gorilla_glue_4__flower.png→ "Gorilla Glue #4" when it is a known strain
//   greenhouse_rows.jpg       → no strain, just a garden photo
// An optional labels.json next to the photos overrides or adds details:
//   { "greenhouse_rows.jpg": { "caption": "Flowering room",
//                              "credit": "Photo: A. Grower / CC BY 4.0" } }
// "strain", "caption" and "credit" are all optional. Credit is shown on screen,
// so photos that need attribution keep it.
//
// GARDEN_BACKGROUNDS_DIR overrides the folder list (used by tests).
// GARDEN_BACKGROUND_INTERVAL_SECS sets seconds per photo: default 12, minimum 4.

import 'dart:convert';
import 'dart:io' hide Platform;
import 'dart:math';
import '../platform/platform.dart';
import 'garden_photos_service.dart';
import 'wallpaper_rotation_service.dart';

class GardenBackground {
  const GardenBackground({required this.path, this.strain, this.caption, this.credit});

  final String path;

  /// Display name of the strain in the photo; null when the photo isn't tied
  /// to one.
  final String? strain;
  final String? caption;
  final String? credit;
}

class GardenBackgroundsService {
  GardenBackgroundsService._();

  static const List<String> defaultDirs = [
    '/opt/swarm_os/garden/backgrounds',
    '/mnt/Lucy/images/weedbackgrounds',
  ];
  static const int defaultIntervalSecs = 12;
  static const int minIntervalSecs = 4;
  static const String manifestName = 'labels.json';

  static List<String> get dirs {
    final override = Platform.environment['GARDEN_BACKGROUNDS_DIR'];
    return (override != null && override.isNotEmpty) ? [override] : defaultDirs;
  }

  static Duration get interval =>
      parseInterval(Platform.environment['GARDEN_BACKGROUND_INTERVAL_SECS']);

  static Duration parseInterval(String? raw) {
    final secs = int.tryParse(raw?.trim() ?? '') ?? defaultIntervalSecs;
    return Duration(seconds: max(secs, minIntervalSecs));
  }

  /// Labelled photos from the first folder in [folders] that has any, or an
  /// empty list. [knownStrains] are display names (e.g. "Gorilla Glue #4") so a
  /// file slug can be matched back to its proper name.
  static Future<List<GardenBackground>> load(
    List<String> folders, {
    Iterable<String> knownStrains = const [],
  }) async {
    for (final folder in folders) {
      final paths = await WallpaperRotationService.listImages(folder);
      if (paths.isEmpty) continue;
      final manifest = await _readManifest(folder);
      return [
        for (final p in paths)
          labelFor(p, knownStrains: knownStrains, entry: manifest[p.split('/').last]),
      ];
    }
    return const [];
  }

  /// Build the label for one photo from its file name and optional manifest
  /// [entry].
  static GardenBackground labelFor(
    String path, {
    Iterable<String> knownStrains = const [],
    Map<String, dynamic>? entry,
  }) {
    final file = path.split('/').last;
    final dot = file.lastIndexOf('.');
    final stem = dot > 0 ? file.substring(0, dot) : file;

    String? strain;
    final sep = stem.indexOf('__');
    if (sep > 0) strain = _strainFromSlug(stem.substring(0, sep), knownStrains);

    String? caption, credit;
    if (entry != null) {
      strain = _text(entry['strain']) ?? strain;
      caption = _text(entry['caption']);
      credit = _text(entry['credit']);
    }
    return GardenBackground(path: path, strain: strain, caption: caption, credit: credit);
  }

  static String? _strainFromSlug(String raw, Iterable<String> known) {
    final slug = GardenPhotosService.slugFor(raw);
    if (slug.isEmpty) return null;
    for (final name in known) {
      if (GardenPhotosService.slugFor(name) == slug) return name;
    }
    // Not one of ours, but the file names it — show it as written.
    return slug.split('_').map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1)).join(' ');
  }

  static String? _text(Object? v) {
    if (v is! String) return null;
    final t = v.trim();
    return t.isEmpty ? null : t;
  }

  static Future<Map<String, Map<String, dynamic>>> _readManifest(String folder) async {
    try {
      final decoded = jsonDecode(await File('$folder/$manifestName').readAsString());
      if (decoded is! Map) return const {};
      return {
        for (final e in decoded.entries)
          if (e.key is String && e.value is Map) e.key as String: Map<String, dynamic>.from(e.value as Map),
      };
    } on FileSystemException {
      return const {}; // no manifest — normal
    } on FormatException {
      return const {}; // bad JSON: keep the file-name labels rather than fail
    } on UnsupportedError {
      return const {};
    }
  }
}

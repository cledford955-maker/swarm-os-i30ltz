// Garden photo lookup.
//
// The garden mode paints procedural buds by default. When the user drops real
// strain photos into `/opt/swarm_os/garden/`, we prefer those over the painter.
//
// File-name convention: snake_case of the strain name, any of jpg/jpeg/png/webp.
//   "Lucille OG"            → lucille_og.jpg
//   "Gorilla Glue #4"       → gorilla_glue_4.png
//   "Girl Scout Cookies"    → girl_scout_cookies.webp
//
// A single lookup per name is cached for the process lifetime — file appears at
// build time and does not change between runs. If the folder is missing (dev
// laptop, ISO where the user hasn't populated it yet), every call reports
// "no photo" and the procedural fallback stays.
//
// GARDEN_PHOTOS_DIR env var overrides the default path — used by tests.

import 'dart:io';
import 'dart:collection';

class GardenPhotosService {
  GardenPhotosService._();
  static final instance = GardenPhotosService._();

  static String get defaultDir {
    final override = Platform.environment['GARDEN_PHOTOS_DIR'];
    return override ?? '/opt/swarm_os/garden';
  }

  static const List<String> _extensions = ['jpg', 'jpeg', 'png', 'webp'];

  final HashMap<String, String?> _cache = HashMap<String, String?>();

  /// Convert a display strain name to the on-disk slug.
  ///
  /// "Lucille OG"          → "lucille_og"
  /// "Gorilla Glue #4"     → "gorilla_glue_4"
  /// "Girl Scout Cookies"  → "girl_scout_cookies"
  static String slugFor(String strainName) {
    final buf = StringBuffer();
    var prevUnderscore = false;
    for (final rune in strainName.toLowerCase().runes) {
      final c = String.fromCharCode(rune);
      final isAlnum = (c.codeUnitAt(0) >= 0x30 && c.codeUnitAt(0) <= 0x39) ||
          (c.codeUnitAt(0) >= 0x61 && c.codeUnitAt(0) <= 0x7A);
      if (isAlnum) {
        buf.write(c);
        prevUnderscore = false;
      } else {
        if (!prevUnderscore && buf.isNotEmpty) {
          buf.write('_');
          prevUnderscore = true;
        }
      }
    }
    // Trim trailing underscore.
    final out = buf.toString();
    if (out.endsWith('_')) return out.substring(0, out.length - 1);
    return out;
  }

  /// Return the absolute path of a photo file for [strainName], or null when
  /// none exists.
  ///
  /// [dir] overrides the default lookup directory (used in tests).
  String? photoPathFor(String strainName, {String? dir}) {
    final root = dir ?? defaultDir;
    final cacheKey = '$root|$strainName';
    if (_cache.containsKey(cacheKey)) return _cache[cacheKey];

    final slug = slugFor(strainName);
    if (slug.isEmpty) {
      _cache[cacheKey] = null;
      return null;
    }
    for (final ext in _extensions) {
      final candidate = '$root/$slug.$ext';
      // FileSystemException on unreadable dirs must not throw up into the UI.
      try {
        if (File(candidate).existsSync()) {
          _cache[cacheKey] = candidate;
          return candidate;
        }
      } catch (_) {
        // Continue — if one probe fails (permissions on a sibling), a later
        // ext might still succeed.
      }
    }
    _cache[cacheKey] = null;
    return null;
  }

  /// Clear the file-existence cache. Useful only in tests.
  void resetCache() => _cache.clear();
}

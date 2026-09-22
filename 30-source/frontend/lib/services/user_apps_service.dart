import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A user-installed app that shows up as an icon on the hex desktop.
///
/// Distinct from the hardcoded SwarmAppRegistry entries: these are created
/// by the App Store install flow (or "Add to desktop" from the apps page)
/// and persist across reboots in SharedPreferences as JSON.
@immutable
class UserApp {
  final String id;            // stable unique id, e.g. 'user_gimp'
  final String name;          // display name on the tile
  final String packageName;   // pacman/yay package name, e.g. 'gimp'
  final String execCommand;   // launch command from the .desktop entry
  final String iconPath;      // absolute path to a real icon file (png/svg/xpm)
  final String desktopEntry;  // /usr/share/applications/<pkg>.desktop path
  final String description;
  final DateTime installedAt;

  const UserApp({
    required this.id,
    required this.name,
    required this.packageName,
    required this.execCommand,
    required this.iconPath,
    required this.desktopEntry,
    this.description = '',
    required this.installedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'packageName': packageName,
        'execCommand': execCommand,
        'iconPath': iconPath,
        'desktopEntry': desktopEntry,
        'description': description,
        'installedAt': installedAt.toIso8601String(),
      };

  factory UserApp.fromJson(Map<String, dynamic> j) => UserApp(
        id: j['id'] as String? ?? '',
        name: j['name'] as String? ?? '',
        packageName: j['packageName'] as String? ?? '',
        execCommand: j['execCommand'] as String? ?? '',
        iconPath: j['iconPath'] as String? ?? '',
        desktopEntry: j['desktopEntry'] as String? ?? '',
        description: j['description'] as String? ?? '',
        installedAt: DateTime.tryParse(j['installedAt'] as String? ?? '') ?? DateTime.now(),
      );
}

/// Registry of user-installed desktop apps. Singleton so the hex desktop,
/// app store, and apps page all see the same live list.
class UserAppsService extends ChangeNotifier {
  UserAppsService._() {
    _load();
  }
  static final UserAppsService instance = UserAppsService._();

  static const _kPrefsKey = 'swarm_user_desktop_apps';

  final List<UserApp> _apps = [];
  List<UserApp> get apps => List.unmodifiable(_apps);

  bool _loaded = false;
  bool get loaded => _loaded;

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kPrefsKey);
      if (raw != null) {
        final List<dynamic> decoded = jsonDecode(raw);
        _apps
          ..clear()
          ..addAll(decoded
              .whereType<Map>()
              .map((e) => UserApp.fromJson(Map<String, dynamic>.from(e))));
      }
    } catch (e) {
      debugPrint('[UserAppsService] load failed: $e');
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          _kPrefsKey, jsonEncode(_apps.map((a) => a.toJson()).toList()));
    } catch (e) {
      debugPrint('[UserAppsService] persist failed: $e');
    }
  }

  UserApp? byId(String id) {
    for (final a in _apps) {
      if (a.id == id) return a;
    }
    return null;
  }

  UserApp? byPackage(String packageName) {
    for (final a in _apps) {
      if (a.packageName == packageName) return a;
    }
    return null;
  }

  bool isInstalled(String packageName) => byPackage(packageName) != null;

  /// Registers a freshly installed package as a desktop app: reads its
  /// .desktop entry for the real name/exec/icon, then persists + notifies.
  /// Returns the created entry, or null when no .desktop entry exists for
  /// the package (headless packages can't become desktop icons).
  Future<UserApp?> registerInstalled(String packageName) async {
    if (byPackage(packageName) != null) return byPackage(packageName);

    final entry = await findDesktopEntry(packageName);
    if (entry == null) return null;

    final app = UserApp(
      id: 'user_${packageName.replaceAll(RegExp(r'[^a-z0-9_-]'), '_')}',
      name: entry['name'] ?? packageName,
      packageName: packageName,
      execCommand: entry['exec'] ?? packageName,
      iconPath: entry['icon'] ?? '',
      desktopEntry: entry['path'] ?? '',
      description: entry['comment'] ?? '',
      installedAt: DateTime.now(),
    );

    _apps.add(app);
    await _persist();
    notifyListeners();
    return app;
  }

  /// Removes the desktop icon entry only — the package stays installed.
  Future<void> removeIcon(String id) async {
    _apps.removeWhere((a) => a.id == id);
    await _persist();
    notifyListeners();
  }

  /// Removes the desktop icon entry for a package that was just uninstalled.
  Future<void> removeByPackage(String packageName) async {
    _apps.removeWhere((a) => a.packageName == packageName);
    await _persist();
    notifyListeners();
  }

  // ── .desktop entry scanning ───────────────────────────────────────────────

  static const _iconDirs = [
    '/usr/share/icons',
    '/usr/share/pixmaps',
    '/usr/local/share/icons',
    '/usr/local/share/pixmaps',
    '/home',
  ];

  /// Finds the .desktop entry for a package and parses Name/Exec/Icon/Comment.
  /// Tries the exact package name first, then a prefix match (many packages
  /// install org.example.Foo.desktop rather than foo.desktop).
  static Future<Map<String, String>?> findDesktopEntry(String packageName) async {
    final dirs = [
      '/usr/share/applications',
      '/usr/local/share/applications',
      Platform.environment['HOME'] != null
          ? '${Platform.environment['HOME']}/.local/share/applications'
          : '',
    ];
    for (final dir in dirs.where((d) => d.isNotEmpty)) {
      final d = Directory(dir);
      if (!await d.exists()) continue;
      final files = await d.list().toList();
      // Exact match first, then prefix.
      for (final candidate in [
        '$dir/$packageName.desktop',
        ...files
            .whereType<File>()
            .where((f) =>
                f.path.endsWith('.desktop') &&
                f.path
                    .split('/')
                    .last
                    .toLowerCase()
                    .startsWith(packageName.toLowerCase()))
            .map((f) => f.path),
      ]) {
        final file = File(candidate);
        if (!await file.exists()) continue;
        final parsed = await _parseDesktopFile(file);
        if (parsed != null && parsed['exec']?.isNotEmpty == true) return parsed;
      }
    }
    return null;
  }

  static Future<Map<String, String>?> _parseDesktopFile(File file) async {
    try {
      final lines = await file.readAsLines();
      final map = <String, String>{'path': file.path};
      String? icon;
      for (final line in lines) {
        if (line.startsWith('Name=') && !map.containsKey('name')) {
          map['name'] = line.substring(5).trim();
        } else if (line.startsWith('Exec=') && !map.containsKey('exec')) {
          // Strip desktop-entry field codes (%f %u %F %U etc.)
          map['exec'] = line.substring(5).split('%').first.trim();
        } else if (line.startsWith('Icon=') && icon == null) {
          icon = line.substring(5).trim();
        } else if (line.startsWith('Comment=') && !map.containsKey('comment')) {
          map['comment'] = line.substring(8).trim();
        } else if (line.startsWith('NoDisplay=true')) {
          return null; // hidden entry — not a launchable desktop app
        }
      }
      if (icon != null) map['icon'] = await resolveIconPath(icon);
      return map;
    } catch (_) {
      return null;
    }
  }

  /// Resolves an Icon= value (which may be a bare name like 'gimp' or an
  /// absolute path) to a real file path. Bare names are searched through the
  /// standard icon directories, preferring larger sizes.
  static Future<String> resolveIconPath(String icon) async {
    if (icon.isEmpty) return '';
    if (icon.startsWith('/')) {
      if (await File(icon).exists()) return icon;
      return '';
    }

    // Try common sizes, largest first, in each icon root.
    const sizes = ['512', '256', '128', '96', '64', '48', '32', '24', '16'];
    for (final root in _iconDirs) {
      if (root == '/home') continue; // handled below via XDG data dirs
      final rootDir = Directory(root);
      if (!await rootDir.exists()) continue;
      // hicolor / theme dirs: <root>/<theme>/<size>/<category>/<name>.<ext>
      try {
        await for (final theme in rootDir.list()) {
          if (theme is! Directory) continue;
          for (final size in sizes) {
            for (final ext in ['png', 'svg', 'xpm']) {
              for (final category in ['apps', 'applications', '']) {
                final p = '${theme.path}/$size/$category/$icon.$ext';
                if (await File(p).exists()) return p;
                // Some icons are size-suffixed: name_128.png
                final p2 = '${theme.path}/$size/$category/${icon}_$size.$ext';
                if (await File(p2).exists()) return p2;
              }
            }
          }
          // scalable dir
          for (final category in ['apps', 'applications', '']) {
            final p = '${theme.path}/scalable/$category/$icon.svg';
            if (await File(p).exists()) return p;
          }
        }
      } catch (_) {}
      // pixmaps-style flat lookup
      for (final ext in ['png', 'svg', 'xpm']) {
        final p = '$root/$icon.$ext';
        if (await File(p).exists()) return p;
      }
    }
    return '';
  }
}

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// A package search result row from `yay -Ss` / `pacman -Ss`.
@immutable
class PackageResult {
  final String repo;        // 'core', 'extra', 'multilib', 'aur', …
  final String name;
  final String version;
  final String description;
  final bool isAur;

  const PackageResult({
    required this.repo,
    required this.name,
    required this.version,
    required this.description,
    required this.isAur,
  });
}

/// Install / uninstall pipeline for Arch-family packages.
///
/// Search runs `yay -Ss --noconfirm` (falling back to `pacman -Ss`) and
/// parses the two-line repo/name ver — description format both emit.
///
/// Install and uninstall need root, which can't be granted from a detached
/// Flutter process — so they open a terminal emulator running the command
/// with a completion marker appended. When the marker file appears, the
/// install is treated as done and the app is registered as a desktop icon.
/// This mirrors how SystemLauncher verifies launches via status files.
class AppInstallerService {
  AppInstallerService._();
  static final AppInstallerService instance = AppInstallerService._();

  /// Directory for install/uninstall completion markers.
  static const _markerDir = '/tmp/swarm_installer';

  /// Terminal emulators tried in order for the interactive install window.
  static const _terminals = ['alacritty', 'foot', 'xterm', 'konsole', 'tilix'];

  // ── Search ────────────────────────────────────────────────────────────────

  Future<List<PackageResult>> search(String query) async {
    final q = query.trim();
    if (q.isEmpty) return [];

    // yay covers both repos and AUR; pacman is the fallback when yay isn't
    // installed. Both print the same "repo/name ver" + "    description"
    // two-line format.
    final cmd = await _has('yay') ? 'yay' : 'pacman';
    try {
      final r = await Process.run(cmd, ['-Ss', '--noconfirm', q],
          environment: {'TERM': 'xterm-256color'});
      if (r.exitCode != 0) return [];
      return _parseSearch(r.stdout.toString());
    } catch (e) {
      debugPrint('[AppInstaller] search failed: $e');
      return [];
    }
  }

  List<PackageResult> _parseSearch(String out) {
    final results = <PackageResult>[];
    final lines = out.split('\n');
    for (int i = 0; i + 1 < lines.length; i++) {
      final header = lines[i];
      if (header.isEmpty || header.startsWith(' ')) continue;
      // Format: repo/name version [installed]
      final slash = header.indexOf('/');
      if (slash <= 0) continue;
      final repo = header.substring(0, slash);
      final rest = header.substring(slash + 1);
      final parts = rest.split(' ');
      if (parts.length < 2) continue;
      final name = parts[0];
      final version = parts[1];
      final description = lines[i + 1].trim();
      results.add(PackageResult(
        repo: repo,
        name: name,
        version: version,
        description: description,
        isAur: repo == 'aur',
      ));
      i++; // consumed the description line
    }
    return results;
  }

  /// Whether a package is installed locally (`pacman -Qi` exit code).
  Future<bool> isInstalled(String packageName) async {
    try {
      final r = await Process.run('pacman', ['-Qi', packageName]);
      return r.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  // ── Install / Uninstall ────────────────────────────────────────────────────

  /// Opens a terminal window running the install command. Returns the
  /// completion marker path once the install finishes (marker file created),
  /// or null if no terminal emulator could be started.
  ///
  /// The marker is written by the shell command itself after pacman exits,
  /// which is the only reliable signal — the terminal stays open for the
  /// user to read the output, so the process exit can't be observed.
  Future<String?> installInTerminal(String packageName) =>
      _runInTerminal('Installing $packageName',
          'yay -S --needed $packageName || sudo pacman -S --needed $packageName');

  Future<String?> uninstallInTerminal(String packageName) =>
      _runInTerminal('Removing $packageName',
          'sudo pacman -Rns $packageName');

  Future<String?> _runInTerminal(String title, String command) async {
    final marker = '$_markerDir/${DateTime.now().microsecondsSinceEpoch}_${command.hashCode}.done';
    await Directory(_markerDir).create(recursive: true);

    // The marker is written after the command finishes (success or not);
    // the exit code is captured too so the caller can tell them apart.
    final wrapped =
        '$command; echo \$? > "$marker" 2>/dev/null; echo "Done — you can close this window"; read -r';

    for (final term in _terminals) {
      if (!await _has(term)) continue;
      try {
        await Process.start(
          term,
          ['-e', 'bash', '-c', wrapped],
          mode: ProcessStartMode.detached,
        );
        return marker;
      } catch (e) {
        debugPrint('[AppInstaller] $term failed: $e');
      }
    }
    return null;
  }

  /// Waits for a completion marker to appear, then returns the captured exit
  /// code (0 = success). Times out after [timeout] and returns null.
  Future<int?> waitForMarker(String markerPath,
      {Duration timeout = const Duration(minutes: 30)}) async {
    final file = File(markerPath);
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      await Future.delayed(const Duration(milliseconds: 800));
      if (await file.exists()) {
        final code = int.tryParse((await file.readAsString()).trim());
        unawaited(file.delete().catchError((_) => file));
        return code;
      }
    }
    return null;
  }

  /// Convenience: install + wait + register as desktop app.
  /// Returns the registered UserApp on success, null otherwise.
  Future<bool> installAndRegister(
    String packageName, {
    void Function(String status)? onStatus,
  }) async {
    onStatus?.call('Opening install terminal for $packageName…');
    final marker = await installInTerminal(packageName);
    if (marker == null) {
      onStatus?.call('No terminal emulator found — install manually with: yay -S $packageName');
      return false;
    }
    onStatus?.call('Waiting for install to finish…');
    final code = await waitForMarker(marker);
    if (code == null) {
      onStatus?.call('Timed out waiting for the install to finish.');
      return false;
    }
    if (code != 0) {
      onStatus?.call('Install exited with code $code.');
      return false;
    }
    onStatus?.call('Install finished — adding desktop icon…');
    return true;
  }

  /// Uninstall + wait + remove the desktop icon. Returns true on success.
  Future<bool> uninstallAndCleanup(
    String packageName, {
    void Function(String status)? onStatus,
  }) async {
    onStatus?.call('Opening uninstall terminal for $packageName…');
    final marker = await uninstallInTerminal(packageName);
    if (marker == null) {
      onStatus?.call('No terminal emulator found — uninstall manually with: sudo pacman -Rns $packageName');
      return false;
    }
    onStatus?.call('Waiting for uninstall to finish…');
    final code = await waitForMarker(marker);
    if (code == null) {
      onStatus?.call('Timed out waiting for the uninstall to finish.');
      return false;
    }
    return code == 0;
  }

  static Future<bool> _has(String cmd) async {
    return await File('/usr/bin/$cmd').exists() ||
        await File('/usr/local/bin/$cmd').exists() ||
        await Process.run('bash', ['-c', 'command -v $cmd'])
                .then((r) => r.exitCode == 0)
                .catchError((_) => false);
  }
}

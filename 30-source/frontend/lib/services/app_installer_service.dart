import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../theme/swarm_colors.dart';
import '../theme/swarm_text_styles.dart';

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

  /// Sudo password collected from the in-app dialog. Kept in memory only —
  /// never written to disk — and re-validated with `sudo -S -v` on every
  /// install, since the sudo timestamp expires (~15 min default).
  static String? _sudoPass;

  // ── Sudo pre-authentication ───────────────────────────────────────────────

  /// Ensures root is pre-authorized before a terminal install opens, so the
  /// user never has to type their password inside the spawned terminal
  /// (which previously stalled the install flow).
  ///
  /// Shows a masked password dialog, validates it with `sudo -S -v`, and
  /// caches it in memory for subsequent installs. Returns false if the user
  /// cancelled or the password was rejected.
  Future<bool> ensureSudoAuthenticated(BuildContext context) async {
    final cached = _sudoPass;
    if (cached != null && await validateSudoPassword(cached)) return true;
    final pass = await _promptSudoPassword(context);
    if (pass == null) return false;
    _sudoPass = pass;
    return true;
  }

  /// Validates a sudo password non-interactively (`sudo -S -v` reads it
  /// from stdin). Exit 0 means the password is correct.
  static Future<bool> validateSudoPassword(String password) async {
    try {
      final proc = await Process.start('sudo', ['-S', '-p', '', '-v']);
      // Drain stderr/stdout so a chatty sudo never blocks on a full pipe.
      unawaited(proc.stdout.drain<void>());
      unawaited(proc.stderr.drain<void>());
      proc.stdin.writeln(password);
      await proc.stdin.close();
      return await proc.exitCode == 0;
    } catch (e) {
      debugPrint('[AppInstaller] sudo validation failed: $e');
      return false;
    }
  }

  /// Masked in-app password prompt with up to 3 attempts. Returns the
  /// validated password, or null on cancel / give-up.
  Future<String?> _promptSudoPassword(
    BuildContext context, {
    String? errorText,
    int attempt = 1,
  }) async {
    if (attempt > 3) return null;
    final ctrl = TextEditingController();
    final pass = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: SwarmColors.bgElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: SwarmColors.border),
        ),
        title: Text('Sudo Password Required',
            style: SwarmTextStyles.h3.copyWith(color: SwarmColors.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              errorText ??
                  'Enter your password to authorize package installs. '
                      'It stays in memory for this session and is never saved to disk.',
              style: SwarmTextStyles.bodySmall
                  .copyWith(color: errorText != null ? SwarmColors.statusCritical : SwarmColors.textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              obscureText: true,
              autofocus: true,
              onSubmitted: (v) => Navigator.pop(ctx, v),
              decoration: InputDecoration(
                hintText: 'Password',
                hintStyle: const TextStyle(color: SwarmColors.textMuted, fontSize: 13),
                prefixIcon: const Icon(Icons.lock_rounded, color: SwarmColors.textMuted, size: 18),
                filled: true,
                fillColor: SwarmColors.bgBase,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: SwarmColors.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child: const Text('Authenticate', style: TextStyle(color: SwarmColors.accent)),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (pass == null || pass.isEmpty) return null;
    if (await validateSudoPassword(pass)) return pass;
    // Wrong password — retry with an error message.
    return _promptSudoPassword(
      context,
      errorText: 'Incorrect password ($attempt/3) — try again:',
      attempt: attempt + 1,
    );
  }

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

    // When a sudo password was pre-authorized in-app, validate it up front in
    // this shell (same tty, so the timestamp carries to the install command's
    // own sudo call) — the terminal then never prompts for a password. If the
    // prefix fails or no password is cached, sudo falls back to prompting
    // inside the terminal as before. The password travels via the process
    // environment (readable only by the same user via /proc), never the
    // command line, and is unset immediately after use.
    final pass = _sudoPass;
    final sudoPrefix = pass != null
        ? r'printf "%s\n" "$SWARM_SUDO_PASS" | sudo -S -v 2>/dev/null && unset SWARM_SUDO_PASS; '
        : '';

    // The marker is written after the command finishes (success or not);
    // the exit code is captured too so the caller can tell them apart.
    final wrapped =
        '$sudoPrefix($command); echo \$? > "$marker" 2>/dev/null; echo "Done — you can close this window"; read -r';

    final env = <String, String>{'TERM': 'xterm-256color', if (pass != null) 'SWARM_SUDO_PASS': pass};

    for (final term in _terminals) {
      if (!await _has(term)) continue;
      try {
        await Process.start(
          term,
          ['-e', 'bash', '-c', wrapped],
          environment: env,
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

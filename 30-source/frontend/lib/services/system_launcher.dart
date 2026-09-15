import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import '../theme/swarm_colors.dart';
import 'launch_status.dart';

/// Direct Native Process Launcher for Swarm OS
///
/// Bypasses any external server and directly spawns processes using Linux
/// Process.start with detached mode so GUI windows (terminal, browser, file manager)
/// appear immediately on the desktop.
class SystemLauncher {
  SystemLauncher._();

  // How long we wait before deciding a launch "took" — a command whose
  // every fallback fails (all `command not found`) exits almost instantly,
  // while a real GUI app is still running at this point.
  static const _verifyWindow = Duration(milliseconds: 900);

  static Future<bool> launch(BuildContext? context, String command,
      {String? displayName, String? agentId}) async {
    if (agentId != null) LaunchStatusRegistry.setLoading(agentId);

    // Detached mode discards the child's stdio, so we can't read its exit
    // status directly. Route it through a status file instead — this is
    // what lets us tell a real launch apart from every fallback silently
    // failing with "command not found" (previously this always reported
    // success the instant bash forked, even when nothing ever opened).
    final statusFile =
        '/tmp/swarm_launch_${DateTime.now().microsecondsSinceEpoch}_${command.hashCode}.status';
    try {
      await Process.start(
        'bash',
        ['-c', '($command) ; echo \$? > "$statusFile" 2>/dev/null'],
        mode: ProcessStartMode.detached,
      );

      await Future.delayed(_verifyWindow);

      int? exitCode;
      final file = File(statusFile);
      if (await file.exists()) {
        exitCode = int.tryParse((await file.readAsString()).trim());
        unawaited(file.delete().catchError((_) => file));
      }
      final failed = exitCode != null && exitCode != 0;

      if (agentId != null) {
        if (failed) {
          LaunchStatusRegistry.setClosed(agentId);
        } else {
          LaunchStatusRegistry.setRunning(agentId);
        }
      }

      if (context != null && context.mounted) {
        if (failed) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: SwarmColors.statusCritical,
              content: Text(
                '⚠️ ${displayName ?? command} failed to start — no compatible app found on this system',
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
              duration: const Duration(seconds: 4),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: SwarmColors.bgElevated,
              content: Row(
                children: [
                  const Icon(Icons.rocket_launch, color: SwarmColors.accent, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    displayName != null ? '🚀 Launched $displayName' : '🚀 Launched $command',
                    style: const TextStyle(color: SwarmColors.textPrimary, fontSize: 12),
                  ),
                ],
              ),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
      return !failed;
    } catch (e) {
      if (agentId != null) LaunchStatusRegistry.setClosed(agentId);
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: SwarmColors.statusCritical,
            content: Text(
              '⚠️ Failed to launch: $e',
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      }
      return false;
    }
  }

  // Sandboxing prefix for GUI apps that render untrusted internet content
  // (Task #2/#3, SWARM OS journey: firejail sandbox isolation). Resolved once
  // per launch, at shell time, so a machine without the `firejail` package
  // still launches these apps normally instead of failing closed — every
  // alternative below would otherwise fail if $FJ were hardcoded to a binary
  // that doesn't exist. firejail auto-selects its bundled per-app profile
  // (e.g. /etc/firejail/firefox.profile) when the wrapped binary name matches
  // one, and falls back to its generic default profile otherwise.
  static const String _fj = r'$(command -v firejail >/dev/null 2>&1 && echo firejail)';

  // Pre-configured fallback commands for core OS apps
  static const String terminalCmd = 'alacritty || foot || xterm || konsole || tilix || xfce4-terminal';
  static const String browserCmd = '$_fj firefox || $_fj chromium || $_fj google-chrome-stable || $_fj epiphany';
  static const String fileManagerCmd = 'thunar || pcmanfm || dolphin || nautilus';
  static const String monitorCmd = 'foot -e btop || alacritty -e btop || xterm -e htop || alacritty -e htop || foot -e htop || btop || htop';
  static const String installerCmd = 'if [ -x /usr/local/bin/install_swarm_os.sh ]; then alacritty -e sudo /usr/local/bin/install_swarm_os.sh --disk /dev/nvme0n1 || foot -e sudo /usr/local/bin/install_swarm_os.sh --disk /dev/nvme0n1 || xterm -e sudo /usr/local/bin/install_swarm_os.sh --disk /dev/nvme0n1; else alacritty -e bash -lc "echo SWARM OS installer is only available from the live ISO; read -r" || xterm -e bash -lc "echo SWARM OS installer is only available from the live ISO; read -r"; fi';
  static const String antigravityIdeCmd = 'antigravity || "/run/media/i30ltz/lucy-master/Antigravity-x64/antigravity" || code';
  // chromium is the installed browser on SWARM OS (not google-chrome-stable) —
  // always try chromium before google-chrome-stable to avoid a silent fallback gap.
  static const String claudeDesktopCmd = 'claude-desktop || $_fj chromium --app=https://claude.ai || $_fj google-chrome-stable --app=https://claude.ai || $_fj firefox --new-window https://claude.ai';
  // The `claude` CLI isn't a pacman/AUR package — it's installed per-user via
  // `npm install -g @anthropic-ai/claude-code`. Check for it on PATH first so
  // a missing install surfaces a real, actionable message in a terminal
  // instead of every terminal-emulator fallback failing silently.
  // Opens a terminal that: runs claude if installed, otherwise auto-installs
  // via npm (which is on PATH after the 2026-09-15 pacman install) then runs it.
  static const String claudeCodeCmd =
      r'alacritty -e bash -lc "command -v claude >/dev/null 2>&1 && exec claude; echo Installing Claude Code CLI...; npm install -g @anthropic-ai/claude-code && exec claude; echo; echo Install failed - run: npm install -g @anthropic-ai/claude-code; read -r"'
      r' || foot -e bash -lc "command -v claude >/dev/null 2>&1 && exec claude; echo Installing Claude Code CLI...; npm install -g @anthropic-ai/claude-code && exec claude; echo; echo Install failed - run: npm install -g @anthropic-ai/claude-code; read -r"'
      r' || xterm -e bash -lc "command -v claude >/dev/null 2>&1 && exec claude; echo Installing Claude Code CLI...; npm install -g @anthropic-ai/claude-code && exec claude; echo; echo Install failed - run: npm install -g @anthropic-ai/claude-code; read -r"';

  static Future<bool> launchAntigravity(BuildContext? context) {
    return launch(context, antigravityIdeCmd, displayName: 'Antigravity IDE');
  }

  static Future<bool> launchClaudeDesktop(BuildContext? context) {
    return launch(context, claudeDesktopCmd, displayName: 'Claude Desktop');
  }

  static Future<bool> launchClaudeCode(BuildContext? context) {
    return launch(context, claudeCodeCmd, displayName: 'Claude Code');
  }
}

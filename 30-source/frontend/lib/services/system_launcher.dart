import 'dart:io';
import 'package:flutter/material.dart';
import '../theme/swarm_colors.dart';

/// Direct Native Process Launcher for Swarm OS
///
/// Bypasses any external server and directly spawns processes using Linux
/// Process.start with detached mode so GUI windows (terminal, browser, file manager)
/// appear immediately on the desktop.
class SystemLauncher {
  SystemLauncher._();

  static Future<bool> launch(BuildContext? context, String command, {String? displayName}) async {
    try {
      // Launch detached in background
      await Process.start('bash', ['-c', command], mode: ProcessStartMode.detached);

      if (context != null && context.mounted) {
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
      return true;
    } catch (e) {
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
  static const String monitorCmd = 'alacritty -e btop || xterm -e htop || alacritty -e htop || btop || htop';
  static const String installerCmd = 'if [ -x /usr/local/bin/install_swarm_os.sh ]; then alacritty -e sudo /usr/local/bin/install_swarm_os.sh --disk /dev/nvme0n1 || foot -e sudo /usr/local/bin/install_swarm_os.sh --disk /dev/nvme0n1 || xterm -e sudo /usr/local/bin/install_swarm_os.sh --disk /dev/nvme0n1; else alacritty -e bash -lc "echo SWARM OS installer is only available from the live ISO; read -r" || xterm -e bash -lc "echo SWARM OS installer is only available from the live ISO; read -r"; fi';
  static const String antigravityIdeCmd = 'antigravity || "/run/media/i30ltz/lucy-master/Antigravity-x64/antigravity" || code';
  static const String claudeDesktopCmd = 'claude-desktop || $_fj google-chrome-stable --app=https://claude.ai || $_fj chromium --app=https://claude.ai || $_fj firefox --new-window https://claude.ai';
  static const String claudeCodeCmd = 'alacritty -e claude || foot -e claude || kitty -e claude || xterm -e claude';

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

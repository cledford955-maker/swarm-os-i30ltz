import 'dart:io';
import 'package:flutter/foundation.dart';

class ScreenshotResult {
  final bool success;
  final String? filePath;
  final String? message;

  ScreenshotResult({required this.success, this.filePath, this.message});
}

enum ScreenshotMode { fullscreen, region, window }

class ScreenshotService {
  static final ScreenshotService _instance = ScreenshotService._internal();
  factory ScreenshotService() => _instance;
  ScreenshotService._internal();

  static const String _primaryDir = '/run/media/i30ltz/lucy-master/screenshots';

  /// Ensures screenshot directory exists and returns valid path
  Future<String> _getScreenshotDir() async {
    try {
      final primary = Directory(_primaryDir);
      if (!await primary.exists()) {
        await primary.create(recursive: true);
      }
      return primary.path;
    } catch (_) {
      final home = Platform.environment['HOME'] ?? '/home/i30ltz';
      final fallback = Directory('$home/Pictures/Screenshots');
      if (!await fallback.exists()) {
        await fallback.create(recursive: true);
      }
      return fallback.path;
    }
  }

  String _generateFilename() {
    final now = DateTime.now();
    final y = now.year.toString();
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    final h = now.hour.toString().padLeft(2, '0');
    final min = now.minute.toString().padLeft(2, '0');
    final s = now.second.toString().padLeft(2, '0');
    return 'swarm_capture_$y$m${d}_$h$min$s.png';
  }

  /// Capture full desktop screen
  Future<ScreenshotResult> captureFullScreen({bool copyToClipboard = true}) async {
    return _executeCapture(ScreenshotMode.fullscreen, copyToClipboard: copyToClipboard);
  }

  /// Capture interactive rectangular region
  Future<ScreenshotResult> captureRegion({bool copyToClipboard = true}) async {
    return _executeCapture(ScreenshotMode.region, copyToClipboard: copyToClipboard);
  }

  /// Capture active window
  Future<ScreenshotResult> captureActiveWindow({bool copyToClipboard = true}) async {
    return _executeCapture(ScreenshotMode.window, copyToClipboard: copyToClipboard);
  }

  Future<ScreenshotResult> _executeCapture(ScreenshotMode mode, {bool copyToClipboard = true}) async {
    final dir = await _getScreenshotDir();
    final filename = _generateFilename();
    final targetPath = '$dir/$filename';

    final args = <String>[
      '-b', // Background headless
      '-n', // No spectacle internal popup (we handle notifications)
    ];

    switch (mode) {
      case ScreenshotMode.fullscreen:
        args.add('-f');
        break;
      case ScreenshotMode.region:
        args.add('-r');
        break;
      case ScreenshotMode.window:
        args.add('-a');
        break;
    }

    if (copyToClipboard) {
      args.add('-c'); // Copy image to clipboard
    }

    args.addAll(['-o', targetPath]);

    try {
      final proc = await Process.run('spectacle', args);
      if (proc.exitCode == 0 && await File(targetPath).exists()) {
        await _notifySuccess(targetPath, mode);
        return ScreenshotResult(
          success: true,
          filePath: targetPath,
          message: 'Screenshot saved to $filename & copied to clipboard',
        );
      } else {
        // Fallback for Wayland: grim
        return await _grimFallback(targetPath, mode);
      }
    } catch (e) {
      if (kDebugMode) print('Spectacle capture error: $e, trying grim...');
      return await _grimFallback(targetPath, mode);
    }
  }

  Future<ScreenshotResult> _grimFallback(String targetPath, ScreenshotMode mode) async {
    try {
      final proc = await Process.run('grim', [targetPath]);
      if (proc.exitCode == 0 && await File(targetPath).exists()) {
        await _notifySuccess(targetPath, mode);
        return ScreenshotResult(
          success: true,
          filePath: targetPath,
          message: 'Screenshot saved via grim',
        );
      }
    } catch (_) {}
    return ScreenshotResult(success: false, message: 'Screenshot command failed');
  }

  Future<void> _notifySuccess(String filePath, ScreenshotMode mode) async {
    final label = switch (mode) {
      ScreenshotMode.fullscreen => 'Fullscreen Capture',
      ScreenshotMode.region => 'Region Capture',
      ScreenshotMode.window => 'Window Capture',
    };

    try {
      await Process.run('notify-send', [
        '📸 SWARM OS $label',
        'Saved to ${filePath.split('/').last}\n(Copied to clipboard)',
        '-i',
        filePath,
        '-u',
        'normal',
      ]);
    } catch (_) {}
  }

  /// Open directory in system file manager (Dolphin)
  Future<void> openScreenshotsFolder() async {
    final dir = await _getScreenshotDir();
    try {
      await Process.run('xdg-open', [dir]);
    } catch (_) {}
  }
}

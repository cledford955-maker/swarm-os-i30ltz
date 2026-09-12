import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'swarm_config.dart';

/// HTTP client for the sentinel.js Express backend (port 8000).
/// Handles REST calls for commands, file system operations, and swarm management.
class SentinelClient {
  final String baseUrl;
  final http.Client _client;

  SentinelClient({String? baseUrl})
      : baseUrl = baseUrl ?? SwarmConfig.httpBase,
        _client = http.Client();

  // ─── Command Dispatch ─────────────────────────────────────────────────

  /// Sends a command to be executed on the host via unified backend.
  Future<void> sendCommand(String command) async {
    await http.post(
      Uri.parse('$baseUrl/api/terminal/run'),
      headers: SwarmConfig.authHeaders,
      body: jsonEncode({'command': command}),
    );
  }

  /// Sends text to the host clipboard (wl-copy).
  Future<void> copyToClipboard(String text) async {
    await _post('/message', {'command': text, 'type': 'copy'});
  }

  /// Types text on the host (ydotool).
  Future<void> typeOnHost(String text) async {
    await _post('/message', {'command': text, 'type': 'type'});
  }

  // ─── File System ──────────────────────────────────────────────────────

  /// Lists files in a directory.
  Future<List<FileEntry>> listDirectory(String dirPath) async {
    final dir = Directory(dirPath);
    if (!await dir.exists()) return [];
    
    final entries = <FileEntry>[];
    await for (final entity in dir.list()) {
      try {
        final stat = await entity.stat();
        final name = entity.uri.pathSegments.where((s) => s.isNotEmpty).last;
        entries.add(FileEntry(
          name: name,
          path: entity.path,
          isDirectory: entity is Directory,
          size: stat.size,
          mtime: stat.modified,
          birthtime: stat.changed,
        ));
      } catch (_) {}
    }
    entries.sort((a, b) {
      if (a.isDirectory && !b.isDirectory) return -1;
      if (!a.isDirectory && b.isDirectory) return 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return entries;
  }

  /// Reads a file's contents.
  Future<String> readFile(String filePath) async {
    return await File(filePath).readAsString();
  }

  /// Writes content to a file.
  Future<void> writeFile(String filePath, String content) async {
    await File(filePath).writeAsString(content);
  }

  // ─── Swarm Management ─────────────────────────────────────────────────

  /// Registers this device as a swarm node.
  Future<int> registerNode({
    required String nodeId,
    required String deviceName,
    required Map<String, dynamic> capabilities,
  }) async {
    final resp = await _post('/swarm/register', {
      'nodeId': nodeId,
      'deviceName': deviceName,
      'capabilities': capabilities,
    });
    return resp['activeNodes'] as int;
  }

  /// Sends a heartbeat for this node.
  Future<void> heartbeat({
    required String nodeId,
    required double cpu,
    required double ram,
    required List<Map<String, dynamic>> processes,
  }) async {
    await _post('/swarm/heartbeat', {
      'nodeId': nodeId,
      'cpu': cpu,
      'ram': ram,
      'processes': processes,
    });
  }

  /// Gets all active swarm nodes.
  Future<List<SwarmNode>> getNodes() async {
    final resp = await _get('/swarm/nodes', {});
    final nodes = (resp['nodes'] as List<dynamic>?) ?? [];
    return nodes
        .map((n) => SwarmNode(
              id: n['id'] as String,
              deviceName: n['deviceName'] as String,
              cpu: (n['cpu'] as num).toDouble(),
              ram: (n['ram'] as num).toDouble(),
              lastSeen: n['lastSeen'] as int,
            ))
        .toList();
  }

  /// Dispatches a task to all swarm nodes.
  Future<int> dispatchTask(Map<String, dynamic> payload) async {
    final resp = await _post('/swarm/dispatch', {'taskPayload': payload});
    return resp['dispatchedTo'] as int;
  }

  /// Gets block device info.
  Future<Map<String, dynamic>> getBlockDevices() async {
    return _get('/api/sys/lsblk', {});
  }

  // ─── Internal HTTP helpers ────────────────────────────────────────────

  Future<Map<String, dynamic>> _get(
      String path, Map<String, String> query) async {
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: query);
    final resp = await _client.get(uri, headers: SwarmConfig.authHeaders);
    if (resp.statusCode != 200) {
      throw SentinelException('GET $path failed: ${resp.statusCode}');
    }
    return jsonDecode(resp.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> _post(
      String path, Map<String, dynamic> body) async {
    final resp = await _client.post(
      Uri.parse('$baseUrl$path'),
      headers: SwarmConfig.authHeaders,
      body: jsonEncode(body),
    );
    if (resp.statusCode != 200) {
      throw SentinelException('POST $path failed: ${resp.statusCode}');
    }
    return jsonDecode(resp.body) as Map<String, dynamic>;
  }

  void dispose() => _client.close();
}

// ─── Data Models ──────────────────────────────────────────────────────────────

class FileEntry {
  final String name;
  final String path;
  final bool isDirectory;
  final int size;
  final DateTime? mtime;
  final DateTime? birthtime;

  const FileEntry({
    required this.name,
    required this.path,
    required this.isDirectory,
    this.size = 0,
    this.mtime,
    this.birthtime,
  });
}

class SwarmNode {
  final String id;
  final String deviceName;
  final double cpu;
  final double ram;
  final int lastSeen;
  const SwarmNode({
    required this.id,
    required this.deviceName,
    required this.cpu,
    required this.ram,
    required this.lastSeen,
  });
}

class SentinelException implements Exception {
  final String message;
  const SentinelException(this.message);
  @override
  String toString() => 'SentinelException: $message';
}

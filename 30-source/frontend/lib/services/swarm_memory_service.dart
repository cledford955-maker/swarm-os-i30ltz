import 'dart:convert';
import 'dart:io' hide Platform;
import '../platform/platform.dart';

import 'package:http/http.dart' as http;

import 'swarm_config.dart';

// ═══════════════════════════════════════════════════════════════════════════
// Shared Memory (swarm-memory) — live client for LucyServer's /api/memory/*
// endpoints. This is THE cross-device memory mesh: entries written here are
// gossiped between all OSes and companions via peer.go, consumed by Lucille's
// chat context, and synced to/from Claude Code's ~/.claude memory files.
// ChatGPT memory arrives as one-way import snapshots (export-only API).
// ═══════════════════════════════════════════════════════════════════════════

/// One entry from the shared memory log (JSONL store at /mnt/brains/swarm-memory).
class SwarmMemoryEntry {
  final String id;
  final String device;
  final String ts;
  final String kind; // doc, decision, claude_memory, chatgpt_memory, note…
  final String key;
  final String content;

  const SwarmMemoryEntry({
    required this.id,
    required this.device,
    required this.ts,
    required this.kind,
    required this.key,
    required this.content,
  });

  factory SwarmMemoryEntry.fromJson(Map<String, dynamic> json) {
    return SwarmMemoryEntry(
      id: json['id'] ?? '',
      device: json['device'] ?? '',
      ts: json['ts'] ?? '',
      kind: json['kind'] ?? 'note',
      key: json['key'] ?? '',
      content: json['content'] ?? '',
    );
  }
}

/// Lease holder info — only one device may push live edits at a time.
class SwarmMemoryLease {
  final String holder;
  final String expires;

  const SwarmMemoryLease({required this.holder, required this.expires});

  factory SwarmMemoryLease.fromJson(Map<String, dynamic> json) =>
      SwarmMemoryLease(
        holder: json['holder'] ?? '',
        expires: json['expires']?.toString() ?? '',
      );

  bool get isFree => holder.isEmpty;
}

/// HTTP client for the shared swarm-memory mesh served by LucyServer.
class SwarmMemoryService {
  SwarmMemoryService._();
  static final SwarmMemoryService instance = SwarmMemoryService._();

  /// Device id this client identifies as (shown to the mesh as the source).
  static String deviceId = Platform.localHostname;

  final http.Client _client = http.Client();

  Uri _u(String path, [Map<String, String>? q]) =>
      Uri.parse('${SwarmConfig.httpBase}/api/memory$path')
          .replace(queryParameters: q);

  /// Overall mesh status: entry count, lease, peer devices.
  Future<Map<String, dynamic>?> status() async {
    try {
      final r = await _client
          .get(_u('/status'))
          .timeout(const Duration(seconds: 4));
      if (r.statusCode == 200) {
        return jsonDecode(r.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  /// Latest entries, newest first. [limit] caps the response size.
  Future<List<SwarmMemoryEntry>> entries({int limit = 50, String? kind}) async {
    try {
      final q = {'limit': '$limit', if (kind != null) 'kind': kind};
      final r = await _client
          .get(_u('/entries', q))
          .timeout(const Duration(seconds: 6));
      if (r.statusCode != 200) return [];
      final data = jsonDecode(r.body) as Map<String, dynamic>;
      final list = (data['entries'] as List? ?? [])
          .map((e) => SwarmMemoryEntry.fromJson(e as Map<String, dynamic>))
          .toList();
      return list.reversed.toList(); // store returns oldest-first
    } catch (_) {
      return [];
    }
  }

  /// "current" view — latest entry per kind (what render.go presents as the
  /// live project memory).
  Future<List<SwarmMemoryEntry>> current() async {
    try {
      final r =
          await _client.get(_u('/current')).timeout(const Duration(seconds: 6));
      if (r.statusCode != 200) return [];
      final data = jsonDecode(r.body) as Map<String, dynamic>;
      return (data['entries'] as List? ?? [])
          .map((e) => SwarmMemoryEntry.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Write a live entry. Returns null (never throws) if another device holds
  /// the write lease (409) or the server is unreachable.
  Future<SwarmMemoryEntry?> write({
    required String kind,
    required String key,
    required String content,
  }) async {
    try {
      final r = await _client
          .post(
            _u('/entries'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'device': deviceId,
              'kind': kind,
              'key': key,
              'content': content,
            }),
          )
          .timeout(const Duration(seconds: 8));
      if (r.statusCode != 200) return null;
      final data = jsonDecode(r.body) as Map<String, dynamic>;
      final entry = data['entry'];
      if (entry is Map<String, dynamic>) return SwarmMemoryEntry.fromJson(entry);
      return SwarmMemoryEntry(
        id: '',
        device: deviceId,
        ts: DateTime.now().toUtc().toIso8601String(),
        kind: kind,
        key: key,
        content: content,
      );
    } catch (_) {
      return null;
    }
  }

  /// Current write-lease holder ({} means free).
  Future<SwarmMemoryLease> lease() async {
    try {
      final r =
          await _client.get(_u('/lease')).timeout(const Duration(seconds: 4));
      if (r.statusCode == 200) {
        return SwarmMemoryLease.fromJson(
            jsonDecode(r.body) as Map<String, dynamic>);
      }
    } catch (_) {}
    return const SwarmMemoryLease(holder: '', expires: '');
  }

  /// Acquire the write lease before a burst of edits. Pass [force] to
  /// explicitly take over an expired/stale lease.
  Future<bool> acquireLease({bool force = false}) async {
    try {
      final r = await _client
          .post(
            _u('/lease/acquire'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'device': deviceId, 'force': force}),
          )
          .timeout(const Duration(seconds: 4));
      return r.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}

// Swarm OS — Agent Memory Service
// Connects Flutter frontend to the agent_memory backend with Google Keep integration.
// Falls back to local JSON if API is down.

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class MemoryNote {
  final String id;
  String title;
  String content;
  List<String> tags;
  List<String> labels;
  String category;
  bool pinned;
  bool archived;
  String color;
  String source; // "google_keep" or "local"
  final String createdAt;
  String updatedAt;

  MemoryNote({
    required this.id,
    required this.title,
    required this.content,
    this.tags = const [],
    this.labels = const [],
    this.category = 'general',
    this.pinned = false,
    this.archived = false,
    this.color = 'white',
    this.source = 'local',
    required this.createdAt,
    required this.updatedAt,
  });

  factory MemoryNote.fromJson(Map<String, dynamic> json) {
    return MemoryNote(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      content: json['content'] ?? '',
      tags: List<String>.from(json['tags'] ?? []),
      labels: List<String>.from(json['labels'] ?? json['tags'] ?? []),
      category: json['category'] ?? 'general',
      pinned: json['pinned'] ?? false,
      archived: json['archived'] ?? false,
      color: json['color'] ?? 'white',
      source: json['source'] ?? 'local',
      createdAt: json['created_at'] ?? '',
      updatedAt: json['updated_at'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'content': content,
        'tags': tags,
        'labels': labels,
        'category': category,
        'pinned': pinned,
        'archived': archived,
        'color': color,
        'source': source,
        'created_at': createdAt,
        'updated_at': updatedAt,
      };

  bool get isFromKeep => source == 'google_keep';
}

class MemoryStats {
  final String backend;
  final bool keepConnected;
  final int totalNotes;
  final int active;
  final int archived;
  final int pinned;
  final String? email;

  MemoryStats({
    required this.backend,
    required this.keepConnected,
    required this.totalNotes,
    required this.active,
    required this.archived,
    required this.pinned,
    this.email,
  });

  factory MemoryStats.fromJson(Map<String, dynamic> json) {
    return MemoryStats(
      backend: json['backend'] ?? 'local',
      keepConnected: json['keep_connected'] ?? json['connected'] ?? false,
      totalNotes: json['total_notes'] ?? json['total'] ?? 0,
      active: json['active'] ?? 0,
      archived: json['archived'] ?? 0,
      pinned: json['pinned'] ?? 0,
      email: json['email'],
    );
  }
}

/// Service for agent memory / notes with Google Keep integration.
class MemoryService {
  static const String _defaultHost = 'http://127.0.0.1:8399';
  final String apiHost;
  final http.Client _client;

  // Local fallback storage path
  static String get _localPath {
    final home = Platform.environment['HOME'] ?? '/tmp';
    return '$home/.swarm-os/agent_notes.json';
  }

  MemoryService({String? host, http.Client? client})
      : apiHost = host ?? _defaultHost,
        _client = client ?? http.Client();

  // ─── Google Keep Connection ───

  Future<bool> connectKeep(String email, String masterToken) async {
    try {
      final resp = await _client.post(
        Uri.parse('$apiHost/keep/connect'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'master_token': masterToken,
        }),
      );
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> isKeepConnected() async {
    try {
      final resp = await _client.get(Uri.parse('$apiHost/keep/status'));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        return data['connected'] == true;
      }
    } catch (_) {}
    return false;
  }

  // ─── Notes CRUD ───

  Future<MemoryNote> writeNote({
    required String content,
    String? title,
    List<String> tags = const [],
    bool pinned = false,
    String category = 'general',
    String? color,
  }) async {
    try {
      final body = <String, dynamic>{
        'content': content,
        'title': title,
        'tags': tags,
        'pinned': pinned,
        'category': category,
      };
      if (color != null) body['color'] = color;

      final resp = await _client.post(
        Uri.parse('$apiHost/notes'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        return MemoryNote.fromJson(data['note']);
      }
    } catch (_) {}
    return _localWrite(content, title, tags, pinned, category);
  }

  Future<List<MemoryNote>> readNotes({
    String? search,
    String? tag,
    String? category,
    bool pinnedOnly = false,
    bool includeArchived = false,
    int limit = 50,
  }) async {
    try {
      final params = <String, String>{};
      if (search != null) params['search'] = search;
      if (tag != null) params['tag'] = tag;
      if (category != null) params['category'] = category;
      if (pinnedOnly) params['pinned_only'] = 'true';
      if (includeArchived) params['include_archived'] = 'true';
      params['limit'] = limit.toString();

      final uri = Uri.parse('$apiHost/notes').replace(queryParameters: params);
      final resp = await _client.get(uri);
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        return (data['notes'] as List)
            .map((n) => MemoryNote.fromJson(n))
            .toList();
      }
    } catch (_) {}
    return _localRead(search: search);
  }

  Future<bool> updateNote(
    String noteId, {
    String? content,
    String? title,
    List<String>? tags,
    bool? pinned,
    String? color,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (content != null) body['content'] = content;
      if (title != null) body['title'] = title;
      if (tags != null) body['tags'] = tags;
      if (pinned != null) body['pinned'] = pinned;
      if (color != null) body['color'] = color;

      final resp = await _client.put(
        Uri.parse('$apiHost/notes/$noteId'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );
      return resp.statusCode == 200;
    } catch (_) {
      return _localUpdate(noteId, content: content, title: title, pinned: pinned);
    }
  }

  Future<bool> eraseNote(String noteId, {bool hard = false}) async {
    try {
      final resp = await _client.delete(
        Uri.parse('$apiHost/notes/$noteId?hard=$hard'),
      );
      return resp.statusCode == 200;
    } catch (_) {
      return _localErase(noteId);
    }
  }

  Future<int> eraseAllNotes({bool hard = false}) async {
    try {
      final resp = await _client.delete(
        Uri.parse('$apiHost/notes'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'hard_delete': hard}),
      );
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        return data['erased_count'] ?? 0;
      }
    } catch (_) {}
    return _localEraseAll();
  }

  Future<MemoryNote?> createChecklist({
    required String title,
    required List<Map<String, dynamic>> items,
    bool pinned = false,
  }) async {
    try {
      final resp = await _client.post(
        Uri.parse('$apiHost/checklist'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'title': title,
          'items': items,
          'pinned': pinned,
        }),
      );
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        return MemoryNote.fromJson(data['note']);
      }
    } catch (_) {}
    return null;
  }

  Future<List<String>> getLabels() async {
    try {
      final resp = await _client.get(Uri.parse('$apiHost/labels'));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        return List<String>.from(data['labels'] ?? []);
      }
    } catch (_) {}
    return [];
  }

  Future<MemoryStats?> getStats() async {
    try {
      final resp = await _client.get(Uri.parse('$apiHost/stats'));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        return MemoryStats.fromJson(data['stats']);
      }
    } catch (_) {}
    return null;
  }

  // ─── Local Fallback Storage ───

  Map<String, dynamic> _loadLocal() {
    final file = File(_localPath);
    if (file.existsSync()) {
      try {
        return jsonDecode(file.readAsStringSync());
      } catch (_) {}
    }
    return {'notes': []};
  }

  void _saveLocal(Map<String, dynamic> data) {
    final file = File(_localPath);
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(jsonEncode(data));
  }

  MemoryNote _localWrite(String content, String? title, List<String> tags,
      bool pinned, String category) {
    final data = _loadLocal();
    final notes = data['notes'] as List;
    final now = DateTime.now().toUtc().toIso8601String();
    final id = content.hashCode.toRadixString(16).padLeft(12, '0').substring(0, 12);

    final note = {
      'id': id,
      'title': title ?? (content.length > 60 ? content.substring(0, 60) : content),
      'content': content,
      'tags': tags,
      'labels': tags,
      'category': category,
      'pinned': pinned,
      'archived': false,
      'color': 'white',
      'source': 'local',
      'created_at': now,
      'updated_at': now,
    };
    notes.add(note);
    _saveLocal(data);
    return MemoryNote.fromJson(note);
  }

  List<MemoryNote> _localRead({String? search}) {
    final data = _loadLocal();
    List notes = data['notes'] as List;
    notes = notes.where((n) => n['archived'] != true).toList();
    if (search != null && search.isNotEmpty) {
      final q = search.toLowerCase();
      notes = notes.where((n) {
        return (n['content'] ?? '').toString().toLowerCase().contains(q) ||
            (n['title'] ?? '').toString().toLowerCase().contains(q);
      }).toList();
    }
    notes.sort((a, b) {
      if (a['pinned'] == true && b['pinned'] != true) return -1;
      if (b['pinned'] == true && a['pinned'] != true) return 1;
      return (b['updated_at'] ?? '').compareTo(a['updated_at'] ?? '');
    });
    return notes.map((n) => MemoryNote.fromJson(Map<String, dynamic>.from(n))).toList();
  }

  bool _localUpdate(String noteId, {String? content, String? title, bool? pinned}) {
    final data = _loadLocal();
    final notes = data['notes'] as List;
    for (var n in notes) {
      if (n['id'] == noteId) {
        if (content != null) n['content'] = content;
        if (title != null) n['title'] = title;
        if (pinned != null) n['pinned'] = pinned;
        n['updated_at'] = DateTime.now().toUtc().toIso8601String();
        _saveLocal(data);
        return true;
      }
    }
    return false;
  }

  bool _localErase(String noteId) {
    final data = _loadLocal();
    final notes = data['notes'] as List;
    final before = notes.length;
    data['notes'] = notes.where((n) => n['id'] != noteId).toList();
    _saveLocal(data);
    return (data['notes'] as List).length < before;
  }

  int _localEraseAll() {
    final data = _loadLocal();
    final count = (data['notes'] as List).length;
    data['notes'] = [];
    _saveLocal(data);
    return count;
  }
}
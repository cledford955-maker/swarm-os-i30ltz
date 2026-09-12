// Swarm OS — Unified Google Hub Service
// Single Dart client for all Google agents: Auth, Gmail, Calendar, Drive, Tasks, Contacts, Keep

import 'dart:convert';
import 'package:http/http.dart' as http;

class GoogleHubService {
  static const String _defaultHost = 'http://127.0.0.1:8399';
  final String apiHost;
  final http.Client _client;

  GoogleHubService({String? host, http.Client? client})
      : apiHost = host ?? _defaultHost,
        _client = client ?? http.Client();

  // ══════════ AUTH ══════════

  Future<Map<String, dynamic>> login({bool headless = false}) async {
    final resp = await _post('/auth/login', {'headless': headless});
    return resp;
  }

  Future<void> logout() async {
    await _post('/auth/logout', {});
  }

  Future<Map<String, dynamic>> authStatus() async {
    return await _get('/auth/status');
  }

  Future<bool> get isAuthenticated async {
    try {
      final status = await authStatus();
      return status['authenticated'] == true;
    } catch (_) {
      return false;
    }
  }

  // ══════════ GMAIL ══════════

  Future<List<Map<String, dynamic>>> getInbox({
    int maxResults = 20,
    String? query,
    String label = 'INBOX',
    bool unreadOnly = false,
  }) async {
    final params = <String, String>{
      'max_results': maxResults.toString(),
      'label': label,
    };
    if (query != null) params['query'] = query;
    if (unreadOnly) params['unread_only'] = 'true';

    final data = await _get('/gmail/inbox', params: params);
    return List<Map<String, dynamic>>.from(data['messages'] ?? []);
  }

  Future<Map<String, dynamic>?> getMessage(String messageId) async {
    try {
      final data = await _get('/gmail/message/$messageId');
      return data['message'];
    } catch (_) {
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> searchGmail(String query, {int maxResults = 20}) async {
    final data = await _get('/gmail/search', params: {'q': query, 'max_results': maxResults.toString()});
    return List<Map<String, dynamic>>.from(data['messages'] ?? []);
  }

  Future<int> getUnreadCount() async {
    try {
      final data = await _get('/gmail/unread');
      return data['count'] ?? 0;
    } catch (_) {
      return 0;
    }
  }

  Future<Map<String, dynamic>?> sendEmail({
    required String to,
    required String subject,
    required String body,
    String? cc,
    String? bcc,
    bool html = false,
  }) async {
    final payload = <String, dynamic>{
      'to': to,
      'subject': subject,
      'body': body,
      'html': html,
    };
    if (cc != null) payload['cc'] = cc;
    if (bcc != null) payload['bcc'] = bcc;

    final data = await _post('/gmail/send', payload);
    return data['result'];
  }

  Future<Map<String, dynamic>?> replyEmail(
    String messageId, {
    required String body,
    bool html = false,
    bool replyAll = false,
  }) async {
    final data = await _post('/gmail/reply/$messageId', {
      'body': body,
      'html': html,
      'reply_all': replyAll,
    });
    return data['result'];
  }

  Future<Map<String, dynamic>?> forwardEmail(
    String messageId, {
    required String to,
    String additionalBody = '',
  }) async {
    final data = await _post('/gmail/forward/$messageId', {
      'to': to,
      'additional_body': additionalBody,
    });
    return data['result'];
  }

  Future<bool> markRead(String messageId) async {
    final data = await _post('/gmail/$messageId/read', {});
    return data['ok'] == true;
  }

  Future<bool> markUnread(String messageId) async {
    final data = await _post('/gmail/$messageId/unread', {});
    return data['ok'] == true;
  }

  Future<bool> starMessage(String messageId) async {
    final data = await _post('/gmail/$messageId/star', {});
    return data['ok'] == true;
  }

  Future<bool> trashMessage(String messageId) async {
    final data = await _post('/gmail/$messageId/trash', {});
    return data['ok'] == true;
  }

  Future<bool> archiveMessage(String messageId) async {
    final data = await _post('/gmail/$messageId/archive', {});
    return data['ok'] == true;
  }

  Future<Map<String, dynamic>?> getThread(String threadId) async {
    try {
      final data = await _get('/gmail/thread/$threadId');
      return data['thread'];
    } catch (_) {
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getGmailLabels() async {
    final data = await _get('/gmail/labels');
    return List<Map<String, dynamic>>.from(data['labels'] ?? []);
  }

  Future<Map<String, dynamic>> getGmailStats() async {
    return (await _get('/gmail/stats'))['stats'] ?? {};
  }

  // ══════════ CALENDAR ══════════

  Future<List<Map<String, dynamic>>> getCalendars() async {
    final data = await _get('/calendar/calendars');
    return List<Map<String, dynamic>>.from(data['calendars'] ?? []);
  }

  Future<List<Map<String, dynamic>>> getUpcomingEvents({
    int maxResults = 10,
    int daysAhead = 7,
  }) async {
    final data = await _get('/calendar/events', params: {
      'max_results': maxResults.toString(),
      'days_ahead': daysAhead.toString(),
    });
    return List<Map<String, dynamic>>.from(data['events'] ?? []);
  }

  Future<List<Map<String, dynamic>>> getEventsForDate(String date) async {
    final data = await _get('/calendar/events/date/$date');
    return List<Map<String, dynamic>>.from(data['events'] ?? []);
  }

  Future<Map<String, dynamic>?> createEvent({
    required String summary,
    required String start,
    required String end,
    String description = '',
    String location = '',
    List<String>? attendees,
    bool allDay = false,
  }) async {
    final data = await _post('/calendar/events', {
      'summary': summary,
      'start': start,
      'end': end,
      'description': description,
      'location': location,
      'attendees': attendees,
      'all_day': allDay,
    });
    return data['event'];
  }

  Future<Map<String, dynamic>?> quickAddEvent(String text) async {
    final data = await _post('/calendar/events/quick', {'text': text});
    return data['event'];
  }

  Future<bool> deleteEvent(String eventId) async {
    final data = await _delete('/calendar/events/$eventId');
    return data['ok'] == true;
  }

  // ══════════ DRIVE ══════════

  Future<List<Map<String, dynamic>>> listDriveFiles({
    String? query,
    String? folderId,
    int maxResults = 20,
  }) async {
    final params = <String, String>{'max_results': maxResults.toString()};
    if (query != null) params['query'] = query;
    if (folderId != null) params['folder_id'] = folderId;

    final data = await _get('/drive/files', params: params);
    return List<Map<String, dynamic>>.from(data['files'] ?? []);
  }

  Future<List<Map<String, dynamic>>> searchDrive(String query) async {
    final data = await _get('/drive/search', params: {'q': query});
    return List<Map<String, dynamic>>.from(data['files'] ?? []);
  }

  Future<Map<String, dynamic>?> createFolder(String name, {String? parentId}) async {
    final data = await _post('/drive/folder', {
      'name': name,
      'parent_id': parentId,
    });
    return data['folder'];
  }

  Future<bool> shareFile(String fileId, String email, {String role = 'reader'}) async {
    final data = await _post('/drive/files/$fileId/share', {
      'email': email,
      'role': role,
    });
    return data['ok'] == true;
  }

  Future<Map<String, dynamic>> getDriveQuota() async {
    final data = await _get('/drive/quota');
    return data['quota'] ?? {};
  }

  // ══════════ TASKS ══════════

  Future<List<Map<String, dynamic>>> getTaskLists() async {
    final data = await _get('/tasks/lists');
    return List<Map<String, dynamic>>.from(data['lists'] ?? []);
  }

  Future<List<Map<String, dynamic>>> getTasks({
    String taskListId = '@default',
    bool showCompleted = false,
  }) async {
    final data = await _get('/tasks', params: {
      'task_list_id': taskListId,
      'show_completed': showCompleted.toString(),
    });
    return List<Map<String, dynamic>>.from(data['tasks'] ?? []);
  }

  Future<Map<String, dynamic>?> createTask({
    required String title,
    String notes = '',
    String? due,
    String taskListId = '@default',
  }) async {
    final data = await _post('/tasks', {
      'title': title,
      'notes': notes,
      'due': due,
      'task_list_id': taskListId,
    });
    return data['task'];
  }

  Future<bool> completeTask(String taskId, {String taskListId = '@default'}) async {
    final data = await _post('/tasks/$taskId/complete', {}, params: {'task_list_id': taskListId});
    return data['ok'] == true;
  }

  Future<bool> deleteTask(String taskId, {String taskListId = '@default'}) async {
    final data = await _delete('/tasks/$taskId', params: {'task_list_id': taskListId});
    return data['ok'] == true;
  }

  // ══════════ CONTACTS ══════════

  Future<List<Map<String, dynamic>>> getContacts({int maxResults = 50}) async {
    final data = await _get('/contacts', params: {'max_results': maxResults.toString()});
    return List<Map<String, dynamic>>.from(data['contacts'] ?? []);
  }

  Future<List<Map<String, dynamic>>> searchContacts(String query) async {
    final data = await _get('/contacts/search', params: {'q': query});
    return List<Map<String, dynamic>>.from(data['contacts'] ?? []);
  }

  Future<Map<String, dynamic>?> createContact({
    required String firstName,
    String lastName = '',
    String email = '',
    String phone = '',
    String organization = '',
  }) async {
    final data = await _post('/contacts', {
      'first_name': firstName,
      'last_name': lastName,
      'email': email,
      'phone': phone,
      'organization': organization,
    });
    return data['contact'];
  }

  // ══════════ KEEP / NOTES ══════════

  Future<bool> connectKeep(String email, String masterToken) async {
    try {
      final data = await _post('/keep/connect', {
        'email': email,
        'master_token': masterToken,
      });
      return data['ok'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> get isKeepConnected async {
    try {
      final data = await _get('/keep/status');
      return data['connected'] == true;
    } catch (_) {
      return false;
    }
  }

  // ══════════ DASHBOARD ══════════

  Future<Map<String, dynamic>> getDashboard() async {
    return await _get('/dashboard');
  }

  // ══════════ HTTP HELPERS ══════════

  Future<Map<String, dynamic>> _get(
    String path, {
    Map<String, String>? params,
  }) async {
    final uri = Uri.parse('$apiHost$path').replace(queryParameters: params);
    final resp = await _client.get(uri);
    if (resp.statusCode == 200) {
      return jsonDecode(resp.body);
    }
    throw Exception('GET $path failed: ${resp.statusCode}');
  }

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body, {
    Map<String, String>? params,
  }) async {
    var uri = Uri.parse('$apiHost$path');
    if (params != null) {
      uri = uri.replace(queryParameters: params);
    }
    final resp = await _client.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    if (resp.statusCode == 200) {
      return jsonDecode(resp.body);
    }
    throw Exception('POST $path failed: ${resp.statusCode}');
  }

  Future<Map<String, dynamic>> _put(
    String path,
    Map<String, dynamic> body,
  ) async {
    final resp = await _client.put(
      Uri.parse('$apiHost$path'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    if (resp.statusCode == 200) {
      return jsonDecode(resp.body);
    }
    throw Exception('PUT $path failed: ${resp.statusCode}');
  }

  Future<Map<String, dynamic>> _delete(
    String path, {
    Map<String, String>? params,
  }) async {
    var uri = Uri.parse('$apiHost$path');
    if (params != null) {
      uri = uri.replace(queryParameters: params);
    }
    final resp = await _client.delete(uri);
    if (resp.statusCode == 200) {
      return jsonDecode(resp.body);
    }
    throw Exception('DELETE $path failed: ${resp.statusCode}');
  }
}
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'swarm_config.dart';

/// Thrown when LucyServer cannot satisfy a request.
///
/// Every method here used to swallow failures and return invented data — a
/// "CLEAN" malware verdict for an unscanned package, audit-log entries for
/// privilege elevations that never happened, revenue figures, "Root Authority"
/// developers, and `true` from sync calls that had thrown. Callers could not
/// distinguish real results from fiction. They now get this instead, and are
/// expected to render an error state.
class EcosystemUnavailable implements Exception {
  final String endpoint;
  final int? statusCode;
  final Object? cause;

  EcosystemUnavailable(this.endpoint, {this.statusCode, this.cause});

  @override
  String toString() {
    final reason = statusCode != null ? 'HTTP $statusCode' : (cause?.toString() ?? 'unreachable');
    return 'LucyServer unavailable for $endpoint ($reason)';
  }
}

class AdvancedEcosystemService {
  static String get baseUrl => '${SwarmConfig.httpBase}/api';

  Future<dynamic> _get(String path) async {
    http.Response res;
    try {
      res = await http.get(Uri.parse('$baseUrl$path'), headers: SwarmConfig.authHeaders);
    } catch (e) {
      throw EcosystemUnavailable(path, cause: e);
    }
    if (res.statusCode != 200) {
      throw EcosystemUnavailable(path, statusCode: res.statusCode);
    }
    return jsonDecode(res.body);
  }

  Future<dynamic> _post(String path, [Map<String, dynamic>? body]) async {
    http.Response res;
    try {
      res = await http.post(
        Uri.parse('$baseUrl$path'),
        headers: SwarmConfig.authHeaders,
        body: body == null ? null : jsonEncode(body),
      );
    } catch (e) {
      throw EcosystemUnavailable(path, cause: e);
    }
    if (res.statusCode != 200) {
      throw EcosystemUnavailable(path, statusCode: res.statusCode);
    }
    return res.body.isEmpty ? null : jsonDecode(res.body);
  }

  // --- 1 & 2. AI Coding Agents & Suggested Fixes ---
  Future<Map<String, dynamic>> dispatchAiCodingTask({
    required String title,
    required String prompt,
    required String activeFilePath,
    String language = 'dart',
    int role = 1, // 0: Architect, 1: LeadCoder, 2: SecurityAuditor, 3: TestEngineer
  }) async {
    final json = await _post('/ai-coder/task', {
      'Title': title,
      'Prompt': prompt,
      'ActiveFilePath': activeFilePath,
      'Language': language,
      'Role': role,
    });
    return (json as Map).cast<String, dynamic>();
  }

  Future<List<dynamic>> suggestCodeFixes({
    required String filePath,
    required String fileContent,
    required String compilerOutput,
  }) async {
    final json = await _post('/ai-coder/suggest-fixes', {
      'FilePath': filePath,
      'FileContent': fileContent,
      'CompilerOutput': compilerOutput,
    });
    return json as List<dynamic>;
  }

  // --- 3. Cloud Remote Workspaces ---
  Future<List<dynamic>> getCloudWorkspaces() async =>
      await _get('/workspaces/cloud') as List<dynamic>;

  Future<bool> syncCloudWorkspace(String workspaceId) async {
    // Previously returned true when the request threw, reporting a sync that
    // never happened.
    await _post('/workspaces/cloud/$workspaceId/sync');
    return true;
  }

  // --- 4, 5, 6 & 7. App Store, Templates & Monetization ---
  Future<List<dynamic>> getCommunityTemplates() async =>
      await _get('/templates/community') as List<dynamic>;

  Future<Map<String, dynamic>> getMarketplaceAnalytics() async =>
      (await _get('/marketplace/analytics') as Map).cast<String, dynamic>();

  // --- 8 & 9. Screen Mirroring & Hardware Performance Stats ---
  Future<Map<String, dynamic>> startScreenMirror({
    String deviceSerial = 'USB-DEVICE',
    String deviceModel = 'Android Companion',
    bool isWireless = false,
    String ipAddress = '',
    int port = 5555,
  }) async {
    final json = await _post('/device/mirror/start', {
      'DeviceSerial': deviceSerial,
      'DeviceModel': deviceModel,
      'IsWireless': isWireless,
      'IpAddress': ipAddress,
      'Port': port,
      'MaxFps': 60,
      'BitrateMbps': 8,
      'ForwardAudio': true,
    });
    return (json as Map).cast<String, dynamic>();
  }

  Future<bool> stopScreenMirror(String sessionId) async {
    await _post('/device/mirror/$sessionId/stop');
    return true;
  }

  Future<Map<String, dynamic>> getHardwarePerformanceStats() async =>
      (await _get('/device/stats') as Map).cast<String, dynamic>();

  // --- 10 & 11. Telemetry, Crash Reports & App Analytics ---
  Future<List<dynamic>> getCrashReports() async {
    final json = await _get('/telemetry/crash-reports');
    // The Go handler wraps the list: {"crash_reports": [...]}
    if (json is Map && json['crash_reports'] is List) {
      return json['crash_reports'] as List<dynamic>;
    }
    return json as List<dynamic>;
  }

  Future<Map<String, dynamic>> getAppAnalytics(String appId) async =>
      (await _get('/telemetry/app-analytics?app_id=$appId') as Map).cast<String, dynamic>();

  // --- 12, 13, 14 & 15. Audit Logs, Malware Scanning & PKI ---
  Future<List<dynamic>> getAuditLogs() async {
    final json = await _get('/security/audit-logs');
    if (json is Map && json['audit_logs'] is List) {
      return json['audit_logs'] as List<dynamic>;
    }
    return json as List<dynamic>;
  }

  /// Scans a package. Never returns a verdict it did not actually receive —
  /// a scanner that reports CLEAN because it could not reach the scanner is
  /// worse than one that reports nothing.
  Future<Map<String, dynamic>> scanPackage(String packagePath) async {
    final json = await _post('/security/scan-package', {'PackagePath': packagePath});
    return (json as Map).cast<String, dynamic>();
  }

  Future<List<dynamic>> getVerifiedDevelopers() async {
    final json = await _get('/security/verified-developers');
    if (json is Map && json['verified_developers'] is List) {
      return json['verified_developers'] as List<dynamic>;
    }
    return json as List<dynamic>;
  }
}

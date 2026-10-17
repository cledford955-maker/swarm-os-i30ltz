import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'swarm_config.dart';

/// Status returned by LucyServer's `/api/google/auth/status` (which proxies to
/// the .NET GoogleWorkspaceService on 8402).
class GoogleAuthStatus {
  final bool authenticated;
  final bool hasCredentials;
  final String? email;
  final String? name;
  final String? error; // populated when upstream is unreachable

  const GoogleAuthStatus({
    required this.authenticated,
    required this.hasCredentials,
    this.email,
    this.name,
    this.error,
  });

  bool get isOffline => error != null;

  static const GoogleAuthStatus offline = GoogleAuthStatus(
    authenticated: false,
    hasCredentials: false,
    error: 'google workspace service unreachable',
  );

  factory GoogleAuthStatus.fromJson(Map<String, dynamic> json) => GoogleAuthStatus(
        authenticated: json['authenticated'] as bool? ?? false,
        hasCredentials: json['has_credentials'] as bool? ?? false,
        email: json['email'] as String?,
        name: json['name'] as String?,
        error: json['error'] as String?,
      );
}

/// Thin client for LucyServer's Google OAuth proxy.
///
/// OAuth credentials and refresh tokens belong to the shared Google Workspace
/// service behind LucyServer. Flutter clients keep no Google password, access
/// token, or refresh token locally, so the same server-side sign-in is visible
/// to every app using this LucyServer instance.
///
/// Flow:
///   1. [uploadCredentials] — user supplies the OAuth client credentials.json
///      downloaded from Google Cloud Console.
///   2. [getAuthUrl] — server returns the Google consent URL. The Flutter
///      shell opens it in the user's browser.
///   3. User approves; browser is redirected to `/auth/callback` on 8402
///      which completes the token exchange server-side.
///   4. Poll [status] until [GoogleAuthStatus.authenticated] is true.
///   5. Or, if the callback couldn't reach 8402 (mobile companion, tunnelled
///      environment, etc.), pass the code manually via [exchangeCode].
class GoogleWorkspaceService {
  final String baseUrl;
  GoogleWorkspaceService({String? baseUrl}) : baseUrl = baseUrl ?? SwarmConfig.httpBase;

  Future<GoogleAuthStatus> status() async {
    try {
      final resp = await http
          .get(Uri.parse('$baseUrl/api/google/auth/status'), headers: SwarmConfig.authHeaders)
          .timeout(const Duration(seconds: 5));
      if (resp.statusCode == 503) {
        return GoogleAuthStatus.offline;
      }
      if (resp.statusCode != 200) {
        return GoogleAuthStatus.offline;
      }
      return GoogleAuthStatus.fromJson(jsonDecode(resp.body) as Map<String, dynamic>);
    } catch (_) {
      return GoogleAuthStatus.offline;
    }
  }

  /// Returns the OAuth consent URL to open in the user's browser. Throws if
  /// credentials.json has not been uploaded yet.
  Future<String> getAuthUrl() async {
    final resp = await http
        .get(Uri.parse('$baseUrl/api/google/auth/url'), headers: SwarmConfig.authHeaders)
        .timeout(const Duration(seconds: 5));
    if (resp.statusCode != 200) {
      final body = jsonDecode(resp.body) as Map<String, dynamic>;
      throw StateError(body['error']?.toString() ?? 'auth url failed (HTTP ${resp.statusCode})');
    }
    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    final url = body['url'] as String?;
    if (url == null || url.isEmpty) {
      throw StateError('empty auth url from server');
    }
    return url;
  }

  /// Upload `credentials.json` bytes as multipart/form-data.
  Future<void> uploadCredentials(List<int> bytes) async {
    final req = http.MultipartRequest('POST', Uri.parse('$baseUrl/api/google/auth/upload_credentials'))
      ..headers.addAll(SwarmConfig.authHeaders)
      ..files.add(http.MultipartFile.fromBytes('file', bytes, filename: 'credentials.json'));
    final streamed = await req.send().timeout(const Duration(seconds: 10));
    if (streamed.statusCode != 200) {
      final body = await streamed.stream.bytesToString();
      throw StateError('upload failed (HTTP ${streamed.statusCode}): $body');
    }
  }

  /// Manually complete the OAuth exchange with a code pasted by the user —
  /// used when the browser callback couldn't reach the service (e.g. auth on
  /// a remote workstation).
  Future<void> exchangeCode(String code) async {
    final resp = await http
        .post(
          Uri.parse('$baseUrl/api/google/auth/exchange'),
          headers: {...SwarmConfig.authHeaders, 'Content-Type': 'application/json'},
          body: jsonEncode({'code': code}),
        )
        .timeout(const Duration(seconds: 10));
    if (resp.statusCode != 200) {
      throw StateError('exchange failed (HTTP ${resp.statusCode})');
    }
  }

  /// Revoke the OAuth token and delete stored refresh material.
  Future<void> logout() async {
    await http
        .post(Uri.parse('$baseUrl/api/google/auth/logout'), headers: SwarmConfig.authHeaders)
        .timeout(const Duration(seconds: 5));
  }
}

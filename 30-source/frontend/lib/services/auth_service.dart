import 'dart:convert';
import 'package:http/http.dart' as http;
import 'swarm_config.dart';

class AuthService {
  static String get baseUrl => SwarmConfig.httpBase;

  // 1. Get Login Options from Backend
  Future<Map<String, dynamic>> getWebAuthnLoginOptions() async {
    final response = await http.get(Uri.parse('$baseUrl/webauthn/login/options'), headers: SwarmConfig.authHeaders);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to get login options');
    }
  }

  // 2. Verify Login with Backend (Placeholder for when companion app/passkey signs it)
  Future<bool> verifyWebAuthnLogin(Map<String, dynamic> authResponse) async {
    final response = await http.post(
      Uri.parse('$baseUrl/webauthn/login/verify'),
      headers: SwarmConfig.authHeaders,
      body: jsonEncode(authResponse),
    );
    return response.statusCode == 200;
  }
}

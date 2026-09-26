import 'dart:convert';
import 'package:http/http.dart' as http;
import 'swarm_config.dart';

class PasskeyCredential {
  final String id;
  final String name;
  final String createdAt;

  const PasskeyCredential({
    required this.id,
    this.name = '',
    this.createdAt = '',
  });

  factory PasskeyCredential.fromJson(Map<String, dynamic> json) {
    return PasskeyCredential(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? json['id']?.toString() ?? '',
      createdAt: json['created_at']?.toString() ?? '',
    );
  }
}

class AuthService {
  static String get baseUrl => SwarmConfig.httpBase;

  Future<Map<String, dynamic>> getRegisterOptions() async {
    final response = await http.get(
      Uri.parse('$baseUrl/webauthn/register/options'),
      headers: SwarmConfig.authHeaders,
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Failed to get register options');
  }

  Future<bool> verifyRegister(Map<String, dynamic> attestation) async {
    final response = await http.post(
      Uri.parse('$baseUrl/webauthn/register/verify'),
      headers: {...SwarmConfig.authHeaders, 'Content-Type': 'application/json'},
      body: jsonEncode(attestation),
    );
    return response.statusCode == 200;
  }

  Future<Map<String, dynamic>> getLoginOptions() async {
    final response = await http.get(
      Uri.parse('$baseUrl/webauthn/login/options'),
      headers: SwarmConfig.authHeaders,
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Failed to get login options');
  }

  Future<bool> verifyLogin(Map<String, dynamic> assertion) async {
    final response = await http.post(
      Uri.parse('$baseUrl/webauthn/login/verify'),
      headers: {...SwarmConfig.authHeaders, 'Content-Type': 'application/json'},
      body: jsonEncode(assertion),
    );
    return response.statusCode == 200;
  }

  Future<List<PasskeyCredential>> listCredentials() async {
    final response = await http.get(
      Uri.parse('$baseUrl/webauthn/list'),
      headers: SwarmConfig.authHeaders,
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data is List) {
        return data.map((e) => PasskeyCredential.fromJson(e as Map<String, dynamic>)).toList();
      }
      return [];
    }
    throw Exception('Failed to list credentials');
  }

  Future<bool> clearCredentials() async {
    final response = await http.post(
      Uri.parse('$baseUrl/webauthn/clear'),
      headers: SwarmConfig.authHeaders,
    );
    return response.statusCode == 200;
  }
}

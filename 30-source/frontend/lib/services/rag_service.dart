import 'dart:convert';
import 'package:http/http.dart' as http;
import 'swarm_config.dart';

class RagDocument {
  final String text;
  final String source;

  const RagDocument({required this.text, this.source = ''});

  factory RagDocument.fromJson(Map<String, dynamic> json) {
    return RagDocument(
      text: json['text']?.toString() ?? '',
      source: json['source']?.toString() ?? '',
    );
  }
}

class RagService {
  final String baseUrl;

  RagService({String? baseUrl}) : baseUrl = baseUrl ?? SwarmConfig.httpBase;

  Future<Map<String, dynamic>> ingestText(String text, {String source = 'manual'}) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/rag/ingest'),
      headers: {...SwarmConfig.authHeaders, 'Content-Type': 'application/json'},
      body: jsonEncode({'text': text, 'source': source}),
    );
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('RAG ingest failed: ${res.statusCode}');
  }

  Future<Map<String, dynamic>> ingestFile(String filePath) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/rag/ingest/file'),
      headers: {...SwarmConfig.authHeaders, 'Content-Type': 'application/json'},
      body: jsonEncode({'filePath': filePath}),
    );
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('RAG file ingest failed: ${res.statusCode}');
  }

  Future<List<RagDocument>> listDocuments() async {
    final res = await http.get(
      Uri.parse('$baseUrl/api/rag/documents'),
      headers: SwarmConfig.authHeaders,
    );
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      if (data is List) {
        return data.map((e) => RagDocument.fromJson(e as Map<String, dynamic>)).toList();
      }
      return [];
    }
    throw Exception('RAG list failed: ${res.statusCode}');
  }

  Future<bool> deleteDocument(String source) async {
    final res = await http.delete(
      Uri.parse('$baseUrl/api/rag/document?source=${Uri.encodeComponent(source)}'),
      headers: SwarmConfig.authHeaders,
    );
    return res.statusCode == 200;
  }

  Future<bool> clearAll() async {
    final res = await http.delete(
      Uri.parse('$baseUrl/api/rag/clear'),
      headers: SwarmConfig.authHeaders,
    );
    return res.statusCode == 200;
  }
}

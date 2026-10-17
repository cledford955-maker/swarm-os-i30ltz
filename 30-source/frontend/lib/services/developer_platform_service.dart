import 'dart:convert';
import 'package:http/http.dart' as http;
import 'swarm_config.dart';

class DeveloperPlatformService {
  final String baseUrl;

  DeveloperPlatformService({String? baseUrl}) : baseUrl = baseUrl ?? SwarmConfig.httpBase;

  // Extension SDK & Local Linking
  Future<List<Map<String, dynamic>>> getLocalExtensions() async {
    final res = await http.get(Uri.parse('$baseUrl/api/extensions/local/list'));
    if (res.statusCode == 200) {
      return (jsonDecode(res.body) as List).cast<Map<String, dynamic>>();
    }
    return [];
  }

  Future<Map<String, dynamic>?> linkLocalExtension(String path) async {
    final res = await http.post(Uri.parse('$baseUrl/api/extensions/local/link?path=${Uri.encodeComponent(path)}'));
    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    }
    return null;
  }

  Future<bool> unlinkLocalExtension(String extensionId) async {
    final res = await http.delete(Uri.parse('$baseUrl/api/extensions/local/$extensionId'));
    return res.statusCode == 200;
  }

  Future<Map<String, dynamic>> resolveDependencies(Map<String, String> dependencies) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/extensions/dependencies/resolve'),
      headers: SwarmConfig.authHeaders,
      body: jsonEncode(dependencies),
    );
    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    }
    return {'success': false};
  }

  // App Releases & Channels
  Future<List<Map<String, dynamic>>> getReleases(String appId, {String? channel}) async {
    var url = '$baseUrl/api/releases/$appId';
    if (channel != null) url += '?channel=$channel';
    final res = await http.get(Uri.parse(url));
    if (res.statusCode == 200) {
      return (jsonDecode(res.body) as List).cast<Map<String, dynamic>>();
    }
    return [];
  }

  Future<bool> promoteRelease(String releaseId, String targetChannel) async {
    final res = await http.post(Uri.parse('$baseUrl/api/releases/$releaseId/promote?targetChannel=$targetChannel'));
    return res.statusCode == 200;
  }

  // Git & CI/CD
  Future<List<Map<String, dynamic>>> getGitRepositories() async {
    final res = await http.get(Uri.parse('$baseUrl/api/git/repos'));
    if (res.statusCode == 200) {
      return (jsonDecode(res.body) as List).cast<Map<String, dynamic>>();
    }
    return [];
  }

  Future<Map<String, dynamic>?> createGitRepository(String name) async {
    final res = await http.post(Uri.parse('$baseUrl/api/git/repos/create?name=${Uri.encodeComponent(name)}'));
    if (res.statusCode == 201) {
      return jsonDecode(res.body);
    }
    return null;
  }

  Future<Map<String, dynamic>?> triggerPipeline(String repoName, {String? commitSha}) async {
    var url = '$baseUrl/api/ci/pipelines/trigger?repoName=${Uri.encodeComponent(repoName)}';
    if (commitSha != null) url += '&commitSha=$commitSha';
    final res = await http.post(Uri.parse(url));
    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    }
    return null;
  }

  Future<Map<String, dynamic>?> getPipeline(String pipelineId) async {
    final res = await http.get(Uri.parse('$baseUrl/api/ci/pipelines/$pipelineId'));
    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    }
    return null;
  }

  // Artifacts
  Future<List<Map<String, dynamic>>> getArtifacts() async {
    final res = await http.get(Uri.parse('$baseUrl/api/artifacts'));
    if (res.statusCode == 200) {
      return (jsonDecode(res.body) as List).cast<Map<String, dynamic>>();
    }
    return [];
  }

  // Analytics Dashboard
  Future<Map<String, dynamic>> getDeveloperAnalytics() async {
    final res = await http.get(Uri.parse('$baseUrl/api/analytics/dashboard'));
    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    }
    return {};
  }
}

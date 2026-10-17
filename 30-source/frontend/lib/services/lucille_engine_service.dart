import 'dart:convert';
import 'package:http/http.dart' as http;
import 'swarm_config.dart';

class LucilleEngineStatus {
  final bool running;
  final String user;
  final int uid;
  final int pCores;
  final int eCores;
  final int totalRamMb;
  final int cgroupMemoryHighMb;
  final String soulSha256;
  final int activeProcesses;

  LucilleEngineStatus({
    required this.running,
    this.user = '',
    this.uid = 0,
    this.pCores = 0,
    this.eCores = 0,
    this.totalRamMb = 0,
    this.cgroupMemoryHighMb = 0,
    this.soulSha256 = '',
    this.activeProcesses = 0,
  });

  factory LucilleEngineStatus.fromJson(Map<String, dynamic> j) =>
      LucilleEngineStatus(
        running: j['status'] == 'running',
        user: j['user'] ?? '',
        uid: j['uid'] ?? 0,
        pCores: j['p_cores'] ?? 0,
        eCores: j['e_cores'] ?? 0,
        totalRamMb: j['total_ram_mb'] ?? 0,
        cgroupMemoryHighMb: j['cgroup_memory_high_mb'] ?? 0,
        soulSha256: j['soul_sha256'] ?? '',
        activeProcesses: j['active_processes'] ?? 0,
      );

  factory LucilleEngineStatus.offline() =>
      LucilleEngineStatus(running: false);
}

class PipelineResult {
  final bool success;
  final int totalBlocks;
  final int passedBlocks;
  final int rejectedBlocks;
  final bool highRisk;
  final bool consensusApproved;
  final bool humanApproved;
  final bool applied;
  final String checkpointId;
  final int latencyMs;
  final bool mock;
  final String? error;

  PipelineResult({
    required this.success,
    this.totalBlocks = 0,
    this.passedBlocks = 0,
    this.rejectedBlocks = 0,
    this.highRisk = false,
    this.consensusApproved = false,
    this.humanApproved = false,
    this.applied = false,
    this.checkpointId = '',
    this.latencyMs = 0,
    this.mock = false,
    this.error,
  });

  factory PipelineResult.fromJson(Map<String, dynamic> j) => PipelineResult(
        success: j['success'] ?? false,
        totalBlocks: j['blocks'] ?? 0,
        passedBlocks: j['passed'] ?? 0,
        rejectedBlocks: j['rejected'] ?? 0,
        highRisk: j['high_risk'] ?? false,
        consensusApproved: j['consensus'] ?? false,
        humanApproved: j['human'] ?? false,
        applied: j['applied'] ?? false,
        checkpointId: j['checkpoint'] ?? '',
        latencyMs: j['latency_ms'] ?? 0,
        mock: j['mock'] ?? false,
        error: j['error'],
      );
}

class LucilleEngineService {
  final String _base = SwarmConfig.httpBase;
  final Map<String, String> _headers = SwarmConfig.authHeaders;

  Future<LucilleEngineStatus> getStatus() async {
    try {
      final r = await http
          .get(Uri.parse('$_base/api/lucille/status'), headers: _headers)
          .timeout(const Duration(seconds: 5));
      if (r.statusCode == 200) {
        return LucilleEngineStatus.fromJson(jsonDecode(r.body));
      }
      return LucilleEngineStatus.offline();
    } catch (_) {
      return LucilleEngineStatus.offline();
    }
  }

  Future<PipelineResult> runPipeline({
    required String taskId,
    required String instruction,
    String targetFile = '',
    String content = '',
    String language = '',
    String workspace = '',
    String compilerLogs = '',
  }) async {
    final body = jsonEncode({
      'task_id': taskId,
      'instruction': instruction,
      'target_file': targetFile,
      'content': content,
      'language': language,
      'workspace': workspace,
      'compiler_logs': compilerLogs,
    });
    final r = await http
        .post(Uri.parse('$_base/api/lucille/pipeline'),
            headers: _headers, body: body)
        .timeout(const Duration(seconds: 120));
    return PipelineResult.fromJson(jsonDecode(r.body));
  }

  Future<Map<String, dynamic>> routeTask({
    required String taskId,
    required String instruction,
    String targetFile = '',
    String content = '',
    String language = '',
    String workspace = '',
  }) async {
    final body = jsonEncode({
      'task_id': taskId,
      'instruction': instruction,
      'target_file': targetFile,
      'content': content,
      'language': language,
      'workspace': workspace,
    });
    final r = await http
        .post(Uri.parse('$_base/api/lucille/route'),
            headers: _headers, body: body)
        .timeout(const Duration(seconds: 120));
    return jsonDecode(r.body);
  }

  Future<Map<String, dynamic>> checkpointConfirm({
    required String workspace,
    required String checkpointId,
  }) async {
    final body = jsonEncode({
      'command': 'checkpoint_confirm',
      'workspace': workspace,
      'checkpoint_id': checkpointId,
    });
    final r = await http
        .post(Uri.parse('$_base/api/lucille/checkpoint'),
            headers: _headers, body: body)
        .timeout(const Duration(seconds: 10));
    return jsonDecode(r.body);
  }

  Future<Map<String, dynamic>> checkpointRollback({
    required String workspace,
    required String checkpointId,
  }) async {
    final body = jsonEncode({
      'command': 'checkpoint_rollback',
      'workspace': workspace,
      'checkpoint_id': checkpointId,
    });
    final r = await http
        .post(Uri.parse('$_base/api/lucille/checkpoint'),
            headers: _headers, body: body)
        .timeout(const Duration(seconds: 10));
    return jsonDecode(r.body);
  }
}

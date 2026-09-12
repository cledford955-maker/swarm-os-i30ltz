import 'dart:convert';
import 'package:http/http.dart' as http;
import 'swarm_config.dart';

class VirtualMachineDto {
  final String id;
  final String name;
  final String description;
  final String osType;
  final String status;
  final int cpuCores;
  final int ramMb;
  final int diskSizeGb;
  final int sshPort;
  final int httpPort;
  final int vncPort;
  final int? processId;

  VirtualMachineDto({
    required this.id,
    required this.name,
    required this.description,
    required this.osType,
    required this.status,
    required this.cpuCores,
    required this.ramMb,
    required this.diskSizeGb,
    required this.sshPort,
    required this.httpPort,
    required this.vncPort,
    this.processId,
  });

  factory VirtualMachineDto.fromJson(Map<String, dynamic> json) {
    return VirtualMachineDto(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      osType: (json['osType'] == 0 ? 'Linux' : json['osType'] == 1 ? 'Windows' : json['osType'] == 2 ? 'MacOS' : 'Container'),
      status: (json['status'] == 0 ? 'Stopped' : json['status'] == 2 ? 'Running' : json['status'] == 3 ? 'Paused' : 'Error'),
      cpuCores: json['cpuCores'] ?? 4,
      ramMb: json['ramMb'] ?? 8192,
      diskSizeGb: json['diskSizeGb'] ?? 32,
      sshPort: json['sshPort'] ?? 2222,
      httpPort: json['httpPort'] ?? 8080,
      vncPort: json['vncPort'] ?? 5900,
      processId: json['processId'],
    );
  }
}

class VmTelemetryDto {
  final double cpuUsagePercent;
  final int memoryUsedMb;
  final int memoryTotalMb;
  final double diskReadBytesPerSec;
  final double diskWriteBytesPerSec;

  VmTelemetryDto({
    required this.cpuUsagePercent,
    required this.memoryUsedMb,
    required this.memoryTotalMb,
    required this.diskReadBytesPerSec,
    required this.diskWriteBytesPerSec,
  });

  factory VmTelemetryDto.fromJson(Map<String, dynamic> json) {
    return VmTelemetryDto(
      cpuUsagePercent: (json['cpuUsagePercent'] as num?)?.toDouble() ?? 0.0,
      memoryUsedMb: json['memoryUsedMb'] ?? 0,
      memoryTotalMb: json['memoryTotalMb'] ?? 0,
      diskReadBytesPerSec: (json['diskReadBytesPerSec'] as num?)?.toDouble() ?? 0.0,
      diskWriteBytesPerSec: (json['diskWriteBytesPerSec'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class VirtualizationService {
  final String baseUrl;

  VirtualizationService({String? baseUrl}) : baseUrl = baseUrl ?? SwarmConfig.httpBase;

  Future<List<VirtualMachineDto>> getVms() async {
    final res = await http.get(Uri.parse('$baseUrl/api/vms'));
    if (res.statusCode == 200) {
      final list = jsonDecode(res.body) as List;
      return list.map((e) => VirtualMachineDto.fromJson(e)).toList();
    }
    return [];
  }

  Future<bool> startVm(String id) async {
    final res = await http.post(Uri.parse('$baseUrl/api/vms/$id/start'));
    return res.statusCode == 200;
  }

  Future<bool> stopVm(String id, {bool force = false}) async {
    final res = await http.post(Uri.parse('$baseUrl/api/vms/$id/stop?force=$force'));
    return res.statusCode == 200;
  }

  Future<bool> pauseVm(String id) async {
    final res = await http.post(Uri.parse('$baseUrl/api/vms/$id/pause'));
    return res.statusCode == 200;
  }

  Future<bool> resumeVm(String id) async {
    final res = await http.post(Uri.parse('$baseUrl/api/vms/$id/resume'));
    return res.statusCode == 200;
  }

  Future<bool> deleteVm(String id) async {
    final res = await http.delete(Uri.parse('$baseUrl/api/vms/$id'));
    return res.statusCode == 200;
  }

  Future<VmTelemetryDto?> getTelemetry(String id) async {
    final res = await http.get(Uri.parse('$baseUrl/api/vms/$id/telemetry'));
    if (res.statusCode == 200) {
      return VmTelemetryDto.fromJson(jsonDecode(res.body));
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> getSnapshots(String id) async {
    final res = await http.get(Uri.parse('$baseUrl/api/vms/$id/snapshots'));
    if (res.statusCode == 200) {
      return (jsonDecode(res.body) as List).cast<Map<String, dynamic>>();
    }
    return [];
  }

  Future<bool> createSnapshot(String id, String name, {String? description}) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/vms/$id/snapshots'),
      headers: SwarmConfig.authHeaders,
      body: jsonEncode({'Name': name, 'Description': description}),
    );
    return res.statusCode == 201;
  }

  Future<bool> restoreSnapshot(String id, String snapshotName) async {
    final res = await http.post(Uri.parse('$baseUrl/api/vms/$id/snapshots/$snapshotName/restore'));
    return res.statusCode == 200;
  }

  Future<List<Map<String, dynamic>>> getTemplates() async {
    final res = await http.get(Uri.parse('$baseUrl/api/templates/environments'));
    if (res.statusCode == 200) {
      return (jsonDecode(res.body) as List).cast<Map<String, dynamic>>();
    }
    return [];
  }

  Future<Map<String, dynamic>?> instantiateTemplate(String templateId, String vmName) async {
    final res = await http.post(Uri.parse('$baseUrl/api/templates/environments/$templateId/instantiate?name=${Uri.encodeComponent(vmName)}'));
    if (res.statusCode == 201) {
      return jsonDecode(res.body);
    }
    return null;
  }

  Future<Map<String, dynamic>> executeSandbox({
    required String code,
    String language = 'bash',
    int timeoutSeconds = 30,
    int memoryLimitMb = 512,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/sandbox/execute'),
      headers: SwarmConfig.authHeaders,
      body: jsonEncode({
        'Code': code,
        'Language': language,
        'TimeoutSeconds': timeoutSeconds,
        'MemoryLimitMb': memoryLimitMb,
      }),
    );
    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    }
    throw Exception('Sandbox execution failed: ${res.statusCode}');
  }
}

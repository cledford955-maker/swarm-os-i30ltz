import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'swarm_config.dart';

class InstallDisk {
  final String path;
  final int sizeBytes;
  final String sizeHuman;
  final String model;
  final bool hasLuks;
  final bool partitionsReady;
  /// Filesystem UUIDs the installer is driven by: [rootUuid] is the btrfs
  /// partition that gets formatted, [efiUuid] the FAT EFI that is kept.
  final String efiUuid;
  final String rootUuid;

  InstallDisk({
    required this.path,
    required this.sizeBytes,
    required this.sizeHuman,
    required this.model,
    required this.hasLuks,
    required this.partitionsReady,
    this.efiUuid = '',
    this.rootUuid = '',
  });

  factory InstallDisk.fromJson(Map<String, dynamic> j) => InstallDisk(
        path: j['path'] as String,
        sizeBytes: (j['sizeBytes'] as num?)?.toInt() ?? 0,
        sizeHuman: j['sizeHuman'] as String? ?? '',
        model: j['model'] as String? ?? '',
        hasLuks: j['hasLuks'] as bool? ?? false,
        partitionsReady: j['partitionsReady'] as bool? ?? false,
        efiUuid: j['efiUuid'] as String? ?? '',
        rootUuid: j['rootUuid'] as String? ?? '',
      );
}

/// Talks to LucyServer's /api/install/* endpoints — the graphical
/// replacement for shelling out to install_swarm_os.sh in a terminal.
class InstallService {
  Future<List<InstallDisk>> listDisks() async {
    final res = await http.get(
      Uri.parse('${SwarmConfig.httpBase}/api/install/disks'),
      headers: SwarmConfig.authHeaders,
    );
    if (res.statusCode != 200) {
      throw Exception('Could not list disks (HTTP ${res.statusCode})');
    }
    final list = jsonDecode(res.body) as List<dynamic>? ?? [];
    return list.map((e) => InstallDisk.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Opens the live install session for [disk].
  ///
  /// [password] becomes the i30ltz account password (sudo / terminal
  /// commands). [adminPassword] becomes the SWARM OS admin login password
  /// used by the Flutter lock-screen for "forgot cipher" recovery — typically
  /// the same value as [password] for a single-user system.
  ///
  /// Both are sent as the first WebSocket message (a handshake, not URL query
  /// params) so they never appear in server access logs or WS-URL history.
  /// An empty [password] is only accepted when a prior install's hash was
  /// preserved; an empty [adminPassword] makes the installer warn and skip it.
  /// [onLine] gets every output chunk as it streams in, [onDone] fires once
  /// the socket closes (install finished or connection dropped).
  Future<WebSocket> startInstall({
    required String disk,
    required String rootUuid,
    required String efiUuid,
    required String password,
    String adminPassword = '',
    required void Function(String chunk) onLine,
    required void Function() onDone,
  }) async {
    final wsBase = SwarmConfig.httpBase.replaceFirst('http', 'ws');
    final uri = Uri.parse('$wsBase/api/install/ws'
        '?disk=${Uri.encodeQueryComponent(disk)}'
        '&rootUuid=${Uri.encodeQueryComponent(rootUuid)}'
        '&espUuid=${Uri.encodeQueryComponent(efiUuid)}');
    final socket = await WebSocket.connect(
      uri.toString(),
      headers: {'X-Swarm-Auth': SwarmConfig.authToken},
    );
    socket.add(jsonEncode({
      'password': password,
      'adminPassword': adminPassword,
    }));
    socket.listen(
      (data) => onLine(data is String ? data : utf8.decode(data as List<int>)),
      onDone: onDone,
      onError: (_) => onDone(),
    );
    return socket;
  }
}

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

  InstallDisk({
    required this.path,
    required this.sizeBytes,
    required this.sizeHuman,
    required this.model,
    required this.hasLuks,
    required this.partitionsReady,
  });

  factory InstallDisk.fromJson(Map<String, dynamic> j) => InstallDisk(
        path: j['path'] as String,
        sizeBytes: (j['sizeBytes'] as num?)?.toInt() ?? 0,
        sizeHuman: j['sizeHuman'] as String? ?? '',
        model: j['model'] as String? ?? '',
        hasLuks: j['hasLuks'] as bool? ?? false,
        partitionsReady: j['partitionsReady'] as bool? ?? false,
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

  /// Opens the live install session for [disk]. [password] becomes the
  /// i30ltz account password on the installed system — sent as the first
  /// WebSocket message (a handshake, not a URL query param) so it never ends
  /// up in server access logs or WS-URL history. Pass '' if a prior install's
  /// password hash was preserved and none is needed (the server-side script
  /// only asks for one when it actually has to set a fresh account).
  /// Call [onLine] for every chunk of output as it streams in, and [onDone]
  /// once the socket closes (the install finished, or the connection dropped).
  Future<WebSocket> startInstall({
    required String disk,
    required String password,
    required void Function(String chunk) onLine,
    required void Function() onDone,
  }) async {
    final wsBase = SwarmConfig.httpBase.replaceFirst('http', 'ws');
    final uri = Uri.parse('$wsBase/api/install/ws?disk=${Uri.encodeQueryComponent(disk)}');
    final socket = await WebSocket.connect(
      uri.toString(),
      headers: {'X-Swarm-Auth': SwarmConfig.authToken},
    );
    socket.add(jsonEncode({'password': password}));
    socket.listen(
      (data) => onLine(data is String ? data : utf8.decode(data as List<int>)),
      onDone: onDone,
      onError: (_) => onDone(),
    );
    return socket;
  }
}

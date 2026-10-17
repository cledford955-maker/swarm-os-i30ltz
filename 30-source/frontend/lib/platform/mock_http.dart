import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Canned backend for the web demo. Installed with http.runWithClient so every
/// http.get/post/Request in the shell hits this instead of LucyServer (:5000),
/// GamingAgent (:8401), the memory service (:8399), Ollama, OpenRouter, etc.
/// Nothing leaves the browser. State (notes, VMs) lives for the page session.
const _lucilleReply =
    "Hi, I'm Lucille. This is the SWARM OS web demo, so I'm running on canned "
    "responses. On a real SWARM OS box I'd be answering from the live agent: "
    "routing tasks, watching your swarm and managing your VMs.";

http.Response _json(Object body, [int status = 200]) => http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json'},
    );

String _ago(int minutes) =>
    DateTime.now().toUtc().subtract(Duration(minutes: minutes)).toIso8601String();

// ── Notes (memory service :8399) ────────────────────────────────────────────
final List<Map<String, dynamic>> _notes = [
  _note('n1', 'Stone cipher design', 'Lock screen uses shuffling glyph stones; learn by glyph, not position.', ['security', 'ui'], true, 'security', 'yellow', 3000),
  _note('n2', 'Swarm routing', 'Top Swarm handles everyday coding + chat. Specialists: Kimi K2.6, Qwen 3.6 Plus, GLM 5.3 Flash.', ['agents'], true, 'architecture', 'blue', 1500),
  _note('n3', 'Build checklist', '1) bump VERSION  2) run build_swarm_iso.sh  3) boot-test in the VM  4) copy to Ventoy.', ['build'], false, 'ops', 'green', 800),
  _note('n4', 'Gaming agent', 'GamingAgent (Go, :8401) serves the Steam/GFN catalog and Lucille game evals.', ['gaming'], false, 'architecture', 'red', 400),
  _note('n5', 'Idea: voice HUD', 'Wake word "Hey Lucy" should duck media volume while listening.', ['ideas', 'voice'], false, 'ideas', 'white', 90),
];

Map<String, dynamic> _note(String id, String title, String content, List<String> tags,
        bool pinned, String category, String color, int minsAgo) =>
    {
      'id': id,
      'title': title,
      'content': content,
      'tags': tags,
      'labels': tags,
      'category': category,
      'pinned': pinned,
      'archived': false,
      'color': color,
      'source': 'local',
      'created_at': _ago(minsAgo),
      'updated_at': _ago(minsAgo),
    };

// ── Shared swarm memory mesh ────────────────────────────────────────────────
List<Map<String, dynamic>> _meshEntries() => [
      {'id': 'm1', 'device': 'workstation', 'ts': _ago(240), 'kind': 'decision', 'key': 'iso-retention', 'content': 'Keep the newest 5 SWARM builds on Ventoy; Recovery OS keeps its own 5.'},
      {'id': 'm2', 'device': 'claude', 'ts': _ago(180), 'kind': 'note', 'key': 'web-demo', 'content': 'Flutter shell builds for web with mocked backends for the public demo.'},
      {'id': 'm3', 'device': 'pixel-companion', 'ts': _ago(95), 'kind': 'status', 'key': 'hitl', 'content': 'Approval service connected to lucille-core :9091 over Tailscale.'},
      {'id': 'm4', 'device': 'workstation', 'ts': _ago(40), 'kind': 'decision', 'key': 'gaming-chat', 'content': 'Lucille chat provider is read from the constants in lucille_service.go.'},
      {'id': 'm5', 'device': 'lucille', 'ts': _ago(6), 'kind': 'note', 'key': 'swarm-health', 'content': '7 agent nodes online. All subsystems nominal.'},
    ];

// ── VMs ─────────────────────────────────────────────────────────────────────
final List<Map<String, dynamic>> _vms = [
  _vm('vm-arch', 'SWARM OS Test Bench', 'Arch live ISO boot-test (QEMU/OVMF)', 0, 2, 4, 8192, 40, 2201),
  _vm('vm-win', 'Windows 11 Gaming', 'GPU passthrough sandbox', 1, 0, 8, 16384, 120, 2202),
  _vm('vm-deb', 'Debian CI Runner', 'Headless build agent', 0, 3, 2, 4096, 20, 2203),
  _vm('vm-con', 'Postgres Container', 'Dev database', 3, 2, 1, 1024, 10, 2204),
];

Map<String, dynamic> _vm(String id, String name, String desc, int os, int status,
        int cpu, int ram, int disk, int ssh) =>
    {
      'id': id,
      'name': name,
      'description': desc,
      'osType': os,
      'status': status,
      'cpuCores': cpu,
      'ramMb': ram,
      'diskSizeGb': disk,
      'sshPort': ssh,
      'httpPort': 8080 + (ssh - 2200),
      'vncPort': 5900 + (ssh - 2200),
      'processId': status == 2 ? 4000 + ssh : null,
    };

Map<String, dynamic>? _vmById(String id) {
  for (final v in _vms) {
    if (v['id'] == id) return v;
  }
  return null;
}

const _templates = [
  {'id': 'tpl-arch', 'name': 'Arch Linux Dev', 'description': 'Minimal Arch with Go, Rust and Flutter toolchains.', 'tags': ['linux', 'dev']},
  {'id': 'tpl-ubuntu', 'name': 'Ubuntu 24.04 Server', 'description': 'Headless server image with Docker preinstalled.', 'tags': ['linux', 'server']},
  {'id': 'tpl-win', 'name': 'Windows 11 Sandbox', 'description': 'Throwaway Windows for testing installers.', 'tags': ['windows']},
  {'id': 'tpl-pg', 'name': 'Postgres 17', 'description': 'Container with a seeded demo database.', 'tags': ['container', 'db']},
];

// ── Handler ─────────────────────────────────────────────────────────────────
Map<String, dynamic> _body(http.Request req) {
  try {
    final d = jsonDecode(req.body);
    return d is Map<String, dynamic> ? d : {};
  } catch (_) {
    return {};
  }
}

Future<http.Response> _handle(http.Request req) async {
  final path = req.url.path;
  final m = req.method;

  if (path.endsWith('/health') || path == '/api/health') {
    return _json({'status': 'ok', 'mock': true});
  }
  if (path.contains('chat') || path == '/lucy' || path.contains('completions')) {
    return _json({
      'reply': _lucilleReply,
      'response': _lucilleReply,
      'text': _lucilleReply,
      'message': _lucilleReply,
      'content': _lucilleReply,
      'choices': [
        {'message': {'role': 'assistant', 'content': _lucilleReply}}
      ],
    });
  }

  // Notes / memory service
  if (path == '/notes') {
    if (m == 'POST') {
      final b = _body(req);
      final n = _note('n${_notes.length + 1}', (b['title'] ?? 'Untitled').toString(),
          (b['content'] ?? '').toString(),
          List<String>.from(b['tags'] ?? const []), b['pinned'] == true,
          (b['category'] ?? 'general').toString(), (b['color'] ?? 'white').toString(), 0);
      _notes.insert(0, n);
      return _json({'note': n});
    }
    final q = (req.url.queryParameters['search'] ?? '').toLowerCase();
    final list = q.isEmpty
        ? _notes
        : _notes.where((n) => jsonEncode(n).toLowerCase().contains(q)).toList();
    return _json({'notes': list});
  }
  if (path.startsWith('/notes/')) return _json({'ok': true});
  if (path == '/labels') return _json({'labels': ['security', 'ui', 'agents', 'build', 'gaming', 'ideas', 'voice']});
  if (path == '/stats') {
    return _json({'stats': {'backend': 'local', 'keep_connected': false, 'total_notes': _notes.length, 'active': _notes.length, 'archived': 0, 'pinned': _notes.where((n) => n['pinned'] == true).length}});
  }
  if (path == '/keep/status') return _json({'connected': false});

  // Shared swarm memory mesh
  if (path == '/api/memory/status') {
    return _json({'entries': _meshEntries().length, 'devices': ['workstation', 'claude', 'pixel-companion', 'lucille'], 'lease': {'holder': '', 'expires': ''}});
  }
  if (path == '/api/memory/entries' || path == '/api/memory/current') {
    return _json({'entries': _meshEntries()});
  }
  if (path.startsWith('/api/memory')) return _json({'ok': true, 'entry': _meshEntries().last});

  // VMs
  if (path == '/api/vms') return _json(_vms);
  final vmMatch = RegExp(r'^/api/vms/([^/]+)(?:/([^/]+))?').firstMatch(path);
  if (vmMatch != null) {
    final id = vmMatch.group(1)!;
    final action = vmMatch.group(2);
    final vm = _vmById(id);
    switch (action) {
      case 'start':
      case 'resume':
        vm?['status'] = 2;
        return _json({'ok': true});
      case 'stop':
        vm?['status'] = 0;
        return _json({'ok': true});
      case 'pause':
        vm?['status'] = 3;
        return _json({'ok': true});
      case 'telemetry':
        final t = DateTime.now().second;
        return _json({
          'cpuUsagePercent': 12.0 + (t % 25),
          'memoryUsedMb': ((vm?['ramMb'] ?? 4096) as int) ~/ 3,
          'memoryTotalMb': vm?['ramMb'] ?? 4096,
          'diskReadBytesPerSec': 1200000.0 + t * 9000,
          'diskWriteBytesPerSec': 640000.0 + t * 5000,
        });
      case 'snapshots':
        return _json([
          {'name': 'clean-install', 'description': 'Fresh OS', 'createdAt': _ago(4000)},
          {'name': 'before-update', 'description': 'Known good', 'createdAt': _ago(900)},
        ]);
      default:
        if (m == 'DELETE') _vms.removeWhere((v) => v['id'] == id);
        return _json({'ok': true});
    }
  }
  if (path == '/api/templates/environments') return _json(_templates);
  if (path.startsWith('/api/templates/environments/')) {
    final v = _vm('vm-${_vms.length + 1}', 'New Instance', 'Provisioned from template (demo)', 0, 2, 2, 4096, 20, 2210 + _vms.length);
    _vms.add(v);
    return _json(v);
  }
  if (path == '/api/sandbox/execute') {
    return _json({'exitCode': 0, 'executionTimeMs': 42, 'memoryPeakMb': 18, 'stdout': 'Hello from the SWARM sandbox (demo)\n', 'stderr': ''});
  }

  // Developer ecosystem
  if (path == '/api/extensions/local/list') {
    return _json([
      {'extensionId': 'swarm.theme-pack', 'sourcePath': '~/dev/swarm-theme-pack', 'manifest': {'displayName': 'SWARM Theme Pack', 'version': '1.2.0'}},
      {'extensionId': 'swarm.steam-overlay', 'sourcePath': '~/dev/steam-overlay', 'manifest': {'displayName': 'Steam Overlay Widget', 'version': '0.4.1'}},
    ]);
  }
  if (path == '/api/git/repos') {
    return _json([
      {'name': 'swarm-os', 'cloneUrl': 'git@swarm.local:swarm-os.git', 'lastCommitMessage': 'Update recovery repo names and autosync note'},
      {'name': 'lucille-core', 'cloneUrl': 'git@swarm.local:lucille-core.git', 'lastCommitMessage': 'Consensus gate fails closed without voters'},
      {'name': 'gaming-agent', 'cloneUrl': 'git@swarm.local:gaming-agent.git', 'lastCommitMessage': 'Route Lucille chat through OpenRouter'},
    ]);
  }
  if (path == '/api/artifacts') {
    return _json([
      {'name': 'swarm-os-live', 'version': '6.2.81', 'sha256': '9f2c4e1ab07d33c8e5…41d0', 'downloadCount': 128},
      {'name': 'lucille-companion', 'version': '6.2.21', 'sha256': 'c04b77d19e5aa2f0b1…77e3', 'downloadCount': 54},
    ]);
  }
  if (path == '/api/analytics/dashboard') {
    return _json({'totalInstalls': 14280, 'activeUsers': 3840, 'crashRate': 0.02, 'revenueUsd': 1250});
  }
  if (path.startsWith('/api/releases/')) return _json([]);
  if (path.startsWith('/api/ci/pipelines')) {
    return _json({'id': 'pipe-1', 'status': 'Succeeded', 'repoName': 'swarm-os', 'stages': ['build', 'test', 'package']});
  }

  // Misc
  if (path.endsWith('/api/companion/status')) {
    return _json({
      'companions': [
        {'device_id': 'demo-phone', 'device_name': 'Pixel (demo)'}
      ]
    });
  }
  if (path.endsWith('/api/tags')) {
    return _json({
      'models': [
        {'name': 'llama3.2:3b'},
        {'name': 'qwen2.5-coder:7b'},
      ]
    });
  }
  if (path.endsWith('/models')) return _json({'data': [], 'models': []});
  if (path.contains('/credits') || path.contains('/auth/key')) {
    return _json({
      'data': {'total_credits': 25.0, 'total_usage': 4.2, 'limit': 25.0, 'usage': 4.2}
    });
  }
  if (path.endsWith('/api/gfn/catalog')) return _json({'games': []});
  if (path.endsWith('/api/lucille/status')) return _json({'online': true, 'mock': true});
  if (path == '/api/google/auth/status') return _json({'authenticated': false});
  if (path == '/api/updates/check') return _json({'updateAvailable': false, 'version': '6.2.81'});

  // Everything else: succeed with an empty object so screens render empty
  // states instead of error banners.
  return _json({});
}

http.Client createMockClient() => MockClient(_handle);

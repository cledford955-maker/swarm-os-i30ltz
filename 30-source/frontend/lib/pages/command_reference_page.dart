// ═══════════════════════════════════════════════════════════════
// SWARM OS — Command Reference v1.0.0 (2026-09-16)
//
// The first-boot checklist (FIRST_BOOT_CHECKLIST.md / "SWARM OS Boot"
// artifact) as a page inside the OS: every command has a Copy button.
// Paste into foot (Super+Enter) — use foot, not the in-shell terminal,
// for anything that asks for a password.
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/swarm_colors.dart';

class _Cmd {
  final String label;
  final String code;
  const _Cmd(this.code, [this.label = '']);
}

class _Step {
  final String title;
  final String note;
  final List<_Cmd> cmds;
  final String tag;
  const _Step(this.title, this.note, this.cmds, [this.tag = '']);
}

const _steps = <_Step>[
  _Step('Set your sudo password', 'Do this first. Open foot with Super+Enter and run passwd. If it asks for a current password, use the one from the OS you installed from (CachyOS). Nothing appears while you type — that is normal.', [
    _Cmd('passwd'),
    _Cmd('sudo -v && echo "sudo works"', 'Check it'),
  ], 'first'),
  _Step('Fix system file ownership', 'SWARM OS only — never run this on CachyOS or another OS. Installs before 2026-09-16 copied system files owned by your user instead of root. This hands /etc, /usr and /opt/swarm_os back to root and leaves apps you installed yourself (Android Studio, Flutter) alone.', [
    _Cmd('test -d /opt/swarm_os && echo "OK: SWARM OS" || echo "STOP: this is not SWARM OS"', 'Check you are on SWARM OS'),
    _Cmd('sudo find /etc /usr /opt/swarm_os -xdev -uid 1000 -exec chown -h root:root {} +'),
    _Cmd('sudo chmod 440 /etc/sudoers.d/10-wheel', 'Then'),
  ], 'first'),
  _Step('Verify core services', 'All should show active (running).', [
    _Cmd('systemctl status swarm-ui gaming-agent lucy-server google-workspace'),
    _Cmd('journalctl -u gaming-agent -n 40\njournalctl -u lucy-server -n 40', 'If any failed'),
  ]),
  _Step('Confirm LUCILLE drive mounted', '', [
    _Cmd('ls /mnt/Lucy/SWARM_AI_FEATURES.md && echo "LUCILLE: OK"'),
    _Cmd('udisksctl mount -b /dev/disk/by-uuid/62f0e009-43c2-4760-8d6c-d7c445f5f3df', 'If missing'),
  ]),
  _Step('Install Tailscale', 'Not in packages.x86_64 — install once, then sign in in the browser that opens.', [
    _Cmd('curl -fsSL https://tailscale.com/install.sh | sh\nsudo systemctl enable --now tailscaled\nsudo tailscale up --accept-routes --ssh'),
  ], 'first'),
  _Step('Set lock screen password', 'LucyServer on port 5000, loopback only. Replace YOUR_STRONG_PASSWORD.', [
    _Cmd('curl -s -X POST http://127.0.0.1:5000/api/settings/login_password -H "Content-Type: application/json" -d \'{"password":"YOUR_STRONG_PASSWORD"}\''),
  ]),
  _Step('Set up TOTP 2FA on all 3 phones', 'Turn the uri field into a QR code and scan it with Aegis, Google Authenticator or Bitwarden.', [
    _Cmd('curl -s http://127.0.0.1:5000/api/settings/totp/setup | python3 -m json.tool', 'Get the QR uri'),
    _Cmd('curl -s -X POST http://127.0.0.1:5000/api/settings/totp/confirm -H "Content-Type: application/json" -d \'{"secret":"YOURSECRET","code":"123456"}\'', 'Confirm to activate'),
  ]),
  _Step('Install Claude Code', '', [
    _Cmd('npm install -g @anthropic-ai/claude-code'),
    _Cmd('claude --version', 'Verify'),
  ]),
  _Step('Verify firewall', 'Expect policy drop on input, lo and tailscale0 accepted, SSH tailscale-only.', [
    _Cmd('sudo nft list ruleset'),
  ]),
  _Step('Verify AppArmor', 'gaming-agent enforce, lucy-server complain (intentional).', [
    _Cmd('sudo aa-status | grep -E "gaming-agent|lucy-server"'),
    _Cmd('sudo aa-logprof', 'After real use, tighten LucyServer'),
  ]),
  _Step('Test GamingAgent (Nemotron)', 'Port 8401. The eval call spends a Nemotron credit.', [
    _Cmd('curl -s http://127.0.0.1:8401/api/gfn/catalog | python3 -c "import sys,json; print(len(json.load(sys.stdin)), \'GFN games\')"', 'Warm the GFN catalog'),
    _Cmd('curl -s http://127.0.0.1:8401/api/lucille/eval -H "X-Swarm-Auth: \$SWARM_AUTH_TOKEN" | python3 -m json.tool | head -20', 'Lucille eval'),
  ]),
  _Step('Test LucyServer chat', '', [
    _Cmd('curl -s -X POST http://127.0.0.1:5000/lucy -H "Content-Type: application/json" -d \'{"messages":[{"role":"user","content":"Hello Lucille"}],"modelId":"groq"}\' | head -5'),
  ]),
  _Step('Lucille Core engine (C++ pipeline)', 'Port 5000 proxies to the Unix socket at /run/lucille/ipc.sock. Needs lucille-core.service running.', [
    _Cmd('curl -s http://127.0.0.1:5000/api/lucille/status -H "X-Swarm-Auth: \$SWARM_AUTH_TOKEN" | python3 -m json.tool', 'Engine status'),
    _Cmd('curl -s -X POST http://127.0.0.1:5000/api/lucille/pipeline -H "X-Swarm-Auth: \$SWARM_AUTH_TOKEN" -H "Content-Type: application/json" -d \'{"task_id":"test-1","instruction":"Add error handling","target_file":"main.cpp","content":"int main(){}","language":"cpp"}\' | python3 -m json.tool', 'Run pipeline'),
    _Cmd('curl -s -X POST http://127.0.0.1:5000/api/lucille/route -H "X-Swarm-Auth: \$SWARM_AUTH_TOKEN" -H "Content-Type: application/json" -d \'{"task_id":"test-1","instruction":"Fix memory leak"}\' | python3 -m json.tool', 'Route task'),
  ]),
  _Step('Install Ollama', 'Needed for /api/rag/* endpoints.', [
    _Cmd('curl -fsSL https://ollama.ai/install.sh | sh\nsudo systemctl enable --now ollama\nollama pull nomic-embed-text'),
  ], 'optional'),
  _Step('Verify GPU / Vulkan', 'Intel or AMD should appear. If missing: sudo pacman -S vulkan-tools', [
    _Cmd('vulkaninfo --summary 2>/dev/null | grep -E "GPU|deviceName"'),
  ]),
  _Step('Change the SWARM auth token', 'If you change it, update SwarmConnection.kt in the companion app too.', [
    _Cmd('echo "SWARM_AUTH_TOKEN=\$(openssl rand -hex 32)" | sudo tee -a /etc/swarm_os.env\nsudo systemctl restart lucy-server gaming-agent'),
  ], 'optional'),
  _Step('Enable auto-snapshots', 'Snapshots @ at every boot, keeps 5. Roll back from the GRUB Snapshot entries.', [
    _Cmd('systemctl is-enabled swarm-snapshot.service'),
    _Cmd('sudo systemctl enable swarm-snapshot.service', 'If disabled'),
  ]),
  _Step('Verify git sync', 'auto_sync_github.sh commits /mnt/Lucy every 10 minutes.', [
    _Cmd('cd /mnt/Lucy && git log --oneline -3'),
    _Cmd('cd /mnt/Lucy && git pull origin main', 'On another machine'),
  ]),
  _Step('Quick health check', 'Run any time.', [
    _Cmd('curl -s http://127.0.0.1:5000/health && curl -s http://127.0.0.1:8401/health && echo "Both servers OK"'),
  ]),
];

class CommandReferencePage extends StatelessWidget {
  const CommandReferencePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xE6080B12),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 60),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('COMMAND REFERENCE',
                    style: TextStyle(color: SwarmColors.accent, fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: 3)),
                const SizedBox(height: 6),
                Text('First-boot setup and checks. Copy a command, open foot with Super+Enter, paste with Ctrl+Shift+V.',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.65), fontSize: 14)),
                const SizedBox(height: 18),
                for (var i = 0; i < _steps.length; i++) _StepCard(number: i + 1, step: _steps[i]),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  final int number;
  final _Step step;
  const _StepCard({required this.number, required this.step});

  @override
  Widget build(BuildContext context) {
    final tagColor = step.tag == 'first' ? SwarmColors.accent : const Color(0xFFF59E0B);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1117).withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF1E3A5F)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(number.toString().padLeft(2, '0'),
              style: const TextStyle(color: SwarmColors.accent, fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(step.title.toUpperCase(),
                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 1)),
          ),
          if (step.tag.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: tagColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: tagColor.withValues(alpha: 0.4)),
              ),
              child: Text(step.tag == 'first' ? 'FIRST BOOT' : 'OPTIONAL',
                  style: TextStyle(color: tagColor, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1)),
            ),
        ]),
        if (step.note.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(step.note, style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13, height: 1.45)),
        ],
        for (final c in step.cmds) _CommandBlock(cmd: c),
      ]),
    );
  }
}

class _CommandBlock extends StatelessWidget {
  final _Cmd cmd;
  const _CommandBlock({required this.cmd});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (cmd.label.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(cmd.label.toUpperCase(),
                style: TextStyle(color: Colors.white.withValues(alpha: 0.45), fontSize: 10, letterSpacing: 1.2, fontWeight: FontWeight.w600)),
          ),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF050810),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: const Color(0xFF1A2840)),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: SelectableText(cmd.code,
                    style: const TextStyle(color: Color(0xFF8EC4FF), fontFamily: 'monospace', fontSize: 13, height: 1.5)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(6),
              child: TextButton.icon(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: cmd.code));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Copied — paste into foot with Ctrl+Shift+V'),
                      duration: Duration(seconds: 2),
                    ));
                  }
                },
                icon: const Icon(Icons.copy, size: 14),
                label: const Text('Copy'),
                style: TextButton.styleFrom(foregroundColor: SwarmColors.accent),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

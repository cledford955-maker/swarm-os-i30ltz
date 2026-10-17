// ═══════════════════════════════════════════════════════════════
// Swarm OS — Home Screen v3
// Hex grid + windows + terminal + OpenRouter balance on top bar
// AiTelemetryBar REMOVED — balance lives in top_bar globally
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'hex_grid.dart';
import 'window_manager.dart';
import 'swarm_terminal.dart';
import 'agent_memory_panel.dart';
import 'gmail_panel.dart';
import 'companion_telemetry.dart';

class SwarmHomeScreen extends StatefulWidget {
  const SwarmHomeScreen({super.key});

  @override
  State<SwarmHomeScreen> createState() => _SwarmHomeScreenState();
}

class _SwarmHomeScreenState extends State<SwarmHomeScreen> {
  final GlobalKey<WindowManagerState> _wmKey = GlobalKey();
  late final List<HexAgent> _agents;

  @override
  void initState() {
    super.initState();
    _agents = [
      HexAgent(id: 'gmail', name: 'Gmail', icon: Icons.mail,
        color: const Color(0xFFEA4335), bgColor: const Color(0xFF1A0E0D)),
      HexAgent(id: 'notes', name: 'Notes', icon: Icons.sticky_note_2,
        color: const Color(0xFFFBBC04), bgColor: const Color(0xFF1A1708)),
      HexAgent(id: 'calendar', name: 'Calendar', icon: Icons.calendar_today,
        color: const Color(0xFF4285F4), bgColor: const Color(0xFF0D1220)),
      HexAgent(id: 'terminal', name: 'Terminal', icon: Icons.terminal,
        color: const Color(0xFF00D4FF), bgColor: const Color(0xFF0A1520)),
      HexAgent(id: 'companion', name: 'Companion', icon: Icons.device_hub,
        color: const Color(0xFF26A69A), bgColor: const Color(0xFF0D1A18)),
      HexAgent(id: 'tasks', name: 'Tasks', icon: Icons.check_circle_outline,
        color: const Color(0xFF34A853), bgColor: const Color(0xFF0D1A10)),
      HexAgent(id: 'drive', name: 'Drive', icon: Icons.folder,
        color: const Color(0xFF4285F4), bgColor: const Color(0xFF0D1220)),
      HexAgent(id: 'contacts', name: 'Contacts', icon: Icons.contacts,
        color: const Color(0xFF673AB7), bgColor: const Color(0xFF150D20)),
      HexAgent(id: 'keep', name: 'Keep', icon: Icons.lightbulb,
        color: const Color(0xFFFBBC04), bgColor: const Color(0xFF1A1708)),
      HexAgent(id: 'settings', name: 'Settings', icon: Icons.settings,
        color: const Color(0xFF90A4AE), bgColor: const Color(0xFF14161A)),
      HexAgent(id: 'files', name: 'Files', icon: Icons.snippet_folder,
        color: const Color(0xFF8D6E63), bgColor: const Color(0xFF1A1510)),
      HexAgent(id: 'network', name: 'Network', icon: Icons.lan,
        color: const Color(0xFF26A69A), bgColor: const Color(0xFF0D1A18)),
      HexAgent(id: 'monitor', name: 'Monitor', icon: Icons.monitor_heart,
        color: const Color(0xFFEF5350), bgColor: const Color(0xFF1A0D0D)),
      HexAgent(id: 'ai_chat', name: 'AI Chat', icon: Icons.smart_toy,
        color: const Color(0xFFAB47BC), bgColor: const Color(0xFF180D1A)),
      HexAgent(id: 'music', name: 'Music', icon: Icons.music_note,
        color: const Color(0xFFFF7043), bgColor: const Color(0xFF1A120D)),
    ];
  }

  void _openAgent(HexAgent agent) {
    _wmKey.currentState?.openWindow(
      id: agent.id, title: agent.name, icon: agent.icon,
      accentColor: agent.color,
      builder: (ctx) => _buildAgentContent(agent.id),
      size: _windowSizeFor(agent.id),
    );
  }

  Size _windowSizeFor(String id) {
    switch (id) {
      case 'terminal': return const Size(620, 420);
      case 'gmail': return const Size(560, 480);
      case 'notes': case 'keep': return const Size(420, 500);
      case 'companion': case 'monitor': return const Size(580, 540);
      case 'calendar': return const Size(500, 440);
      default: return const Size(480, 380);
    }
  }

  Widget _buildAgentContent(String id) {
    switch (id) {
      case 'gmail': return const GmailPanel();
      case 'notes': case 'keep': return const AgentMemoryPanel();
      case 'terminal': return const SwarmTerminal(initialPanes: 1);
      case 'companion': case 'monitor': return const CompanionTelemetryPanel();
      default: return _placeholderAgent(id);
    }
  }

  Widget _placeholderAgent(String id) {
    final agent = _agents.where((a) => a.id == id).firstOrNull;
    return Container(
      color: const Color(0xFF0A0A18),
      child: Column(children: [
        Expanded(child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(agent?.icon ?? Icons.apps, color: (agent?.color ?? Colors.white54).withValues(alpha: 0.2), size: 48),
          const SizedBox(height: 12),
          Text(agent?.name ?? id, style: TextStyle(color: (agent?.color ?? Colors.white54).withValues(alpha: 0.4), fontSize: 16)),
        ]))),
        const SizedBox(height: 160, child: SwarmTerminal(initialPanes: 1)),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080816),
      body: WindowManager(
        key: _wmKey,
        background: _buildBackground(),
      ),
    );
  }

  Widget _buildBackground() {
    return Column(children: [
      _buildStatusBar(),
      Expanded(flex: 3, child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 12, top: 8),
            child: Row(children: [
              const Text('⚡', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Swarm OS', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: 1)),
                Text('Drag hexagons · Tap to open', style: TextStyle(color: Colors.white.withValues(alpha: 0.2), fontSize: 10)),
              ]),
              const Spacer(),
              _utilButton('Companion', Icons.device_hub, const Color(0xFF26A69A), () {
                _openAgent(HexAgent(id: 'companion', name: 'Companion', icon: Icons.device_hub,
                  color: const Color(0xFF26A69A), bgColor: const Color(0xFF0D1A18)));
              }),
              const SizedBox(width: 6),
              _utilButton('Terminal', Icons.terminal, const Color(0xFF00D4FF), () {
                _openAgent(HexAgent(id: 'terminal', name: 'Terminal', icon: Icons.terminal,
                  color: const Color(0xFF00D4FF), bgColor: const Color(0xFF0A1520)));
              }),
            ]),
          ),
          Expanded(child: Center(child: HexGrid(
            agents: _agents, columns: 5, rows: 3, hexSize: 52, onAgentOpen: _openAgent,
          ))),
        ]),
      )),
      SizedBox(height: 220, child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: const SwarmTerminal(initialPanes: 1),
      )),
    ]);
  }

  Widget _utilButton(String label, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }

  Widget _buildStatusBar() {
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: Color(0xFF0A0A1E),
        border: Border(bottom: BorderSide(color: Color(0xFF1A1A3A))),
      ),
      child: Row(children: [
        Text('SWARM OS', style: TextStyle(color: const Color(0xFF00D4FF).withValues(alpha: 0.6),
          fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 2)),
        const Spacer(),
        StreamBuilder(
          stream: Stream.periodic(const Duration(seconds: 1)),
          builder: (_, __) {
            final n = DateTime.now();
            return Text('${n.hour.toString().padLeft(2, '0')}:${n.minute.toString().padLeft(2, '0')}:${n.second.toString().padLeft(2, '0')}',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 10, fontFamily: 'monospace'));
          },
        ),
      ]),
    );
  }
}
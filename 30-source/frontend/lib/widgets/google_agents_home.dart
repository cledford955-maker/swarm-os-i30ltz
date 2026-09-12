// Swarm OS — Google Agents Home Screen
// Unified dashboard showing all Google services as agent panels.

import 'package:flutter/material.dart';
import '../services/google_hub_service.dart';
import 'agent_memory_panel.dart';
import 'gmail_panel.dart';

class GoogleAgentsHome extends StatefulWidget {
  const GoogleAgentsHome({super.key});

  @override
  State<GoogleAgentsHome> createState() => _GoogleAgentsHomeState();
}

class _GoogleAgentsHomeState extends State<GoogleAgentsHome> {
  final GoogleHubService _hub = GoogleHubService();
  Map<String, dynamic>? _dashboard;
  bool _loading = true;
  int _selectedTab = 0;

  final List<_AgentTab> _tabs = [
    const _AgentTab('Mail', Icons.mail, Color(0xFFEA4335)),
    const _AgentTab('Notes', Icons.sticky_note_2, Color(0xFFFBBC04)),
    const _AgentTab('Calendar', Icons.calendar_today, Color(0xFF4285F4)),
    const _AgentTab('Tasks', Icons.check_circle_outline, Color(0xFF34A853)),
    const _AgentTab('Drive', Icons.folder, Color(0xFF4285F4)),
    const _AgentTab('Contacts', Icons.contacts, Color(0xFF673AB7)),
  ];

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    try {
      final data = await _hub.getDashboard();
      if (mounted) setState(() { _dashboard = data; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0A0A16),
      child: Column(
        children: [
          _buildTabBar(),
          Expanded(child: _buildActivePanel()),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: const BoxDecoration(
        color: Color(0xFF0D0D1A),
        border: Border(bottom: BorderSide(color: Color(0xFF2A2A4A), width: 1)),
      ),
      child: Row(
        children: List.generate(_tabs.length, (i) {
          final tab = _tabs[i];
          final active = _selectedTab == i;
          return GestureDetector(
            onTap: () => setState(() => _selectedTab = i),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 8),
              decoration: BoxDecoration(
                color: active ? tab.color.withValues(alpha: 0.15) : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(tab.icon, color: active ? tab.color : Colors.white24, size: 16),
                  if (active) ...[
                    const SizedBox(width: 6),
                    Text(
                      tab.label,
                      style: TextStyle(
                        color: tab.color,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildActivePanel() {
    switch (_selectedTab) {
      case 0:
        return GmailPanel(service: _hub);
      case 1:
        return const AgentMemoryPanel();
      case 2:
        return _buildCalendarPanel();
      case 3:
        return _buildTasksPanel();
      case 4:
        return _buildDrivePanel();
      case 5:
        return _buildContactsPanel();
      default:
        return const SizedBox.shrink();
    }
  }

  // Quick panels for Calendar, Tasks, Drive, Contacts
  // (These can be expanded into full widgets like Gmail/Notes)

  Widget _buildCalendarPanel() {
    return _QuickAgentPanel(
      icon: Icons.calendar_today,
      color: const Color(0xFF4285F4),
      title: 'Calendar',
      hub: _hub,
      loader: () async {
        final events = await _hub.getUpcomingEvents(maxResults: 10, daysAhead: 7);
        return events.map((e) => {
          'title': e['summary'] ?? '(No title)',
          'subtitle': '${e['start'] ?? ''} · ${e['location'] ?? ''}',
          'icon': e['all_day'] == true ? Icons.wb_sunny : Icons.access_time,
        }).toList();
      },
    );
  }

  Widget _buildTasksPanel() {
    return _QuickAgentPanel(
      icon: Icons.check_circle_outline,
      color: const Color(0xFF34A853),
      title: 'Tasks',
      hub: _hub,
      loader: () async {
        final tasks = await _hub.getTasks();
        return tasks.map((t) => {
          'title': t['title'] ?? '(No title)',
          'subtitle': t['notes'] ?? '',
          'icon': t['completed'] == true ? Icons.check_circle : Icons.radio_button_unchecked,
        }).toList();
      },
    );
  }

  Widget _buildDrivePanel() {
    return _QuickAgentPanel(
      icon: Icons.folder,
      color: const Color(0xFF4285F4),
      title: 'Drive',
      hub: _hub,
      loader: () async {
        final files = await _hub.listDriveFiles(maxResults: 15);
        return files.map((f) => {
          'title': f['name'] ?? '',
          'subtitle': f['mime_type'] ?? '',
          'icon': f['is_folder'] == true ? Icons.folder : Icons.insert_drive_file,
        }).toList();
      },
    );
  }

  Widget _buildContactsPanel() {
    return _QuickAgentPanel(
      icon: Icons.contacts,
      color: const Color(0xFF673AB7),
      title: 'Contacts',
      hub: _hub,
      loader: () async {
        final contacts = await _hub.getContacts(maxResults: 20);
        return contacts.map((c) => {
          'title': c['display_name'] ?? '${c['first_name']} ${c['last_name']}',
          'subtitle': (c['emails'] as List?)?.join(', ') ?? '',
          'icon': Icons.person,
        }).toList();
      },
    );
  }
}

class _AgentTab {
  final String label;
  final IconData icon;
  final Color color;
  const _AgentTab(this.label, this.icon, this.color);
}

/// Generic quick-view panel for any Google agent
class _QuickAgentPanel extends StatefulWidget {
  final IconData icon;
  final Color color;
  final String title;
  final GoogleHubService hub;
  final Future<List<Map<String, dynamic>>> Function() loader;

  const _QuickAgentPanel({
    required this.icon,
    required this.color,
    required this.title,
    required this.hub,
    required this.loader,
  });

  @override
  State<_QuickAgentPanel> createState() => _QuickAgentPanelState();
}

class _QuickAgentPanelState extends State<_QuickAgentPanel> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  bool _authenticated = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final auth = await widget.hub.isAuthenticated;
    if (!auth) {
      setState(() { _authenticated = false; _loading = false; });
      return;
    }
    setState(() => _authenticated = true);
    try {
      final items = await widget.loader();
      if (mounted) setState(() { _items = items; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_authenticated) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(widget.icon, color: Colors.white.withValues(alpha: 0.1), size: 48),
            const SizedBox(height: 12),
            Text('Sign in with Google to access ${widget.title}',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.2), fontSize: 12)),
          ],
        ),
      );
    }

    if (_loading) {
      return Center(child: CircularProgressIndicator(color: widget.color, strokeWidth: 2));
    }

    if (_error != null) {
      return Center(child: Text(_error!, style: TextStyle(color: Colors.redAccent.withValues(alpha: 0.5), fontSize: 12)));
    }

    if (_items.isEmpty) {
      return Center(
        child: Text('No ${widget.title.toLowerCase()} items',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.2), fontSize: 13)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _items.length,
      itemBuilder: (ctx, i) {
        final item = _items[i];
        return Container(
          margin: const EdgeInsets.only(bottom: 4),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF141425),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(item['icon'] as IconData? ?? widget.icon,
                  color: widget.color.withValues(alpha: 0.6), size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['title'] ?? '',
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if ((item['subtitle'] ?? '').toString().isNotEmpty)
                      Text(
                        item['subtitle'],
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 10),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
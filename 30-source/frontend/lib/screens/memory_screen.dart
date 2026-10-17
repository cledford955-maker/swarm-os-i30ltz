import 'package:flutter/material.dart';

import '../services/swarm_memory_service.dart';
import '../theme/swarm_colors.dart';
import '../theme/swarm_text_styles.dart';

/// SWARM OS — Shared Memory (live)
///
/// Renders the cross-device memory mesh served by LucyServer at /api/memory.
/// Entries come from this device, other OSes, companions, Claude Code sync
/// and ChatGPT import snapshots. Search filters client-side; the FAB writes
/// a new entry (lease-gated by the server).
class MemoryScreen extends StatefulWidget {
  const MemoryScreen({super.key});

  @override
  State<MemoryScreen> createState() => _MemoryScreenState();
}

class _MemoryScreenState extends State<MemoryScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  List<SwarmMemoryEntry> _entries = [];
  Map<String, dynamic>? _status;
  bool _loading = true;
  bool _writing = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    final results = await Future.wait([
      SwarmMemoryService.instance.entries(limit: 100),
      SwarmMemoryService.instance.status(),
    ]);
    if (!mounted) return;
    setState(() {
      _entries = results[0] as List<SwarmMemoryEntry>;
      _status = results[1] as Map<String, dynamic>?;
      _loading = false;
    });
  }

  Future<void> _writeEntry(String key, String content) async {
    setState(() => _writing = true);
    // Acquire the write lease first so the mesh serializes edits cleanly.
    final ok = await SwarmMemoryService.instance.acquireLease();
    final entry = ok
        ? await SwarmMemoryService.instance.write(
            kind: 'note', key: key, content: content)
        : null;
    if (!mounted) return;
    setState(() => _writing = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor:
          entry != null ? SwarmColors.statusOnline : SwarmColors.statusCritical,
      content: Text(
        entry != null
            ? '✅ Shared with all devices via memory mesh'
            : '⚠️ Could not write — server unreachable or lease held',
        style: const TextStyle(color: Colors.white, fontSize: 12),
      ),
      duration: const Duration(seconds: 3),
    ));
    if (entry != null) _refresh();
  }

  Future<void> _showWriteDialog() async {
    final keyCtrl = TextEditingController();
    final contentCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: SwarmColors.bgElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: SwarmColors.border),
        ),
        title: Text('Add Shared Memory',
            style:
                SwarmTextStyles.h3.copyWith(color: SwarmColors.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: keyCtrl,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Title / key',
                hintStyle:
                    TextStyle(color: SwarmColors.textMuted, fontSize: 13),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: contentCtrl,
              maxLines: 5,
              decoration: const InputDecoration(
                hintText:
                    'Memory content — visible to every device, Lucille, Claude & ChatGPT imports',
                hintStyle:
                    TextStyle(color: SwarmColors.textMuted, fontSize: 13),
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(color: SwarmColors.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child:
                const Text('Share', style: TextStyle(color: SwarmColors.accent)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final key = keyCtrl.text.trim();
    final content = contentCtrl.text.trim();
    if (key.isEmpty || content.isEmpty) return;
    await _writeEntry(key, content);
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _entries.where((e) {
      if (_query.isEmpty) return true;
      final q = _query.toLowerCase();
      return e.key.toLowerCase().contains(q) ||
          e.content.toLowerCase().contains(q) ||
          e.kind.toLowerCase().contains(q) ||
          e.device.toLowerCase().contains(q);
    }).toList();

    final deviceCount = _entries.map((e) => e.device).toSet().length;

    return Scaffold(
      backgroundColor: SwarmColors.bgBase,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: SwarmColors.accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: SwarmColors.accent.withValues(alpha: 0.3)),
                  ),
                  child: const Icon(Icons.psychology_alt_rounded,
                      color: SwarmColors.accent, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('SHARED MEMORY MESH',
                          style: SwarmTextStyles.headlineMedium.copyWith(
                              color: SwarmColors.textPrimary,
                              letterSpacing: 1.5,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(
                        _status != null
                            ? '${_status!['entries'] ?? _entries.length} entries · $deviceCount device(s) · Claude, ChatGPT, Lucille & companions'
                            : 'LucyServer unreachable — showing cached state',
                        style: SwarmTextStyles.bodyMedium
                            .copyWith(color: SwarmColors.textMuted),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: _refresh,
                  tooltip: 'Refresh mesh',
                  icon: _loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: SwarmColors.accent))
                      : const Icon(Icons.refresh_rounded,
                          color: SwarmColors.textMuted),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Search
            Container(
              decoration: BoxDecoration(
                color: SwarmColors.bgElevated,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: SwarmColors.borderSubtle),
              ),
              child: TextField(
                controller: _searchCtrl,
                style: const TextStyle(color: SwarmColors.textPrimary),
                decoration: const InputDecoration(
                  hintText: 'Search shared memory — keys, content, devices...',
                  hintStyle:
                      TextStyle(color: SwarmColors.textMuted, fontSize: 13),
                  prefixIcon: Icon(Icons.search_rounded,
                      color: SwarmColors.textMuted),
                  border: InputBorder.none,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            const SizedBox(height: 16),

            // Entries
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: SwarmColors.accent))
                  : filtered.isEmpty
                      ? Center(
                          child: Text(
                            _entries.isEmpty
                                ? 'No shared memory yet — LucyServer unreachable or mesh is empty'
                                : 'No entries match "$_query"',
                            style: SwarmTextStyles.bodyMedium
                                .copyWith(color: SwarmColors.textMuted),
                          ),
                        )
                      : ListView.builder(
                          itemCount: filtered.length,
                          itemBuilder: (_, i) {
                            final e = filtered[i];
                            return _EntryCard(entry: e);
                          },
                        ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _writing ? null : _showWriteDialog,
        backgroundColor: SwarmColors.accent,
        icon: _writing
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.black))
            : const Icon(Icons.add, color: Colors.black),
        label: Text(_writing ? 'Sharing…' : 'Share Memory',
            style: const TextStyle(color: Colors.black)),
      ),
    );
  }
}

class _EntryCard extends StatelessWidget {
  final SwarmMemoryEntry entry;
  const _EntryCard({required this.entry});

  IconData get _kindIcon {
    switch (entry.kind) {
      case 'claude_memory':
        return Icons.auto_awesome;
      case 'chatgpt_memory':
      case 'chatgpt_conversation':
        return Icons.forum;
      case 'decision':
        return Icons.gavel;
      case 'doc':
        return Icons.description;
      default:
        return Icons.note_alt;
    }
  }

  Color get _kindColor {
    switch (entry.kind) {
      case 'claude_memory':
        return const Color(0xFFD97706);
      case 'chatgpt_memory':
      case 'chatgpt_conversation':
        return const Color(0xFF10A37F);
      case 'decision':
        return SwarmColors.agentPurple;
      case 'doc':
        return SwarmColors.agentSky;
      default:
        return SwarmColors.accent;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: SwarmColors.bgElevated,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: _kindColor.withValues(alpha: 0.25)),
      ),
      child: ExpansionTile(
        iconColor: SwarmColors.textMuted,
        collapsedIconColor: SwarmColors.textMuted,
        leading: Icon(_kindIcon, color: _kindColor, size: 22),
        title: Text(entry.key,
            overflow: TextOverflow.ellipsis,
            style: SwarmTextStyles.bodyMedium
                .copyWith(color: SwarmColors.textPrimary)),
        subtitle: Text(
          '${entry.kind} · ${entry.device} · ${entry.ts.substring(0, 10)}',
          style: SwarmTextStyles.bodySmall
              .copyWith(color: SwarmColors.textMuted, fontSize: 11),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: Align(
              alignment: Alignment.centerLeft,
              child: SelectableText(
                entry.content,
                style: SwarmTextStyles.bodySmall
                    .copyWith(color: SwarmColors.textSecondary, height: 1.5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
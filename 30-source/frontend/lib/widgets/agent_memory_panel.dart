// Swarm OS — Agent Memory Panel Widget
// Home screen widget connected to Google Keep.
// Write, view, search, pin, color, and erase notes — synced to Keep.

import 'package:flutter/material.dart';
import '../services/memory_service.dart';

class AgentMemoryPanel extends StatefulWidget {
  final MemoryService? memoryService;

  const AgentMemoryPanel({super.key, this.memoryService});

  @override
  State<AgentMemoryPanel> createState() => _AgentMemoryPanelState();
}

class _AgentMemoryPanelState extends State<AgentMemoryPanel> {
  late final MemoryService _memory;
  final TextEditingController _writeController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _writeFocus = FocusNode();

  List<MemoryNote> _notes = [];
  bool _loading = true;
  bool _composing = false;
  bool _keepConnected = false;
  String? _editingId;
  String _selectedColor = 'white';

  // Keep colors matching Google Keep's palette
  static const Map<String, Color> keepColors = {
    'white': Color(0xFF1A1A2E),
    'red': Color(0xFF5C2B29),
    'orange': Color(0xFF614A19),
    'yellow': Color(0xFF635D19),
    'green': Color(0xFF345920),
    'teal': Color(0xFF16504B),
    'blue': Color(0xFF2D555E),
    'purple': Color(0xFF42275E),
    'pink': Color(0xFF5B2245),
    'brown': Color(0xFF442F19),
    'gray': Color(0xFF3C3F43),
  };

  @override
  void initState() {
    super.initState();
    _memory = widget.memoryService ?? MemoryService();
    _checkKeepStatus();
    _loadNotes();
  }

  @override
  void dispose() {
    _writeController.dispose();
    _titleController.dispose();
    _searchController.dispose();
    _writeFocus.dispose();
    super.dispose();
  }

  Future<void> _checkKeepStatus() async {
    final connected = await _memory.isKeepConnected();
    if (mounted) {
      setState(() => _keepConnected = connected);
    }
  }

  Future<void> _loadNotes({String? search}) async {
    setState(() => _loading = true);
    try {
      final notes = await _memory.readNotes(search: search);
      if (mounted) {
        setState(() {
          _notes = notes;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveNote() async {
    final content = _writeController.text.trim();
    if (content.isEmpty) return;

    final title = _titleController.text.trim().isNotEmpty
        ? _titleController.text.trim()
        : null;

    if (_editingId != null) {
      await _memory.updateNote(
        _editingId!,
        content: content,
        title: title,
        color: _selectedColor != 'white' ? _selectedColor : null,
      );
    } else {
      await _memory.writeNote(
        content: content,
        title: title,
        color: _selectedColor != 'white' ? _selectedColor : null,
      );
    }

    _writeController.clear();
    _titleController.clear();
    setState(() {
      _composing = false;
      _editingId = null;
      _selectedColor = 'white';
    });
    await _loadNotes();
  }

  Future<void> _togglePin(MemoryNote note) async {
    await _memory.updateNote(note.id, pinned: !note.pinned);
    await _loadNotes();
  }

  Future<void> _eraseNote(MemoryNote note) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('Erase Note', style: TextStyle(color: Colors.white)),
        content: Text(
          'Delete "${note.title}"${note.isFromKeep ? " from Google Keep" : ""}?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Erase', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _memory.eraseNote(note.id, hard: true);
      await _loadNotes();
    }
  }

  Future<void> _eraseAllNotes() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('Erase All Notes', style: TextStyle(color: Colors.white)),
        content: Text(
          _keepConnected
              ? 'This will trash ALL notes in Google Keep. Continue?'
              : 'This will permanently delete ALL local notes. Continue?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Erase All', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _memory.eraseAllNotes(hard: true);
      await _loadNotes();
    }
  }

  void _startEdit(MemoryNote note) {
    setState(() {
      _composing = true;
      _editingId = note.id;
      _titleController.text = note.title;
      _writeController.text = note.content;
      _selectedColor = note.color;
    });
    _writeFocus.requestFocus();
  }

  void _showKeepConnect() {
    final emailController = TextEditingController();
    final tokenController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Row(
          children: [
            Icon(Icons.cloud, color: Color(0xFFFBBC04), size: 22),
            SizedBox(width: 8),
            Text('Connect Google Keep', style: TextStyle(color: Colors.white, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Enter your Google account email and app password / master token to sync notes with Google Keep.',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: emailController,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'your.email@gmail.com',
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.2)),
                filled: true,
                fillColor: const Color(0xFF0D0D1A),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: tokenController,
              obscureText: true,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'App password or master token',
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.2)),
                filled: true,
                fillColor: const Color(0xFF0D0D1A),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF0D0D1A),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                '💡 Generate an App Password at:\nmyaccount.google.com/apppasswords\n\nOr use gkeepapi master token.',
                style: TextStyle(color: Colors.white38, fontSize: 10),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () async {
              final email = emailController.text.trim();
              final token = tokenController.text.trim();
              if (email.isNotEmpty && token.isNotEmpty) {
                Navigator.pop(ctx);
                final ok = await _memory.connectKeep(email, token);
                if (ok) {
                  setState(() => _keepConnected = true);
                  await _loadNotes();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('✅ Connected to Google Keep'),
                        backgroundColor: Color(0xFF1A5C2B),
                      ),
                    );
                  }
                } else {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('❌ Failed to connect. Check credentials.'),
                        backgroundColor: Color(0xFF5C1A1A),
                      ),
                    );
                  }
                }
              }
            },
            child: const Text('Connect', style: TextStyle(color: Color(0xFF00D4FF))),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2A2A4A), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(),
          _buildSearchBar(),
          if (_composing) _buildComposeArea(),
          Expanded(child: _buildNotesList()),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color(0xFF2A2A4A), width: 1),
        ),
      ),
      child: Row(
        children: [
          // Keep status icon
          GestureDetector(
            onTap: _showKeepConnect,
            child: Icon(
              _keepConnected ? Icons.cloud_done : Icons.cloud_off,
              color: _keepConnected
                  ? const Color(0xFFFBBC04) // Google Keep yellow
                  : Colors.white24,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Agent Memory',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  _keepConnected ? 'Synced with Google Keep' : 'Local storage · Tap cloud to connect Keep',
                  style: TextStyle(
                    color: _keepConnected
                        ? const Color(0xFFFBBC04).withValues(alpha: 0.7)
                        : Colors.white24,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          // Note count
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFF00D4FF).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '${_notes.length}',
              style: const TextStyle(
                color: Color(0xFF00D4FF),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // New note button
          _iconButton(
            icon: _composing ? Icons.close : Icons.add,
            tooltip: _composing ? 'Cancel' : 'New Note',
            onTap: () {
              setState(() {
                _composing = !_composing;
                if (!_composing) {
                  _writeController.clear();
                  _titleController.clear();
                  _editingId = null;
                  _selectedColor = 'white';
                }
              });
              if (_composing) _writeFocus.requestFocus();
            },
          ),
          if (_notes.isNotEmpty)
            _iconButton(
              icon: Icons.delete_sweep,
              tooltip: 'Erase All',
              onTap: _eraseAllNotes,
              color: Colors.redAccent.withValues(alpha: 0.7),
            ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: TextField(
        controller: _searchController,
        style: const TextStyle(color: Colors.white, fontSize: 13),
        decoration: InputDecoration(
          hintText: _keepConnected ? 'Search Google Keep...' : 'Search notes...',
          hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
          prefixIcon: Icon(Icons.search, color: Colors.white.withValues(alpha: 0.3), size: 18),
          suffixIcon: _searchController.text.isNotEmpty
              ? GestureDetector(
                  onTap: () {
                    _searchController.clear();
                    _loadNotes();
                  },
                  child: Icon(Icons.clear, color: Colors.white.withValues(alpha: 0.3), size: 18),
                )
              : null,
          filled: true,
          fillColor: const Color(0xFF1A1A2E),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
        ),
        onChanged: (query) {
          _loadNotes(search: query.isNotEmpty ? query : null);
        },
      ),
    );
  }

  Widget _buildComposeArea() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: keepColors[_selectedColor] ?? const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF00D4FF).withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _titleController,
            style: const TextStyle(
                color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              hintText: 'Title',
              hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.25)),
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
              isDense: true,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _writeController,
            focusNode: _writeFocus,
            maxLines: 4,
            minLines: 2,
            style: const TextStyle(color: Colors.white70, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Take a note...',
              hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.2)),
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
              isDense: true,
            ),
          ),
          const SizedBox(height: 8),
          // Color picker row
          SizedBox(
            height: 28,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: keepColors.entries.map((entry) {
                final isSelected = _selectedColor == entry.key;
                return GestureDetector(
                  onTap: () => setState(() => _selectedColor = entry.key),
                  child: Container(
                    width: 24,
                    height: 24,
                    margin: const EdgeInsets.only(right: 6),
                    decoration: BoxDecoration(
                      color: entry.value,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? Colors.white : Colors.white24,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, color: Colors.white, size: 14)
                        : null,
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (_keepConnected)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Icon(Icons.cloud_upload, color: const Color(0xFFFBBC04).withValues(alpha: 0.5), size: 14),
                ),
              Text(
                _editingId != null ? 'Editing' : (_keepConnected ? 'Saves to Keep' : 'Saves locally'),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.3),
                  fontSize: 11,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: _saveNote,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00D4FF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _editingId != null ? 'Update' : 'Save',
                    style: const TextStyle(
                      color: Color(0xFF0D0D1A),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNotesList() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF00D4FF), strokeWidth: 2),
      );
    }

    if (_notes.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _keepConnected ? Icons.cloud_queue : Icons.note_add,
              color: Colors.white.withValues(alpha: 0.15),
              size: 48,
            ),
            const SizedBox(height: 12),
            Text(
              _keepConnected ? 'No notes in Keep' : 'No notes yet',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.25), fontSize: 14),
            ),
            const SizedBox(height: 4),
            Text(
              'Tap + to write your first note',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.15), fontSize: 12),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      itemCount: _notes.length,
      itemBuilder: (context, index) => _buildNoteCard(_notes[index]),
    );
  }

  Widget _buildNoteCard(MemoryNote note) {
    final bgColor = keepColors[note.color] ?? const Color(0xFF141425);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: note.pinned
              ? const Color(0xFF00D4FF).withValues(alpha: 0.25)
              : Colors.white.withValues(alpha: 0.08),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title row
          Row(
            children: [
              if (note.pinned)
                const Padding(
                  padding: EdgeInsets.only(right: 6),
                  child: Icon(Icons.push_pin, color: Color(0xFF00D4FF), size: 14),
                ),
              if (note.isFromKeep)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Icon(Icons.cloud, color: const Color(0xFFFBBC04).withValues(alpha: 0.5), size: 12),
                ),
              Expanded(
                child: Text(
                  note.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              _tinyButton(
                icon: note.pinned ? Icons.push_pin : Icons.push_pin_outlined,
                onTap: () => _togglePin(note),
                color: note.pinned ? const Color(0xFF00D4FF) : Colors.white.withValues(alpha: 0.3),
              ),
              _tinyButton(icon: Icons.edit_outlined, onTap: () => _startEdit(note)),
              _tinyButton(
                icon: Icons.delete_outline,
                onTap: () => _eraseNote(note),
                color: Colors.redAccent.withValues(alpha: 0.6),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Content
          Text(
            note.content,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12, height: 1.4),
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
          ),
          // Labels/Tags
          if (note.labels.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: note.labels
                  .map((label) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00D4FF).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text('#$label',
                            style: const TextStyle(color: Color(0xFF00D4FF), fontSize: 10)),
                      ))
                  .toList(),
            ),
          ],
          // Timestamp + source
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                _formatTime(note.updatedAt),
                style: TextStyle(color: Colors.white.withValues(alpha: 0.2), fontSize: 10),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _iconButton({
    required IconData icon,
    required VoidCallback onTap,
    String? tooltip,
    Color? color,
  }) {
    final btn = GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(icon, color: color ?? Colors.white54, size: 20),
      ),
    );
    return tooltip != null ? Tooltip(message: tooltip, child: btn) : btn;
  }

  Widget _tinyButton({
    required IconData icon,
    required VoidCallback onTap,
    Color? color,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Icon(icon, color: color ?? Colors.white.withValues(alpha: 0.3), size: 16),
      ),
    );
  }

  String _formatTime(String iso) {
    try {
      final dt = DateTime.parse(iso);
      final now = DateTime.now().toUtc();
      final diff = now.difference(dt);
      if (diff.inMinutes < 1) return 'just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return '${dt.month}/${dt.day}/${dt.year}';
    } catch (_) {
      return '';
    }
  }
}
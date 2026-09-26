// ═══════════════════════════════════════════════════════════════
// SWARM OS — File Explorer v1.0.0  (2026-09-15)
//
// Enterprise-grade file browser: drag & drop, right-click menus,
// inline image/video preview, Kate text editor, artifact support.
// Left sidebar tree  |  Main grid/list  |  Right preview pane.
// ═══════════════════════════════════════════════════════════════

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../theme/swarm_colors.dart';
import '../services/system_launcher.dart';

// ─── Version ─────────────────────────────────────────────────
const _kVersion = 'v1.0.0';
const _kDate    = '2026-09-15';

// ─── Root bookmarks shown in the sidebar ────────────────────
final _kBookmarks = [
  _Bookmark('Home',    Icons.home,           Platform.environment['HOME'] ?? '/home', SwarmColors.agentSky),
  const _Bookmark('Lucy',    Icons.storage,        '/mnt/Lucy',                            SwarmColors.accent),
  const _Bookmark('Root',    Icons.folder_special, '/',                                    SwarmColors.agentAmber),
  _Bookmark('Desktop', Icons.desktop_windows,'${Platform.environment['HOME']}/Desktop', SwarmColors.agentPurple),
  const _Bookmark('Boltz',   Icons.memory,         '/mnt/boltz',                           SwarmColors.agentPink),
];

class _Bookmark {
  final String name;
  final IconData icon;
  final String path;
  final Color color;
  const _Bookmark(this.name, this.icon, this.path, this.color);
}

// ─── File type helpers ───────────────────────────────────────
enum _FType { dir, image, video, text, archive, code, pdf, other }

_FType _ftype(FileSystemEntity e) {
  if (e is Directory) return _FType.dir;
  final x = e.path.toLowerCase();
  if (RegExp(r'\.(png|jpe?g|gif|bmp|webp|avif|svg|ico)$').hasMatch(x)) return _FType.image;
  if (RegExp(r'\.(mp4|mkv|avi|mov|webm|m4v|flv|wmv)$').hasMatch(x)) return _FType.video;
  if (RegExp(r'\.(zip|tar|gz|bz2|xz|7z|rar|zst)$').hasMatch(x)) return _FType.archive;
  if (RegExp(r'\.(dart|go|rs|py|js|ts|sh|c|cpp|h|java|kt|swift|lua)$').hasMatch(x)) return _FType.code;
  if (RegExp(r'\.(pdf)$').hasMatch(x)) return _FType.pdf;
  if (RegExp(r'\.(txt|md|yaml|yml|toml|json|xml|csv|log|conf|env|ini)$').hasMatch(x)) return _FType.text;
  return _FType.other;
}

Color _ftypeColor(_FType t) => switch (t) {
  _FType.dir     => SwarmColors.agentAmber,
  _FType.image   => SwarmColors.agentPink,
  _FType.video   => SwarmColors.agentPurple,
  _FType.text    => SwarmColors.agentSky,
  _FType.archive => SwarmColors.agentOrange,
  _FType.code    => SwarmColors.agentEmerald,
  _FType.pdf     => SwarmColors.agentRose,
  _FType.other   => SwarmColors.textMuted,
};

IconData _ftypeIcon(_FType t) => switch (t) {
  _FType.dir     => Icons.folder,
  _FType.image   => Icons.image,
  _FType.video   => Icons.movie_filter,
  _FType.text    => Icons.description,
  _FType.archive => Icons.archive,
  _FType.code    => Icons.code,
  _FType.pdf     => Icons.picture_as_pdf,
  _FType.other   => Icons.insert_drive_file,
};

String _humanSize(int bytes) {
  if (bytes < 1024) return '${bytes}B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
  if (bytes < 1024 * 1024 * 1024) return '${(bytes / 1024 / 1024).toStringAsFixed(1)}MB';
  return '${(bytes / 1024 / 1024 / 1024).toStringAsFixed(2)}GB';
}

// ─── Main widget ─────────────────────────────────────────────
class FileExplorerPage extends StatefulWidget {
  final String? initialPath;
  const FileExplorerPage({super.key, this.initialPath});

  @override
  State<FileExplorerPage> createState() => _FileExplorerPageState();
}

class _FileExplorerPageState extends State<FileExplorerPage> {
  late String _cwd;
  List<FileSystemEntity> _entries = [];
  FileSystemEntity? _selected;
  bool _loading = false;
  String? _error;
  bool _viewGrid = true;
  bool _showHidden = false;
  final _pathCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();
  String _searchQ = '';

  // Clipboard for cut/copy
  FileSystemEntity? _clipEntity;
  bool _clipCut = false;

  // Navigation history
  final _history = <String>[];
  int _histIdx = -1;

  @override
  void initState() {
    super.initState();
    _cwd = widget.initialPath ?? Platform.environment['HOME'] ?? '/';
    _navigate(_cwd, push: false);
    _searchCtrl.addListener(() => setState(() => _searchQ = _searchCtrl.text.toLowerCase()));
  }

  @override
  void dispose() {
    _pathCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  // ─── Navigation ─────────────────────────────────────────────
  Future<void> _navigate(String path, {bool push = true}) async {
    final dir = Directory(path);
    if (!dir.existsSync()) return;

    if (push) {
      _history.removeRange(_histIdx + 1, _history.length);
      _history.add(path);
      _histIdx = _history.length - 1;
    }

    setState(() { _loading = true; _error = null; _selected = null; });
    try {
      var raw = dir.listSync(followLinks: false);
      raw.sort((a, b) {
        final da = a is Directory; final db = b is Directory;
        if (da != db) return da ? -1 : 1;
        return a.path.split('/').last.toLowerCase().compareTo(b.path.split('/').last.toLowerCase());
      });
      setState(() {
        _cwd = dir.resolveSymbolicLinksSync();
        _entries = raw;
        _loading = false;
      });
      _pathCtrl.text = _cwd;
    } catch (e) {
      setState(() { _loading = false; _error = e.toString(); });
    }
  }

  List<FileSystemEntity> get _visible {
    var list = _showHidden ? _entries : _entries.where((e) => !e.path.split('/').last.startsWith('.')).toList();
    if (_searchQ.isEmpty) return list;
    return list.where((e) => e.path.split('/').last.toLowerCase().contains(_searchQ)).toList();
  }

  void _navBack() { if (_histIdx > 0) { _histIdx--; _navigate(_history[_histIdx], push: false); } }
  void _navFwd()  { if (_histIdx < _history.length - 1) { _histIdx++; _navigate(_history[_histIdx], push: false); } }
  void _navUp()   { final p = Directory(_cwd).parent.path; if (p != _cwd) _navigate(p); }

  // ─── Open item ──────────────────────────────────────────────
  void _open(FileSystemEntity e) {
    final t = _ftype(e);
    switch (t) {
      case _FType.dir:
        _navigate(e.path);
      case _FType.image:
        setState(() => _selected = e);
      case _FType.video:
        context.go('/cinema?file=${Uri.encodeComponent(e.path)}');
      case _FType.code:
      case _FType.text:
        _openKate(e.path);
      default:
        setState(() => _selected = e);
    }
  }

  void _openKate(String path) {
    SystemLauncher.launch(context, 'kate "${path.replaceAll('"', '\\"')}"', displayName: 'Kate');
  }

  void _openTerminalHere() {
    context.go('/grub?path=${Uri.encodeComponent(_cwd)}');
  }

  // ─── File operations ─────────────────────────────────────────
  Future<void> _delete(FileSystemEntity e) async {
    final name = e.path.split('/').last;
    final ok = await _confirm('Delete "$name"?', 'This cannot be undone.');
    if (!ok) return;
    try {
      if (e is Directory) {
        await e.delete(recursive: true);
      } else {
        await e.delete();
      }
      _navigate(_cwd, push: false);
    } catch (ex) {
      _toast('Delete failed: $ex', SwarmColors.error);
    }
  }

  Future<void> _rename(FileSystemEntity e) async {
    final name = e.path.split('/').last;
    final newName = await _promptText('Rename', name);
    if (newName == null || newName.isEmpty || newName == name) return;
    try {
      await e.rename('${Directory(e.path).parent.path}/$newName');
      _navigate(_cwd, push: false);
    } catch (ex) {
      _toast('Rename failed: $ex', SwarmColors.error);
    }
  }

  Future<void> _newFolder() async {
    final name = await _promptText('New Folder', 'New Folder');
    if (name == null || name.isEmpty) return;
    try {
      await Directory('$_cwd/$name').create();
      _navigate(_cwd, push: false);
    } catch (ex) {
      _toast('Create failed: $ex', SwarmColors.error);
    }
  }

  void _copyPath(FileSystemEntity e) {
    Clipboard.setData(ClipboardData(text: e.path));
    _toast('Path copied', SwarmColors.agentSky);
  }

  Future<void> _paste() async {
    if (_clipEntity == null) return;
    final src = _clipEntity!;
    final name = src.path.split('/').last;
    final dst  = '$_cwd/$name';
    try {
      if (_clipCut) {
        await src.rename(dst);
        _clipEntity = null;
        _clipCut = false;
      } else {
        if (src is File) {
          await File(src.path).copy(dst);
        } else {
          // shallow copy of dir
          await Process.run('cp', ['-r', src.path, dst]);
        }
      }
      _navigate(_cwd, push: false);
    } catch (ex) {
      _toast('Paste failed: $ex', SwarmColors.error);
    }
  }

  // ─── Drag & drop ─────────────────────────────────────────────
  Future<void> _dropMove(FileSystemEntity src, String destDir) async {
    final name = src.path.split('/').last;
    try {
      await src.rename('$destDir/$name');
      _navigate(_cwd, push: false);
    } catch (ex) {
      _toast('Move failed: $ex', SwarmColors.error);
    }
  }

  // ─── Dialogs ─────────────────────────────────────────────────
  Future<bool> _confirm(String title, String body) async {
    final r = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF15102A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 14)),
        content: Text(body, style: const TextStyle(color: SwarmColors.textSecondary, fontSize: 12)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: SwarmColors.textMuted))),
          FilledButton(onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: SwarmColors.error, textStyle: const TextStyle(fontSize: 11)),
            child: const Text('Delete')),
        ],
      ),
    );
    return r ?? false;
  }

  Future<String?> _promptText(String title, String initial) async {
    final ctrl = TextEditingController(text: initial);
    final r = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF15102A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 13)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: const TextStyle(color: Colors.white, fontSize: 13),
          decoration: const InputDecoration(
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: SwarmColors.accent)),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: SwarmColors.accent, width: 2)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: SwarmColors.textMuted))),
          FilledButton(onPressed: () => Navigator.pop(context, ctrl.text),
            style: FilledButton.styleFrom(backgroundColor: SwarmColors.accent),
            child: const Text('OK', style: TextStyle(color: Colors.black))),
        ],
      ),
    );
    ctrl.dispose();
    return r;
  }

  void _toast(String msg, [Color c = SwarmColors.accent]) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontSize: 12)),
      backgroundColor: c.withValues(alpha: 0.85),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
    ));
  }

  // ─── Context menus ───────────────────────────────────────────
  void _bgCtx(Offset pos) {
    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(pos.dx, pos.dy, pos.dx + 1, pos.dy + 1),
      color: const Color(0xFF14102A),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFF3A2870)),
      ),
      elevation: 20,
      items: [
        _mi2('New Folder',    Icons.create_new_folder, 'newdir', SwarmColors.agentAmber),
        _mi2('Open Terminal', Icons.terminal,           'term',   SwarmColors.agentSky),
        if (_clipEntity != null)
          _mi2('Paste',       Icons.paste,              'paste',  SwarmColors.agentEmerald),
        const PopupMenuDivider(),
        _mi2('Toggle Hidden', Icons.visibility,         'hidden', SwarmColors.textMuted),
        _mi2(_viewGrid ? 'List View' : 'Grid View', Icons.view_list, 'view', SwarmColors.textMuted),
        _mi2('Refresh',       Icons.refresh,            'refresh',SwarmColors.textMuted),
      ],
    ).then((v) {
      if (v == null) return;
      switch (v) {
        case 'newdir':  _newFolder();
        case 'term':    _openTerminalHere();
        case 'paste':   _paste();
        case 'hidden':  setState(() => _showHidden = !_showHidden);
        case 'view':    setState(() => _viewGrid = !_viewGrid);
        case 'refresh': _navigate(_cwd, push: false);
      }
    });
  }

  void _fileCtx(Offset pos, FileSystemEntity e) {
    final t = _ftype(e);
    final name = e.path.split('/').last;
    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(pos.dx, pos.dy, pos.dx + 1, pos.dy + 1),
      color: const Color(0xFF14102A),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFF3A2870)),
      ),
      elevation: 20,
      items: [
        _mi2('Open',      Icons.open_in_new,    'open',  SwarmColors.agentSky),
        if (t == _FType.code || t == _FType.text)
          _mi2('Edit in Kate', Icons.edit,      'kate',  SwarmColors.agentEmerald),
        if (t == _FType.video)
          _mi2('Play in Cinema', Icons.movie,   'video', SwarmColors.agentPurple),
        if (t == _FType.image)
          _mi2('View Image',Icons.image,        'img',   SwarmColors.agentPink),
        const PopupMenuDivider(),
        _mi2('Copy',      Icons.copy,           'copy',  SwarmColors.agentSky),
        _mi2('Cut',       Icons.content_cut,    'cut',   SwarmColors.agentAmber),
        _mi2('Copy Path', Icons.copy_all,       'path',  SwarmColors.textMuted),
        const PopupMenuDivider(),
        _mi2('Rename',    Icons.drive_file_rename_outline, 'rename', SwarmColors.agentTeal),
        _mi2('Delete',    Icons.delete_outline, 'delete',SwarmColors.error),
      ],
    ).then((v) {
      if (v == null) return;
      switch (v) {
        case 'open':   _open(e);
        case 'kate':   _openKate(e.path);
        case 'video':  if (mounted) context.go('/cinema?file=${Uri.encodeComponent(e.path)}');
        case 'img':    setState(() => _selected = e);
        case 'copy':   setState(() { _clipEntity = e; _clipCut = false; }); _toast('Copied "$name"');
        case 'cut':    setState(() { _clipEntity = e; _clipCut = true; }); _toast('Cut "$name"');
        case 'path':   _copyPath(e);
        case 'rename': _rename(e);
        case 'delete': _delete(e);
      }
    });
  }

  PopupMenuItem<String> _mi2(String label, IconData icon, String val, Color c) =>
      PopupMenuItem(
        value: val,
        height: 34,
        child: Row(children: [
          Icon(icon, color: c, size: 15),
          const SizedBox(width: 10),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
        ]),
      );

  // ══════════════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onSecondaryTapUp: (d) => _bgCtx(d.globalPosition),
      child: Scaffold(
        backgroundColor: SwarmColors.bg,
        body: Column(children: [
          _topBar(),
          Expanded(child: Row(children: [
            _sidebar(),
            const VerticalDivider(width: 1, color: SwarmColors.borderSubtle),
            Expanded(child: Column(children: [
              _breadcrumb(),
              Expanded(child: _loading
                ? const Center(child: CircularProgressIndicator(color: SwarmColors.accent))
                : _error != null
                  ? _errorWidget()
                  : _mainArea()),
            ])),
            if (_selected != null) ...[
              const VerticalDivider(width: 1, color: SwarmColors.borderSubtle),
              _previewPane(),
            ],
          ])),
          _statusBar(),
        ]),
      ),
    );
  }

  // ─── Top bar ────────────────────────────────────────────────
  Widget _topBar() {
    return Container(
      height: 48,
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [Color(0xFF0D0A20), Color(0xFF18112A)]),
        border: Border(bottom: BorderSide(color: SwarmColors.borderSubtle)),
      ),
      child: Row(children: [
        const SizedBox(width: 10),
        const Icon(Icons.folder_open, color: SwarmColors.agentAmber, size: 18),
        const SizedBox(width: 6),
        const Text('File Explorer', style: TextStyle(
          color: SwarmColors.textPrimary, fontSize: 13,
          fontWeight: FontWeight.w700, letterSpacing: 0.8,
        )),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
          decoration: BoxDecoration(
            color: SwarmColors.bgElevated,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: SwarmColors.border),
          ),
          child: const Text('$_kVersion · $_kDate',
            style: TextStyle(color: SwarmColors.textDisabled, fontSize: 9, letterSpacing: 0.6)),
        ),
        const SizedBox(width: 14),

        // Nav buttons
        _navBtn(Icons.arrow_back,    'Back',    _histIdx > 0, _navBack),
        _navBtn(Icons.arrow_forward, 'Forward', _histIdx < _history.length - 1, _navFwd),
        _navBtn(Icons.arrow_upward,  'Up',      Directory(_cwd).parent.path != _cwd, _navUp),
        const SizedBox(width: 8),

        // Path field
        Expanded(child: TextField(
          controller: _pathCtrl,
          style: const TextStyle(color: SwarmColors.textPrimary, fontSize: 12, fontFamily: 'monospace'),
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            fillColor: SwarmColors.bgPanel,
            filled: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: SwarmColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: SwarmColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: SwarmColors.accent, width: 1.5),
            ),
            prefixIcon: const Icon(Icons.folder, color: SwarmColors.agentAmber, size: 16),
          ),
          onSubmitted: (p) => _navigate(p),
        )),
        const SizedBox(width: 8),

        // Search
        SizedBox(width: 180, child: TextField(
          controller: _searchCtrl,
          style: const TextStyle(color: SwarmColors.textPrimary, fontSize: 12),
          decoration: InputDecoration(
            isDense: true,
            hintText: 'Search…',
            hintStyle: const TextStyle(color: SwarmColors.textDisabled, fontSize: 12),
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            fillColor: SwarmColors.bgPanel,
            filled: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: SwarmColors.border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: SwarmColors.border)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: SwarmColors.agentSky, width: 1.5)),
            prefixIcon: const Icon(Icons.search, color: SwarmColors.textMuted, size: 16),
            suffixIcon: _searchQ.isNotEmpty
              ? IconButton(icon: const Icon(Icons.close, size: 14, color: SwarmColors.textMuted), onPressed: () => _searchCtrl.clear())
              : null,
          ),
        )),
        const SizedBox(width: 8),

        // View toggle
        IconButton(
          icon: Icon(_viewGrid ? Icons.grid_view : Icons.view_list, color: SwarmColors.textMuted, size: 18),
          tooltip: _viewGrid ? 'List view' : 'Grid view',
          onPressed: () => setState(() => _viewGrid = !_viewGrid),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        ),
        IconButton(
          icon: Icon(_showHidden ? Icons.visibility : Icons.visibility_off, color: SwarmColors.textMuted, size: 18),
          tooltip: 'Toggle hidden',
          onPressed: () => setState(() => _showHidden = !_showHidden),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        ),
        IconButton(
          icon: const Icon(Icons.add_box_outlined, color: SwarmColors.agentAmber, size: 18),
          tooltip: 'New Folder',
          onPressed: _newFolder,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        ),
        IconButton(
          icon: const Icon(Icons.terminal, color: SwarmColors.agentSky, size: 18),
          tooltip: 'Open Terminal here',
          onPressed: _openTerminalHere,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        ),
        IconButton(
          icon: const Icon(Icons.refresh, color: SwarmColors.textMuted, size: 18),
          tooltip: 'Refresh',
          onPressed: () => _navigate(_cwd, push: false),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        ),
        const SizedBox(width: 6),
        IconButton(
          icon: const Icon(Icons.close, color: Color(0xFF553344), size: 18),
          tooltip: 'Close',
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        ),
        const SizedBox(width: 4),
      ]),
    );
  }

  Widget _navBtn(IconData icon, String tip, bool enabled, VoidCallback fn) =>
      IconButton(
        icon: Icon(icon, color: enabled ? SwarmColors.textSecondary : SwarmColors.textDisabled, size: 18),
        tooltip: tip,
        onPressed: enabled ? fn : null,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      );

  // ─── Sidebar bookmarks ───────────────────────────────────────
  Widget _sidebar() {
    return Container(
      width: 180,
      color: SwarmColors.bgSurface,
      child: Column(children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: Align(alignment: Alignment.centerLeft,
            child: Text('PLACES', style: TextStyle(
              color: SwarmColors.textDisabled, fontSize: 9.5, letterSpacing: 1.5, fontWeight: FontWeight.w600,
            ))),
        ),
        ..._kBookmarks.map((b) {
          final active = _cwd == b.path || _cwd.startsWith('${b.path}/');
          return InkWell(
            onTap: () => _navigate(b.path),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              color: active ? b.color.withValues(alpha: 0.12) : Colors.transparent,
              child: Row(children: [
                Icon(b.icon, color: b.color, size: 15),
                const SizedBox(width: 8),
                Expanded(child: Text(b.name, style: TextStyle(
                  color: active ? b.color : SwarmColors.textSecondary,
                  fontSize: 12,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                ))),
                if (active)
                  Container(width: 3, height: 14, decoration: BoxDecoration(color: b.color, borderRadius: BorderRadius.circular(2))),
              ]),
            ),
          );
        }),

        const Padding(
          padding: EdgeInsets.fromLTRB(12, 16, 12, 4),
          child: Align(alignment: Alignment.centerLeft,
            child: Text('DRIVES', style: TextStyle(
              color: SwarmColors.textDisabled, fontSize: 9.5, letterSpacing: 1.5, fontWeight: FontWeight.w600,
            ))),
        ),
        _driveEntry('/mnt', Icons.storage, 'Mounts', SwarmColors.agentTeal),
        _driveEntry('/dev', Icons.developer_board, 'Devices', SwarmColors.agentPurple),
        _driveEntry('/opt/swarm_os', Icons.rocket, 'SWARM Apps', SwarmColors.accent),
      ]),
    );
  }

  Widget _driveEntry(String path, IconData icon, String label, Color c) {
    final active = _cwd == path || _cwd.startsWith('$path/');
    return InkWell(
      onTap: () => _navigate(path),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        color: active ? c.withValues(alpha: 0.10) : Colors.transparent,
        child: Row(children: [
          Icon(icon, color: c.withValues(alpha: active ? 1 : 0.5), size: 14),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(
            color: active ? c : SwarmColors.textMuted, fontSize: 11,
            fontWeight: active ? FontWeight.w600 : FontWeight.w400,
          )),
        ]),
      ),
    );
  }

  // ─── Breadcrumb ─────────────────────────────────────────────
  Widget _breadcrumb() {
    final parts = _cwd.split('/').where((p) => p.isNotEmpty).toList();
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      color: SwarmColors.bgPanel,
      child: Row(children: [
        InkWell(
          onTap: () => _navigate('/'),
          child: const Icon(Icons.home, color: SwarmColors.textMuted, size: 14),
        ),
        ...parts.asMap().entries.map((e) {
          final seg  = e.value;
          final full = '/${parts.sublist(0, e.key + 1).join('/')}';
          return Row(children: [
            const Icon(Icons.chevron_right, color: SwarmColors.textDisabled, size: 14),
            InkWell(
              onTap: () => _navigate(full),
              child: Text(seg, style: const TextStyle(
                color: SwarmColors.textSecondary, fontSize: 11,
              )),
            ),
          ]);
        }),
      ]),
    );
  }

  // ─── Error ──────────────────────────────────────────────────
  Widget _errorWidget() => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.error_outline, color: SwarmColors.error, size: 40),
      const SizedBox(height: 10),
      Text(_error!, style: const TextStyle(color: SwarmColors.textSecondary, fontSize: 12)),
      const SizedBox(height: 10),
      TextButton(onPressed: _navUp, child: const Text('Go Up')),
    ]),
  );

  // ─── Main area — grid or list ────────────────────────────────
  Widget _mainArea() {
    final items = _visible;
    if (items.isEmpty) {
      return const Center(child: Text('Empty folder', style: TextStyle(color: SwarmColors.textDisabled, fontSize: 13)));
    }
    return _viewGrid ? _gridView(items) : _listView(items);
  }

  // ─── Grid view ──────────────────────────────────────────────
  Widget _gridView(List<FileSystemEntity> items) {
    return GestureDetector(
      onSecondaryTapUp: (d) => _bgCtx(d.globalPosition),
      child: GridView.builder(
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 110, crossAxisSpacing: 8, mainAxisSpacing: 8, childAspectRatio: 0.85,
        ),
        itemCount: items.length,
        itemBuilder: (_, i) => _gridTile(items[i]),
      ),
    );
  }

  Widget _gridTile(FileSystemEntity e) {
    final name = e.path.split('/').last;
    final t    = _ftype(e);
    final c    = _ftypeColor(t);
    final selected = _selected?.path == e.path;

    return Draggable<FileSystemEntity>(
      data: e,
      feedback: Material(
        color: Colors.transparent,
        child: Opacity(opacity: 0.7, child: _gridTileBody(e, name, t, c, false)),
      ),
      childWhenDragging: Opacity(opacity: 0.3, child: _gridTileBody(e, name, t, c, false)),
      child: DragTarget<FileSystemEntity>(
        onAcceptWithDetails: (d) {
          if (t == _FType.dir && d.data.path != e.path) _dropMove(d.data, e.path);
        },
        builder: (_, candidates, __) {
          final hover = candidates.isNotEmpty && t == _FType.dir;
          return GestureDetector(
            onTap: () => setState(() => _selected = e),
            onDoubleTap: () => _open(e),
            onSecondaryTapUp: (d) => _fileCtx(d.globalPosition, e),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              decoration: BoxDecoration(
                color: selected ? c.withValues(alpha: 0.14) : hover ? SwarmColors.bgHover : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: selected ? c.withValues(alpha: 0.6) : hover ? c.withValues(alpha: 0.4) : Colors.transparent,
                  width: 1.5,
                ),
              ),
              child: _gridTileBody(e, name, t, c, selected),
            ),
          );
        },
      ),
    );
  }

  Widget _gridTileBody(FileSystemEntity e, String name, _FType t, Color c, bool sel) {
    return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      // Thumbnail for images, icon for others
      if (t == _FType.image)
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Image.file(
            e as File,
            width: 64, height: 64, fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Icon(_ftypeIcon(t), color: c, size: 40),
          ),
        )
      else
        Container(
          width: 56, height: 56,
          decoration: BoxDecoration(
            color: c.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: c.withValues(alpha: 0.18)),
          ),
          child: Icon(_ftypeIcon(t), color: c, size: 28),
        ),
      const SizedBox(height: 6),
      Text(
        name,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: sel ? c : SwarmColors.textSecondary,
          fontSize: 10.5,
          fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
    ]);
  }

  // ─── List view ──────────────────────────────────────────────
  Widget _listView(List<FileSystemEntity> items) {
    return GestureDetector(
      onSecondaryTapUp: (d) => _bgCtx(d.globalPosition),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 4),
        itemCount: items.length,
        itemBuilder: (_, i) => _listRow(items[i]),
      ),
    );
  }

  Widget _listRow(FileSystemEntity e) {
    final name = e.path.split('/').last;
    final t    = _ftype(e);
    final c    = _ftypeColor(t);
    final sel  = _selected?.path == e.path;

    String? size;
    if (e is File) {
      try { size = _humanSize(e.statSync().size); } catch (_) {}
    }

    return Draggable<FileSystemEntity>(
      data: e,
      feedback: Material(color: Colors.transparent,
        child: Container(width: 300, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          color: SwarmColors.bgHover.withValues(alpha: 0.9),
          child: Text(name, style: const TextStyle(color: Colors.white, fontSize: 12)))),
      child: DragTarget<FileSystemEntity>(
        onAcceptWithDetails: (d) {
          if (t == _FType.dir && d.data.path != e.path) _dropMove(d.data, e.path);
        },
        builder: (_, candidates, __) {
          final hover = candidates.isNotEmpty && t == _FType.dir;
          return GestureDetector(
            onTap: () => setState(() => _selected = e),
            onDoubleTap: () => _open(e),
            onSecondaryTapUp: (d) => _fileCtx(d.globalPosition, e),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 100),
              color: sel ? c.withValues(alpha: 0.10)
                : hover ? SwarmColors.bgHover
                : Colors.transparent,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              child: Row(children: [
                Icon(_ftypeIcon(t), color: c, size: 16),
                const SizedBox(width: 10),
                Expanded(child: Text(name, style: TextStyle(
                  color: sel ? c : SwarmColors.textPrimary,
                  fontSize: 12,
                  fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
                ))),
                if (size != null)
                  Text(size, style: const TextStyle(color: SwarmColors.textDisabled, fontSize: 10, fontFamily: 'monospace')),
                const SizedBox(width: 10),
                if (t == _FType.dir) const Icon(Icons.chevron_right, color: SwarmColors.textDisabled, size: 14),
              ]),
            ),
          );
        },
      ),
    );
  }

  // ─── Preview pane ────────────────────────────────────────────
  Widget _previewPane() {
    final e    = _selected!;
    final name = e.path.split('/').last;
    final t    = _ftype(e);
    final c    = _ftypeColor(t);

    return Container(
      width: 260,
      color: SwarmColors.bgSurface,
      child: Column(children: [
        // Header
        Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: SwarmColors.borderSubtle))),
          child: Row(children: [
            Icon(_ftypeIcon(t), color: c, size: 16),
            const SizedBox(width: 6),
            Expanded(child: Text(name, style: const TextStyle(color: SwarmColors.textPrimary, fontSize: 11, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis)),
            IconButton(
              icon: const Icon(Icons.close, color: SwarmColors.textMuted, size: 14),
              onPressed: () => setState(() => _selected = null),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
            ),
          ]),
        ),
        // Content
        Expanded(child: _previewContent(e, t, c)),
        // Actions
        _previewActions(e, t),
      ]),
    );
  }

  Widget _previewContent(FileSystemEntity e, _FType t, Color c) {
    if (t == _FType.image) {
      return Padding(
        padding: const EdgeInsets.all(8),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.file(
            e as File,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, color: SwarmColors.textMuted, size: 40),
          ),
        ),
      );
    }

    // File stats
    FileStat? stat;
    try { stat = e.statSync(); } catch (_) {}

    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Center(child: Container(
          width: 80, height: 80,
          decoration: BoxDecoration(
            color: c.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: c.withValues(alpha: 0.20)),
          ),
          child: Icon(_ftypeIcon(t), color: c, size: 40),
        )),
        const SizedBox(height: 16),
        _infoRow('Type',  t.name.toUpperCase(), c),
        if (stat != null) ...[
          if (e is File) _infoRow('Size', _humanSize(stat.size), SwarmColors.textSecondary),
          _infoRow('Modified', _fmtDate(stat.modified), SwarmColors.textSecondary),
          _infoRow('Mode', stat.modeString(), SwarmColors.textMuted),
        ],
        const SizedBox(height: 8),
        _infoRow('Path', e.path, SwarmColors.textMuted),
      ]),
    );
  }

  Widget _infoRow(String label, String val, Color c) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(width: 68, child: Text(label, style: const TextStyle(color: SwarmColors.textDisabled, fontSize: 10.5, fontWeight: FontWeight.w600))),
      Expanded(child: Text(val, style: TextStyle(color: c, fontSize: 10.5, fontFamily: 'monospace'), overflow: TextOverflow.ellipsis)),
    ]),
  );

  String _fmtDate(DateTime d) => '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}  ${d.hour.toString().padLeft(2,'0')}:${d.minute.toString().padLeft(2,'0')}';

  Widget _previewActions(FileSystemEntity e, _FType t) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: SwarmColors.borderSubtle))),
      child: Column(children: [
        if (t == _FType.image)
          _actionBtn('View Fullscreen', Icons.fullscreen, SwarmColors.agentPink, () => setState(() => _selected = e)),
        if (t == _FType.video)
          _actionBtn('Play in Cinema', Icons.movie, SwarmColors.agentPurple, () => context.go('/cinema?file=${Uri.encodeComponent(e.path)}')),
        if (t == _FType.code || t == _FType.text)
          _actionBtn('Edit in Kate', Icons.edit, SwarmColors.agentEmerald, () => _openKate(e.path)),
        _actionBtn('Copy Path', Icons.copy_all, SwarmColors.agentSky, () => _copyPath(e)),
        _actionBtn('Delete',    Icons.delete_outline, SwarmColors.error, () => _delete(e)),
      ]),
    );
  }

  Widget _actionBtn(String label, IconData icon, Color c, VoidCallback fn) =>
      SizedBox(width: double.infinity, child: TextButton.icon(
        onPressed: fn,
        icon: Icon(icon, color: c, size: 14),
        label: Text(label, style: TextStyle(color: c, fontSize: 11)),
        style: TextButton.styleFrom(alignment: Alignment.centerLeft),
      ));

  // ─── Status bar ──────────────────────────────────────────────
  Widget _statusBar() {
    final visible = _visible;
    final dirs  = visible.whereType<Directory>().length;
    final files = visible.length - dirs;
    return Container(
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      color: SwarmColors.bgPanel,
      child: Row(children: [
        Text(
          '$dirs folders, $files files${_searchQ.isNotEmpty ? " (filtered)" : ""}${_clipEntity != null ? "  ·  ${_clipCut ? "Cut" : "Copied"}: ${_clipEntity!.path.split('/').last}" : ""}',
          style: const TextStyle(color: SwarmColors.textDisabled, fontSize: 9.5),
        ),
        const Spacer(),
        const Text('SWARM OS  ·  File Explorer $_kVersion',
          style: TextStyle(color: SwarmColors.textDisabled, fontSize: 9, letterSpacing: 0.6)),
      ]),
    );
  }
}

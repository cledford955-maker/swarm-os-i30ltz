import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../services/sentinel_client.dart';
import '../providers/sentinel_providers.dart';
import '../theme/swarm_colors.dart';
import '../theme/swarm_text_styles.dart';

// ─── Provider ────────────────────────────────────────────────────────────────

// _dirProvider removed, using projectDirectoryProvider from sentinel_providers.dart

final _filesProvider = FutureProvider.family<List<FileEntry>, String>(
  (ref, dirPath) async {
    final client = ref.read(sentinelClientProvider);
    return client.listDirectory(dirPath);
  },
);

// ─── Vault File Browser ──────────────────────────────────────────────────────

class VaultFileBrowser extends ConsumerStatefulWidget {
  const VaultFileBrowser({super.key});

  @override
  ConsumerState<VaultFileBrowser> createState() => _VaultFileBrowserState();
}

class _VaultFileBrowserState extends ConsumerState<VaultFileBrowser> {
  final List<String> _history = ['/home'];
  int _historyIndex = 0;
  FileEntry? _selected;

  String get _currentDir => _history[_historyIndex];


  Future<void> _pickDirectory() async {
    String? selectedDirectory = await FilePicker.getDirectoryPath();
    if (selectedDirectory != null) {
      _navigate(selectedDirectory);
    }
  }

  void _navigate(String path) {

    // Trim forward history on new navigate
    if (_historyIndex < _history.length - 1) {
      _history.removeRange(_historyIndex + 1, _history.length);
    }
    _history.add(path);
    _historyIndex = _history.length - 1;
    ref.read(projectDirectoryProvider.notifier).state = path;
    setState(() => _selected = null);
  }

  void _goBack() {
    if (_historyIndex > 0) {
      _historyIndex--;
      ref.read(projectDirectoryProvider.notifier).state = _history[_historyIndex];
      setState(() => _selected = null);
    }
  }

  void _goUp() {
    final parts = _currentDir.split('/')..removeLast();
    final parent = parts.isEmpty ? '/' : parts.join('/');
    if (parent.isNotEmpty) _navigate(parent.isEmpty ? '/' : parent);
  }

  @override
  Widget build(BuildContext context) {
    final dirPath = ref.watch(projectDirectoryProvider);
    final files = ref.watch(_filesProvider(dirPath));

    return Column(
      children: [
        // ─── Toolbar ────────────────────────────────────────────
        _Toolbar(
          currentDir: _currentDir,
          canGoBack: _historyIndex > 0,
          onBack: _goBack,
          onUp: _goUp,
          onRefresh: () => ref.invalidate(_filesProvider(_currentDir)),
          onNavigate: _navigate,
          onChooseFolder: _pickDirectory,
        ),

        // ─── Breadcrumb ─────────────────────────────────────────
        _Breadcrumb(path: _currentDir, onNavigate: _navigate),

        // ─── Column Headers ─────────────────────────────────────
        _ColumnHeaders(),

        // ─── File List ──────────────────────────────────────────
        Expanded(
          child: files.when(
            loading: () => const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: SwarmColors.accent,
                ),
              ),
            ),
            error: (e, _) => Center(
              child: Text(
                '⚠ $e',
                style: SwarmTextStyles.body.copyWith(color: SwarmColors.statusCritical, fontSize: 12),
              ),
            ),
            data: (entries) => entries.isEmpty
                ? Center(
                    child: Text(
                      'Empty directory',
                      style: SwarmTextStyles.body.copyWith(color: SwarmColors.textMuted, fontSize: 12),
                    ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.zero,
                    itemCount: entries.length,
                    itemBuilder: (context, i) {
                      final entry = entries[i];
                      final isSelected = _selected?.path == entry.path;
                      return _FileRow(
                        entry: entry,
                        isSelected: isSelected,
                        onTap: () {
                          if (entry.isDirectory) {
                            _navigate(entry.path);
                          } else {
                            setState(() => _selected = entry);
                          }
                        },
                        onDoubleTap: () {
                          if (entry.isDirectory) _navigate(entry.path);
                        },
                      );
                    },
                  ),
          ),
        ),

        // ─── Status Bar ─────────────────────────────────────────
        _StatusBar(currentDir: _currentDir, selected: _selected),
      ],
    );
  }
}

// ─── Toolbar ─────────────────────────────────────────────────────────────────

class _Toolbar extends StatelessWidget {
  final String currentDir;
  final bool canGoBack;
  final VoidCallback onBack;
  final VoidCallback onUp;
  final VoidCallback onRefresh;
  final void Function(String) onNavigate;

  final VoidCallback onChooseFolder;

  const _Toolbar({
    required this.currentDir,
    required this.canGoBack,
    required this.onBack,
    required this.onUp,
    required this.onRefresh,
    required this.onNavigate,
    required this.onChooseFolder,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: const BoxDecoration(
        color: SwarmColors.bgElevated,
        border: Border(bottom: BorderSide(color: SwarmColors.border)),
      ),
      child: Row(
        children: [
          _ToolBtn(icon: Icons.arrow_back_rounded, enabled: canGoBack, onTap: onBack, tooltip: 'Back'),
          _ToolBtn(icon: Icons.arrow_upward_rounded, enabled: currentDir != '/', onTap: onUp, tooltip: 'Up'),
          _ToolBtn(icon: Icons.refresh_rounded, enabled: true, onTap: onRefresh, tooltip: 'Refresh'),
          _ToolBtn(icon: Icons.folder_open, enabled: true, onTap: onChooseFolder, tooltip: 'Open Project Folder'),
          const SizedBox(width: 8),
          const VerticalDivider(color: SwarmColors.border, width: 1, indent: 8, endIndent: 8),
          const SizedBox(width: 8),
          // Path jump box
          Expanded(
            child: _PathInput(currentDir: currentDir, onNavigate: onNavigate),
          ),
        ],
      ),
    );
  }
}

class _ToolBtn extends StatefulWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;
  final String tooltip;
  const _ToolBtn({required this.icon, required this.enabled, required this.onTap, required this.tooltip});

  @override
  State<_ToolBtn> createState() => _ToolBtnState();
}

class _ToolBtnState extends State<_ToolBtn> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        cursor: widget.enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        child: GestureDetector(
          onTap: widget.enabled ? widget.onTap : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: _hovered && widget.enabled ? SwarmColors.bgHover : Colors.transparent,
              borderRadius: BorderRadius.circular(5),
            ),
            child: Icon(
              widget.icon,
              size: 16,
              color: widget.enabled ? SwarmColors.textSecondary : SwarmColors.textMuted.withValues(alpha: 0.3),
            ),
          ),
        ),
      ),
    );
  }
}

class _PathInput extends StatefulWidget {
  final String currentDir;
  final void Function(String) onNavigate;
  const _PathInput({required this.currentDir, required this.onNavigate});

  @override
  State<_PathInput> createState() => _PathInputState();
}

class _PathInputState extends State<_PathInput> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.currentDir);
  }

  @override
  void didUpdateWidget(_PathInput old) {
    super.didUpdateWidget(old);
    if (old.currentDir != widget.currentDir) {
      _ctrl.text = widget.currentDir;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: SwarmColors.bg,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: SwarmColors.border),
      ),
      child: TextField(
        controller: _ctrl,
        style: SwarmTextStyles.code.copyWith(fontSize: 11, color: SwarmColors.textPrimary),
        decoration: const InputDecoration(border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero),
        onSubmitted: widget.onNavigate,
      ),
    );
  }
}

// ─── Breadcrumb ──────────────────────────────────────────────────────────────

class _Breadcrumb extends StatelessWidget {
  final String path;
  final void Function(String) onNavigate;

  const _Breadcrumb({required this.path, required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    final parts = path.split('/').where((p) => p.isNotEmpty).toList();

    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(
        color: SwarmColors.bgSurface,
        border: Border(bottom: BorderSide(color: SwarmColors.border)),
      ),
      child: Row(
        children: [
          // Root
          _BreadCrumbItem(
            label: '/',
            onTap: () => onNavigate('/'),
          ),
          ...List.generate(parts.length, (i) {
            final segPath = '/${parts.sublist(0, i + 1).join('/')}';
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.chevron_right_rounded, size: 12, color: SwarmColors.textMuted),
                _BreadCrumbItem(
                  label: parts[i],
                  onTap: () => onNavigate(segPath),
                  isCurrent: i == parts.length - 1,
                ),
              ],
            );
          }),
        ],
      ),
    );
  }
}

class _BreadCrumbItem extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  final bool isCurrent;
  const _BreadCrumbItem({required this.label, required this.onTap, this.isCurrent = false});

  @override
  State<_BreadCrumbItem> createState() => _BreadCrumbItemState();
}

class _BreadCrumbItemState extends State<_BreadCrumbItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: Text(
            widget.label,
            style: SwarmTextStyles.code.copyWith(
              fontSize: 10,
              color: widget.isCurrent
                  ? SwarmColors.accent
                  : _hovered
                      ? SwarmColors.textPrimary
                      : SwarmColors.textSecondary,
              fontWeight: widget.isCurrent ? FontWeight.w700 : FontWeight.w400,
              decoration: _hovered && !widget.isCurrent ? TextDecoration.underline : null,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Column Headers ───────────────────────────────────────────────────────────

class _ColumnHeaders extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 26,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(
        color: SwarmColors.bgElevated,
        border: Border(bottom: BorderSide(color: SwarmColors.border)),
      ),
      child: Row(
        children: [
          const SizedBox(width: 22), // icon
          Expanded(
            flex: 5,
            child: Text('NAME', style: _headerStyle),
          ),
          SizedBox(
            width: 160,
            child: Text('CREATED', style: _headerStyle),
          ),
          SizedBox(
            width: 130,
            child: Text('MODIFIED', style: _headerStyle),
          ),
          SizedBox(
            width: 80,
            child: Text('SIZE', style: _headerStyle, textAlign: TextAlign.right),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  TextStyle get _headerStyle => SwarmTextStyles.labelSmall.copyWith(
        fontSize: 9,
        color: SwarmColors.textMuted,
        letterSpacing: 0.8,
        fontWeight: FontWeight.w700,
      );
}

// ─── File Row ────────────────────────────────────────────────────────────────

class _FileRow extends StatefulWidget {
  final FileEntry entry;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onDoubleTap;

  const _FileRow({
    required this.entry,
    required this.isSelected,
    required this.onTap,
    required this.onDoubleTap,
  });

  @override
  State<_FileRow> createState() => _FileRowState();
}

class _FileRowState extends State<_FileRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final e = widget.entry;
    final bg = widget.isSelected
        ? SwarmColors.accent.withValues(alpha: 0.15)
        : _hovered
            ? SwarmColors.bgHover
            : Colors.transparent;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        onDoubleTap: widget.onDoubleTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          height: 30,
          color: bg,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              // Icon
              Icon(
                e.isDirectory ? Icons.folder_rounded : _fileIcon(e.name),
                size: 15,
                color: e.isDirectory ? const Color(0xFFFFBF00) : SwarmColors.textSecondary,
              ),
              const SizedBox(width: 7),
              // Name
              Expanded(
                flex: 5,
                child: Text(
                  e.name,
                  style: SwarmTextStyles.body.copyWith(
                    fontSize: 12,
                    color: widget.isSelected ? SwarmColors.accent : SwarmColors.textPrimary,
                    fontWeight: e.isDirectory ? FontWeight.w600 : FontWeight.w400,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (MediaQuery.of(context).size.width > 400) ...[
                // Created
                SizedBox(
                  width: 160,
                  child: Text(
                    _formatDate(e.birthtime),
                    style: SwarmTextStyles.code.copyWith(
                      fontSize: 10,
                      color: e.birthtime != null ? SwarmColors.textSecondary : SwarmColors.textMuted.withValues(alpha: 0.4),
                    ),
                  ),
                ),
                // Modified
                SizedBox(
                  width: 130,
                  child: Text(
                    _formatDate(e.mtime),
                    style: SwarmTextStyles.code.copyWith(
                      fontSize: 10,
                      color: SwarmColors.textMuted,
                    ),
                  ),
                ),
                // Size
                SizedBox(
                  width: 80,
                  child: Text(
                    e.isDirectory ? '—' : _formatSize(e.size),
                    style: SwarmTextStyles.code.copyWith(
                      fontSize: 10,
                      color: SwarmColors.textMuted,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
              const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return '—';
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    final dateStr = '${months[dt.month - 1]} ${dt.day.toString().padLeft(2, ' ')}, ${dt.year}  $h:$m';
    return dateStr;
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)}GB';
  }

  IconData _fileIcon(String name) {
    final ext = name.split('.').last.toLowerCase();
    return switch (ext) {
      'dart' || 'ts' || 'tsx' || 'js' || 'jsx' || 'py' || 'rs' || 'go' => Icons.code_rounded,
      'md' || 'txt' || 'rst' => Icons.article_rounded,
      'json' || 'yaml' || 'yml' || 'toml' => Icons.data_object_rounded,
      'png' || 'jpg' || 'jpeg' || 'gif' || 'svg' || 'webp' => Icons.image_rounded,
      'mp4' || 'mkv' || 'avi' || 'mov' => Icons.movie_rounded,
      'mp3' || 'wav' || 'flac' || 'ogg' => Icons.music_note_rounded,
      'zip' || 'tar' || 'gz' || 'bz2' || 'xz' => Icons.folder_zip_rounded,
      'pdf' => Icons.picture_as_pdf_rounded,
      'sh' || 'bash' || 'zsh' => Icons.terminal_rounded,
      _ => Icons.insert_drive_file_rounded,
    };
  }
}

// ─── Status Bar ──────────────────────────────────────────────────────────────

class _StatusBar extends StatelessWidget {
  final String currentDir;
  final FileEntry? selected;

  const _StatusBar({required this.currentDir, required this.selected});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(
        color: SwarmColors.bgElevated,
        border: Border(top: BorderSide(color: SwarmColors.border)),
      ),
      child: Row(
        children: [
          Text(
            selected != null
                ? selected!.isDirectory
                    ? '📁 ${selected!.path}'
                    : '📄 ${selected!.name}  ·  ${_formatSizeStatic(selected!.size)}'
                : currentDir,
            style: SwarmTextStyles.code.copyWith(fontSize: 9, color: SwarmColors.textMuted),
          ),
          if (selected?.birthtime != null) ...[
            const SizedBox(width: 16),
            Text(
              'Created: ${_fmtFull(selected!.birthtime!)}',
              style: SwarmTextStyles.code.copyWith(
                fontSize: 9,
                color: SwarmColors.accent.withValues(alpha: 0.8),
              ),
            ),
          ],
          if (selected?.mtime != null) ...[
            const SizedBox(width: 16),
            Text(
              'Modified: ${_fmtFull(selected!.mtime!)}',
              style: SwarmTextStyles.code.copyWith(fontSize: 9, color: SwarmColors.textMuted),
            ),
          ],
        ],
      ),
    );
  }

  static String _formatSizeStatic(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }

  static String _fmtFull(DateTime dt) {
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    final h = dt.hour.toString().padLeft(2,'0');
    final m = dt.minute.toString().padLeft(2,'0');
    final s = dt.second.toString().padLeft(2,'0');
    return '${months[dt.month-1]} ${dt.day}, ${dt.year} at $h:$m:$s';
  }
}

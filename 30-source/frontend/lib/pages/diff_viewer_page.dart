import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../theme/swarm_colors.dart';
import '../coder/diff_viewer_widget.dart';

class GitDiffEntry {
  final String path;
  final bool isStaged;

  const GitDiffEntry({required this.path, required this.isStaged});
}

class DiffViewerPage extends StatefulWidget {
  final String? oldFilePath;
  final String? newFilePath;
  final String? repoPath;

  const DiffViewerPage({
    super.key,
    this.oldFilePath,
    this.newFilePath,
    this.repoPath,
  });

  @override
  State<DiffViewerPage> createState() => _DiffViewerPageState();
}

class _DiffViewerPageState extends State<DiffViewerPage> {
  String? _oldPath;
  String? _newPath;
  String _oldContent = '';
  String _newContent = '';
  bool _isLoading = false;
  List<GitDiffEntry> _gitModifiedFiles = [];
  String? _selectedGitFile;

  @override
  void initState() {
    super.initState();
    _oldPath = widget.oldFilePath;
    _newPath = widget.newFilePath;

    if (_oldPath != null && _newPath != null) {
      _loadFiles();
    } else if (widget.repoPath != null) {
      _loadGitChanges(widget.repoPath!);
    } else {
      // Demo initial diff
      _oldContent = '''// Swarm OS Core Kernel
void main() {
  print("Booting SWARM OS v1.0");
  final service = KernelService();
  service.initialize();
}''';
      _newContent = '''// Swarm OS Core Kernel v2.5
void main() async {
  print("Booting SWARM OS v2.5 with GitLens & Diff Engine");
  final service = KernelService(enableTelemetry: true);
  await service.initialize();
  print("System Ready.");
}''';
    }
  }

  Future<void> _loadFiles() async {
    if (_oldPath == null || _newPath == null) return;
    setState(() => _isLoading = true);
    try {
      final oldF = File(_oldPath!);
      final newF = File(_newPath!);
      final oldTxt = oldF.existsSync() ? await oldF.readAsString() : '';
      final newTxt = newF.existsSync() ? await newF.readAsString() : '';
      if (mounted) {
        setState(() {
          _oldContent = oldTxt;
          _newContent = newTxt;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadGitChanges(String repo) async {
    setState(() => _isLoading = true);
    try {
      final res = await Process.run('git', ['status', '--porcelain'], workingDirectory: repo);
      final lines = res.stdout.toString().split('\n').where((l) => l.trim().isNotEmpty);
      final files = <GitDiffEntry>[];

      for (final line in lines) {
        if (line.length >= 3) {
          final indexStatus = line.substring(0, 1);
          final filePath = line.substring(3).trim();
          final isStaged = indexStatus != ' ' && indexStatus != '?';
          files.add(GitDiffEntry(path: filePath, isStaged: isStaged));
        }
      }

      if (mounted) {
        setState(() {
          _gitModifiedFiles = files;
          _isLoading = false;
        });
        if (_gitModifiedFiles.isNotEmpty) {
          _inspectGitFile(_gitModifiedFiles.first.path);
        }
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _inspectGitFile(String filePath) async {
    setState(() {
      _selectedGitFile = filePath;
      _isLoading = true;
    });
    try {
      final cwd = widget.repoPath ?? '.';
      // Read working tree version
      final fullPath = '$cwd/$filePath';
      final currentFile = File(fullPath);
      final currentContent = currentFile.existsSync() ? await currentFile.readAsString() : '';

      // Read HEAD version via git show HEAD:path
      final r = await Process.run('git', ['show', 'HEAD:$filePath'], workingDirectory: cwd);
      final headContent = r.exitCode == 0 ? r.stdout.toString() : '';

      if (mounted) {
        setState(() {
          _oldPath = 'HEAD:$filePath';
          _newPath = filePath;
          _oldContent = headContent;
          _newContent = currentContent;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickFile({required bool isOld}) async {
    final file = await FilePicker.pickFile();
    if (file != null && file.path != null) {
      final path = file.path!;
      final text = await File(path).readAsString();
      setState(() {
        if (isOld) {
          _oldPath = path;
          _oldContent = text;
        } else {
          _newPath = path;
          _newContent = text;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SwarmColors.bgBase,
      appBar: AppBar(
        backgroundColor: SwarmColors.bgSurface,
        elevation: 0,
        titleSpacing: 16,
        title: Row(
          children: [
            const Icon(Icons.difference_rounded, color: SwarmColors.accent, size: 20),
            const SizedBox(width: 8),
            const Text('Visual Diff Studio', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: SwarmColors.textPrimary)),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: SwarmColors.accent.withAlpha(30),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text('PRO DIFF ENGINE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: SwarmColors.accent)),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.folder_open, size: 16),
            label: const Text('Pick Base File', style: TextStyle(fontSize: 12)),
            style: TextButton.styleFrom(foregroundColor: SwarmColors.textSecondary),
            onPressed: () => _pickFile(isOld: true),
          ),
          TextButton.icon(
            icon: const Icon(Icons.file_copy_outlined, size: 16),
            label: const Text('Pick Target File', style: TextStyle(fontSize: 12)),
            style: TextButton.styleFrom(foregroundColor: SwarmColors.textSecondary),
            onPressed: () => _pickFile(isOld: false),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Row(
        children: [
          // If git modified files exist, show sidebar
          if (_gitModifiedFiles.isNotEmpty)
            Container(
              width: 240,
              decoration: const BoxDecoration(
                color: SwarmColors.bgSurface,
                border: Border(right: BorderSide(color: SwarmColors.border)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    child: Row(
                      children: [
                        const Icon(Icons.commit_rounded, size: 16, color: SwarmColors.accent),
                        const SizedBox(width: 6),
                        Text('CHANGES (${_gitModifiedFiles.length})', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: SwarmColors.textMuted)),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _gitModifiedFiles.length,
                      itemBuilder: (context, index) {
                        final file = _gitModifiedFiles[index];
                        final isSel = file.path == _selectedGitFile;
                        return ListTile(
                          dense: true,
                          selected: isSel,
                          selectedTileColor: SwarmColors.accent.withAlpha(30),
                          leading: Icon(
                            file.isStaged ? Icons.check_circle_outline : Icons.change_circle_outlined,
                            size: 16,
                            color: file.isStaged ? SwarmColors.agentEmerald : SwarmColors.agentAmber,
                          ),
                          title: Text(file.path, style: const TextStyle(fontSize: 12, color: SwarmColors.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
                          onTap: () => _inspectGitFile(file.path),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          // Main diff canvas
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: SwarmColors.accent))
                : DiffViewerWidget(
                    oldText: _oldContent,
                    newText: _newContent,
                    oldTitle: _oldPath ?? 'Base (Original)',
                    newTitle: _newPath ?? 'Target (Modified)',
                  ),
          ),
        ],
      ),
    );
  }
}

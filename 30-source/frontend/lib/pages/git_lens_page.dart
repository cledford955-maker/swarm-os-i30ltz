import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../theme/swarm_colors.dart';
import '../theme/swarm_text_styles.dart';
import '../services/git_lens_service.dart';

class GitLensPage extends StatefulWidget {
  final String? initialWorkspacePath;
  const GitLensPage({super.key, this.initialWorkspacePath});

  @override
  State<GitLensPage> createState() => _GitLensPageState();
}

class _GitLensPageState extends State<GitLensPage> {
  String _workspacePath = Directory.current.path;
  bool _loading = false;
  List<GitCommit> _commits = [];
  List<GitBranch> _branches = [];
  List<GitStash> _stashes = [];
  GitCommit? _selectedCommit;
  String _commitDiff = '';
  bool _diffLoading = false;
  final _searchCtrl = TextEditingController();

  // File History inspector mode
  String? _inspectedFilePath;
  List<GitCommit> _fileHistory = [];

  @override
  void initState() {
    super.initState();
    if (widget.initialWorkspacePath != null && Directory(widget.initialWorkspacePath!).existsSync()) {
      _workspacePath = widget.initialWorkspacePath!;
    }
    _refreshAll();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _refreshAll() async {
    setState(() => _loading = true);
    try {
      final commits = await GitLensService.instance.getCommitGraph(
        limit: 100,
        search: _searchCtrl.text.isNotEmpty ? _searchCtrl.text : null,
        cwd: _workspacePath,
      );
      final branches = await GitLensService.instance.getBranches(cwd: _workspacePath);
      final stashes = await GitLensService.instance.getStashes(cwd: _workspacePath);

      if (mounted) {
        setState(() {
          _commits = commits;
          _branches = branches;
          _stashes = stashes;
          _loading = false;
          if (_selectedCommit == null && commits.isNotEmpty) {
            _selectCommit(commits.first);
          }
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _selectCommit(GitCommit commit) async {
    setState(() {
      _selectedCommit = commit;
      _diffLoading = true;
    });

    final diff = await GitLensService.instance.getCommitDiff(commit.hash, cwd: _workspacePath);
    if (mounted) {
      setState(() {
        _commitDiff = diff;
        _diffLoading = false;
      });
    }
  }

  Future<void> _inspectFile(String relativePath) async {
    setState(() {
      _inspectedFilePath = relativePath;
      _loading = true;
    });

    final history = await GitLensService.instance.getFileHistory(relativePath, limit: 50, cwd: _workspacePath);
    if (mounted) {
      setState(() {
        _fileHistory = history;
        _loading = false;
        if (history.isNotEmpty) {
          _selectCommit(history.first);
        }
      });
    }
  }

  String get _currentBranchName {
    return _branches.where((b) => b.isCurrent).firstOrNull?.name ?? 'HEAD';
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF070A10),
      body: SafeArea(
        child: Column(
          children: [
            // Top Navigation & Git Toolbar
            _buildTopBar(),

            // Main Content Area
            Expanded(
              child: Row(
                children: [
                  // Left Sidebar (Branches, Stashes, File Timeline)
                  SizedBox(
                    width: 280,
                    child: _buildSidebar(),
                  ),
                  const VerticalDivider(width: 1, color: SwarmColors.border),

                  // Middle Column: Visual Commit Graph / Log
                  Expanded(
                    flex: 5,
                    child: _buildCommitGraph(),
                  ),
                  const VerticalDivider(width: 1, color: SwarmColors.border),

                  // Right Column: Commit Inspector & Full Diff Viewer
                  Expanded(
                    flex: 6,
                    child: _buildCommitInspector(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Top Bar ─────────────────────────────────────────────────────────────────

  Widget _buildTopBar() {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: Color(0xFF0C101A),
        border: Border(bottom: BorderSide(color: SwarmColors.border)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: SwarmColors.textMuted, size: 18),
            tooltip: 'Back to Desktop',
            onPressed: () => context.go('/'),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.hub_rounded, color: SwarmColors.agentCyan, size: 20),
          const SizedBox(width: 10),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'GITLENS STUDIO',
                    style: SwarmTextStyles.labelSmall.copyWith(
                      color: SwarmColors.agentCyan,
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: SwarmColors.agentCyan.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: SwarmColors.agentCyan.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.call_split_rounded, size: 11, color: SwarmColors.agentCyan),
                        const SizedBox(width: 4),
                        Text(
                          _currentBranchName,
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.bold,
                            color: SwarmColors.agentCyan,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Text(
                _workspacePath,
                style: const TextStyle(fontSize: 10, color: SwarmColors.textMuted),
              ),
            ],
          ),
          const Spacer(),

          // Search Field
          SizedBox(
            width: 220,
            height: 30,
            child: TextField(
              controller: _searchCtrl,
              onSubmitted: (_) => _refreshAll(),
              style: const TextStyle(fontSize: 11.5, color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Filter graph (Enter)...',
                hintStyle: const TextStyle(fontSize: 11, color: SwarmColors.textDisabled),
                filled: true,
                fillColor: const Color(0xFF141926),
                prefixIcon: const Icon(Icons.search, size: 14, color: SwarmColors.textMuted),
                contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: SwarmColors.border)),
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Actions
          _TopActionBtn('Fetch', Icons.sync, SwarmColors.agentSky, () async {
            final res = await GitLensService.instance.fetch(cwd: _workspacePath);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res)));
            }
            _refreshAll();
          }),
          const SizedBox(width: 6),
          _TopActionBtn('Pull', Icons.download_rounded, SwarmColors.agentEmerald, () async {
            final res = await GitLensService.instance.pull(cwd: _workspacePath);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res)));
            }
            _refreshAll();
          }),
          const SizedBox(width: 6),
          _TopActionBtn('Push', Icons.upload_rounded, SwarmColors.agentAmber, () async {
            final res = await GitLensService.instance.push(cwd: _workspacePath);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res)));
            }
            _refreshAll();
          }),
          const SizedBox(width: 10),
          ElevatedButton.icon(
            onPressed: () => context.push('/coder'),
            icon: const Icon(Icons.code_rounded, size: 14),
            label: const Text('Open Coder', style: TextStyle(fontSize: 11.5)),
            style: ElevatedButton.styleFrom(
              backgroundColor: SwarmColors.accent.withValues(alpha: 0.2),
              foregroundColor: SwarmColors.accent,
              side: const BorderSide(color: SwarmColors.accent),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }

  // ── Left Sidebar ────────────────────────────────────────────────────────────

  Widget _buildSidebar() {
    return Container(
      color: const Color(0xFF090D15),
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          // Repository Stats Pill
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF101522),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: SwarmColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('REPOSITORY METRICS', style: TextStyle(fontSize: 9.5, letterSpacing: 1, fontWeight: FontWeight.bold, color: SwarmColors.textMuted)),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _StatBadge('Commits', '${_commits.length}+', SwarmColors.agentCyan),
                    _StatBadge('Branches', '${_branches.length}', SwarmColors.agentEmerald),
                    _StatBadge('Stashes', '${_stashes.length}', SwarmColors.agentAmber),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // File History Switcher
          if (_inspectedFilePath != null) ...[
            Row(
              children: [
                const Icon(Icons.history_edu, size: 14, color: SwarmColors.agentCyan),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'History: ${_inspectedFilePath!.split("/").last}',
                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.white),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 14, color: SwarmColors.textMuted),
                  onPressed: () => setState(() => _inspectedFilePath = null),
                ),
              ],
            ),
            const Divider(color: SwarmColors.border),
          ],

          // Branches Section
          _SectionTitle('BRANCHES (${_branches.length})'),
          ..._branches.map((b) => InkWell(
                onTap: () async {
                  await GitLensService.instance.checkoutBranch(b.name, cwd: _workspacePath);
                  _refreshAll();
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 3),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: b.isCurrent ? SwarmColors.agentCyan.withValues(alpha: 0.12) : Colors.transparent,
                    borderRadius: BorderRadius.circular(4),
                    border: b.isCurrent ? Border.all(color: SwarmColors.agentCyan.withValues(alpha: 0.4)) : null,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        b.isRemote ? Icons.cloud_queue : Icons.call_split,
                        size: 13,
                        color: b.isCurrent ? SwarmColors.agentCyan : SwarmColors.textMuted,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          b.name,
                          style: TextStyle(
                            fontSize: 11,
                            fontFamily: 'monospace',
                            color: b.isCurrent ? Colors.white : SwarmColors.textSecondary,
                            fontWeight: b.isCurrent ? FontWeight.bold : FontWeight.normal,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (b.isCurrent)
                        const Icon(Icons.check, size: 13, color: SwarmColors.agentCyan),
                    ],
                  ),
                ),
              )),
          const SizedBox(height: 16),

          // Stashes Section
          _SectionTitle('STASHES (${_stashes.length})'),
          if (_stashes.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Text('No stashed commits', style: TextStyle(fontSize: 10.5, color: SwarmColors.textDisabled)),
            )
          else
            ..._stashes.map((s) => Container(
                  margin: const EdgeInsets.only(bottom: 4),
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF101522),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: SwarmColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text('stash@{${s.index}}', style: const TextStyle(fontSize: 10.5, fontFamily: 'monospace', color: SwarmColors.agentAmber, fontWeight: FontWeight.bold)),
                          const Spacer(),
                          Text(s.relativeDate, style: const TextStyle(fontSize: 9.5, color: SwarmColors.textMuted)),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(s.message, style: const TextStyle(fontSize: 10.5, color: SwarmColors.textSecondary)),
                    ],
                  ),
                )),
          const SizedBox(height: 16),

          // Quick Inspect Common Files
          const _SectionTitle('FILE REVISION TIMELINE'),
          _FileTimelineLink('frontend/pubspec.yaml', _inspectFile),
          _FileTimelineLink('frontend/lib/router.dart', _inspectFile),
          _FileTimelineLink('frontend/lib/coder/coder_page.dart', _inspectFile),
          _FileTimelineLink('install_swarm_os.sh', _inspectFile),
        ],
      ),
    );
  }

  // ── Visual Commit Graph / Log ───────────────────────────────────────────────

  Widget _buildCommitGraph() {
    final commitList = _inspectedFilePath != null ? _fileHistory : _commits;

    if (_loading && commitList.isEmpty) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 1.5, color: SwarmColors.accent));
    }

    if (commitList.isEmpty) {
      return const Center(child: Text('No commits match your criteria', style: TextStyle(color: SwarmColors.textMuted)));
    }

    return Column(
      children: [
        // Graph Header
        Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: const BoxDecoration(
            color: Color(0xFF0C101A),
            border: Border(bottom: BorderSide(color: SwarmColors.border)),
          ),
          child: const Row(
            children: [
              SizedBox(width: 32, child: Text('GRAPH', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: SwarmColors.textMuted))),
              SizedBox(width: 65, child: Text('SHA', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: SwarmColors.textMuted))),
              Expanded(child: Text('COMMIT MESSAGE', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: SwarmColors.textMuted))),
              SizedBox(width: 100, child: Text('AUTHOR', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: SwarmColors.textMuted))),
              SizedBox(width: 80, child: Text('DATE', textAlign: TextAlign.right, style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: SwarmColors.textMuted))),
            ],
          ),
        ),

        // Commits List
        Expanded(
          child: ListView.builder(
            itemCount: commitList.length,
            itemBuilder: (_, i) {
              final c = commitList[i];
              final isSelected = _selectedCommit?.hash == c.hash;

              return InkWell(
                onTap: () => _selectCommit(c),
                child: Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: isSelected ? SwarmColors.agentCyan.withValues(alpha: 0.12) : (i % 2 == 0 ? const Color(0xFF080B12) : Colors.transparent),
                    border: Border(
                      left: BorderSide(
                        color: isSelected ? SwarmColors.agentCyan : Colors.transparent,
                        width: 3,
                      ),
                      bottom: const BorderSide(color: Color(0xFF131824), width: 0.5),
                    ),
                  ),
                  child: Row(
                    children: [
                      // Graph node bullet
                      SizedBox(
                        width: 32,
                        child: Center(
                          child: Container(
                            width: 9,
                            height: 9,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isSelected ? SwarmColors.agentCyan : const Color(0xFF3B82F6),
                              boxShadow: isSelected ? [const BoxShadow(color: SwarmColors.agentCyan, blurRadius: 6)] : null,
                            ),
                          ),
                        ),
                      ),
                      // Short SHA
                      SizedBox(
                        width: 65,
                        child: Text(
                          c.shortHash,
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                            color: isSelected ? SwarmColors.agentCyan : SwarmColors.textMuted,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      // Commit Message + Branch Tags
                      Expanded(
                        child: Row(
                          children: [
                            if (c.refs.isNotEmpty) ...[
                              ...c.refs.take(2).map((r) => Container(
                                    margin: const EdgeInsets.only(right: 6),
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: SwarmColors.agentEmerald.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(3),
                                      border: Border.all(color: SwarmColors.agentEmerald.withValues(alpha: 0.5)),
                                    ),
                                    child: Text(r, style: const TextStyle(fontSize: 8.5, color: SwarmColors.agentEmerald, fontWeight: FontWeight.bold)),
                                  )),
                            ],
                            Expanded(
                              child: Text(
                                c.message,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: isSelected ? Colors.white : SwarmColors.textPrimary,
                                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Author
                      SizedBox(
                        width: 100,
                        child: Text(
                          c.author,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 10.5, color: SwarmColors.textSecondary),
                        ),
                      ),
                      // Relative Date
                      SizedBox(
                        width: 80,
                        child: Text(
                          c.relativeDate,
                          textAlign: TextAlign.right,
                          style: const TextStyle(fontSize: 10, color: SwarmColors.textMuted),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ── Right Column: Commit Inspector & Full Diff Viewer ───────────────────────

  Widget _buildCommitInspector() {
    if (_selectedCommit == null) {
      return const Center(child: Text('Select a commit to view diff & details', style: TextStyle(color: SwarmColors.textMuted)));
    }

    final c = _selectedCommit!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Commit Header Card
        Container(
          padding: const EdgeInsets.all(12),
          decoration: const BoxDecoration(
            color: Color(0xFF0C101A),
            border: Border(bottom: BorderSide(color: SwarmColors.border)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: SwarmColors.agentCyan.withValues(alpha: 0.2),
                    child: Text(
                      c.author.isNotEmpty ? c.author[0].toUpperCase() : '?',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: SwarmColors.agentCyan),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(c.author, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 12)),
                      Text(c.authorEmail, style: const TextStyle(fontSize: 10.5, color: SwarmColors.textMuted)),
                    ],
                  ),
                  const Spacer(),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(c.relativeDate, style: const TextStyle(fontSize: 11, color: SwarmColors.agentEmerald, fontWeight: FontWeight.w600)),
                      Text(c.date.toLocal().toString().split('.').first, style: const TextStyle(fontSize: 10, color: SwarmColors.textMuted)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SelectableText(
                c.message,
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: SwarmColors.textPrimary),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text('SHA: ${c.hash}', style: const TextStyle(fontSize: 10.5, fontFamily: 'monospace', color: SwarmColors.agentCyan)),
                  const Spacer(),
                  InkWell(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: c.hash));
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Commit SHA copied'), duration: Duration(seconds: 2)));
                    },
                    child: const Row(
                      children: [
                        Icon(Icons.copy, size: 12, color: SwarmColors.textMuted),
                        SizedBox(width: 4),
                        Text('Copy', style: TextStyle(fontSize: 10.5, color: SwarmColors.textMuted)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Diff Viewer
        Expanded(
          child: _diffLoading
              ? const Center(child: CircularProgressIndicator(strokeWidth: 1.5, color: SwarmColors.accent))
              : Container(
                  color: const Color(0xFF070A10),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(12),
                    child: SelectableText.rich(
                      TextSpan(
                        children: _commitDiff.split('\n').map((line) {
                          Color c = SwarmColors.textSecondary;
                          Color? bg;
                          if (line.startsWith('+')) {
                            c = SwarmColors.agentEmerald;
                            bg = const Color(0x1810B981);
                          } else if (line.startsWith('-')) {
                            c = SwarmColors.agentRose;
                            bg = const Color(0x18EF4444);
                          } else if (line.startsWith('@@')) {
                            c = SwarmColors.agentCyan;
                            bg = const Color(0x1400D2FF);
                          } else if (line.startsWith('diff') || line.startsWith('index') || line.startsWith('+++') || line.startsWith('---')) {
                            c = SwarmColors.textMuted;
                          }
                          return TextSpan(
                            text: '$line\n',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 11,
                              color: c,
                              backgroundColor: bg,
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

class _StatBadge extends StatelessWidget {
  final String label, val;
  final Color color;
  const _StatBadge(this.label, this.val, this.color);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(val, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: const TextStyle(fontSize: 9.5, color: SwarmColors.textMuted)),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(text, style: const TextStyle(fontSize: 9.5, letterSpacing: 0.8, fontWeight: FontWeight.bold, color: SwarmColors.textMuted)),
    );
  }
}

class _FileTimelineLink extends StatelessWidget {
  final String path;
  final ValueChanged<String> onSelect;
  const _FileTimelineLink(this.path, this.onSelect);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onSelect(path),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 4),
        child: Row(
          children: [
            const Icon(Icons.description_outlined, size: 12, color: SwarmColors.textMuted),
            const SizedBox(width: 6),
            Expanded(child: Text(path.split('/').last, style: const TextStyle(fontSize: 10.5, fontFamily: 'monospace', color: SwarmColors.textSecondary), overflow: TextOverflow.ellipsis)),
          ],
        ),
      ),
    );
  }
}

class _TopActionBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _TopActionBtn(this.label, this.icon, this.color, this.onTap);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }
}

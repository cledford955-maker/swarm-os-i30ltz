import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/swarm_colors.dart';

enum DiffViewMode { sideBySide, unified }

enum DiffLineType { unchanged, added, deleted, header }

class DiffLine {
  final DiffLineType type;
  final String text;
  final int? oldLineNumber;
  final int? newLineNumber;

  const DiffLine({
    required this.type,
    required this.text,
    this.oldLineNumber,
    this.newLineNumber,
  });
}

class DiffHunk {
  final int oldStart;
  final int oldCount;
  final int newStart;
  final int newCount;
  final List<DiffLine> lines;

  const DiffHunk({
    required this.oldStart,
    required this.oldCount,
    required this.newStart,
    required this.newCount,
    required this.lines,
  });
}

class DiffResult {
  final List<DiffLine> allLines;
  final List<DiffHunk> hunks;
  final int additions;
  final int deletions;

  const DiffResult({
    required this.allLines,
    required this.hunks,
    required this.additions,
    required this.deletions,
  });
}

class DiffViewerWidget extends StatefulWidget {
  final String oldText;
  final String newText;
  final String? oldTitle;
  final String? newTitle;
  final DiffViewMode initialMode;
  final void Function(DiffHunk hunk)? onStageHunk;
  final void Function(DiffHunk hunk)? onRevertHunk;

  const DiffViewerWidget({
    super.key,
    required this.oldText,
    required this.newText,
    this.oldTitle = 'Original',
    this.newTitle = 'Modified',
    this.initialMode = DiffViewMode.sideBySide,
    this.onStageHunk,
    this.onRevertHunk,
  });

  @override
  State<DiffViewerWidget> createState() => _DiffViewerWidgetState();
}

class _DiffViewerWidgetState extends State<DiffViewerWidget> {
  late DiffViewMode _viewMode;
  bool _ignoreWhitespace = false;
  late DiffResult _diffResult;
  int _currentHunkIndex = 0;
  final ScrollController _scrollCtrlLeft = ScrollController();
  final ScrollController _scrollCtrlRight = ScrollController();
  final ScrollController _scrollCtrlUnified = ScrollController();
  bool _syncingScroll = false;

  @override
  void initState() {
    super.initState();
    _viewMode = widget.initialMode;
    _computeDiff();

    _scrollCtrlLeft.addListener(() {
      if (_syncingScroll || _viewMode != DiffViewMode.sideBySide) return;
      _syncingScroll = true;
      if (_scrollCtrlRight.hasClients && _scrollCtrlRight.offset != _scrollCtrlLeft.offset) {
        _scrollCtrlRight.jumpTo(_scrollCtrlLeft.offset);
      }
      _syncingScroll = false;
    });

    _scrollCtrlRight.addListener(() {
      if (_syncingScroll || _viewMode != DiffViewMode.sideBySide) return;
      _syncingScroll = true;
      if (_scrollCtrlLeft.hasClients && _scrollCtrlLeft.offset != _scrollCtrlRight.offset) {
        _scrollCtrlLeft.jumpTo(_scrollCtrlRight.offset);
      }
      _syncingScroll = false;
    });
  }

  @override
  void didUpdateWidget(covariant DiffViewerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.oldText != widget.oldText || oldWidget.newText != widget.newText) {
      _computeDiff();
    }
  }

  @override
  void dispose() {
    _scrollCtrlLeft.dispose();
    _scrollCtrlRight.dispose();
    _scrollCtrlUnified.dispose();
    super.dispose();
  }

  void _computeDiff() {
    final oldLines = widget.oldText.split('\n');
    final newLines = widget.newText.split('\n');

    _diffResult = _generateDiff(oldLines, newLines, ignoreWhitespace: _ignoreWhitespace);
    if (_currentHunkIndex >= _diffResult.hunks.length) {
      _currentHunkIndex = (_diffResult.hunks.isEmpty) ? 0 : _diffResult.hunks.length - 1;
    }
    if (mounted) setState(() {});
  }

  static DiffResult _generateDiff(List<String> a, List<String> b, {bool ignoreWhitespace = false}) {
    final cleanA = ignoreWhitespace ? a.map((s) => s.trim()).toList() : a;
    final cleanB = ignoreWhitespace ? b.map((s) => s.trim()).toList() : b;

    final n = cleanA.length;
    final m = cleanB.length;

    // LCS table for diffing
    final dp = List.generate(n + 1, (_) => List.filled(m + 1, 0));
    for (int i = 1; i <= n; i++) {
      for (int j = 1; j <= m; j++) {
        if (cleanA[i - 1] == cleanB[j - 1]) {
          dp[i][j] = dp[i - 1][j - 1] + 1;
        } else {
          dp[i][j] = dp[i - 1][j] > dp[i][j - 1] ? dp[i - 1][j] : dp[i][j - 1];
        }
      }
    }

    final diffLines = <DiffLine>[];
    int i = n;
    int j = m;
    int additions = 0;
    int deletions = 0;

    final temp = <DiffLine>[];
    while (i > 0 || j > 0) {
      if (i > 0 && j > 0 && cleanA[i - 1] == cleanB[j - 1]) {
        temp.add(DiffLine(type: DiffLineType.unchanged, text: a[i - 1], oldLineNumber: i, newLineNumber: j));
        i--;
        j--;
      } else if (j > 0 && (i == 0 || dp[i][j - 1] >= dp[i - 1][j])) {
        temp.add(DiffLine(type: DiffLineType.added, text: b[j - 1], newLineNumber: j));
        additions++;
        j--;
      } else if (i > 0 && (j == 0 || dp[i][j - 1] < dp[i - 1][j])) {
        temp.add(DiffLine(type: DiffLineType.deleted, text: a[i - 1], oldLineNumber: i));
        deletions++;
        i--;
      }
    }

    diffLines.addAll(temp.reversed);

    // Group into hunks
    final hunks = <DiffHunk>[];
    List<DiffLine> currentHunkLines = [];
    int hunkOldStart = 1;
    int hunkNewStart = 1;
    int oldCount = 0;
    int newCount = 0;
    bool inHunk = false;

    for (final line in diffLines) {
      if (line.type != DiffLineType.unchanged) {
        if (!inHunk) {
          inHunk = true;
          hunkOldStart = line.oldLineNumber ?? 1;
          hunkNewStart = line.newLineNumber ?? 1;
          oldCount = 0;
          newCount = 0;
          currentHunkLines = [];
        }
        currentHunkLines.add(line);
        if (line.type == DiffLineType.deleted) oldCount++;
        if (line.type == DiffLineType.added) newCount++;
      } else {
        if (inHunk) {
          // Include small context then close hunk
          hunks.add(DiffHunk(
            oldStart: hunkOldStart,
            oldCount: oldCount,
            newStart: hunkNewStart,
            newCount: newCount,
            lines: List.from(currentHunkLines),
          ));
          inHunk = false;
        }
      }
    }

    if (inHunk) {
      hunks.add(DiffHunk(
        oldStart: hunkOldStart,
        oldCount: oldCount,
        newStart: hunkNewStart,
        newCount: newCount,
        lines: List.from(currentHunkLines),
      ));
    }

    return DiffResult(allLines: diffLines, hunks: hunks, additions: additions, deletions: deletions);
  }

  void _jumpToNextHunk() {
    if (_diffResult.hunks.isEmpty) return;
    setState(() {
      _currentHunkIndex = (_currentHunkIndex + 1) % _diffResult.hunks.length;
    });
    _scrollToCurrentHunk();
  }

  void _jumpToPrevHunk() {
    if (_diffResult.hunks.isEmpty) return;
    setState(() {
      _currentHunkIndex = (_currentHunkIndex - 1 + _diffResult.hunks.length) % _diffResult.hunks.length;
    });
    _scrollToCurrentHunk();
  }

  void _scrollToCurrentHunk() {
    if (_diffResult.hunks.isEmpty) return;
    final targetHunk = _diffResult.hunks[_currentHunkIndex];
    // Find index in diffLines
    final lineIdx = _diffResult.allLines.indexWhere((l) =>
        (l.type == DiffLineType.added && l.newLineNumber == targetHunk.newStart) ||
        (l.type == DiffLineType.deleted && l.oldLineNumber == targetHunk.oldStart));

    if (lineIdx >= 0) {
      final offset = (lineIdx * 22.0).clamp(0.0, 999999.0);
      if (_viewMode == DiffViewMode.sideBySide) {
        if (_scrollCtrlLeft.hasClients) _scrollCtrlLeft.animateTo(offset, duration: const Duration(milliseconds: 250), curve: Curves.easeInOut);
        if (_scrollCtrlRight.hasClients) _scrollCtrlRight.animateTo(offset, duration: const Duration(milliseconds: 250), curve: Curves.easeInOut);
      } else {
        if (_scrollCtrlUnified.hasClients) _scrollCtrlUnified.animateTo(offset, duration: const Duration(milliseconds: 250), curve: Curves.easeInOut);
      }
    }
  }

  void _copyPatch() {
    final buffer = StringBuffer();
    buffer.writeln('--- a/${widget.oldTitle ?? 'old'}');
    buffer.writeln('+++ b/${widget.newTitle ?? 'new'}');
    for (final hunk in _diffResult.hunks) {
      buffer.writeln('@@ -${hunk.oldStart},${hunk.oldCount} +${hunk.newStart},${hunk.newCount} @@');
      for (final line in hunk.lines) {
        if (line.type == DiffLineType.added) {
          buffer.writeln('+${line.text}');
        } else if (line.type == DiffLineType.deleted) {
          buffer.writeln('-${line.text}');
        } else {
          buffer.writeln(' ${line.text}');
        }
      }
    }
    Clipboard.setData(ClipboardData(text: buffer.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Unified diff patch copied to clipboard'),
        backgroundColor: SwarmColors.bgElevated,
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: SwarmColors.bgBase,
      child: Column(
        children: [
          // Diff Toolbar
          _buildToolbar(),
          // Main diff view
          Expanded(
            child: _diffResult.allLines.isEmpty
                ? const Center(
                    child: Text('Files are identical (No changes)', style: TextStyle(color: SwarmColors.textMuted)),
                  )
                : _viewMode == DiffViewMode.sideBySide
                    ? _buildSideBySideView()
                    : _buildUnifiedView(),
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar() {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: const BoxDecoration(
        color: SwarmColors.bgSurface,
        border: Border(bottom: BorderSide(color: SwarmColors.border)),
      ),
      child: Row(
        children: [
          // View Mode Selector
          SegmentedButton<DiffViewMode>(
            segments: const [
              ButtonSegment(
                value: DiffViewMode.sideBySide,
                label: Text('Split', style: TextStyle(fontSize: 11)),
                icon: Icon(Icons.vertical_split_rounded, size: 14),
              ),
              ButtonSegment(
                value: DiffViewMode.unified,
                label: Text('Unified', style: TextStyle(fontSize: 11)),
                icon: Icon(Icons.view_agenda_rounded, size: 14),
              ),
            ],
            selected: {_viewMode},
            onSelectionChanged: (val) => setState(() => _viewMode = val.first),
            style: ButtonStyle(
              visualDensity: VisualDensity.compact,
              textStyle: WidgetStateProperty.all(const TextStyle(fontSize: 11)),
              backgroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) return SwarmColors.accent.withAlpha(50);
                return Colors.transparent;
              }),
            ),
          ),
          const SizedBox(width: 12),
          // Stats Pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: SwarmColors.bgElevated,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: SwarmColors.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('+${_diffResult.additions}', style: const TextStyle(color: SwarmColors.agentEmerald, fontSize: 11, fontWeight: FontWeight.bold)),
                const SizedBox(width: 6),
                Text('-${_diffResult.deletions}', style: const TextStyle(color: SwarmColors.agentRose, fontSize: 11, fontWeight: FontWeight.bold)),
                if (_diffResult.hunks.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Text('${_diffResult.hunks.length} hunks', style: const TextStyle(color: SwarmColors.textMuted, fontSize: 10)),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Hunk Navigation
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_up, size: 18),
            tooltip: 'Previous Hunk (Alt+Up)',
            color: SwarmColors.textSecondary,
            onPressed: _diffResult.hunks.isEmpty ? null : _jumpToPrevHunk,
          ),
          if (_diffResult.hunks.isNotEmpty)
            Text('${_currentHunkIndex + 1}/${_diffResult.hunks.length}', style: const TextStyle(color: SwarmColors.textMuted, fontSize: 11)),
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_down, size: 18),
            tooltip: 'Next Hunk (Alt+Down)',
            color: SwarmColors.textSecondary,
            onPressed: _diffResult.hunks.isEmpty ? null : _jumpToNextHunk,
          ),
          const Spacer(),
          // Ignore Whitespace Toggle
          FilterChip(
            label: const Text('Ignore Whitespace', style: TextStyle(fontSize: 10)),
            selected: _ignoreWhitespace,
            onSelected: (val) {
              setState(() => _ignoreWhitespace = val);
              _computeDiff();
            },
            visualDensity: VisualDensity.compact,
            backgroundColor: Colors.transparent,
            selectedColor: SwarmColors.accent.withAlpha(40),
            checkmarkColor: SwarmColors.accent,
          ),
          const SizedBox(width: 8),
          // Copy Patch
          OutlinedButton.icon(
            icon: const Icon(Icons.copy_rounded, size: 13),
            label: const Text('Patch', style: TextStyle(fontSize: 11)),
            onPressed: _copyPatch,
            style: OutlinedButton.styleFrom(
              visualDensity: VisualDensity.compact,
              foregroundColor: SwarmColors.textSecondary,
              side: const BorderSide(color: SwarmColors.border),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSideBySideView() {
    final oldLines = <DiffLine>[];
    final newLines = <DiffLine>[];

    for (final line in _diffResult.allLines) {
      if (line.type == DiffLineType.unchanged) {
        oldLines.add(line);
        newLines.add(line);
      } else if (line.type == DiffLineType.deleted) {
        oldLines.add(line);
        newLines.add(const DiffLine(type: DiffLineType.header, text: ''));
      } else if (line.type == DiffLineType.added) {
        oldLines.add(const DiffLine(type: DiffLineType.header, text: ''));
        newLines.add(line);
      }
    }

    return Row(
      children: [
        // Left Column (Old/Original)
        Expanded(
          child: Column(
            children: [
              _buildColumnHeader(widget.oldTitle ?? 'Original', SwarmColors.agentRose.withAlpha(30)),
              Expanded(
                child: ListView.builder(
                  controller: _scrollCtrlLeft,
                  itemCount: oldLines.length,
                  itemExtent: 22,
                  itemBuilder: (context, index) {
                    final line = oldLines[index];
                    return _buildLineRow(line, isLeft: true);
                  },
                ),
              ),
            ],
          ),
        ),
        Container(width: 1, color: SwarmColors.border),
        // Right Column (New/Modified)
        Expanded(
          child: Column(
            children: [
              _buildColumnHeader(widget.newTitle ?? 'Modified', SwarmColors.agentEmerald.withAlpha(30)),
              Expanded(
                child: ListView.builder(
                  controller: _scrollCtrlRight,
                  itemCount: newLines.length,
                  itemExtent: 22,
                  itemBuilder: (context, index) {
                    final line = newLines[index];
                    return _buildLineRow(line, isLeft: false);
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildColumnHeader(String title, Color bgColor) {
    return Container(
      height: 24,
      width: double.infinity,
      color: bgColor,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Text(
        title,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: SwarmColors.textSecondary),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildLineRow(DiffLine line, {required bool isLeft}) {
    Color bg = Colors.transparent;
    Color fg = SwarmColors.textPrimary;
    Color numColor = SwarmColors.textDisabled;

    if (line.type == DiffLineType.deleted) {
      bg = SwarmColors.agentRose.withAlpha(35);
      fg = const Color(0xFFFFA3A3);
      numColor = SwarmColors.agentRose;
    } else if (line.type == DiffLineType.added) {
      bg = SwarmColors.agentEmerald.withAlpha(35);
      fg = const Color(0xFFA3FFA3);
      numColor = SwarmColors.agentEmerald;
    } else if (line.type == DiffLineType.header) {
      bg = SwarmColors.bgSurface.withAlpha(80);
      fg = Colors.transparent;
    }

    final lineNum = isLeft ? line.oldLineNumber?.toString() ?? '' : line.newLineNumber?.toString() ?? '';

    return Container(
      height: 22,
      color: bg,
      child: Row(
        children: [
          Container(
            width: 44,
            padding: const EdgeInsets.only(right: 8),
            alignment: Alignment.centerRight,
            color: SwarmColors.bgSurface.withAlpha(50),
            child: Text(
              lineNum,
              style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: numColor),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              line.text,
              style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: fg),
              maxLines: 1,
              overflow: TextOverflow.clip,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUnifiedView() {
    return ListView.builder(
      controller: _scrollCtrlUnified,
      itemCount: _diffResult.allLines.length,
      itemExtent: 22,
      itemBuilder: (context, index) {
        final line = _diffResult.allLines[index];
        Color bg = Colors.transparent;
        Color fg = SwarmColors.textPrimary;
        String prefix = ' ';

        if (line.type == DiffLineType.deleted) {
          bg = SwarmColors.agentRose.withAlpha(35);
          fg = const Color(0xFFFFA3A3);
          prefix = '-';
        } else if (line.type == DiffLineType.added) {
          bg = SwarmColors.agentEmerald.withAlpha(35);
          fg = const Color(0xFFA3FFA3);
          prefix = '+';
        }

        return Container(
          height: 22,
          color: bg,
          child: Row(
            children: [
              Container(
                width: 36,
                padding: const EdgeInsets.only(right: 6),
                alignment: Alignment.centerRight,
                child: Text(
                  line.oldLineNumber?.toString() ?? '',
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 10, color: SwarmColors.textDisabled),
                ),
              ),
              Container(
                width: 36,
                padding: const EdgeInsets.only(right: 6),
                alignment: Alignment.centerRight,
                child: Text(
                  line.newLineNumber?.toString() ?? '',
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 10, color: SwarmColors.textDisabled),
                ),
              ),
              Container(
                width: 18,
                alignment: Alignment.center,
                child: Text(
                  prefix,
                  style: TextStyle(fontFamily: 'monospace', fontSize: 11, fontWeight: FontWeight.bold, color: fg),
                ),
              ),
              Expanded(
                child: Text(
                  line.text,
                  style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: fg),
                  maxLines: 1,
                  overflow: TextOverflow.clip,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

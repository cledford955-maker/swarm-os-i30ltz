// ═══════════════════════════════════════════════════════════════
// Lucille's Team Brief, native in SWARM OS (2026-10-15)
//
// Every statement is commentable; tap one to open its thread, post a
// comment, or Ask Lucille / Ask Boltz / Ask Claude right there. Mirrors
// the web Brief (Lucille Assistant web/lucille-team.js) as a native tab.
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/lucille_brief.dart';
import '../providers/lucille_assistant_providers.dart';
import '../theme/swarm_colors.dart';
import '../theme/swarm_text_styles.dart';

class LucilleTeamBriefTab extends ConsumerWidget {
  const LucilleTeamBriefTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final briefAsync = ref.watch(teamBriefProvider);

    return briefAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _ErrorPane(
        message: 'Could not reach Lucille Assistant.\n$e',
        onRetry: () => ref.read(teamBriefProvider.notifier).refresh(),
      ),
      data: (brief) {
        if (brief.sections.isEmpty) {
          return Center(
            child: Text('Nothing in the Brief yet.', style: SwarmTextStyles.body),
          );
        }
        return RefreshIndicator(
          onRefresh: () => ref.read(teamBriefProvider.notifier).refresh(),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: brief.sections.length,
            itemBuilder: (context, i) => _SectionCard(section: brief.sections[i], brief: brief),
          ),
        );
      },
    );
  }
}

class _ErrorPane extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorPane({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_off, color: SwarmColors.textMuted, size: 32),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(message, textAlign: TextAlign.center, style: SwarmTextStyles.bodySmall),
          ),
          const SizedBox(height: 10),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final BriefSection section;
  final TeamBrief brief;
  const _SectionCard({required this.section, required this.brief});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(section.title, style: SwarmTextStyles.h3),
          if (section.note.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(section.note, style: SwarmTextStyles.bodySmall),
          ],
          const SizedBox(height: 8),
          ...section.items.map((s) => _StatementRow(
                statement: s,
                threads: brief.threads[s.anchor] ?? const [],
                jobs: brief.jobs[s.anchor] ?? const [],
              )),
        ],
      ),
    );
  }
}

Color _levelColor(String level) {
  switch (level) {
    case 'ok':
      return SwarmColors.statusOnline;
    case 'warn':
      return SwarmColors.statusIdle;
    case 'bad':
      return SwarmColors.statusCritical;
    default:
      return SwarmColors.textMuted;
  }
}

class _StatementRow extends ConsumerWidget {
  final Statement statement;
  final List<ThreadMsg> threads;
  final List<CoderJob> jobs;
  const _StatementRow({required this.statement, required this.threads, required this.jobs});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expanded = ref.watch(expandedAnchorProvider) == statement.anchor;
    final color = _levelColor(statement.level);

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: SwarmColors.bgSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: expanded ? SwarmColors.accent.withValues(alpha: 0.4) : SwarmColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => ref.read(expandedAnchorProvider.notifier).state =
                expanded ? null : statement.anchor,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 5),
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if (statement.tag.isNotEmpty) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                                child: Text(statement.tag,
                                    style: SwarmTextStyles.labelSmall.copyWith(color: color)),
                              ),
                              const SizedBox(width: 6),
                            ],
                            if (threads.isNotEmpty)
                              Icon(Icons.forum_outlined, size: 13, color: SwarmColors.textMuted),
                            if (threads.isNotEmpty) const SizedBox(width: 3),
                            if (threads.isNotEmpty)
                              Text('${threads.length}', style: SwarmTextStyles.labelSmall),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(statement.text, style: SwarmTextStyles.body),
                        if (statement.sub.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(statement.sub, style: SwarmTextStyles.bodySmall),
                          ),
                      ],
                    ),
                  ),
                  Icon(expanded ? Icons.expand_less : Icons.expand_more,
                      color: SwarmColors.textMuted, size: 18),
                ],
              ),
            ),
          ),
          if (expanded)
            _ThreadPanel(anchor: statement.anchor, quote: statement.text, threads: threads, jobs: jobs),
        ],
      ),
    );
  }
}

class _ThreadPanel extends ConsumerStatefulWidget {
  final String anchor;
  final String quote;
  final List<ThreadMsg> threads;
  final List<CoderJob> jobs;
  const _ThreadPanel({
    required this.anchor,
    required this.quote,
    required this.threads,
    required this.jobs,
  });

  @override
  ConsumerState<_ThreadPanel> createState() => _ThreadPanelState();
}

class _ThreadPanelState extends ConsumerState<_ThreadPanel> {
  final _controller = TextEditingController();
  bool _posting = false;
  String? _asking; // "lucille" | "boltz" | "claude" while a reply is pending

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _post() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _posting) return;
    setState(() => _posting = true);
    try {
      await ref.read(lucilleAssistantClientProvider)
          .postThread(anchor: widget.anchor, text: text, quote: widget.quote);
      _controller.clear();
      await ref.read(teamBriefProvider.notifier).refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _posting = false);
    }
  }

  Future<void> _ask(String who) async {
    if (_asking != null) return;
    setState(() => _asking = who);
    try {
      await ref.read(lucilleAssistantClientProvider).askThread(anchor: widget.anchor, who: who);
      // The reply is generated async on the server; poll a few times.
      for (var i = 0; i < 6 && mounted; i++) {
        await Future.delayed(const Duration(seconds: 3));
        await ref.read(teamBriefProvider.notifier).refresh();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _asking = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: SwarmColors.borderSubtle)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          ...widget.threads.map((m) => _MsgBubble(msg: m)),
          ...widget.jobs.map((j) => _JobBubble(job: j)),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  style: SwarmTextStyles.bodySmall,
                  decoration: const InputDecoration(
                    hintText: 'Comment on this…',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _post(),
                ),
              ),
              const SizedBox(width: 6),
              IconButton(
                icon: _posting
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.send, size: 18),
                color: SwarmColors.accent,
                onPressed: _posting ? null : _post,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            children: [
              _askChip('Ask Lucille', 'lucille'),
              _askChip('Ask Boltz', 'boltz'),
              _askChip('Ask Claude', 'claude'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _askChip(String label, String who) {
    final busy = _asking == who;
    return ActionChip(
      avatar: busy
          ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2))
          : null,
      label: Text(label, style: SwarmTextStyles.labelSmall),
      onPressed: _asking == null ? () => _ask(who) : null,
    );
  }
}

class _MsgBubble extends StatelessWidget {
  final ThreadMsg msg;
  const _MsgBubble({required this.msg});

  @override
  Widget build(BuildContext context) {
    final isAI = msg.by == 'lucille' || msg.by == 'boltz' || msg.by == 'claude';
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(msg.displayName,
                  style: SwarmTextStyles.labelSmall.copyWith(
                      color: isAI ? SwarmColors.accent : SwarmColors.textSecondary)),
              if (msg.kind == 'coder') ...[
                const SizedBox(width: 4),
                Icon(Icons.code, size: 11, color: SwarmColors.textMuted),
              ],
            ],
          ),
          Text(
            msg.text,
            style: SwarmTextStyles.bodySmall.copyWith(
              color: msg.err ? SwarmColors.statusCritical : SwarmColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _JobBubble extends StatelessWidget {
  final CoderJob job;
  const _JobBubble({required this.job});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.assignment_outlined, size: 13, color: SwarmColors.textMuted),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              '${job.to} · ${job.status}: ${job.prompt}',
              style: SwarmTextStyles.labelSmall,
            ),
          ),
        ],
      ),
    );
  }
}

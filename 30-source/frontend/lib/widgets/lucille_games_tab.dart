// ═══════════════════════════════════════════════════════════════
// Lucille's Games tab, native in SWARM OS (2026-10-15)
//
// Search a title, read its description/reviews/price, like/dislike or
// wish-list it. Backed by Lucille Assistant's games.go (Steam store,
// CheapShark, Wikipedia — no key, no account).
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/lucille_game.dart';
import '../providers/lucille_assistant_providers.dart';
import '../theme/swarm_colors.dart';
import '../theme/swarm_text_styles.dart';

class LucilleGamesTab extends ConsumerStatefulWidget {
  const LucilleGamesTab({super.key});

  @override
  ConsumerState<LucilleGamesTab> createState() => _LucilleGamesTabState();
}

class _LucilleGamesTabState extends ConsumerState<LucilleGamesTab> {
  final _searchController = TextEditingController();
  List<SteamHit>? _results;
  bool _searching = false;
  String? _searchError;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final q = _searchController.text.trim();
    if (q.isEmpty) {
      setState(() {
        _results = null;
        _searchError = null;
      });
      return;
    }
    setState(() {
      _searching = true;
      _searchError = null;
    });
    try {
      final hits = await ref.read(lucilleAssistantClientProvider).searchGames(q);
      if (mounted) setState(() => _results = hits);
    } catch (e) {
      if (mounted) setState(() => _searchError = '$e');
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  void _openCard({int appId = 0, String title = ''}) {
    showDialog(
      context: context,
      builder: (_) => _GameCardDialog(appId: appId, title: title),
    ).then((_) => ref.read(gameMarksProvider.notifier).refresh());
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  style: SwarmTextStyles.body,
                  decoration: const InputDecoration(
                    hintText: 'Search a game…',
                    prefixIcon: Icon(Icons.search, size: 18),
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _search(),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _searching ? null : _search,
                child: _searching
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Search'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _results == null
                ? const _MarksList()
                : _searchError != null
                    ? Center(child: Text(_searchError!, style: SwarmTextStyles.bodySmall))
                    : _SearchResults(results: _results!, onTap: _openCard),
          ),
        ],
      ),
    );
  }
}

class _SearchResults extends StatelessWidget {
  final List<SteamHit> results;
  final void Function({int appId, String title}) onTap;
  const _SearchResults({required this.results, required this.onTap});

  @override
  Widget build(BuildContext context) {
    if (results.isEmpty) {
      return Center(child: Text('No matches.', style: SwarmTextStyles.bodySmall));
    }
    return ListView.separated(
      itemCount: results.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (context, i) {
        final h = results[i];
        return _GameListRow(
          name: h.name,
          image: h.image,
          sub: [if (h.price.isNotEmpty) h.price, if (h.metascore.isNotEmpty) 'Meta ${h.metascore}'].join(' · '),
          mark: h.mark,
          onTap: () => onTap(appId: h.appId, title: h.name),
        );
      },
    );
  }
}

class _MarksList extends ConsumerWidget {
  const _MarksList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final marksAsync = ref.watch(gameMarksProvider);
    return marksAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e', style: SwarmTextStyles.bodySmall)),
      data: (marks) {
        if (marks.isEmpty) {
          return Center(
            child: Text('Search above to find a game, then like, dislike or wish-list it.',
                textAlign: TextAlign.center, style: SwarmTextStyles.bodySmall),
          );
        }
        return ListView.separated(
          itemCount: marks.length,
          separatorBuilder: (_, __) => const SizedBox(height: 6),
          itemBuilder: (context, i) {
            final m = marks[i];
            return _GameListRow(
              name: m.name,
              image: m.image,
              sub: [
                if (m.like == 'like') '👍 Liked',
                if (m.like == 'dislike') '👎 Disliked',
                if (m.wish) '♡ Wish list',
              ].join(' · '),
              mark: m,
              onTap: () => showDialog(
                context: context,
                builder: (_) => _GameCardDialog(appId: m.appId, title: m.name),
              ).then((_) => ref.read(gameMarksProvider.notifier).refresh()),
            );
          },
        );
      },
    );
  }
}

class _GameListRow extends StatelessWidget {
  final String name;
  final String image;
  final String sub;
  final GameMark? mark;
  final VoidCallback onTap;
  const _GameListRow({required this.name, required this.image, required this.sub, this.mark, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: SwarmColors.bgSurface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: SwarmColors.border),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: image.isEmpty
                  ? Container(width: 64, height: 30, color: SwarmColors.bgElevated)
                  : Image.network(image, width: 64, height: 30, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(width: 64, height: 30, color: SwarmColors.bgElevated)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: SwarmTextStyles.body, maxLines: 1, overflow: TextOverflow.ellipsis),
                  if (sub.isNotEmpty)
                    Text(sub, style: SwarmTextStyles.bodySmall),
                ],
              ),
            ),
            if (mark?.like == 'like') const Icon(Icons.thumb_up, size: 14, color: SwarmColors.statusOnline),
            if (mark?.like == 'dislike') const Icon(Icons.thumb_down, size: 14, color: SwarmColors.statusCritical),
            if (mark?.wish == true) const Padding(
              padding: EdgeInsets.only(left: 4),
              child: Icon(Icons.favorite, size: 14, color: SwarmColors.statusIdle),
            ),
          ],
        ),
      ),
    );
  }
}

class _GameCardDialog extends ConsumerStatefulWidget {
  final int appId;
  final String title;
  const _GameCardDialog({required this.appId, required this.title});

  @override
  ConsumerState<_GameCardDialog> createState() => _GameCardDialogState();
}

class _GameCardDialogState extends ConsumerState<_GameCardDialog> {
  GameCard? _card;
  String? _error;
  bool _marking = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final card = await ref.read(lucilleAssistantClientProvider)
          .fetchGame(appId: widget.appId, title: widget.title);
      if (mounted) setState(() => _card = card);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  Future<void> _mark({String? like, bool? wish}) async {
    final card = _card;
    if (card == null || _marking) return;
    setState(() => _marking = true);
    try {
      await ref.read(lucilleAssistantClientProvider).setGameMark(
            appId: card.appId,
            name: card.name,
            image: card.image,
            like: like,
            wish: wish,
          );
      await _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _marking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: SwarmColors.bgElevated,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 560),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: _error != null
              ? Text(_error!, style: SwarmTextStyles.bodySmall)
              : _card == null
                  ? const Center(child: CircularProgressIndicator())
                  : _body(_card!),
        ),
      ),
    );
  }

  Widget _body(GameCard c) {
    final mark = c.mark;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (c.image.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(c.image, fit: BoxFit.cover, height: 140, width: double.infinity,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink()),
            ),
          const SizedBox(height: 10),
          Text(c.name, style: SwarmTextStyles.h3),
          if (c.genres.isNotEmpty || c.release.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text([c.release, c.genres.join(', ')].where((s) => s.isNotEmpty).join(' · '),
                  style: SwarmTextStyles.bodySmall),
            ),
          const SizedBox(height: 8),
          if (c.description.isNotEmpty) Text(c.description, style: SwarmTextStyles.bodySmall),
          if (c.webExtract.isNotEmpty) Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(c.webExtract, style: SwarmTextStyles.bodySmall.copyWith(fontStyle: FontStyle.italic)),
          ),
          const SizedBox(height: 10),
          Wrap(spacing: 10, runSpacing: 4, children: [
            if (c.price.isNotEmpty) _stat('Price', c.price),
            if (c.metacritic > 0) _stat('Metacritic', '${c.metacritic}'),
            if (c.reviewWord.isNotEmpty) _stat('Reviews', '${c.reviewWord} (${c.reviewPct}%)'),
            if (c.lowestEver.isNotEmpty) _stat('Lowest ever', c.lowestEver),
          ]),
          const SizedBox(height: 14),
          Row(
            children: [
              _markButton(
                icon: Icons.thumb_up,
                active: mark?.like == 'like',
                color: SwarmColors.statusOnline,
                onTap: () => _mark(like: mark?.like == 'like' ? '' : 'like'),
              ),
              const SizedBox(width: 6),
              _markButton(
                icon: Icons.thumb_down,
                active: mark?.like == 'dislike',
                color: SwarmColors.statusCritical,
                onTap: () => _mark(like: mark?.like == 'dislike' ? '' : 'dislike'),
              ),
              const SizedBox(width: 6),
              _markButton(
                icon: Icons.favorite,
                active: mark?.wish == true,
                color: SwarmColors.statusIdle,
                onTap: () => _mark(wish: !(mark?.wish ?? false)),
              ),
              const Spacer(),
              TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stat(String label, String value) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: SwarmTextStyles.labelSmall),
          Text(value, style: SwarmTextStyles.bodySmall),
        ],
      );

  Widget _markButton({required IconData icon, required bool active, required Color color, required VoidCallback onTap}) {
    return IconButton(
      onPressed: _marking ? null : onTap,
      icon: Icon(icon, color: active ? color : SwarmColors.textMuted),
      style: IconButton.styleFrom(
        backgroundColor: active ? color.withValues(alpha: 0.15) : null,
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'honeycomb_grid.dart';
import 'hex_player_card_content.dart';

/// A scrollable viewport that wraps the HoneycombGrid.
/// Stretches ~2 pages vertically and allows scrolling/panning.
class HoneycombViewport extends StatefulWidget {
  final List<HoneycombCardData> cards;
  final int columns;
  final int totalRows;
  final double hexWidth;
  final double spacing;
  final void Function(String cardId, int fromSlot, int toSlot)? onCardMoved;
  final void Function(HoneycombCardData card)? onCardTap;

  const HoneycombViewport({
    super.key,
    required this.cards,
    this.columns = 5,
    this.totalRows = 14,
    this.hexWidth = 180,
    this.spacing = 6,
    this.onCardMoved,
    this.onCardTap,
  });

  @override
  State<HoneycombViewport> createState() => _HoneycombViewportState();
}

class _HoneycombViewportState extends State<HoneycombViewport> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        double hexW = widget.hexWidth;
        final colStep = hexW * 0.75 + widget.spacing;
        final neededWidth =
            widget.columns * colStep + colStep / 2 + hexW * 0.25;

        // Scale down if grid is wider than viewport
        if (neededWidth > constraints.maxWidth - 40) {
          final scale = (constraints.maxWidth - 40) / neededWidth;
          hexW = hexW * scale;
        }

        return SingleChildScrollView(
          controller: _scrollController,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
          child: Center(
            child: HoneycombGrid(
              cards: widget.cards,
              columns: widget.columns,
              totalRows: widget.totalRows,
              hexWidth: hexW,
              spacing: widget.spacing,
              onCardMoved: widget.onCardMoved,
              cardContentBuilder: (card) {
                return HexPlayerCardContent(
                  name: card.name,
                  role: card.role,
                  status: card.status,
                  model: card.model,
                  task: card.task,
                  icon: card.icon,
                  accentColor: card.accentColor,
                  onTap: () => widget.onCardTap?.call(card),
                );
              },
            ),
          ),
        );
      },
    );
  }
}
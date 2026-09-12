import 'package:flutter/material.dart';
import 'hexagon_clipper.dart';
import 'draggable_hex_card.dart';

/// Data for a single card placed on the honeycomb.
class HoneycombCardData {
  final String id;
  final String name;
  final String role;
  final String status;
  final String? model;
  final String? task;
  final IconData icon;
  final Color accentColor;
  int slotIndex;

  HoneycombCardData({
    required this.id,
    required this.name,
    required this.role,
    this.status = 'offline',
    this.model,
    this.task,
    this.icon = Icons.smart_toy,
    this.accentColor = const Color(0xFF00FFFF),
    required this.slotIndex,
  });
}

/// Honeycomb grid with flat-top hexagons.
///
/// - Every other slot is SKIPPED (checkerboard) so background shows through
/// - Cards are draggable and snap to empty slots
/// - Grid stretches ~2 pages vertically
class HoneycombGrid extends StatefulWidget {
  final List<HoneycombCardData> cards;
  final int columns;
  final int totalRows;
  final double hexWidth;
  final double spacing;
  final Widget Function(HoneycombCardData card)? cardContentBuilder;
  final void Function(String cardId, int fromSlot, int toSlot)? onCardMoved;

  const HoneycombGrid({
    super.key,
    required this.cards,
    this.columns = 5,
    this.totalRows = 14,
    this.hexWidth = 180,
    this.spacing = 6,
    this.cardContentBuilder,
    this.onCardMoved,
  });

  @override
  State<HoneycombGrid> createState() => _HoneycombGridState();
}

class _HoneycombGridState extends State<HoneycombGrid> {
  late Map<int, HoneycombCardData?> _slotMap;
  final Set<int> _validSlots = {};

  double get hexHeight => HexagonClipper.heightForWidth(widget.hexWidth);
  double get colStep => widget.hexWidth * 0.75 + widget.spacing;
  double get rowStep => hexHeight + widget.spacing;

  @override
  void initState() {
    super.initState();
    _buildSlotMap();
  }

  @override
  void didUpdateWidget(covariant HoneycombGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cards != widget.cards) {
      _buildSlotMap();
    }
  }

  void _buildSlotMap() {
    _slotMap = {};
    _validSlots.clear();

    for (int row = 0; row < widget.totalRows; row++) {
      for (int col = 0; col < widget.columns; col++) {
        final slotIndex = row * widget.columns + col;
        // Checkerboard: skip every other slot
        if ((row + col) % 2 == 0) {
          _validSlots.add(slotIndex);
          _slotMap[slotIndex] = null;
        }
      }
    }

    for (final card in widget.cards) {
      if (_validSlots.contains(card.slotIndex)) {
        _slotMap[card.slotIndex] = card;
      } else {
        final nextSlot = _validSlots.firstWhere(
          (s) => _slotMap[s] == null,
          orElse: () => -1,
        );
        if (nextSlot >= 0) {
          card.slotIndex = nextSlot;
          _slotMap[nextSlot] = card;
        }
      }
    }
  }

  Offset _slotPosition(int slotIndex) {
    final row = slotIndex ~/ widget.columns;
    final col = slotIndex % widget.columns;

    double x = col * colStep;
    double y = row * rowStep;

    // Offset odd rows for honeycomb stagger
    if (row.isOdd) {
      x += colStep / 2;
    }

    return Offset(x, y);
  }

  void _moveCard(String cardId, int toSlot) {
    setState(() {
      HoneycombCardData? card;
      int? fromSlot;

      for (final entry in _slotMap.entries) {
        if (entry.value?.id == cardId) {
          card = entry.value;
          fromSlot = entry.key;
          break;
        }
      }

      if (card == null || fromSlot == null) return;
      if (fromSlot == toSlot) return;

      // Swap cards if target is occupied
      final targetCard = _slotMap[toSlot];
      _slotMap[fromSlot] = targetCard;
      _slotMap[toSlot] = card;

      card.slotIndex = toSlot;
      if (targetCard != null) {
        targetCard.slotIndex = fromSlot;
      }

      widget.onCardMoved?.call(cardId, fromSlot, toSlot);
    });
  }

  @override
  Widget build(BuildContext context) {
    final totalWidth =
        widget.columns * colStep + colStep / 2 + widget.hexWidth * 0.25;
    final totalHeight = widget.totalRows * rowStep + hexHeight;

    return SizedBox(
      width: totalWidth,
      height: totalHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (final slotIndex in _validSlots) _buildSlot(slotIndex),
        ],
      ),
    );
  }

  Widget _buildSlot(int slotIndex) {
    final pos = _slotPosition(slotIndex);
    final card = _slotMap[slotIndex];

    return Positioned(
      left: pos.dx,
      top: pos.dy,
      child: DragTarget<String>(
        onWillAcceptWithDetails: (details) {
          return _validSlots.contains(slotIndex);
        },
        onAcceptWithDetails: (details) {
          _moveCard(details.data, slotIndex);
        },
        builder: (context, candidateData, rejectedData) {
          final isHovering = candidateData.isNotEmpty;

          if (card != null) {
            return DraggableHexCard(
              slotIndex: slotIndex,
              cardId: card.id,
              hexWidth: widget.hexWidth,
              hexHeight: hexHeight,
              borderColor: card.accentColor,
              glowRadius: 8.0,
              child: widget.cardContentBuilder?.call(card) ??
                  _defaultCardContent(card),
            );
          } else {
            return _buildEmptySlot(isHovering);
          }
        },
      ),
    );
  }

  Widget _buildEmptySlot(bool isHovering) {
    return HexagonWidget(
      width: widget.hexWidth,
      height: hexHeight,
      flatTop: true,
      borderColor: isHovering
          ? const Color(0xFF00FFFF).withValues(alpha: 0.6)
          : const Color(0xFF1A1A2E).withValues(alpha: 0.3),
      borderWidth: isHovering ? 2.0 : 0.5,
      glowColor: isHovering
          ? const Color(0xFF00FFFF).withValues(alpha: 0.2)
          : Colors.transparent,
      glowRadius: isHovering ? 12.0 : 0.0,
      child: Container(
        color: isHovering
            ? const Color(0xFF00FFFF).withValues(alpha: 0.05)
            : Colors.transparent,
      ),
    );
  }

  Widget _defaultCardContent(HoneycombCardData card) {
    return Container(
      color: const Color(0xDD0A0A12),
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(card.icon, color: card.accentColor, size: 24),
          const SizedBox(height: 6),
          Text(
            card.name,
            style: TextStyle(
              color: card.accentColor,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            card.role.toUpperCase(),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.4),
              fontSize: 8,
              letterSpacing: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
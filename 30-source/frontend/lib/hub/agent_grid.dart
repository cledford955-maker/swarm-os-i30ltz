import 'package:flutter/material.dart';
import '../models/agent.dart';
import 'agent_card.dart';

/// Honeycomb hex grid: agent hexagons with open hexagons between them.
class AgentGrid extends StatelessWidget {
  final List<Agent> agents;
  final double hexSize;
  final double gap;
  final void Function(Agent)? onAgentTap;

  const AgentGrid({
    super.key,
    required this.agents,
    this.hexSize = 120,
    this.gap = 6,
    this.onAgentTap,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Flat-top hex: col step = 3/4 width, row step = full height
        // Odd columns offset down by half height
        final hexH = hexSize * 1.1547;
        final colStep = (hexSize + gap) * 0.75;
        final rowStep = hexH + gap;

        final cols = (constraints.maxWidth / colStep).floor().clamp(2, 10);

        // Build checkerboard slots: (row+col) even = agent, odd = open hex
        final slots = <_Slot>[];
        int agentIdx = 0;
        int row = 0;

        while (agentIdx < agents.length) {
          for (int col = 0; col < cols; col++) {
            final isAgentSlot = (row + col) % 2 == 0;
            if (isAgentSlot && agentIdx < agents.length) {
              slots.add(_Slot(row: row, col: col, agent: agents[agentIdx]));
              agentIdx++;
            } else {
              slots.add(_Slot(row: row, col: col, agent: null));
            }
          }
          row++;
        }

        // Fill remaining columns of last row with open hexes
        final lastRow = slots.isEmpty ? 0 : slots.last.row;
        final lastRowCols = slots.where((s) => s.row == lastRow).length;
        for (int col = lastRowCols; col < cols; col++) {
          slots.add(_Slot(row: lastRow, col: col, agent: null));
        }

        final maxRow = slots.fold<int>(0, (m, s) => s.row > m ? s.row : m);
        final totalH = (maxRow + 1) * rowStep + hexH * 0.5;

        // Center the grid
        final gridWidth = cols * colStep + hexSize * 0.25;
        final offsetX = (constraints.maxWidth - gridWidth) / 2;

        return SizedBox(
          height: totalH + 20,
          child: Stack(
            children: slots.map((slot) {
              final x = offsetX + slot.col * colStep;
              // Odd columns shift down by half a hex height
              final yShift = slot.col.isOdd ? (hexH + gap) * 0.5 : 0.0;
              final y = slot.row * rowStep + yShift;

              return Positioned(
                left: x,
                top: y,
                child: slot.agent != null
                    ? AgentCard(
                        agent: slot.agent!,
                        size: hexSize,
                        onTap: onAgentTap != null
                            ? () => onAgentTap!(slot.agent!)
                            : null,
                      )
                    : OpenHexCard(size: hexSize),
              );
            }).toList(),
          ),
        );
      },
    );
  }
}

class _Slot {
  final int row;
  final int col;
  final Agent? agent;
  _Slot({required this.row, required this.col, this.agent});
}
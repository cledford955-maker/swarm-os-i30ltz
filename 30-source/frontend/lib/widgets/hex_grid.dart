// ═══════════════════════════════════════════════════════════════
// Swarm OS — Draggable Hexagon Grid
// Checkerboard hex layout with drag-to-reorder, snap-to-position,
// and trade/bump animations. Each hex opens an agent window.
// ═══════════════════════════════════════════════════════════════

import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import '../services/launch_status.dart';
import 'wasp_nest_decoration.dart';
import 'swarm_tap_burst.dart';
import 'agent_avatar.dart';

// ─── Hex Slot: a position in the grid ───
class HexSlot {
  final int row;
  final int col;
  Offset center; // computed pixel center

  HexSlot(this.row, this.col, [this.center = Offset.zero]);

  String get key => '$row:$col';

  @override
  bool operator ==(Object other) =>
      other is HexSlot && other.row == row && other.col == col;

  @override
  int get hashCode => row.hashCode ^ col.hashCode;
}

// ─── Hex Agent: data stored per hexagon ───
class HexAgent {
  final String id;
  final String name;
  final IconData icon;
  final Color color;
  final Color bgColor;
  final Widget Function()? windowBuilder;
  // If set, tapping this tile launches a native process via SystemLauncher.
  final String? execCommand;
  // If set, tapping this tile navigates to this go_router path.
  final String? routePath;
  // Placeholder tool/agent idea not wired up yet — renders a "SOON" badge
  // and taps show a "coming soon" message instead of doing nothing.
  final bool mock;
  // Optional real artwork clipped into the hex shape behind the icon —
  // most agents don't have one, and render exactly as before.
  final String? previewImagePath;
  // Set when this tile is a user-installed app (App Store): the pacman
  // package name, used by the desktop's right-click menu to offer
  // Delete Icon / Uninstall App.
  final String? packageName;
  // Absolute path to the app's real icon file (png/svg/xpm) scraped from
  // its .desktop entry at install time. Rendered inside the hex instead of
  // the generic Material icon when present.
  final String? iconFilePath;
  int slotRow;
  int slotCol;

  HexAgent({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    required this.bgColor,
    this.windowBuilder,
    this.execCommand,
    this.routePath,
    this.mock = false,
    this.previewImagePath,
    this.packageName,
    this.iconFilePath,
    this.slotRow = 0,
    this.slotCol = 0,
  });

  String get slotKey => '$slotRow:$slotCol';
}

// ─── Callback for opening agent windows ───
typedef OnAgentOpen = void Function(HexAgent agent);

/// Callback for right-clicking an agent tile — receives the agent and the
/// global screen position where the menu should appear.
typedef OnAgentContextMenu = void Function(HexAgent agent, Offset position);

// ═══════════════════════════════════════════════════════════
// HEX GRID WIDGET
// ═══════════════════════════════════════════════════════════

class HexGrid extends StatefulWidget {
  final List<HexAgent> agents;
  final int columns;
  final int rows;
  final double hexSize;
  final OnAgentOpen? onAgentOpen;
  // Right-click handler — when null, right-clicks are ignored.
  final OnAgentContextMenu? onAgentContextMenu;
  // When false, slot-background hexagons are hidden so a wallpaper shows through.
  final bool showSlotBackgrounds;
  // Checker layout (desktop rails): square cells, an icon only on every
  // other cell, so neighbouring columns stagger. `mirror` flips which column
  // starts on row 0 — use it for the right-hand rail so both sides match.
  final bool checker;
  final bool mirror;

  const HexGrid({
    super.key,
    required this.agents,
    this.columns = 5,
    this.rows = 4,
    this.hexSize = 52,
    this.onAgentOpen,
    this.onAgentContextMenu,
    this.showSlotBackgrounds = true,
    this.checker = false,
    this.mirror = false,
  });

  @override
  State<HexGrid> createState() => HexGridState();
}

class HexGridState extends State<HexGrid> with TickerProviderStateMixin {
  late List<HexSlot> _slots;
  late Map<String, HexAgent> _slotMap; // slotKey → agent
  String? _draggingId;
  Offset _dragOffset = Offset.zero;
  String? _hoverSlotKey;
  late AnimationController _pulseCtrl;
  late AnimationController _swapCtrl;

  // For swap animation
  String? _swapA;
  String? _swapB;
  Offset _swapAStart = Offset.zero;
  Offset _swapAEnd = Offset.zero;
  Offset _swapBStart = Offset.zero;
  Offset _swapBEnd = Offset.zero;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _swapCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _swapCtrl.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          _swapA = null;
          _swapB = null;
        });
        _swapCtrl.reset();
      }
    });
    _buildSlots();
    _assignAgents();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _swapCtrl.dispose();
    super.dispose();
  }

  void _buildSlots() {
    _slots = [];
    for (int r = 0; r < widget.rows; r++) {
      for (int c = 0; c < widget.columns; c++) {
        if (widget.checker &&
            (r + (widget.mirror ? widget.columns - 1 - c : c)) % 2 != 0) {
          continue;
        }
        _slots.add(HexSlot(r, c));
      }
    }
  }

  void _assignAgents() {
    _slotMap = {};
    for (int i = 0; i < widget.agents.length && i < _slots.length; i++) {
      final slot = _slots[i];
      widget.agents[i].slotRow = slot.row;
      widget.agents[i].slotCol = slot.col;
      _slotMap[slot.key] = widget.agents[i];
    }
  }

  // Checker tiles fill this share of their cell, leaving a gap between them.
  static const _checkerFill = 0.88;
  static const _checkerRowStep = 0.62; // of tile height

  Offset _slotCenter(int row, int col, double hexW, double hexH) {
    if (widget.checker) {
      final cellW = hexW / _checkerFill;
      return Offset(
          col * cellW + cellW / 2, row * hexH * _checkerRowStep + hexH / 2);
    }
    final rowOffset = (row % 2 == 1) ? hexW * 0.5 : 0.0;
    final x = col * hexW + rowOffset + hexW / 2;
    final y = row * (hexH * 0.75) + hexH / 2;
    return Offset(x, y);
  }

  HexSlot? _nearestSlot(Offset pos, double hexW, double hexH) {
    HexSlot? best;
    double bestDist = double.infinity;
    for (final slot in _slots) {
      final center = _slotCenter(slot.row, slot.col, hexW, hexH);
      final d = (pos - center).distance;
      if (d < bestDist && d < hexW * 0.6) {
        bestDist = d;
        best = slot;
      }
    }
    return best;
  }

  void _swapAgents(String slotKeyA, String slotKeyB) {
    final agentA = _slotMap[slotKeyA];
    final agentB = _slotMap[slotKeyB];

    if (agentA != null && agentB != null) {
      // Both occupied: trade
      final tmpRow = agentA.slotRow;
      final tmpCol = agentA.slotCol;
      agentA.slotRow = agentB.slotRow;
      agentA.slotCol = agentB.slotCol;
      agentB.slotRow = tmpRow;
      agentB.slotCol = tmpCol;
      _slotMap[slotKeyA] = agentB;
      _slotMap[slotKeyB] = agentA;
    } else if (agentA != null) {
      // Move A to empty slot B
      final parts = slotKeyB.split(':');
      agentA.slotRow = int.parse(parts[0]);
      agentA.slotCol = int.parse(parts[1]);
      _slotMap.remove(slotKeyA);
      _slotMap[slotKeyB] = agentA;
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (ctx, constraints) {
      final totalW = constraints.maxWidth;
      final hexW = widget.checker
          ? totalW / widget.columns * _checkerFill
          : min(widget.hexSize * 2, totalW / (widget.columns + 0.5));
      final hexH = hexW * 1.1547; // ratio for regular hex
      final gridH = widget.checker
          ? (widget.rows - 1) * hexH * _checkerRowStep + hexH
          : widget.rows * (hexH * 0.75) + hexH * 0.25;

      // Compute centers
      for (final slot in _slots) {
        slot.center = _slotCenter(slot.row, slot.col, hexW, hexH);
      }

      return SizedBox(
        height: gridH + 20,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Checkerboard slot shadows (omitted in wallpaper-overlay mode)
            if (widget.showSlotBackgrounds)
              ..._slots.map((slot) => Positioned(
                    left: slot.center.dx - hexW / 2,
                    top: slot.center.dy - hexH / 2,
                    child: _buildSlotBackground(slot, hexW, hexH),
                  )),

            // Agents in slots (non-dragging, non-swapping)
            ..._slotMap.entries
                .where((e) =>
                    e.value.id != _draggingId &&
                    e.value.id != _swapA &&
                    e.value.id != _swapB)
                .map((e) {
              final agent = e.value;
              final center =
                  _slotCenter(agent.slotRow, agent.slotCol, hexW, hexH);
              return Positioned(
                left: center.dx - hexW / 2,
                top: center.dy - hexH / 2,
                child: _buildHexAgent(agent, hexW, hexH, false),
              );
            }),

            // Swap animation
            if (_swapA != null && _swapB != null)
              ..._buildSwapAnimation(hexW, hexH),

            // Drag hover highlight
            if (_hoverSlotKey != null && _draggingId != null)
              _buildHoverHighlight(hexW, hexH),

            // Dragging hex (follows finger/mouse)
            if (_draggingId != null)
              Positioned(
                left: _dragOffset.dx - hexW / 2,
                top: _dragOffset.dy - hexH / 2,
                child: _buildHexAgent(
                  widget.agents.firstWhere((a) => a.id == _draggingId),
                  hexW,
                  hexH,
                  true,
                ),
              ),
          ],
        ),
      );
    });
  }

  Widget _buildSlotBackground(HexSlot slot, double w, double h) {
    final isDark = (slot.row + slot.col) % 2 == 0;
    final isHover = _hoverSlotKey == slot.key;
    // Empty slots (no app assigned) get a wasp nest instead of just sitting
    // dark — the swarm should read as a constant presence surrounding the
    // apps, not empty space between them.
    final isEmpty = !_slotMap.containsKey(slot.key);

    return AnimatedBuilder(
      animation: _pulseCtrl,
      builder: (_, __) {
        final pulse = 0.02 + _pulseCtrl.value * 0.015;
        return Stack(
          alignment: Alignment.center,
          children: [
            CustomPaint(
              size: Size(w, h),
              painter: _HexPainter(
                fillColor: isDark
                    ? const Color(0xFF0E0E22)
                        .withValues(alpha: isHover ? 0.9 : 0.6)
                    : const Color(0xFF12122E)
                        .withValues(alpha: isHover ? 0.9 : 0.5),
                strokeColor: isHover
                    ? const Color(0xFF00D4FF).withValues(alpha: 0.5)
                    : const Color(0xFF1E1E44).withValues(alpha: 0.3 + pulse),
                strokeWidth: isHover ? 2.0 : 1.0,
              ),
            ),
            if (isEmpty && !isHover)
              WaspNestDecoration(
                  size: min(w, h) * 0.86, seed: slot.key.hashCode),
          ],
        );
      },
    );
  }

  Widget _buildHexAgent(HexAgent agent, double w, double h, bool dragging) {
    final child = GestureDetector(
      onTapDown: dragging
          ? null
          : (details) => triggerSwarmBurst(context, details.globalPosition),
      onTap: dragging ? null : () => widget.onAgentOpen?.call(agent),
      onSecondaryTapUp: dragging
          ? null
          : (details) =>
              widget.onAgentContextMenu?.call(agent, details.globalPosition),
      onLongPressStart: dragging
          ? null
          : (details) {
              setState(() {
                _draggingId = agent.id;
                _dragOffset = _slotCenter(agent.slotRow, agent.slotCol, w, h);
              });
            },
      onPanStart: dragging
          ? null
          : (details) {
              setState(() {
                _draggingId = agent.id;
                _dragOffset = _slotCenter(agent.slotRow, agent.slotCol, w, h);
              });
            },
      onPanUpdate: _draggingId == agent.id
          ? (details) {
              setState(() {
                _dragOffset += details.delta;
                final nearest = _nearestSlot(_dragOffset, w, h);
                _hoverSlotKey = nearest?.key;
              });
            }
          : null,
      onPanEnd: _draggingId == agent.id
          ? (details) {
              _handleDrop(agent, w, h);
            }
          : null,
      child: _HexTile(
        agent: agent,
        width: w,
        height: h,
        dragging: dragging,
        pulseAnimation: _pulseCtrl,
      ),
    );

    if (dragging) {
      return Transform.scale(
        scale: 1.15,
        child: Opacity(opacity: 0.9, child: child),
      );
    }
    return child;
  }

  void _handleDrop(HexAgent agent, double w, double h) {
    final target = _nearestSlot(_dragOffset, w, h);
    final sourceKey = agent.slotKey;

    if (target != null && target.key != sourceKey) {
      final targetAgent = _slotMap[target.key];

      if (targetAgent != null) {
        // TRADE: animate both hexagons swapping
        _animateSwap(sourceKey, target.key, agent, targetAgent, w, h);
      } else {
        // MOVE: animate to empty slot
        _swapAgents(sourceKey, target.key);
      }
    }

    setState(() {
      _draggingId = null;
      _hoverSlotKey = null;
    });
  }

  void _animateSwap(
      String keyA, String keyB, HexAgent a, HexAgent b, double w, double h) {
    setState(() {
      _swapA = a.id;
      _swapB = b.id;
      _swapAStart = _slotCenter(a.slotRow, a.slotCol, w, h);
      _swapAEnd = _slotCenter(b.slotRow, b.slotCol, w, h);
      _swapBStart = _slotCenter(b.slotRow, b.slotCol, w, h);
      _swapBEnd = _slotCenter(a.slotRow, a.slotCol, w, h);
    });

    _swapAgents(keyA, keyB);
    _swapCtrl.forward(from: 0);
  }

  List<Widget> _buildSwapAnimation(double w, double h) {
    final agentA = widget.agents.where((a) => a.id == _swapA).firstOrNull;
    final agentB = widget.agents.where((a) => a.id == _swapB).firstOrNull;
    if (agentA == null || agentB == null) return [];

    return [
      AnimatedBuilder(
        animation: _swapCtrl,
        builder: (_, __) {
          final t = Curves.easeInOutCubic.transform(_swapCtrl.value);
          final posA = Offset.lerp(_swapAStart, _swapAEnd, t)!;
          final posB = Offset.lerp(_swapBStart, _swapBEnd, t)!;
          return Stack(children: [
            Positioned(
              left: posA.dx - w / 2,
              top: posA.dy - h / 2,
              child: _HexTile(
                  agent: agentA,
                  width: w,
                  height: h,
                  dragging: false,
                  pulseAnimation: _pulseCtrl),
            ),
            Positioned(
              left: posB.dx - w / 2,
              top: posB.dy - h / 2,
              child: _HexTile(
                  agent: agentB,
                  width: w,
                  height: h,
                  dragging: false,
                  pulseAnimation: _pulseCtrl),
            ),
          ]);
        },
      ),
    ];
  }

  Widget _buildHoverHighlight(double w, double h) {
    final slot = _slots.where((s) => s.key == _hoverSlotKey).firstOrNull;
    if (slot == null) return const SizedBox.shrink();

    return Positioned(
      left: slot.center.dx - w / 2,
      top: slot.center.dy - h / 2,
      child: IgnorePointer(
        child: CustomPaint(
          size: Size(w, h),
          painter: _HexPainter(
            fillColor: const Color(0xFF00D4FF).withValues(alpha: 0.08),
            strokeColor: const Color(0xFF00D4FF).withValues(alpha: 0.6),
            strokeWidth: 2.5,
            glow: true,
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// HEX TILE — Individual hexagon with icon + label
// ═══════════════════════════════════════════════════════════

class _HexTile extends StatelessWidget {
  final HexAgent agent;
  final double width;
  final double height;
  final bool dragging;
  final AnimationController pulseAnimation;

  const _HexTile({
    required this.agent,
    required this.width,
    required this.height,
    required this.dragging,
    required this.pulseAnimation,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<LaunchAuraState>(
      valueListenable: LaunchStatusRegistry.notifierFor(agent.id),
      builder: (_, auraState, __) {
        return AnimatedBuilder(
          animation: pulseAnimation,
          builder: (_, __) {
            final pulse = pulseAnimation.value;

            Color? auraColor;
            double auraAlpha = 0;
            if (auraState == LaunchAuraState.loading) {
              auraColor = const Color(0xFF00FF88);
              auraAlpha = 0.25 + pulse * 0.55;
            } else if (auraState == LaunchAuraState.running) {
              auraColor = const Color(0xFF00FF88);
              auraAlpha = 0.65;
            } else if (auraState == LaunchAuraState.closed) {
              auraColor = const Color(0xFFFF3333);
              auraAlpha = 0.7;
            }

            return SizedBox(
              width: width,
              height: height,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Status aura glow (behind hex shape)
                  if (auraColor != null)
                    CustomPaint(
                      size: Size(width, height),
                      painter: _HexPainter(
                        fillColor: Colors.transparent,
                        strokeColor: auraColor.withValues(alpha: auraAlpha),
                        strokeWidth: 3.0,
                        glow: true,
                        glowColor: auraColor,
                        glowAlpha: auraAlpha * 0.5,
                        glowRadius: 18,
                      ),
                    ),
                  // Hex shape
                  CustomPaint(
                    size: Size(width, height),
                    painter: _HexPainter(
                      fillColor: agent.bgColor
                          .withValues(alpha: dragging ? 0.95 : 0.85),
                      strokeColor: (agent.id == 'gaming'
                              ? const Color(0xFF76B900)
                              : agent.color)
                          .withValues(
                              alpha: (dragging ? 0.8 : 0.3 + pulse * 0.1) *
                                  (agent.mock ? 0.5 : 1.0)),
                      strokeWidth: dragging ? 2.5 : 1.5,
                      glow: dragging,
                      glowColor: agent.color,
                      hasImageOverlay: agent.previewImagePath != null,
                    ),
                  ),
                  // Real artwork, clipped to the exact same hex outline —
                  // dimmed + gradient-scrimmed so the icon/label on top
                  // stay legible over a genuinely busy photo.
                  if (agent.previewImagePath != null)
                    ClipPath(
                      clipper: const _HexClipper(),
                      child: SizedBox(
                        width: width,
                        height: height,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.asset(
                              agent.previewImagePath!,
                              fit: BoxFit.cover,
                              color: Colors.black.withValues(alpha: 0.30),
                              colorBlendMode: BlendMode.darken,
                            ),
                            DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.black.withValues(alpha: 0.05),
                                    Colors.black.withValues(alpha: 0.55),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  // Content
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // User-installed apps render their real icon file (from the
                      // .desktop entry) instead of a generic Material glyph.
                      if (agent.iconFilePath != null &&
                          agent.iconFilePath!.isNotEmpty)
                        SizedBox(
                          width: width * 0.34,
                          height: width * 0.34,
                          child: Image.file(
                            File(agent.iconFilePath!),
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => AppIconOrb(
                              icon: agent.icon,
                              color: agent.color,
                              size: width * 0.34,
                              dimmed: agent.mock,
                            ),
                          ),
                        )
                      else
                        // Featured agents get their animated 3-D orb; every
                        // other tile gets the same glossy sphere treatment
                        // around its glyph.
                        AgentAvatar.maybeFor(
                          agentId: agent.id,
                          icon: agent.icon,
                          color: agent.color,
                          size: width * 0.34,
                          dimmed: agent.mock,
                        ),
                      SizedBox(height: height * 0.03),
                      Text(
                        agent.name,
                        style: TextStyle(
                          color: Colors.white
                              .withValues(alpha: agent.mock ? 0.4 : 0.8),
                          fontSize: width * 0.12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                  // "SOON" badge — idea not wired up yet
                  if (agent.mock)
                    Positioned(
                      bottom: height * 0.06,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color:
                              const Color(0xFF0A0A18).withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.25),
                              width: 0.75),
                        ),
                        child: Text(
                          'SOON',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.55),
                            fontSize: width * 0.075,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ),
                  // Drag indicator
                  if (dragging)
                    Positioned(
                      top: height * 0.08,
                      right: width * 0.15,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: const Color(0xFF00D4FF),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                                color: const Color(0xFF00D4FF)
                                    .withValues(alpha: 0.5),
                                blurRadius: 6)
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════
// Shared hex geometry — used by the painter below AND by the image
// clipper that lets a tile show real artwork instead of a flat fill.
// Was private to _HexPainter; extracted 2026-09-19 so both can draw the
// exact same outline (a clipped image with a differently-shaped fill
// behind it would show visible seams at the edges).
// ═══════════════════════════════════════════════════════════

Path buildHexPath(Size size) {
  final w = size.width;
  final h = size.height;
  final cx = w / 2;
  final cy = h / 2;
  final rx = w / 2 * 0.92;
  final ry = h / 2 * 0.92;

  // Pointy-top hexagon
  final path = Path();
  for (int i = 0; i < 6; i++) {
    final angle = (pi / 3) * i - pi / 2;
    final x = cx + rx * cos(angle);
    final y = cy + ry * sin(angle);
    if (i == 0) {
      path.moveTo(x, y);
    } else {
      path.lineTo(x, y);
    }
  }
  path.close();
  return path;
}

// ═══════════════════════════════════════════════════════════
// HEX PAINTER — CustomPainter for hexagon shape
// ═══════════════════════════════════════════════════════════

class _HexPainter extends CustomPainter {
  final Color fillColor;
  final Color strokeColor;
  final double strokeWidth;
  final bool glow;
  final Color? glowColor;
  final double glowAlpha;
  final double glowRadius;
  // A photo is about to be clipped into this same hex shape on top of the
  // fill — skip painting the flat fill/bevel so the photo isn't dimmed by
  // sitting over it, while keeping the shadow and stroke (they read as the
  // tile's own edge, not part of the fill).
  final bool hasImageOverlay;

  _HexPainter({
    required this.fillColor,
    required this.strokeColor,
    this.strokeWidth = 1.0,
    this.glow = false,
    this.glowColor,
    this.glowAlpha = 0.15,
    this.glowRadius = 12,
    this.hasImageOverlay = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final path = buildHexPath(size);

    // Glow
    if (glow) {
      final glowPaint = Paint()
        ..color = (glowColor ?? strokeColor).withValues(alpha: glowAlpha)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, glowRadius);
      canvas.drawPath(path, glowPaint);
    }

    // Ambient drop shadow — a soft, offset, blurred copy of the hex sitting
    // behind the tile. This plus the gradient fill below is what actually
    // reads as "3D" rather than a flat color swatch with a stroke.
    canvas.save();
    canvas.translate(0, size.height * 0.035);
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.restore();

    if (!hasImageOverlay) {
      // Fill — a diagonal gradient from a lightened version of fillColor
      // (simulating a light source top-left) down to a darkened version
      // (bottom-right), instead of one flat color. Same technique as a
      // CSS glossy-button bevel.
      final hsl = HSLColor.fromColor(fillColor);
      final lightColor =
          hsl.withLightness((hsl.lightness + 0.14).clamp(0.0, 1.0)).toColor();
      final darkColor =
          hsl.withLightness((hsl.lightness - 0.10).clamp(0.0, 1.0)).toColor();
      final rect = Offset.zero & size;
      canvas.drawPath(
        path,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              lightColor.withValues(alpha: fillColor.a),
              darkColor.withValues(alpha: fillColor.a)
            ],
          ).createShader(rect),
      );

      // Glossy highlight — a soft, blurred ellipse near the top edge,
      // simulating a specular reflection. Purely additive, cheap to skip
      // when an image is about to sit on top instead.
      canvas.save();
      canvas.clipPath(path);
      final highlightRect = Rect.fromLTWH(size.width * 0.12,
          -size.height * 0.28, size.width * 0.76, size.height * 0.6);
      canvas.drawOval(
        highlightRect,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.10)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
      );
      canvas.restore();
    }

    // Stroke
    canvas.drawPath(
        path,
        Paint()
          ..color = strokeColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeJoin = StrokeJoin.round);
  }

  @override
  bool shouldRepaint(covariant _HexPainter old) =>
      fillColor != old.fillColor ||
      strokeColor != old.strokeColor ||
      strokeWidth != old.strokeWidth ||
      glow != old.glow ||
      glowAlpha != old.glowAlpha ||
      glowRadius != old.glowRadius ||
      hasImageOverlay != old.hasImageOverlay;
}

// A CustomClipper using the exact same outline as _HexPainter, so a clipped
// photo lines up perfectly with the hex's own stroke/shadow — no seams.
class _HexClipper extends CustomClipper<Path> {
  const _HexClipper();

  @override
  Path getClip(Size size) => buildHexPath(size);

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

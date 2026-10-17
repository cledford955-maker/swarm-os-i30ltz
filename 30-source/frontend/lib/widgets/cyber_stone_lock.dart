import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/lucille_voice_service.dart';
import '../theme/swarm_text_styles.dart';

/// Cyber-Mystic 12-Stone Electric Shock Security Lock
/// Features:
/// - 12 3D-embossed stones with chiseled cybernetic glyphs
/// - Electric Blue (#00E5FF) and Electric Purple (#D500F9) lightning shock arcs
/// - 4-glyph pattern sequence entry with randomized position shuffle
/// - Bluetooth Gamepad / D-Pad friendly controller navigation
/// - Admin Secret Bypass: 3 clicks Top-Left + 3 clicks Bottom-Right
class CyberStoneLockDialog extends StatefulWidget {
  final VoidCallback onUnlocked;
  final VoidCallback? onCancel;

  const CyberStoneLockDialog({
    super.key,
    required this.onUnlocked,
    this.onCancel,
  });

  static Future<bool?> show(BuildContext context) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.88),
      builder: (context) => CyberStoneLockDialog(
        onUnlocked: () => Navigator.of(context).pop(true),
        onCancel: () => Navigator.of(context).pop(false),
      ),
    );
  }

  @override
  State<CyberStoneLockDialog> createState() => _CyberStoneLockDialogState();
}

class _StoneGlyph {
  final int id;
  final String name;
  final String symbol;
  final Color stoneColor;
  final Color glowColor;
  final IconData icon;

  const _StoneGlyph({
    required this.id,
    required this.name,
    required this.symbol,
    required this.stoneColor,
    required this.glowColor,
    required this.icon,
  });
}

class _CyberStoneLockDialogState extends State<CyberStoneLockDialog>
    with TickerProviderStateMixin {
  late AnimationController _lightningController;
  late AnimationController _pulseController;
  final LucilleVoiceService _voice = LucilleVoiceService();

  final List<int> _enteredSequence = [];
  final int _maxSlots = 4;
  int _focusedIndex = 0;
  bool _isAccessDenied = false;

  // Admin secret tracker: 3 clicks Top-Left (Index 0), then 3 clicks Bottom-Right (Index 11)
  int _adminTopLeftCount = 0;
  int _adminBottomRightCount = 0;

  static const List<_StoneGlyph> _allGlyphs = [
    _StoneGlyph(id: 0, name: 'Obsidian Hex', symbol: '⬢', stoneColor: Color(0xFF1E2430), glowColor: Color(0xFF00E5FF), icon: Icons.hexagon),
    _StoneGlyph(id: 1, name: 'Sapphire Delta', symbol: '▲', stoneColor: Color(0xFF162544), glowColor: Color(0xFF2979FF), icon: Icons.change_history),
    _StoneGlyph(id: 2, name: 'Amethyst Nova', symbol: '✦', stoneColor: Color(0xFF2A163B), glowColor: Color(0xFFD500F9), icon: Icons.auto_awesome),
    _StoneGlyph(id: 3, name: 'Emerald Helix', symbol: '🧬', stoneColor: Color(0xFF143322), glowColor: Color(0xFF00E676), icon: Icons.all_inclusive),
    _StoneGlyph(id: 4, name: 'Solar Citrine', symbol: '☼', stoneColor: Color(0xFF382E13), glowColor: Color(0xFFFFD600), icon: Icons.wb_sunny),
    _StoneGlyph(id: 5, name: 'Ruby Plasma', symbol: '🔥', stoneColor: Color(0xFF3A1218), glowColor: Color(0xFFFF1744), icon: Icons.local_fire_department),
    _StoneGlyph(id: 6, name: 'Titanium Prism', symbol: '◈', stoneColor: Color(0xFF212936), glowColor: Color(0xFF00B0FF), icon: Icons.diamond),
    _StoneGlyph(id: 7, name: 'Cyber Wasp', symbol: '🐝', stoneColor: Color(0xFF32281A), glowColor: Color(0xFFFFAB00), icon: Icons.pest_control),
    _StoneGlyph(id: 8, name: 'Ion Surge', symbol: '⚡', stoneColor: Color(0xFF172B3C), glowColor: Color(0xFF00E5FF), icon: Icons.flash_on),
    _StoneGlyph(id: 9, name: 'Aether Core', symbol: '◉', stoneColor: Color(0xFF2D163D), glowColor: Color(0xFFAA00FF), icon: Icons.radio_button_checked),
    _StoneGlyph(id: 10, name: 'Lucille Crown', symbol: '👑', stoneColor: Color(0xFF3B152B), glowColor: Color(0xFFFF4081), icon: Icons.favorite),
    _StoneGlyph(id: 11, name: 'Omega Circuit', symbol: 'Ω', stoneColor: Color(0xFF192A32), glowColor: Color(0xFF00B0FF), icon: Icons.memory),
  ];

  late List<_StoneGlyph> _displayedStones;

  @override
  void initState() {
    super.initState();
    _displayedStones = List.from(_allGlyphs);
    _lightningController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _lightningController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _shuffleStones() {
    setState(() {
      _displayedStones.shuffle(Random());
    });
    HapticFeedback.lightImpact();
  }

  void _onStoneTapped(int tilePositionIndex, _StoneGlyph stone) {
    if (_isAccessDenied) return;

    // Check Secret Admin Bypass: 3 clicks Top-Left (Pos 0), then 3 clicks Bottom-Right (Pos 11)
    if (tilePositionIndex == 0) {
      if (_adminBottomRightCount == 0) {
        _adminTopLeftCount++;
      } else {
        _adminTopLeftCount = 1;
        _adminBottomRightCount = 0;
      }
    } else if (tilePositionIndex == 11 && _adminTopLeftCount >= 3) {
      _adminBottomRightCount++;
      if (_adminBottomRightCount >= 3) {
        _unlockSuccess(isAdminBypass: true);
        return;
      }
    } else {
      _adminTopLeftCount = 0;
      _adminBottomRightCount = 0;
    }

    setState(() {
      if (_enteredSequence.length < _maxSlots) {
        _enteredSequence.add(stone.id);
        HapticFeedback.mediumImpact();
      }

      if (_enteredSequence.length == _maxSlots) {
        _validateSequence();
      }
    });
  }

  void _validateSequence() {
    // Correct default password sequence: 4 unique or custom chosen glyphs
    // By default, any 4-glyph combination or the Admin bypass unlocks
    _unlockSuccess(isAdminBypass: false);
  }

  void _unlockSuccess({required bool isAdminBypass}) {
    HapticFeedback.heavyImpact();
    _voice.speak(isAdminBypass
        ? 'Admin bypass sequence confirmed. Security perimeter disengaged.'
        : 'Stone glyph cipher accepted. Welcome to the Hive.');

    widget.onUnlocked();
  }

  void _clearSequence() {
    setState(() {
      _enteredSequence.clear();
      _adminTopLeftCount = 0;
      _adminBottomRightCount = 0;
      _isAccessDenied = false;
    });
    HapticFeedback.selectionClick();
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: FocusNode()..requestFocus(),
      onKeyEvent: (event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
            setState(() => _focusedIndex = (_focusedIndex + 1) % 12);
          } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
            setState(() => _focusedIndex = (_focusedIndex - 1 + 12) % 12);
          } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
            setState(() => _focusedIndex = (_focusedIndex + 4) % 12);
          } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
            setState(() => _focusedIndex = (_focusedIndex - 4 + 12) % 12);
          } else if (event.logicalKey == LogicalKeyboardKey.enter ||
              event.logicalKey == LogicalKeyboardKey.gameButtonA) {
            _onStoneTapped(_focusedIndex, _displayedStones[_focusedIndex]);
          } else if (event.logicalKey == LogicalKeyboardKey.gameButtonX ||
              event.logicalKey == LogicalKeyboardKey.delete) {
            _clearSequence();
          } else if (event.logicalKey == LogicalKeyboardKey.gameButtonY) {
            _shuffleStones();
          }
        }
      },
      child: Center(
        child: Container(
          width: 720,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF0C0E14),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: const Color(0xFF00E5FF).withValues(alpha: 0.6),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF00E5FF).withValues(alpha: 0.25),
                blurRadius: 36,
                spreadRadius: 4,
              ),
              BoxShadow(
                color: const Color(0xFFD500F9).withValues(alpha: 0.2),
                blurRadius: 48,
                spreadRadius: 2,
              ),
            ],
          ),
          child: CustomPaint(
            painter: _ElectricShockPainter(animation: _lightningController),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header & Title
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00E5FF).withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFF00E5FF)),
                      ),
                      child: const Icon(Icons.security, color: Color(0xFF00E5FF), size: 24),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'CYBER-MYSTIC STONE GLYPH GATEWAY',
                          style: SwarmTextStyles.title.copyWith(
                            color: const Color(0xFF00E5FF),
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                          ),
                        ),
                        Text(
                          'Select 6 Stone Glyphs • Controller & Bluetooth D-Pad Enabled',
                          style: SwarmTextStyles.bodySmall.copyWith(
                            color: const Color(0xFFD500F9),
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.shuffle, color: Color(0xFF00E5FF)),
                      tooltip: 'Randomize Stone Positions',
                      onPressed: _shuffleStones,
                    ),
                    if (widget.onCancel != null)
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white54),
                        onPressed: widget.onCancel,
                      ),
                  ],
                ),
                const SizedBox(height: 16),

                // 6-Slot Glyph Input Indicator
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF06080C),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF1E2A38)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_maxSlots, (index) {
                      final isFilled = index < _enteredSequence.length;
                      final glyph = isFilled
                          ? _allGlyphs.firstWhere((g) => g.id == _enteredSequence[index])
                          : null;

                      return Container(
                        width: 44,
                        height: 44,
                        margin: const EdgeInsets.symmetric(horizontal: 6),
                        decoration: BoxDecoration(
                          color: isFilled ? glyph!.stoneColor : const Color(0xFF10141C),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isFilled
                                ? glyph!.glowColor
                                : const Color(0xFF00E5FF).withValues(alpha: 0.2),
                            width: isFilled ? 2 : 1,
                          ),
                          boxShadow: isFilled
                              ? [
                                  BoxShadow(
                                    color: glyph!.glowColor.withValues(alpha: 0.4),
                                    blurRadius: 10,
                                  ),
                                ]
                              : null,
                        ),
                        child: Center(
                          child: isFilled
                              ? Text(glyph!.symbol, style: TextStyle(color: glyph.glowColor, fontSize: 18))
                              : Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF00E5FF).withValues(alpha: 0.3),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                        ),
                      );
                    }),
                  ),
                ),
                const SizedBox(height: 20),

                // 12 Carved Stone Tiles Grid (4 x 3)
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.45,
                  ),
                  itemCount: 12,
                  itemBuilder: (context, index) {
                    final stone = _displayedStones[index];
                    final isFocused = _focusedIndex == index;

                    return _buildStoneTile(index, stone, isFocused);
                  },
                ),
                const SizedBox(height: 18),

                // Footer Controls & Status
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: _clearSequence,
                      icon: const Icon(Icons.refresh, color: Colors.white60, size: 18),
                      label: Text('CLEAR SEQUENCE', style: SwarmTextStyles.labelSmall.copyWith(color: Colors.white70)),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD500F9).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFD500F9).withValues(alpha: 0.4)),
                      ),
                      child: Text(
                        'ADMIN BYPASS: [TL x3 + BR x3]',
                        style: SwarmTextStyles.labelSmall.copyWith(
                          color: const Color(0xFFD500F9),
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStoneTile(int posIndex, _StoneGlyph stone, bool isFocused) {
    return GestureDetector(
      onTap: () => _onStoneTapped(posIndex, stone),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          // Deep 3D chiseled stone texture gradient
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              stone.stoneColor.withValues(alpha: 0.95),
              const Color(0xFF090C12),
              stone.stoneColor.withValues(alpha: 0.75),
            ],
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isFocused
                ? const Color(0xFF00E5FF)
                : stone.glowColor.withValues(alpha: 0.45),
            width: isFocused ? 2.5 : 1.4,
          ),
          boxShadow: [
            // Outer 3D stone drop shadow
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.8),
              offset: const Offset(3, 4),
              blurRadius: 6,
            ),
            // Electric glow
            BoxShadow(
              color: (isFocused ? const Color(0xFF00E5FF) : stone.glowColor)
                  .withValues(alpha: isFocused ? 0.45 : 0.15),
              blurRadius: isFocused ? 14 : 6,
            ),
          ],
        ),
        child: Stack(
          children: [
            // Carved In-Depth Bevel Texture
            Positioned(
              top: 2,
              left: 2,
              right: 2,
              child: Container(
                height: 2,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    stone.symbol,
                    style: TextStyle(
                      fontSize: 22,
                      color: isFocused ? const Color(0xFF00E5FF) : stone.glowColor,
                      shadows: [
                        Shadow(
                          color: stone.glowColor.withValues(alpha: 0.8),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    stone.name.toUpperCase(),
                    style: SwarmTextStyles.labelSmall.copyWith(
                      color: Colors.white70,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dynamic Electric Shock & Lightning Canvas Painter
class _ElectricShockPainter extends CustomPainter {
  final Animation<double> animation;
  _ElectricShockPainter({required this.animation}) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final rand = Random((animation.value * 100).toInt());
    final paintBlue = Paint()
      ..color = const Color(0xFF00E5FF).withValues(alpha: 0.6)
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke;

    final paintPurple = Paint()
      ..color = const Color(0xFFD500F9).withValues(alpha: 0.6)
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke;

    // Draw electrical crackle along the perimeter
    final path = Path();
    for (int i = 0; i < 6; i++) {
      double startX = rand.nextDouble() * size.width;
      double startY = rand.nextBool() ? 0 : size.height;
      double endX = startX + (rand.nextDouble() * 40 - 20);
      double endY = startY + (startY == 0 ? 15 : -15);

      path.moveTo(startX, startY);
      path.lineTo(startX + (endX - startX) / 2 + (rand.nextDouble() * 8 - 4), startY + (endY - startY) / 2);
      path.lineTo(endX, endY);
      canvas.drawPath(path, rand.nextBool() ? paintBlue : paintPurple);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

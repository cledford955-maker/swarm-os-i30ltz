import 'dart:math';
import 'package:flutter/material.dart';
import '../services/lucille_voice_service.dart';
import '../theme/swarm_colors.dart';
import '../theme/swarm_text_styles.dart';

/// 420 Herbal Hive & Dispensary Easter Egg Overlay
/// Activates when typing '420' in terminal, toggling Stoner Mode, or clicking the Dispensary icon.
/// Displays floating crystalline weed buds, smoking blunts, and interactive dispensary strain profile cards.
class Hive420BudsOverlay extends StatefulWidget {
  const Hive420BudsOverlay({super.key});

  @override
  State<Hive420BudsOverlay> createState() => _Hive420BudsOverlayState();
}

class _Hive420BudsOverlayState extends State<Hive420BudsOverlay> with SingleTickerProviderStateMixin {
  final LucilleVoiceService _voice = LucilleVoiceService();
  late AnimationController _anim;

  final List<({
    String name,
    String type,
    String thc,
    String terpenes,
    String effects,
    Color color,
    Offset pos,
    double size,
    String icon,
    String description
  })> _buds = [
    (
      name: 'Granddaddy Purple',
      type: 'Indica (100%)',
      thc: '28% THC · 1.2% CBD',
      terpenes: 'Myrcene, Caryophyllene, Pinene',
      effects: 'Deep Body Melt, Euphoric Calm, Stress Relief',
      color: const Color(0xFFAB47BC),
      pos: const Offset(0.08, 0.18),
      size: 38,
      icon: '🍇🌿',
      description: 'Classic California purple genetics with deep berry aroma and heavy evening relaxation.'
    ),
    (
      name: 'Sour Diesel',
      type: 'Sativa (90%)',
      thc: '26% THC · 0.8% CBD',
      terpenes: 'Limonene, Terpinolene, Myrcene',
      effects: 'High Energy Focus, Creative Flow, Uplifted',
      color: const Color(0xFF7CB342),
      pos: const Offset(0.88, 0.22),
      size: 42,
      icon: '⛽🌿',
      description: 'Legendary pungent fuel aroma with fast-acting, invigorating cerebral energy.'
    ),
    (
      name: 'OG Kush',
      type: 'Hybrid (55/45)',
      thc: '27% THC · 1.0% CBD',
      terpenes: 'Caryophyllene, Limonene, Linalool',
      effects: 'Balanced Buzz, Full Mind-Body Harmony',
      color: const Color(0xFF43A047),
      pos: const Offset(0.12, 0.72),
      size: 40,
      icon: '🌲🌿',
      description: 'Complex earthy pine and wood tones powering iconic West Coast hybrid excellence.'
    ),
    (
      name: 'Gelato #33 (Larry Bird)',
      type: 'Hybrid (50/50)',
      thc: '29% THC · 0.5% CBD',
      terpenes: 'Limonene, Humulene, Linalool',
      effects: 'Sweet Mood Lift, Warm Relaxation, Smooth Flow',
      color: const Color(0xFFEC407A),
      pos: const Offset(0.84, 0.68),
      size: 36,
      icon: '🍨🌿',
      description: 'Sunset Sherbet x Thin Mint GSC cross delivering sweet dessert citrus notes.'
    ),
    (
      name: 'Lucille Haze',
      type: 'Flagship Neural Sativa',
      thc: '31% THC · 2.0% CBG',
      terpenes: 'Beta-Caryophyllene, Ocimene, Nerolidol',
      effects: 'Hyper-Focus Coding, AI Synapse Expansion, Pure Euphoria',
      color: SwarmColors.lucille,
      pos: const Offset(0.48, 0.88),
      size: 46,
      icon: '👄✨',
      description: 'Exclusive Hive strain cultivated by Dr. Boltz specifically for late-night kernel engineering.'
    ),
    (
      name: 'Northern Lights',
      type: 'Pure Indica',
      thc: '25% THC · 1.5% CBD',
      terpenes: 'Myrcene, Pinene, Beta-Caryophyllene',
      effects: 'Cosmic Relaxation, Lucid Dreaming, Muscle Ease',
      color: const Color(0xFF00E676),
      pos: const Offset(0.24, 0.42),
      size: 34,
      icon: '🌌🌿',
      description: 'Pungently sweet, spicy aromas with crystalline resin trichomes for deep recovery.'
    ),
    (
      name: 'Purple Wasp Kush',
      type: 'Exotic Honeycomb Hybrid',
      thc: '30% THC · 1.8% CBD',
      terpenes: 'Linalool, Alpha-Bisabolol, Terpineol',
      effects: 'Heavy Honey Body High, Euphoric Velvet Mind',
      color: const Color(0xFF8E24AA),
      pos: const Offset(0.74, 0.45),
      size: 38,
      icon: '🐝🍇',
      description: 'Cross of Granddaddy Purple and Honeycomb Wasp genetics. Dense purple buds dripping in golden resin.'
    ),
  ];

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat(reverse: true);
    _voice.addListener(_onVoiceChanged);
  }

  @override
  void dispose() {
    _voice.removeListener(_onVoiceChanged);
    _anim.dispose();
    super.dispose();
  }

  void _onVoiceChanged() {
    if (mounted) setState(() {});
  }

  void _showStrainDetails(dynamic strain) {
    _voice.speak('Examining strain ${strain.name}. Potency is ${strain.thc}. Effects: ${strain.effects}.');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0D140E),
        shape: RoundedCornerShape(18),
        insetPadding: const EdgeInsets.all(24),
        title: Row(
          children: [
            Text(strain.icon, style: const TextStyle(fontSize: 28)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(strain.name, style: TextStyle(color: strain.color, fontWeight: FontWeight.bold, fontSize: 18)),
                  Text('${strain.type} • ${strain.thc}', style: const TextStyle(color: Color(0xFF81C784), fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: strain.color.withValues(alpha: 0.4)),
                ),
                child: Text(strain.description, style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.4)),
              ),
              const SizedBox(height: 14),
              _buildLabRow('🧬 Primary Terpenes', strain.terpenes),
              const SizedBox(height: 8),
              _buildLabRow('✨ Reported Effects', strain.effects),
              const SizedBox(height: 14),
              const Row(
                children: [
                  Icon(Icons.check_circle, color: Color(0xFF66BB6A), size: 16),
                  SizedBox(width: 6),
                  Text('Lab Certified • Dr. Boltz Hive Tested', style: TextStyle(color: Color(0xFF81C784), fontSize: 11, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('CLOSE', style: TextStyle(color: Color(0xFF66BB6A))),
          ),
        ],
      ),
    );
  }

  Widget _buildLabRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Color(0xFF81C784), fontSize: 11, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_voice.is420StonerMode) {
      return const SizedBox.shrink();
    }

    return AnimatedBuilder(
      animation: _anim,
      builder: (context, child) {
        final pulse = _anim.value;

        return Stack(
          children: [
            // Ambient green/purple resin glow
            IgnorePointer(
              ignoring: true,
              child: Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 1.2,
                    colors: [
                      const Color(0xFF43A047).withValues(alpha: 0.08 + (0.04 * pulse)),
                      const Color(0xFF8E24AA).withValues(alpha: 0.04),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            // Floating Strain Badges & Top Easter Egg Banner
            LayoutBuilder(
              builder: (context, constraints) {
                return Stack(
                  children: [
                    // Top Banner Easter Egg Indicator
                    Positioned(
                      top: 48,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1B5E20).withValues(alpha: 0.90),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFF66BB6A), width: 1.2),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF66BB6A).withValues(alpha: 0.4 * pulse),
                                blurRadius: 16,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('🌿💨', style: TextStyle(fontSize: 16)),
                              const SizedBox(width: 8),
                              Text(
                                '420 HERBAL HIVE DISPENSARY • DR. BOLTZ RELAXED FREQUENCY ACTIVE',
                                style: SwarmTextStyles.codeSmall.copyWith(
                                  color: const Color(0xFFE8F5E9),
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.5,
                                  fontSize: 11,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text('🍯🐝', style: TextStyle(fontSize: 16)),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Interactive Crystalline Buds & Strain Cards
                    for (int i = 0; i < _buds.length; i++) ...[
                      Positioned(
                        left: constraints.maxWidth * _buds[i].pos.dx - 40,
                        top: constraints.maxHeight * _buds[i].pos.dy + (sin((pulse * 2 * pi) + i) * 8),
                        child: GestureDetector(
                          onTap: () => _showStrainDetails(_buds[i]),
                          child: MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.85),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: _buds[i].color, width: 1.4),
                                boxShadow: [
                                  BoxShadow(
                                    color: _buds[i].color.withValues(alpha: 0.4 * pulse),
                                    blurRadius: 14,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(_buds[i].icon, style: TextStyle(fontSize: _buds[i].size * 0.5)),
                                  const SizedBox(width: 6),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        _buds[i].name,
                                        style: TextStyle(
                                          color: _buds[i].color,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        '${_buds[i].type} · ${_buds[i].thc}',
                                        style: const TextStyle(
                                          color: Color(0xFFC8E6C9),
                                          fontSize: 9,
                                          fontFamily: 'monospace',
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
          ],
        );
      },
    );
  }
}

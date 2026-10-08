import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/swarm_colors.dart';

/// Placeholder shown in the web demo for features that need a real machine
/// (local files, terminals, hardware, installers).
class WebDemoComingSoonPage extends StatelessWidget {
  final String feature;
  final String blurb;
  const WebDemoComingSoonPage({super.key, required this.feature, required this.blurb});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Container(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: SwarmColors.bg.withValues(alpha: 0.88),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.35)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.rocket_launch, size: 44, color: Color(0xFF00E5FF)),
              const SizedBox(height: 16),
              Text(feature,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              const Text('COMING SOON TO THE WEB DEMO',
                  style: TextStyle(color: Color(0xFF00FF66), fontSize: 12, letterSpacing: 1.6)),
              const SizedBox(height: 16),
              Text(blurb,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.4)),
              const SizedBox(height: 8),
              const Text('This runs natively on SWARM OS.',
                  style: TextStyle(color: Colors.white54, fontSize: 12)),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => context.go('/'),
                icon: const Icon(Icons.home),
                label: const Text('Back to desktop'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

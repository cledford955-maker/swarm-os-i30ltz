import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'lucille_splash_screen.dart';

/// ═══════════════════════════════════════════════════════════════
/// SPLASH ROUTER
/// ═══════════════════════════════════════════════════════════════
/// Plays the cinematic Blue Angels video splash,
/// then navigates to the Hub.
/// ═══════════════════════════════════════════════════════════════
class SplashRouter extends StatelessWidget {
  /// The main app widget (unused — we navigate via GoRouter).
  final Widget child;

  /// Legacy params kept for API compatibility.
  final bool showLoadingScreen;
  final Duration loadingDuration;

  const SplashRouter({
    super.key,
    required this.child,
    this.showLoadingScreen = true,
    this.loadingDuration = const Duration(seconds: 4),
  });

  @override
  Widget build(BuildContext context) {
    return LucilleSplashScreen(
      onComplete: () {
        if (context.mounted) context.go('/lock');
      },
    );
  }
}
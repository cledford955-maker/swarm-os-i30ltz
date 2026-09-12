// Swarm OS — Home Screen Terminal Integration
// Drop-in terminal for home page bottom section + full screen route

import 'package:flutter/material.dart';
import 'swarm_terminal.dart';

/// Compact terminal for the home screen bottom area
class HomeTerminal extends StatelessWidget {
  final double height;
  final String? startDirectory;

  const HomeTerminal({
    super.key,
    this.height = 350,
    this.startDirectory,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: SwarmTerminal(
        initialPanes: 1,
        startDirectory: startDirectory,
      ),
    );
  }
}

/// Full-screen terminal (for dedicated terminal page / route)
class FullScreenTerminal extends StatelessWidget {
  final int initialPanes;
  final String? startDirectory;

  const FullScreenTerminal({
    super.key,
    this.initialPanes = 1,
    this.startDirectory,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080816),
      body: SwarmTerminal(
        initialPanes: initialPanes,
        startDirectory: startDirectory,
      ),
    );
  }
}

/// 4-pane terminal view
class QuadTerminal extends StatelessWidget {
  final String? startDirectory;

  const QuadTerminal({super.key, this.startDirectory});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080816),
      body: SwarmTerminal(
        initialPanes: 4,
        startDirectory: startDirectory,
      ),
    );
  }
}
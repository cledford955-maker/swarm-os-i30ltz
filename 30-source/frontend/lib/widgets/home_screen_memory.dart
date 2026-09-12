// Swarm OS — Home Screen Memory Integration
// Drop-in replacement for the old "keep this agent on home screen" section.
// Usage: just place HomeScreenMemory() in your home screen layout.

import 'package:flutter/material.dart';
import 'agent_memory_panel.dart';

class HomeScreenMemory extends StatelessWidget {
  const HomeScreenMemory({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 480,
      child: AgentMemoryPanel(),
    );
  }
}

/// Expandable full-screen version for dedicated memory view.
class AgentMemoryFullScreen extends StatelessWidget {
  const AgentMemoryFullScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A16),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D1A),
        elevation: 0,
        title: const Row(
          children: [
            Icon(Icons.memory, color: Color(0xFF00D4FF), size: 22),
            SizedBox(width: 10),
            Text(
              'Agent Memory',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white54),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: const Padding(
        padding: EdgeInsets.all(16),
        child: AgentMemoryPanel(),
      ),
    );
  }
}
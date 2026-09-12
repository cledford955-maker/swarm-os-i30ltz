// Swarm OS — Agent Terminal
// Terminal widget that any agent can embed for its own command execution.
// Pre-configures working directory and optional startup commands.

import 'package:flutter/material.dart';
import 'swarm_terminal.dart';

class AgentTerminal extends StatelessWidget {
  final String agentName;
  final String? workingDirectory;
  final double? height;

  const AgentTerminal({
    super.key,
    required this.agentName,
    this.workingDirectory,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: SwarmTerminal(
        initialPanes: 1,
        startDirectory: workingDirectory,
      ),
    );
  }
}
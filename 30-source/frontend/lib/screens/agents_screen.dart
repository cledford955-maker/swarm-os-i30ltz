import 'package:flutter/material.dart';
import '../widgets/agent_list_tile.dart';

class AgentsScreen extends StatelessWidget {
  const AgentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Agents'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {},
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(8),
        children: const [
          Card(
            child: AgentListTile(
              name: 'Orchestrator',
              status: 'active',
              subtitle: 'Managing 4 agents',
            ),
          ),
          SizedBox(height: 4),
          Card(
            child: AgentListTile(
              name: 'Analyst-01',
              status: 'active',
              subtitle: 'Processing data pipeline',
            ),
          ),
          SizedBox(height: 4),
          Card(
            child: AgentListTile(
              name: 'Builder-01',
              status: 'idle',
              subtitle: 'Waiting for task',
            ),
          ),
          SizedBox(height: 4),
          Card(
            child: AgentListTile(
              name: 'Reviewer-01',
              status: 'active',
              subtitle: 'Code review in progress',
            ),
          ),
          SizedBox(height: 4),
          Card(
            child: AgentListTile(
              name: 'Scanner-01',
              status: 'error',
              subtitle: 'Connection timeout',
            ),
          ),
        ],
      ),
    );
  }
}
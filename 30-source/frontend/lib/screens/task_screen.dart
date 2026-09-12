import 'package:flutter/material.dart';

class TaskScreen extends StatelessWidget {
  const TaskScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tasks'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {},
          ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: 5,
        itemBuilder: (context, index) {
          final tasks = [
            {
              'title': 'Data Analysis Pipeline',
              'status': 'running',
              'agent': 'Analyst-01'
            },
            {
              'title': 'Code Review',
              'status': 'completed',
              'agent': 'Reviewer-01'
            },
            {
              'title': 'API Integration',
              'status': 'pending',
              'agent': 'Builder-01'
            },
            {
              'title': 'Security Scan',
              'status': 'running',
              'agent': 'Scanner-01'
            },
            {
              'title': 'Deploy to Staging',
              'status': 'failed',
              'agent': 'DevOps-01'
            },
          ];
          final task = tasks[index];
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 4),
            child: ListTile(
              leading: _statusIcon(task['status']!),
              title: Text(
                task['title']!,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text('Agent: ${task['agent']}'),
              trailing: _statusChip(context, task['status']!),
              onTap: () {},
            ),
          );
        },
      ),
    );
  }

  Widget _statusIcon(String status) {
    switch (status) {
      case 'running':
        return const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        );
      case 'completed':
        return const Icon(Icons.check_circle, color: Colors.green);
      case 'failed':
        return const Icon(Icons.error, color: Colors.red);
      case 'pending':
        return const Icon(Icons.schedule, color: Colors.orange);
      default:
        return const Icon(Icons.help_outline);
    }
  }

  Widget _statusChip(BuildContext context, String status) {
    Color color;
    switch (status) {
      case 'running':
        color = Colors.blue;
        break;
      case 'completed':
        color = Colors.green;
        break;
      case 'failed':
        color = Colors.red;
        break;
      case 'pending':
        color = Colors.orange;
        break;
      default:
        color = Colors.grey;
    }

    return Chip(
      label: Text(
        status.toUpperCase(),
        style:
            TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
      backgroundColor: color.withValues(alpha: 0.1),
      side: BorderSide(color: color.withValues(alpha: 0.3)),
      padding: EdgeInsets.zero,
      labelPadding: const EdgeInsets.symmetric(horizontal: 8),
    );
  }
}

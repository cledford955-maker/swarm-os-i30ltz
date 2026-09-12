import 'package:flutter/material.dart';

class MemoryScreen extends StatelessWidget {
  const MemoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Memory'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {},
          ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: 6,
        itemBuilder: (context, index) {
          final memories = [
            {'title': 'User Preferences', 'type': 'long-term', 'size': '2.4 KB'},
            {'title': 'Chat Context #42', 'type': 'short-term', 'size': '1.1 KB'},
            {'title': 'Agent Skills Map', 'type': 'long-term', 'size': '8.7 KB'},
            {'title': 'Session State', 'type': 'working', 'size': '512 B'},
            {'title': 'Task History', 'type': 'long-term', 'size': '15.3 KB'},
            {'title': 'Tool Results Cache', 'type': 'short-term', 'size': '3.2 KB'},
          ];
          final memory = memories[index];
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 4),
            child: ListTile(
              leading: Icon(
                _typeIcon(memory['type']!),
                color: _typeColor(memory['type']!),
              ),
              title: Text(
                memory['title']!,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text('${memory['type']} • ${memory['size']}'),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline, size: 20),
                onPressed: () {},
              ),
              onTap: () {},
            ),
          );
        },
      ),
    );
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'long-term':
        return Icons.storage;
      case 'short-term':
        return Icons.timer;
      case 'working':
        return Icons.memory;
      default:
        return Icons.data_object;
    }
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'long-term':
        return Colors.blue;
      case 'short-term':
        return Colors.orange;
      case 'working':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }
}
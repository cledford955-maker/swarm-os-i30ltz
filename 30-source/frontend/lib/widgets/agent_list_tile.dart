import 'package:flutter/material.dart';

class AgentListTile extends StatelessWidget {
  final String name;
  final String status;
  final String? subtitle;
  final VoidCallback? onTap;

  const AgentListTile({
    super.key,
    required this.name,
    required this.status,
    this.subtitle,
    this.onTap,
  });

  Color _statusColor(BuildContext context) {
    switch (status.toLowerCase()) {
      case 'active':
      case 'online':
        return Colors.green;
      case 'idle':
        return Colors.orange;
      case 'error':
      case 'offline':
        return Colors.red;
      default:
        return Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListTile(
      tileColor: theme.colorScheme.surface,
      leading: CircleAvatar(
        backgroundColor: _statusColor(context).withValues(alpha: 0.2),
        child: Icon(
          Icons.smart_toy,
          color: _statusColor(context),
          size: 20,
        ),
      ),
      title: Text(
        name,
        style: theme.textTheme.bodyLarge?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        subtitle ?? status,
        style: theme.textTheme.bodySmall?.copyWith(
          color: _statusColor(context),
        ),
      ),
      trailing: Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _statusColor(context),
        ),
      ),
      onTap: onTap,
    );
  }
}

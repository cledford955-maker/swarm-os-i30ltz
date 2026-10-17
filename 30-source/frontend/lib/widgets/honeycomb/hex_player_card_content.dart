import 'package:flutter/material.dart';

/// The inner content of a player hex card.
/// Displays agent name, role, status, and key info
/// arranged to fit inside a hexagon shape.
class HexPlayerCardContent extends StatelessWidget {
  final String name;
  final String role;
  final String status;
  final String? model;
  final String? task;
  final IconData icon;
  final Color accentColor;
  final VoidCallback? onTap;

  const HexPlayerCardContent({
    super.key,
    required this.name,
    required this.role,
    this.status = 'offline',
    this.model,
    this.task,
    this.icon = Icons.smart_toy,
    this.accentColor = const Color(0xFF00FFFF),
    this.onTap,
  });

  Color get statusColor {
    switch (status.toLowerCase()) {
      case 'online':
        return const Color(0xFF00FF88);
      case 'busy':
        return const Color(0xFFFFAA00);
      case 'idle':
        return const Color(0xFF8888FF);
      case 'offline':
      default:
        return const Color(0xFF666666);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xDD0A0A12),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Status dot + icon row
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: statusColor,
                    boxShadow: [
                      BoxShadow(
                        color: statusColor.withValues(alpha: 0.6),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(icon, color: accentColor, size: 22),
              ],
            ),
            const SizedBox(height: 8),

            // Agent name
            Text(
              name,
              style: TextStyle(
                color: accentColor,
                fontSize: 14,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),

            // Role
            Text(
              role.toUpperCase(),
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 9,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.5,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),

            // Model chip
            if (model != null && model!.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  color: accentColor.withValues(alpha: 0.1),
                  border: Border.all(
                    color: accentColor.withValues(alpha: 0.3),
                    width: 0.5,
                  ),
                ),
                child: Text(
                  model!,
                  style: TextStyle(
                    color: accentColor.withValues(alpha: 0.8),
                    fontSize: 8,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

            // Current task
            if (task != null && task!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                task!,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.35),
                  fontSize: 8,
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],

            const SizedBox(height: 6),

            // Status label
            Text(
              status.toUpperCase(),
              style: TextStyle(
                color: statusColor,
                fontSize: 8,
                fontWeight: FontWeight.w700,
                letterSpacing: 2.0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
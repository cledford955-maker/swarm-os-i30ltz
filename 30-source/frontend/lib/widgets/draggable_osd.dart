import 'package:flutter/material.dart';
import '../theme/swarm_colors.dart';
import '../theme/swarm_text_styles.dart';

class DraggableOSD extends StatefulWidget {
  const DraggableOSD({super.key});

  @override
  State<DraggableOSD> createState() => _DraggableOSDState();
}

class _DraggableOSDState extends State<DraggableOSD> {
  // Initial position of the OSD
  Offset _position = const Offset(20, 100);
  bool _isExpanded = true;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: _position.dx,
      top: _position.dy,
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            _position += details.delta;
          });
        },
        onDoubleTap: () {
          setState(() {
            _isExpanded = !_isExpanded;
          });
        },
        child: Container(
          width: _isExpanded ? 250 : 100,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: SwarmColors.bgElevated.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(12),
            border:
                Border.all(color: SwarmColors.accent.withValues(alpha: 0.5)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.speed,
                          size: 16, color: SwarmColors.accent),
                      const SizedBox(width: 6),
                      Text('AI TELEMETRY',
                          style: SwarmTextStyles.label.copyWith(
                              fontSize: 10, color: SwarmColors.accent)),
                    ],
                  ),
                  const Icon(Icons.drag_indicator,
                      size: 16, color: SwarmColors.textSecondary),
                ],
              ),
              if (_isExpanded) ...[
                const SizedBox(height: 12),
                _buildStat('CPU', '14%', SwarmColors.agentCyan),
                const SizedBox(height: 8),
                _buildStat('RAM', '4.2 GB', SwarmColors.agentPink),
                const SizedBox(height: 8),
                _buildStat('GPU (Cloud)', '24ms Ping', Colors.greenAccent),
                const SizedBox(height: 12),
                // AI Graph Mock (Will be wired to backend stream)
                Container(
                  height: 40,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: SwarmColors.bg,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: CustomPaint(
                    painter: _MockGraphPainter(),
                  ),
                ),
                const SizedBox(height: 6),
                Center(
                  child: Text('Tokens/Sec: 42.5',
                      style: SwarmTextStyles.bodySmall.copyWith(fontSize: 10)),
                )
              ] else ...[
                const SizedBox(height: 8),
                Text('42.5 T/s',
                    style: SwarmTextStyles.h2
                        .copyWith(fontSize: 16, color: Colors.white)),
              ]
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStat(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: SwarmTextStyles.bodySmall,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 4),
        Text(value,
            style: SwarmTextStyles.bodySmall
                .copyWith(color: color, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

class _MockGraphPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = SwarmColors.accent
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final path = Path();
    path.moveTo(0, size.height * 0.8);
    path.lineTo(size.width * 0.2, size.height * 0.5);
    path.lineTo(size.width * 0.4, size.height * 0.7);
    path.lineTo(size.width * 0.6, size.height * 0.2);
    path.lineTo(size.width * 0.8, size.height * 0.4);
    path.lineTo(size.width, size.height * 0.1);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

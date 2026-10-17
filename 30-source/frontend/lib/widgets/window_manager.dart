// ═══════════════════════════════════════════════════════════════
// Swarm OS — Agent Window Manager v2
// Floating, draggable, resizable windows for agent panels.
// Multiple windows on screen. Drag from any edge to resize.
// Minimize, maximize, close. Taskbar with window buttons.
// ═══════════════════════════════════════════════════════════════

import 'dart:math';
import 'package:flutter/material.dart';

class AgentWindow {
  final String id;
  final String title;
  final IconData icon;
  final Color accentColor;
  final Widget Function(BuildContext context) builder;

  Offset position;
  Size size;
  bool minimized;
  bool maximized;
  int zIndex;

  // Saved state for restore from maximize
  Offset? _savedPos;
  Size? _savedSize;

  AgentWindow({
    required this.id,
    required this.title,
    required this.icon,
    required this.accentColor,
    required this.builder,
    this.position = const Offset(60, 60),
    this.size = const Size(480, 380),
    this.minimized = false,
    this.maximized = false,
    this.zIndex = 0,
  });
}

enum _ResizeEdge { none, top, bottom, left, right, topLeft, topRight, bottomLeft, bottomRight }

class WindowManager extends StatefulWidget {
  final Widget background;
  final List<AgentWindow>? initialWindows;

  const WindowManager({super.key, required this.background, this.initialWindows});

  @override
  State<WindowManager> createState() => WindowManagerState();
}

class WindowManagerState extends State<WindowManager> {
  final List<AgentWindow> _windows = [];
  int _topZ = 1;
  static const double _minW = 260;
  static const double _minH = 180;
  static const double _barH = 34;
  static const double _taskH = 40;
  static const double _edgePad = 6;

  @override
  void initState() {
    super.initState();
    if (widget.initialWindows != null) _windows.addAll(widget.initialWindows!);
  }

  void openWindow({
    required String id,
    required String title,
    required IconData icon,
    required Color accentColor,
    required Widget Function(BuildContext) builder,
    Size? size,
  }) {
    final existing = _windows.where((w) => w.id == id).firstOrNull;
    if (existing != null) {
      _front(existing);
      if (existing.minimized) setState(() => existing.minimized = false);
      return;
    }
    final off = Offset(70 + (_windows.length % 8) * 28.0, 70 + (_windows.length % 8) * 28.0);
    setState(() {
      _topZ++;
      _windows.add(AgentWindow(
        id: id, title: title, icon: icon, accentColor: accentColor,
        builder: builder, position: off, size: size ?? const Size(500, 400), zIndex: _topZ,
      ));
    });
  }

  void _close(AgentWindow w) => setState(() => _windows.remove(w));

  void _front(AgentWindow w) => setState(() { _topZ++; w.zIndex = _topZ; });

  void _minimize(AgentWindow w) => setState(() => w.minimized = true);

  void _toggleMax(AgentWindow w) {
    setState(() {
      if (w.maximized) {
        w.position = w._savedPos ?? const Offset(60, 60);
        w.size = w._savedSize ?? const Size(500, 400);
        w.maximized = false;
      } else {
        w._savedPos = w.position;
        w._savedSize = w.size;
        w.maximized = true;
        _topZ++;
        w.zIndex = _topZ;
      }
    });
  }

  void _clampPos(AgentWindow w) {
    final s = MediaQuery.of(context).size;
    w.position = Offset(
      w.position.dx.clamp(-w.size.width + 80, s.width - 80),
      w.position.dy.clamp(0, s.height - 60),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sorted = List<AgentWindow>.from(_windows)..sort((a, b) => a.zIndex.compareTo(b.zIndex));

    return Stack(children: [
      Positioned.fill(child: widget.background),
      ...sorted.where((w) => !w.minimized).map((w) => _buildWin(w)),
      if (_windows.isNotEmpty) Positioned(left: 0, right: 0, bottom: 0, child: _taskbar()),
    ]);
  }

  Widget _buildWin(AgentWindow w) {
    final screen = MediaQuery.of(context).size;
    final isFront = w.zIndex == _topZ;

    if (w.maximized) {
      return Positioned(
        left: 0, top: 0,
        width: screen.width, height: screen.height - _taskH,
        child: _winBody(w, screen.width, screen.height - _taskH, isFront),
      );
    }

    return Positioned(
      left: w.position.dx, top: w.position.dy,
      child: _resizable(w, isFront),
    );
  }

  Widget _resizable(AgentWindow w, bool isFront) {
    return SizedBox(
      width: w.size.width + _edgePad * 2,
      height: w.size.height + _edgePad * 2,
      child: Stack(children: [
        // Main window body
        Positioned(
          left: _edgePad, top: _edgePad,
          child: _winBody(w, w.size.width, w.size.height, isFront),
        ),

        // Edge resize zones
        // Top
        Positioned(left: _edgePad + 12, top: 0, right: _edgePad + 12, height: _edgePad,
          child: _edgeHandle(w, _ResizeEdge.top, SystemMouseCursors.resizeUp)),
        // Bottom
        Positioned(left: _edgePad + 12, bottom: 0, right: _edgePad + 12, height: _edgePad,
          child: _edgeHandle(w, _ResizeEdge.bottom, SystemMouseCursors.resizeDown)),
        // Left
        Positioned(left: 0, top: _edgePad + 12, bottom: _edgePad + 12, width: _edgePad,
          child: _edgeHandle(w, _ResizeEdge.left, SystemMouseCursors.resizeLeft)),
        // Right
        Positioned(right: 0, top: _edgePad + 12, bottom: _edgePad + 12, width: _edgePad,
          child: _edgeHandle(w, _ResizeEdge.right, SystemMouseCursors.resizeRight)),
        // Corners
        Positioned(left: 0, top: 0, width: _edgePad + 12, height: _edgePad + 12,
          child: _edgeHandle(w, _ResizeEdge.topLeft, SystemMouseCursors.resizeUpLeft)),
        Positioned(right: 0, top: 0, width: _edgePad + 12, height: _edgePad + 12,
          child: _edgeHandle(w, _ResizeEdge.topRight, SystemMouseCursors.resizeUpRight)),
        Positioned(left: 0, bottom: 0, width: _edgePad + 12, height: _edgePad + 12,
          child: _edgeHandle(w, _ResizeEdge.bottomLeft, SystemMouseCursors.resizeDownLeft)),
        Positioned(right: 0, bottom: 0, width: _edgePad + 12, height: _edgePad + 12,
          child: _edgeHandle(w, _ResizeEdge.bottomRight, SystemMouseCursors.resizeDownRight)),
      ]),
    );
  }

  Widget _edgeHandle(AgentWindow w, _ResizeEdge edge, MouseCursor cursor) {
    return MouseRegion(
      cursor: cursor,
      child: GestureDetector(
        onPanStart: (_) => _front(w),
        onPanUpdate: (d) {
          setState(() {
            final dx = d.delta.dx;
            final dy = d.delta.dy;
            switch (edge) {
              case _ResizeEdge.right:
                w.size = Size(max(_minW, w.size.width + dx), w.size.height);
              case _ResizeEdge.bottom:
                w.size = Size(w.size.width, max(_minH, w.size.height + dy));
              case _ResizeEdge.left:
                final nw = max(_minW, w.size.width - dx);
                if (nw != w.size.width) { w.position = Offset(w.position.dx + dx, w.position.dy); w.size = Size(nw, w.size.height); }
              case _ResizeEdge.top:
                final nh = max(_minH, w.size.height - dy);
                if (nh != w.size.height) { w.position = Offset(w.position.dx, w.position.dy + dy); w.size = Size(w.size.width, nh); }
              case _ResizeEdge.topLeft:
                final nw = max(_minW, w.size.width - dx);
                final nh = max(_minH, w.size.height - dy);
                w.position = Offset(
                  nw != w.size.width ? w.position.dx + dx : w.position.dx,
                  nh != w.size.height ? w.position.dy + dy : w.position.dy,
                );
                w.size = Size(nw, nh);
              case _ResizeEdge.topRight:
                final nh = max(_minH, w.size.height - dy);
                w.position = Offset(w.position.dx, nh != w.size.height ? w.position.dy + dy : w.position.dy);
                w.size = Size(max(_minW, w.size.width + dx), nh);
              case _ResizeEdge.bottomLeft:
                final nw = max(_minW, w.size.width - dx);
                if (nw != w.size.width) w.position = Offset(w.position.dx + dx, w.position.dy);
                w.size = Size(nw, max(_minH, w.size.height + dy));
              case _ResizeEdge.bottomRight:
                w.size = Size(max(_minW, w.size.width + dx), max(_minH, w.size.height + dy));
              case _ResizeEdge.none:
                break;
            }
          });
        },
      ),
    );
  }

  Widget _winBody(AgentWindow w, double width, double height, bool isFront) {
    return GestureDetector(
      onTap: () => _front(w),
      child: Container(
        width: width, height: height,
        decoration: BoxDecoration(
          color: const Color(0xFF0B0B1C),
          borderRadius: w.maximized ? null : BorderRadius.circular(10),
          border: Border.all(
            color: w.accentColor.withValues(alpha: isFront ? 0.35 : 0.1),
            width: isFront ? 1.5 : 0.5,
          ),
          boxShadow: w.maximized ? null : [
            BoxShadow(color: Colors.black.withValues(alpha: 0.6), blurRadius: 30, offset: const Offset(0, 10)),
            if (isFront) BoxShadow(color: w.accentColor.withValues(alpha: 0.08), blurRadius: 40),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(children: [
          _titleBar(w, isFront),
          Expanded(child: ClipRect(child: w.builder(context))),
        ]),
      ),
    );
  }

  Widget _titleBar(AgentWindow w, bool isFront) {
    return GestureDetector(
      onPanUpdate: w.maximized ? null : (d) {
        setState(() { w.position += d.delta; _clampPos(w); });
      },
      onDoubleTap: () => _toggleMax(w),
      onTap: () => _front(w),
      child: Container(
        height: _barH,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [
            w.accentColor.withValues(alpha: isFront ? 0.1 : 0.04),
            const Color(0xFF0E0E24),
          ]),
          border: const Border(bottom: BorderSide(color: Color(0xFF1E1E44))),
        ),
        child: Row(children: [
          Icon(w.icon, color: w.accentColor.withValues(alpha: isFront ? 1 : 0.4), size: 14),
          const SizedBox(width: 8),
          Expanded(child: Text(
            w.title,
            style: TextStyle(
              color: Colors.white.withValues(alpha: isFront ? 0.85 : 0.4),
              fontSize: 11.5, fontWeight: FontWeight.w600, letterSpacing: 0.3,
            ),
            overflow: TextOverflow.ellipsis,
          )),
          _wb(Icons.remove, Colors.white24, () => _minimize(w)),
          _wb(w.maximized ? Icons.filter_none : Icons.crop_square, Colors.white24, () => _toggleMax(w)),
          _wb(Icons.close, const Color(0xFFFF5F56), () => _close(w)),
        ]),
      ),
    );
  }

  Widget _wb(IconData icon, Color c, VoidCallback tap) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: tap,
        child: Container(
          padding: const EdgeInsets.all(4),
          margin: const EdgeInsets.only(left: 2),
          child: Icon(icon, color: c, size: 13),
        ),
      ),
    );
  }

  Widget _taskbar() {
    return Container(
      height: _taskH,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A1C).withValues(alpha: 0.95),
        border: const Border(top: BorderSide(color: Color(0xFF1E1E44))),
      ),
      child: Row(children: [
        const Padding(
          padding: EdgeInsets.only(right: 10),
          child: Text('⚡', style: TextStyle(fontSize: 15)),
        ),
        ..._windows.map((w) {
          final isFront = w.zIndex == _topZ && !w.minimized;
          return GestureDetector(
            onTap: () {
              if (w.minimized) {
                setState(() => w.minimized = false);
                _front(w);
              } else if (isFront) {
                _minimize(w);
              } else {
                _front(w);
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              margin: const EdgeInsets.only(right: 3, top: 5, bottom: 5),
              decoration: BoxDecoration(
                color: isFront ? w.accentColor.withValues(alpha: 0.12) : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: isFront ? w.accentColor.withValues(alpha: 0.25) : Colors.white.withValues(alpha: 0.04)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(w.icon, color: w.accentColor.withValues(alpha: w.minimized ? 0.3 : 0.8), size: 13),
                const SizedBox(width: 5),
                Text(w.title, style: TextStyle(
                  color: Colors.white.withValues(alpha: w.minimized ? 0.25 : 0.6),
                  fontSize: 10.5, fontWeight: isFront ? FontWeight.w600 : FontWeight.w400,
                )),
              ]),
            ),
          );
        }),
        const Spacer(),
        // Clock
        StreamBuilder(
          stream: Stream.periodic(const Duration(seconds: 1)),
          builder: (_, __) {
            final n = DateTime.now();
            return Text(
              '${n.hour.toString().padLeft(2, '0')}:${n.minute.toString().padLeft(2, '0')}',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.25), fontSize: 10, fontFamily: 'monospace'),
            );
          },
        ),
      ]),
    );
  }
}
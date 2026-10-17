import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../theme/swarm_colors.dart';
import 'top_bar.dart';
import 'window_manager.dart';
import 'os_window.dart';
import 'desktop_taskbar.dart';
import 'left_app_drawer.dart';
import 'right_settings_drawer.dart';
import '../services/gamepad_service.dart';
import '../widgets/virtual_cursor_overlay.dart';
import '../widgets/seductive_lips_visualizer.dart';
import '../services/wake_word_service.dart';
import '../widgets/hive_watermark_overlay.dart';
import '../widgets/lucille_voice_hud_button.dart';
import '../widgets/hive_420_overlay.dart';
import '../widgets/rotating_wallpaper.dart';
import '../widgets/swarm_ambient_background.dart';
import 'desktop_geometry.dart';

/// Top-level desktop shell — wraps all pages with edge drawers, seductive lips visualizer, and window manager
class SwarmShell extends ConsumerStatefulWidget {
  final Widget child;
  const SwarmShell({super.key, required this.child});

  @override
  ConsumerState<SwarmShell> createState() => _SwarmShellState();
}

class _SwarmShellState extends ConsumerState<SwarmShell> {
  bool _isLeftDrawerOpen = false;
  bool _isRightDrawerOpen = false;
  bool _isLeftHovered = false;
  bool _isRightHovered = false;
  DateTime _lastDesktopScroll = DateTime.fromMillisecondsSinceEpoch(0);
  double _desktopScrollDistance = 0;

  @override
  void initState() {
    super.initState();
    // Initialize controller & gamepad virtual mouse service
    GamepadService().initialize(
      toggleLeft: _toggleLeftDrawer,
      toggleRight: _toggleRightDrawer,
      closeDrawers: _closeAllDrawers,
    );

    // Initialize Lucille background wake word listener ("Hey Lucy" / "Lucille")
    WakeWordService().startListening();
  }

  void _toggleLeftDrawer() {
    setState(() {
      _isLeftDrawerOpen = !_isLeftDrawerOpen;
      if (_isLeftDrawerOpen) _isRightDrawerOpen = false;
    });
  }

  void _toggleRightDrawer() {
    setState(() {
      _isRightDrawerOpen = !_isRightDrawerOpen;
      if (_isRightDrawerOpen) _isLeftDrawerOpen = false;
    });
  }

  void _closeAllDrawers() {
    if (_isLeftDrawerOpen || _isRightDrawerOpen) {
      setState(() {
        _isLeftDrawerOpen = false;
        _isRightDrawerOpen = false;
      });
    }
  }

  void _handleDesktopScroll(PointerSignalEvent event, List<AppWindow> windows, int page) {
    if (event is! PointerScrollEvent) return;
    final now = DateTime.now();
    if (now.difference(_lastDesktopScroll) < const Duration(milliseconds: 650)) {
      _desktopScrollDistance = 0;
      return;
    }

    final box = context.findRenderObject();
    if (box is! RenderBox) return;
    final localPosition = box.globalToLocal(event.position);
    if (localPosition.dy <= 48) return; // Keep the top-bar controls scroll-safe.
    try {
      if (GoRouterState.of(context).uri.path != '/') return;
    } catch (_) {
      return;
    }

    for (final window in windows.where((w) => w.desktopPage == page)) {
      if (window.isMaximized ||
          (Rect.fromLTWH(window.position.dx, window.position.dy,
                  window.size.width, window.size.height)
              .contains(localPosition))) {
        _desktopScrollDistance = 0;
        return; // Preserve scrolling and gestures inside app windows.
      }
    }

    _desktopScrollDistance += event.scrollDelta.dy;
    if (_desktopScrollDistance.abs() < 48) return;
    final direction = _desktopScrollDistance.sign;
    _desktopScrollDistance = 0;
    _lastDesktopScroll = now;
    final pages = ref.read(activeDesktopPageProvider.notifier);
    pages.state = direction > 0 ? page + 1 : (page > 0 ? page - 1 : 0);
  }

  @override
  Widget build(BuildContext context) {
    final windows = ref.watch(windowProvider);
    final activePage = ref.watch(activeDesktopPageProvider);

    return Scaffold(
      backgroundColor: SwarmColors.bg,
      body: Listener(
        onPointerSignal: (event) => _handleDesktopScroll(event, windows, activePage),
        child: Stack(
        children: [
          // 1. Background Wallpaper — a random picture from
          //    /mnt/Lucy/images/websitebackgrounds, swapped every few minutes
          //    (FALLEN SOLDIER if the folder is missing), with a light aura
          //    that pulses faster as CPU load rises. Also records the shell
          //    size so new windows open between the icon rails.
          Positioned.fill(
            child: LayoutBuilder(builder: (context, constraints) {
              DesktopGeometry.screen = constraints.biggest;
              return const RotatingWallpaper();
            }),
          ),

          // 1b. Large Background Welcome Typography
          const Positioned.fill(
            child: HiveBackgroundWelcome(),
          ),

          // 1c. Ambient swarm — a slow drift of small robotic wasps behind
          // all desktop content and every window, so the swarm reads as a
          // constant presence across the whole shell rather than something
          // confined to specific decorations.
          const Positioned.fill(
            child: SwarmAmbientBackground(),
          ),

          // 2. Base Desktop / Center Cards Content
          Column(
            children: [
              const SwarmTopBar(),
              Expanded(child: widget.child),
            ],
          ),

          // 3. Universal Cybernetic Watermark Overlay (I320K3-N-I30LTZ)
          const Positioned.fill(
            child: HiveWatermarkOverlay(),
          ),

          // 3b. 420 Herbal Hive & Crystalline Weed Buds Easter Egg Overlay
          const Positioned.fill(
            child: Hive420BudsOverlay(),
          ),

          // 4. Full-Screen Transparent Seductive Lips Visualizer
          const SeductiveLipsVisualizer(),

          // 5. Floating Window Overlay
          if (windows.isNotEmpty)
            Stack(
              children: windows.map((w) => OsWindowWidget(
                key: ValueKey('window-${w.id}'),
                window: w,
                isPageVisible: w.desktopPage == activePage,
              )).toList(),
            ),

          // 5b. Static taskbar — every open window, minimized or not, always
          // in the same place. The one way back to a window buried behind
          // a maximized app or on another desktop page.
          const DesktopTaskbar(),

          // 4b. Persistent Floating Lucille Voice Controller (Stop Speaking /
          // Wait / Mute) — kept ABOVE the window overlay and taskbar on
          // purpose: it used to sit underneath them in the stack, so any
          // window placed over it (maximized ones especially) silently
          // covered the one always-available way to talk to Lucille.
          const LucilleVoiceHudButton(),

          // 5. Backdrop barrier when either drawer is open
          if (_isLeftDrawerOpen || _isRightDrawerOpen)
            Positioned.fill(
              child: GestureDetector(
                onTap: _closeAllDrawers,
                child: Container(
                  color: Colors.black.withValues(alpha: 0.4),
                ),
              ),
            ),

          // 6. Left Center-Edge Trigger Handle (App Drawer)
          Positioned(
            left: 0,
            top: MediaQuery.of(context).size.height * 0.42,
            child: MouseRegion(
              onEnter: (_) => setState(() => _isLeftHovered = true),
              onExit: (_) => setState(() => _isLeftHovered = false),
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: _toggleLeftDrawer,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: _isLeftHovered ? 34 : 26,
                  height: 96,
                  decoration: BoxDecoration(
                    color: SwarmColors.bgSurface.withValues(alpha: 0.92),
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(14),
                      bottomRight: Radius.circular(14),
                    ),
                    border: Border.all(
                      color: _isLeftHovered ? SwarmColors.accent : SwarmColors.border,
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _isLeftHovered
                            ? SwarmColors.accent.withValues(alpha: 0.5)
                            : Colors.black.withValues(alpha: 0.4),
                        blurRadius: _isLeftHovered ? 14 : 6,
                        offset: const Offset(3, 0),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _isLeftDrawerOpen ? Icons.chevron_left : Icons.apps,
                        color: _isLeftHovered ? SwarmColors.accent : SwarmColors.textSecondary,
                        size: 16,
                      ),
                      const SizedBox(height: 4),
                      RotatedBox(
                        quarterTurns: 3,
                        child: Text(
                          'APPS',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                            color: _isLeftHovered ? SwarmColors.accent : SwarmColors.textMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // 7. Right Center-Edge Trigger Handle (Settings Drawer)
          Positioned(
            right: 0,
            top: MediaQuery.of(context).size.height * 0.42,
            child: MouseRegion(
              onEnter: (_) => setState(() => _isRightHovered = true),
              onExit: (_) => setState(() => _isRightHovered = false),
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: _toggleRightDrawer,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: _isRightHovered ? 34 : 26,
                  height: 96,
                  decoration: BoxDecoration(
                    color: SwarmColors.bgSurface.withValues(alpha: 0.92),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(14),
                      bottomLeft: Radius.circular(14),
                    ),
                    border: Border.all(
                      color: _isRightHovered ? SwarmColors.accent : SwarmColors.border,
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _isRightHovered
                            ? SwarmColors.accent.withValues(alpha: 0.5)
                            : Colors.black.withValues(alpha: 0.4),
                        blurRadius: _isRightHovered ? 14 : 6,
                        offset: const Offset(-3, 0),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _isRightDrawerOpen ? Icons.chevron_right : Icons.tune,
                        color: _isRightHovered ? SwarmColors.accent : SwarmColors.textSecondary,
                        size: 16,
                      ),
                      const SizedBox(height: 4),
                      RotatedBox(
                        quarterTurns: 3,
                        child: Text(
                          'CONFIG',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                            color: _isRightHovered ? SwarmColors.accent : SwarmColors.textMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // 8. Left Sliding App Drawer
          LeftAppDrawer(
            isOpen: _isLeftDrawerOpen,
            onClose: () => setState(() => _isLeftDrawerOpen = false),
          ),

          // 9. Right Sliding Settings Drawer
          RightSettingsDrawer(
            isOpen: _isRightDrawerOpen,
            onClose: () => setState(() => _isRightDrawerOpen = false),
          ),

          // 10. Controller Virtual Mouse & Crosshair Overlay
          const VirtualCursorOverlay(),
        ],
      ),
      ),
    );
  }
}

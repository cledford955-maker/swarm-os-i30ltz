import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart' as p;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';
import 'package:media_kit/media_kit.dart';

import 'router.dart';
import 'theme/swarm_theme.dart';
import 'widgets/openrouter_balance_widget.dart';
import 'widgets/ui_zoom_control.dart';
import 'services/ui_scale_service.dart';
import 'services/ai_client.dart';
import 'services/telemetry_service.dart';
import 'services/memory_service.dart';
import 'services/sound_service.dart';
import 'services/gamepad_service.dart';
import 'services/vital_service.dart';
import 'services/sentinel_client.dart';
import 'services/openrouter_balance_service.dart';
import 'services/lucille_voice_service.dart';
import 'services/wake_word_service.dart';
import 'services/google_hub_service.dart';
import 'services/auth_service.dart';
import 'services/lucy_server_client.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  await windowManager.ensureInitialized();

  final isWayland = Platform.environment.containsKey('WAYLAND_DISPLAY');

  const windowOptions = WindowOptions(
    size: Size(1440, 900),
    minimumSize: Size(800, 600),
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.hidden,
    title: 'SWARM OS · Lucille v6',
  );

  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    if (isWayland) {
      await windowManager.setFullScreen(true);
    }
    await windowManager.show();
    await windowManager.focus();
  });

  final prefs = await SharedPreferences.getInstance();
  final aiClient = AiClient();
  final telemetryService = TelemetryService();
  final memoryService = MemoryService();
  final soundService = SoundService.instance;
  final gamepadService = GamepadService();
  final vitalService = VitalService();
  final sentinelClient = SentinelClient();
  final openRouterBalanceService = OpenRouterBalanceService();
  final voiceService = LucilleVoiceService();
  final wakeWordService = WakeWordService();
  final googleHubService = GoogleHubService();
  final authService = AuthService();
  final lucyServerClient = LucyServerClient();
  final uiScaleService = UiScaleService();

  runApp(
    ProviderScope(
      child: p.MultiProvider(
        providers: [
          p.ChangeNotifierProvider.value(value: uiScaleService),
          p.Provider.value(value: aiClient),
          p.Provider.value(value: telemetryService),
          p.Provider.value(value: memoryService),
          p.Provider.value(value: soundService),
          p.ChangeNotifierProvider.value(value: gamepadService),
          p.ChangeNotifierProvider.value(value: vitalService),
          p.Provider.value(value: sentinelClient),
          p.ChangeNotifierProvider.value(value: openRouterBalanceService),
          p.ChangeNotifierProvider.value(value: voiceService),
          p.ChangeNotifierProvider.value(value: wakeWordService),
          p.Provider.value(value: googleHubService),
          p.Provider.value(value: authService),
          p.Provider.value(value: lucyServerClient),
          p.Provider.value(value: prefs),
        ],
        child: const SwarmApp(),
      ),
    ),
  );
}

class SwarmApp extends StatefulWidget {
  const SwarmApp({super.key});

  @override
  State<SwarmApp> createState() => _SwarmAppState();
}

class _SwarmAppState extends State<SwarmApp> {
  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    super.dispose();
  }

  // Ctrl+= / Ctrl+- / Ctrl+0 — whole-shell zoom, works from any screen.
  bool _onKey(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    if (!HardwareKeyboard.instance.isControlPressed) return false;
    final ui = context.read<UiScaleService>();
    if (event.logicalKey == LogicalKeyboardKey.equal ||
        event.logicalKey == LogicalKeyboardKey.numpadAdd) {
      ui.zoomIn();
      return true;
    }
    if (event.logicalKey == LogicalKeyboardKey.minus ||
        event.logicalKey == LogicalKeyboardKey.numpadSubtract) {
      ui.zoomOut();
      return true;
    }
    if (event.logicalKey == LogicalKeyboardKey.digit0 ||
        event.logicalKey == LogicalKeyboardKey.numpad0) {
      ui.reset();
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'SWARM OS · Lucille v6',
      debugShowCheckedModeBanner: false,
      theme: SwarmTheme.dark,
      routerConfig: goRouter,
      builder: (context, child) {
        return p.Consumer<UiScaleService>(
          builder: (context, ui, _) {
            return Stack(
              children: [
                if (child != null) _wholeShellZoom(context, child, ui.scale),
                const Positioned(
                  top: 10,
                  right: 15,
                  child: Material(
                    color: Colors.transparent,
                    child: SafeArea(
                      child: OpenRouterBalanceWidget(),
                    ),
                  ),
                ),
                const UiZoomControl(),
              ],
            );
          },
        );
      },
    );
  }

  // Scales every screen in the shell uniformly (icons, text, layout — not
  // just fonts), keeping hit-testing correct. Content is laid out against a
  // shrunk/grown "virtual" screen size and then stretched back to the real
  // one via Transform.scale.
  Widget _wholeShellZoom(BuildContext context, Widget child, double scale) {
    if (scale == 1.0) return child;
    final mq = MediaQuery.of(context);
    final virtualSize = mq.size / scale;
    return MediaQuery(
      data: mq.copyWith(size: virtualSize),
      child: OverflowBox(
        alignment: Alignment.topLeft,
        minWidth: virtualSize.width,
        maxWidth: virtualSize.width,
        minHeight: virtualSize.height,
        maxHeight: virtualSize.height,
        child: Transform.scale(
          scale: scale,
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: virtualSize.width,
            height: virtualSize.height,
            child: child,
          ),
        ),
      ),
    );
  }
}
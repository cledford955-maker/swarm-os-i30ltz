import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:swarm_flutter/pages/command_reference_page.dart';
import 'package:swarm_flutter/services/ui_scale_service.dart';
import 'package:swarm_flutter/widgets/ui_zoom_control.dart';

void main() {
  testWidgets('zoom: hover and tap +/- without build errors, default 1.3', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final ui = UiScaleService();
    expect(ui.scale, 1.3);
    final router = GoRouter(routes: [
      GoRoute(path: '/', builder: (_, __) => const Scaffold(body: Center(child: Text('desktop')))),
    ]);
    await tester.pumpWidget(p.ChangeNotifierProvider.value(
      value: ui,
      child: MaterialApp.router(
        routerConfig: router,
        builder: (context, child) => p.Consumer<UiScaleService>(
          builder: (context, ui, _) => Stack(children: [
            WholeShellZoom(scale: ui.scale, child: child!),
            const UiZoomControl(),
          ]),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(find.byIcon(Icons.add)));
    await tester.pump(const Duration(seconds: 2));
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();
    expect(ui.scale, closeTo(1.4, 1e-9));
    for (var i = 0; i < 6; i++) {
      await tester.tap(find.byIcon(Icons.remove));
      await tester.pump();
    }
    expect(find.text('desktop'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('command reference renders and copies', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: CommandReferencePage())));
    expect(find.text('COMMAND REFERENCE'), findsOneWidget);
    await tester.tap(find.text('Copy').first);
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}

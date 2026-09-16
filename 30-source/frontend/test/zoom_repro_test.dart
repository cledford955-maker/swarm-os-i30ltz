import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:swarm_flutter/services/ui_scale_service.dart';
import 'package:swarm_flutter/widgets/ui_zoom_control.dart';

void main() {
  testWidgets('zoom control: tap + and hover without errors', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final ui = UiScaleService();
    final router = GoRouter(routes: [
      GoRoute(path: '/', builder: (_, __) => const Scaffold(body: Center(child: Text('desktop')))),
    ]);
    await tester.pumpWidget(p.ChangeNotifierProvider.value(
      value: ui,
      child: MaterialApp.router(
        routerConfig: router,
        builder: (context, child) => Stack(children: [child!, const UiZoomControl()]),
      ),
    ));
    await tester.pumpAndSettle();
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    await gesture.moveTo(tester.getCenter(find.byIcon(Icons.add)));
    await tester.pump(const Duration(seconds: 2));
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump(const Duration(seconds: 2));
    expect(tester.takeException(), isNull);
  });
}

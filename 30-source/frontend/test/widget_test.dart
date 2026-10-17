import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swarm_flutter/shell/top_bar.dart';

void main() {
  testWidgets('SWARM OS top bar boots and renders brand and nav', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: SwarmTopBar(),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('SWARM'), findsWidgets);
    expect(find.text('SYSOPT'), findsOneWidget);
  });
}

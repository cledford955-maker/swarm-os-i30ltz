import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/widgets/diagnostics_export.dart';

void main() {
  testWidgets('diagnostic export starts without logs and allows opting in', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: DiagnosticsExport())));
    expect(find.text('Save diagnostic bundle'), findsOneWidget);
    expect(tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value, isFalse);
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();
    expect(tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value, isTrue);
    expect(tester.takeException(), isNull);
  });
}

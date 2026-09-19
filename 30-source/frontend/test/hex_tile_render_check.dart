// Not a real test — a throwaway visual-verification harness. Renders a
// small HexGrid (some tiles with previewImagePath, some without, one
// dragging) to a PNG so the result can actually be looked at: this
// environment has no display, and hex_grid.dart's CustomPainter is shared
// by every tile on the real desktop, so "it compiles" isn't enough
// confidence for a change here. Delete this file once the change has been
// reviewed — it's scaffolding, not a permanent regression test.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swarm_flutter/widgets/hex_grid.dart';

void main() {
  testWidgets('render hex tiles to PNG for visual inspection', (tester) async {
    final agents = [
      HexAgent(
        id: 'lucille',
        name: 'Lucille',
        icon: Icons.auto_awesome,
        color: const Color(0xFFCE93D8),
        bgColor: const Color(0xFF1A1332),
        previewImagePath: 'assets/wallpapers/lucille_swarm_core.jpg',
      ),
      HexAgent(
        id: 'forge',
        name: 'Forge',
        icon: Icons.construction,
        color: const Color(0xFF9575CD),
        bgColor: const Color(0xFF1A1332),
        previewImagePath: 'assets/wallpapers/forge_ide_core.jpg',
      ),
      HexAgent(
        id: 'gaming',
        name: 'Gamer',
        icon: Icons.sports_esports,
        color: const Color(0xFF2979FF),
        bgColor: const Color(0xFF1A1332),
        previewImagePath: 'assets/wallpapers/this_is_now_gaming.jpg',
      ),
      // No previewImagePath — must still look correct (this is the path
      // ~37 other agents take): flat gradient fill, no image logic at all.
      HexAgent(
        id: 'terminal',
        name: 'Terminal',
        icon: Icons.terminal,
        color: const Color(0xFF00D4FF),
        bgColor: const Color(0xFF1A1332),
      ),
      HexAgent(
        id: 'settings',
        name: 'Settings',
        icon: Icons.settings,
        color: const Color(0xFF78909C),
        bgColor: const Color(0xFF1A1332),
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: const Color(0xFF0D0A18),
          body: Center(
            child: RepaintBoundary(
              key: const Key('capture'),
              child: SizedBox(
                width: 700,
                height: 260,
                child: HexGrid(
                  agents: agents,
                  columns: 5,
                  rows: 1,
                  hexSize: 60,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    // Not pumpAndSettle: HexGrid's pulse controller repeats forever, so
    // "settle" never arrives. Explicitly wait for each real JPEG to finish
    // decoding (large files, genuinely async) rather than guessing a frame
    // count — that's what produced blank tiles on the first attempt.
    await tester.pump();
    for (final path in [
      'assets/wallpapers/lucille_swarm_core.jpg',
      'assets/wallpapers/forge_ide_core.jpg',
      'assets/wallpapers/this_is_now_gaming.jpg',
    ]) {
      await tester.runAsync(() async {
        final provider = AssetImage(path);
        final stream = provider.resolve(ImageConfiguration.empty);
        final completer = Completer<void>();
        late ImageStreamListener listener;
        listener = ImageStreamListener((info, _) {
          stream.removeListener(listener);
          completer.complete();
        }, onError: (err, st) {
          stream.removeListener(listener);
          completer.completeError(err);
        });
        stream.addListener(listener);
        await completer.future;
      });
    }
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(const Key('capture')));
    final image = await boundary.toImage(pixelRatio: 2.0);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final outFile = File(
      '${Platform.environment['TMPDIR'] ?? '/tmp'}/hex_tile_render.png',
    );
    outFile.parent.createSync(recursive: true);
    outFile.writeAsBytesSync(bytes!.buffer.asUint8List());
    // ignore: avoid_print
    print('Wrote ${outFile.path} (${bytes.lengthInBytes} bytes)');
  });
}

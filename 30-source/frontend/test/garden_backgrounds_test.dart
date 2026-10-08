import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swarm_flutter/screens/cannabis_mode_screen.dart';
import 'package:swarm_flutter/services/garden_backgrounds_service.dart';
import 'package:swarm_flutter/theme/swarm_text_styles.dart';
import 'package:swarm_flutter/widgets/garden_smoke.dart';

// A valid 1x1 PNG.
final _tinyPng = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==');

const _known = ['Blue Dream', 'Gorilla Glue #4', 'Wedding Cake'];

void main() {
  late Directory tmp;

  setUpAll(() {
    // The card's title style comes from google_fonts, which fetches the font
    // over the network; test mode answers every request with 400, so the fetch
    // fails with an unhandled async error that would abort whichever test is
    // running when it lands. Build the style once here, in a zone that swallows
    // that one error, so the real tests find it already cached.
    TestWidgetsFlutterBinding.ensureInitialized();
    runZonedGuarded(() => SwarmTextStyles.title, (_, __) {});
  });

  setUp(() => tmp = Directory.systemTemp.createTempSync('garden_bg_test_'));
  tearDown(() => tmp.deleteSync(recursive: true));

  void photo(String name, [Directory? dir]) =>
      File('${(dir ?? tmp).path}/$name').writeAsBytesSync(_tinyPng);

  group('GardenBackgroundsService.labelFor', () {
    GardenBackground label(String file, {Map<String, dynamic>? entry}) =>
        GardenBackgroundsService.labelFor('/x/$file', knownStrains: _known, entry: entry);

    test('names a known strain from the text before "__", with its proper name', () {
      expect(label('blue_dream__01.jpg').strain, 'Blue Dream');
      expect(label('gorilla_glue_4__flower.png').strain, 'Gorilla Glue #4');
      expect(label('Wedding-Cake__a.webp').strain, 'Wedding Cake');
    });

    test('an unknown strain named by the file is shown as written, title-cased', () {
      expect(label('sunset_sherbet__02.jpg').strain, 'Sunset Sherbet');
    });

    test('never invents a strain: no "__" means no strain', () {
      expect(label('greenhouse_rows.jpg').strain, isNull);
      expect(label('blue_dream.jpg').strain, isNull, reason: 'a bare name without "__" is not a label');
      expect(label('__orphan.jpg').strain, isNull);
    });

    test('manifest entry adds caption and credit and can set or override the strain', () {
      final l = label('blue_dream__01.jpg', entry: {
        'strain': 'Blue Dream (phenotype 2)',
        'caption': ' Day 56 ',
        'credit': 'Photo: B. Someone / CC BY 4.0',
      });
      expect(l.strain, 'Blue Dream (phenotype 2)');
      expect(l.caption, 'Day 56');
      expect(l.credit, 'Photo: B. Someone / CC BY 4.0');
    });

    test('blank or non-string manifest values are ignored', () {
      final l = label('blue_dream__01.jpg', entry: {'strain': '  ', 'caption': 7, 'credit': ''});
      expect(l.strain, 'Blue Dream', reason: 'a blank override must not erase the file-name label');
      expect(l.caption, isNull);
      expect(l.credit, isNull);
    });
  });

  group('GardenBackgroundsService.load', () {
    test('first folder that has images wins; others are not mixed in', () async {
      final empty = Directory('${tmp.path}/empty')..createSync();
      final a = Directory('${tmp.path}/a')..createSync();
      final b = Directory('${tmp.path}/b')..createSync();
      photo('blue_dream__1.png', a);
      photo('other__1.png', b);

      final got = await GardenBackgroundsService.load([empty.path, a.path, b.path], knownStrains: _known);
      expect(got.map((g) => g.strain), ['Blue Dream']);
    });

    test('reads labels.json, and ignores a broken one', () async {
      photo('rows.png');
      File('${tmp.path}/labels.json').writeAsStringSync(jsonEncode({
        'rows.png': {'caption': 'Flowering room', 'credit': 'Photo: A / CC0'},
      }));
      var got = await GardenBackgroundsService.load([tmp.path]);
      expect(got.single.caption, 'Flowering room');
      expect(got.single.credit, 'Photo: A / CC0');

      File('${tmp.path}/labels.json').writeAsStringSync('{ not json');
      got = await GardenBackgroundsService.load([tmp.path]);
      expect(got.single.caption, isNull, reason: 'bad JSON falls back to file-name labels');
    });

    test('the manifest itself is not treated as a photo; missing folders give an empty list', () async {
      File('${tmp.path}/labels.json').writeAsStringSync('{}');
      expect(await GardenBackgroundsService.load([tmp.path]), isEmpty);
      expect(await GardenBackgroundsService.load(['${tmp.path}/nope']), isEmpty);
    });
  });

  group('GardenBackgroundsService.parseInterval', () {
    test('default, valid, too small, junk', () {
      expect(GardenBackgroundsService.parseInterval(null), const Duration(seconds: 12));
      expect(GardenBackgroundsService.parseInterval('30'), const Duration(seconds: 30));
      expect(GardenBackgroundsService.parseInterval('1'), const Duration(seconds: 4));
      expect(GardenBackgroundsService.parseInterval('x'), const Duration(seconds: 12));
    });
  });

  group('SmokeSystem', () {
    const idle = [SmokeEmitter(Offset(100, 500), rate: 10)];

    test('spawns at the emitter rate', () {
      final s = SmokeSystem(random: Random(1));
      for (var i = 0; i < 20; i++) {
        s.update(0.1, idle); // 2 s at 10/s
      }
      expect(s.particles.length, inInclusiveRange(19, 21));
    });

    test('puffs age out and are removed', () {
      final s = SmokeSystem(random: Random(1));
      for (var i = 0; i < 20; i++) {
        s.update(0.1, idle);
      }
      for (var i = 0; i < 120; i++) {
        s.update(0.1, const []); // 12 s with no emitters: longer than any life
      }
      expect(s.particles, isEmpty);
    });

    test('never exceeds maxParticles', () {
      final s = SmokeSystem(random: Random(1), maxParticles: 25);
      for (var i = 0; i < 100; i++) {
        s.update(0.1, const [SmokeEmitter(Offset(0, 0), rate: 200)]);
      }
      expect(s.particles.length, 25);
    });

    test('a long frame does not dump a burst of puffs', () {
      final s = SmokeSystem(random: Random(1));
      s.update(30, idle); // app was suspended for 30 s
      expect(s.particles.length, lessThanOrEqualTo(3));
    });

    test('same seed gives the same smoke', () {
      List<Offset> run() {
        final s = SmokeSystem(random: Random(42));
        for (var i = 0; i < 30; i++) {
          s.update(0.1, idle);
        }
        return [for (final p in s.particles) p.positionAt(s.now)];
      }

      expect(run(), run());
    });

    test('a puff climbs, grows, and fades in then out to nothing', () {
      final s = SmokeSystem(random: Random(3));
      s.update(0.2, idle);
      final p = s.particles.first;
      final born = p.born;
      final mid = born + p.life / 2;
      final end = born + p.life;

      expect(p.positionAt(mid).dy, lessThan(p.positionAt(born).dy), reason: 'smoke rises (y decreases)');
      expect(p.positionAt(end).dy, lessThan(p.positionAt(mid).dy));
      expect(p.sizeAt(end), greaterThan(p.sizeAt(born) * 3));
      expect(p.alphaAt(born), 0);
      expect(p.alphaAt(mid), greaterThan(0.02));
      expect(p.alphaAt(end), 0);
    });
  });

  group('GardenBluntLayout', () {
    test('lit ends sit above the ashtray and on screen, for common sizes', () {
      for (final size in const [Size(1920, 1080), Size(1366, 768), Size(2560, 1440)]) {
        final l = GardenBluntLayout(size);
        for (var i = 0; i < l.count; i++) {
          final tip = l.tip(i);
          expect(tip.dy, lessThan(l.tray.center.dy), reason: 'tip $i above tray at $size');
          expect((Offset.zero & size).contains(tip), isTrue, reason: 'tip $i on screen at $size');
        }
        final screen = Offset.zero & size;
        expect(screen.contains(l.tray.topLeft) && screen.contains(l.tray.bottomRight), isTrue,
            reason: 'ashtray on screen at $size');
      }
    });

    test('puff is a 0..1 bump that returns to rest; ember stays in range', () {
      var sawPuff = false, sawRest = false;
      for (var t = 0.0; t < 40; t += 0.05) {
        for (var i = 0; i < 3; i++) {
          final p = GardenBluntLayout.puff(i, t);
          expect(p, inInclusiveRange(0.0, 1.0));
          expect(GardenBluntLayout.ember(i, t), inInclusiveRange(0.2, 1.3));
          if (p > 0.9) sawPuff = true;
          if (p == 0) sawRest = true;
        }
      }
      expect(sawPuff && sawRest, isTrue);
    });
  });

  group('widgets', () {
    // Real file IO and image decode hop between real async and microtasks that
    // only run on pump, so alternate the two until [until] holds (or give up).
    Future<void> settle(WidgetTester t, {bool Function()? until}) async {
      for (var i = 0; i < 60; i++) {
        await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
        await t.pump(const Duration(milliseconds: 100));
        if (until != null && until()) break;
        if (until == null && i >= 9) break;
      }
      await t.pump(const Duration(seconds: 2));
    }

    Future<void> showGarden(WidgetTester t, {List<String>? dirs, Finder? waitFor}) async {
      t.view.physicalSize = const Size(1600, 900);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(MaterialApp(
        home: CannabisModeScreen(
          backgroundDirs: dirs ?? [tmp.path],
          backgroundInterval: const Duration(hours: 1),
        ),
      ));
      await settle(t, until: waitFor == null ? null : () => waitFor.evaluate().isNotEmpty);
    }

    Future<void> leave(WidgetTester t) async {
      await t.pumpWidget(const SizedBox.shrink()); // cancels timers
    }

    testWidgets('GardenSmoke builds, animates and disposes without errors', (t) async {
      await t.pumpWidget(const MaterialApp(home: SizedBox.expand(child: GardenSmoke())));
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
      for (var i = 0; i < 30; i++) {
        await t.pump(const Duration(milliseconds: 100));
      }
      expect(find.byType(GardenSmoke), findsOneWidget);
      await t.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('a photo named for a strain labels the card with that strain', (t) async {
      photo('blue_dream__01.png');
      File('${tmp.path}/labels.json').writeAsStringSync(jsonEncode({
        'blue_dream__01.png': {'caption': 'Day 56', 'credit': 'Photo: B. Someone / CC BY 4.0'},
      }));
      await showGarden(t, waitFor: find.text('Blue Dream'));

      expect(find.text('Blue Dream'), findsOneWidget);
      expect(find.text('STRAIN'), findsOneWidget);
      expect(find.text('LIVE STRAIN'), findsNothing);
      expect(find.text('Day 56'), findsOneWidget);
      expect(find.textContaining('Photo: B. Someone / CC BY 4.0'), findsOneWidget);
      expect(find.byType(GardenSmoke), findsOneWidget);

      // With a photo up, the old 7-second strain rotation stands down.
      await t.pump(const Duration(seconds: 20));
      expect(find.text('Blue Dream'), findsOneWidget);
      await leave(t);
    });

    testWidgets('a photo with no strain is labelled as a garden photo, not given a strain', (t) async {
      photo('greenhouse_rows.png');
      File('${tmp.path}/labels.json').writeAsStringSync(jsonEncode({
        'greenhouse_rows.png': {'caption': 'Flowering room'},
      }));
      await showGarden(t, waitFor: find.text('Flowering room'));

      expect(find.text('Flowering room'), findsOneWidget);
      expect(find.text('GARDEN'), findsOneWidget);
      expect(find.text('STRAIN'), findsNothing);
      expect(find.text('LIVE STRAIN'), findsNothing);
      await leave(t);
    });

    testWidgets('with no photos the painted garden and strain rotation remain', (t) async {
      await showGarden(t, dirs: ['${tmp.path}/nope']);

      expect(find.text('LIVE STRAIN'), findsOneWidget);
      expect(find.byType(GardenSmoke), findsOneWidget, reason: 'blunts and smoke show either way');
      await leave(t);
    });
  });
}

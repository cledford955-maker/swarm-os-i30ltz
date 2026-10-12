import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swarm_flutter/services/wallpaper_rotation_service.dart';
import 'package:swarm_flutter/widgets/cpu_aura_wallpaper.dart';
import 'package:swarm_flutter/widgets/garden_smoke.dart';
import 'package:swarm_flutter/widgets/rotating_wallpaper.dart';

// A valid 1x1 PNG.
final _tinyPng = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==');

void main() {
  late Directory tmp;

  setUp(() => tmp = Directory.systemTemp.createTempSync('wallpaper_test_'));
  tearDown(() => tmp.deleteSync(recursive: true));

  group('WallpaperRotationService.listImages', () {
    test('keeps image files, skips everything else, sorted', () async {
      for (final name in ['b.png', 'A.JPG', 'c.webp', 'd.jpeg', 'notes.txt', 'noext', '.hidden.png']) {
        File('${tmp.path}/$name').writeAsBytesSync(_tinyPng);
      }
      Directory('${tmp.path}/_skip').createSync();
      File('${tmp.path}/_skip/parked.png').writeAsBytesSync(_tinyPng);

      final got = await WallpaperRotationService.listImages(tmp.path);
      expect(got.map((p) => p.split('/').last), ['A.JPG', 'b.png', 'c.webp', 'd.jpeg']);
    });

    test('handles spaces, ? and & in file names', () async {
      for (final name in ['electric goddess.png', 'drbolt?.png', 'i320k3n.&i30ltz.png']) {
        File('${tmp.path}/$name').writeAsBytesSync(_tinyPng);
      }
      final got = await WallpaperRotationService.listImages(tmp.path);
      expect(got, hasLength(3));
      expect(got.every((p) => File(p).existsSync()), isTrue);
    });

    test('missing folder gives an empty list instead of throwing', () async {
      expect(await WallpaperRotationService.listImages('${tmp.path}/nope'), isEmpty);
    });
  });

  group('WallpaperRotationService.parseInterval', () {
    test('default, valid, too small, and junk', () {
      expect(WallpaperRotationService.parseInterval(null), const Duration(seconds: 600));
      expect(WallpaperRotationService.parseInterval('90'), const Duration(seconds: 90));
      expect(WallpaperRotationService.parseInterval(' 45 '), const Duration(seconds: 45));
      expect(WallpaperRotationService.parseInterval('2'), const Duration(seconds: 15));
      expect(WallpaperRotationService.parseInterval('-5'), const Duration(seconds: 15));
      expect(WallpaperRotationService.parseInterval('soon'), const Duration(seconds: 600));
    });
  });

  group('WallpaperRotationService.parseFlag', () {
    test('missing/empty use the default; off words turn it off; anything else is on', () {
      bool flag(String? v, {bool d = true}) => WallpaperRotationService.parseFlag(v, defaultValue: d);
      expect(flag(null), isTrue);
      expect(flag(''), isTrue);
      expect(flag('  '), isTrue);
      expect(flag(null, d: false), isFalse);
      for (final off in ['0', 'false', 'FALSE', 'off', ' No ']) {
        expect(flag(off), isFalse, reason: off);
      }
      for (final on in ['1', 'true', 'on', 'yes', 'whatever']) {
        expect(flag(on, d: false), isTrue, reason: on);
      }
    });
  });

  group('WallpaperRotationService.isFallenSoldier', () {
    test('matches the artwork under its usual names only', () {
      expect(WallpaperRotationService.isFallenSoldier('/x/FALLENSOLDIER.jpeg'), isTrue);
      expect(WallpaperRotationService.isFallenSoldier('/x/fallen_soldier.jpg'), isTrue);
      expect(WallpaperRotationService.isFallenSoldier('/x/Fallen Soldier.png'), isTrue);
      expect(WallpaperRotationService.isFallenSoldier('/x/Lucille1.png'), isFalse);
      expect(WallpaperRotationService.isFallenSoldier('/fallensoldier/other.png'), isFalse);
    });
  });

  group('WallpaperRotationService.isWildThing', () {
    test('null path (bundled fallback) is wild-thing', () {
      expect(WallpaperRotationService.isWildThing(null), isTrue);
    });

    test('matches wildthing.jpg and wild_thing.jpg variants', () {
      expect(WallpaperRotationService.isWildThing('/x/wildthing.jpg'), isTrue);
      expect(WallpaperRotationService.isWildThing('/x/wild_thing.jpg'), isTrue);
      expect(WallpaperRotationService.isWildThing('/x/Wild Thing.png'), isTrue);
      expect(WallpaperRotationService.isWildThing('/x/WILDTHING.jpeg'), isTrue);
    });

    test('does not match other wallpapers', () {
      expect(WallpaperRotationService.isWildThing('/x/Lucille1.png'), isFalse);
      expect(WallpaperRotationService.isWildThing('/x/fallen_soldier.jpg'), isFalse);
      expect(WallpaperRotationService.isWildThing('/wildthing/other.jpg'), isFalse);
    });
  });

  group('WallpaperPicker', () {
    final pool = ['a', 'b', 'c', 'd', 'e'];

    test('shows every picture once per round, in random order', () {
      final picker = WallpaperPicker(random: Random(1));
      final round = [for (var i = 0; i < pool.length; i++) picker.next(pool)!];
      expect(round.toSet(), pool.toSet());
    });

    test('never repeats back to back, including across rounds', () {
      final picker = WallpaperPicker(random: Random(7));
      String? last;
      for (var i = 0; i < 200; i++) {
        final pick = picker.next(pool)!;
        expect(pick, isNot(last), reason: 'repeat at step $i');
        last = pick;
      }
    });

    test('empty pool gives null; pool of one keeps returning it', () {
      final picker = WallpaperPicker();
      expect(picker.next(const []), isNull);
      expect(picker.next(const ['only']), 'only');
      expect(picker.next(const ['only']), 'only');
    });

    test('rejected pictures are never picked again', () {
      final picker = WallpaperPicker(random: Random(3));
      picker.reject('c');
      for (var i = 0; i < 50; i++) {
        expect(picker.next(pool), isNot('c'));
      }
    });

    test('a rejected-out pool gives null', () {
      final picker = WallpaperPicker()..reject('x');
      expect(picker.next(const ['x']), isNull);
    });

    test('wild_thing.jpg is always the first pick when present in the pool', () {
      final wtPool = ['a', 'b', '/wallpapers/wild_thing.jpg', 'c'];
      final picker = WallpaperPicker(random: Random(42));
      expect(picker.next(wtPool), '/wallpapers/wild_thing.jpg');
      // Subsequent picks are random (not wild-thing again on second call).
      final second = picker.next(wtPool)!;
      expect(second, isNot('/wallpapers/wild_thing.jpg'));
    });

    test('first-pick skips wild_thing prioritisation when pool lacks it', () {
      final picker = WallpaperPicker(random: Random(0));
      final first = picker.next(pool)!;
      // Just verify no crash — it will be some element of pool.
      expect(pool, contains(first));
    });

    test('a picture added later joins the rotation', () {
      final picker = WallpaperPicker(random: Random(5));
      final first = {for (var i = 0; i < 2; i++) picker.next(['a', 'b'])!};
      expect(first, {'a', 'b'});
      expect(picker.next(['a', 'b', 'new']), 'new');
    });
  });

  group('RotatingWallpaper', () {
    CpuAuraWallpaper aura(WidgetTester t) => t.widget<CpuAuraWallpaper>(find.byType(CpuAuraWallpaper));

    // [swapped]: wait until the picture changes from the bundled one (cases that
    // expect a swap). Without it, wait a fixed, generous time (cases that expect
    // the bundled picture to stay).
    Future<void> pumpWallpaper(WidgetTester t, String folder, {bool swapped = false}) async {
      await t.pumpWidget(MaterialApp(
        home: RotatingWallpaper(folder: folder, interval: const Duration(hours: 1)),
      ));
      // The first-frame pick hops between real IO (list, read, decode) and
      // microtasks that only run on pump, so alternate the two until it settles.
      for (var i = 0; i < 60; i++) {
        await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
        await t.pump(const Duration(milliseconds: 100));
        if (swapped ? aura(t).image is! AssetImage : i >= 24) break;
      }
      await t.pump(const Duration(seconds: 2)); // finish the crossfade
    }

    Future<void> disposeWallpaper(WidgetTester t) async {
      await t.pumpWidget(const SizedBox.shrink()); // cancels the timer
    }

    testWidgets('swaps the bundled picture for one from the folder', (t) async {
      File('${tmp.path}/Lucille1.png').writeAsBytesSync(_tinyPng);
      await pumpWallpaper(t, tmp.path, swapped: true);

      expect(aura(t).image, isA<ResizeImage>());
      expect(aura(t).boltGlows, isFalse);
      await disposeWallpaper(t);
    });

    testWidgets('fallen-soldier file loads like any other picture (bolt glows retired)', (t) async {
      // Bolt glows were pixel-mapped to old artwork; they are permanently off.
      File('${tmp.path}/FALLENSOLDIER.png').writeAsBytesSync(_tinyPng);
      await pumpWallpaper(t, tmp.path, swapped: true);

      expect(aura(t).image, isA<ResizeImage>());
      expect(aura(t).boltGlows, isFalse);
      await disposeWallpaper(t);
    });

    testWidgets('the blunt and smoke sit over the wallpaper, and can be turned off', (t) async {
      File('${tmp.path}/Lucille1.png').writeAsBytesSync(_tinyPng);

      await t.pumpWidget(MaterialApp(
        home: RotatingWallpaper(folder: tmp.path, interval: const Duration(hours: 1), blunt: true),
      ));
      expect(find.byType(GardenSmoke), findsOneWidget);
      await t.pumpWidget(const SizedBox.shrink());

      await t.pumpWidget(MaterialApp(
        home: RotatingWallpaper(folder: tmp.path, interval: const Duration(hours: 1), blunt: false),
      ));
      expect(find.byType(GardenSmoke), findsNothing);
      expect(find.byType(CpuAuraWallpaper), findsOneWidget);
      await disposeWallpaper(t);
    });

    testWidgets('missing folder keeps the bundled picture', (t) async {
      await pumpWallpaper(t, '${tmp.path}/nope');

      expect(aura(t).image, isA<AssetImage>());
      // boltGlows is always false now (bolt glows retired with fallen-soldier art)
      expect(aura(t).boltGlows, isFalse);
      await disposeWallpaper(t);
    });

    testWidgets('a corrupt file is skipped, not shown', (t) async {
      File('${tmp.path}/broken.png').writeAsStringSync('this is not a png');
      await pumpWallpaper(t, tmp.path);

      expect(aura(t).image, isA<AssetImage>());
      await disposeWallpaper(t);
    });

    testWidgets('a corrupt file does not block a good one', (t) async {
      File('${tmp.path}/broken.png').writeAsStringSync('this is not a png');
      File('${tmp.path}/good.png').writeAsBytesSync(_tinyPng);
      await pumpWallpaper(t, tmp.path, swapped: true);

      expect(aura(t).image, isA<ResizeImage>());
      await disposeWallpaper(t);
    });
  });
}

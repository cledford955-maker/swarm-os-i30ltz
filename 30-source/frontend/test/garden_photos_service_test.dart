import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:swarm_flutter/services/garden_photos_service.dart';

void main() {
  group('GardenPhotosService.slugFor', () {
    test('lowercases and collapses whitespace', () {
      expect(GardenPhotosService.slugFor('Lucille OG'), 'lucille_og');
      expect(GardenPhotosService.slugFor('SWARM Sativa'), 'swarm_sativa');
      expect(GardenPhotosService.slugFor('Ghost Train Haze'), 'ghost_train_haze');
    });

    test('digits are preserved, non-alphanumerics collapse to underscore', () {
      expect(GardenPhotosService.slugFor('Gorilla Glue #4'), 'gorilla_glue_4');
      expect(GardenPhotosService.slugFor('Mac 1'), 'mac_1');
      expect(GardenPhotosService.slugFor('Girl Scout Cookies'), 'girl_scout_cookies');
    });

    test('trailing separators are trimmed', () {
      expect(GardenPhotosService.slugFor('Some Strain! '), 'some_strain');
      expect(GardenPhotosService.slugFor('Weird---Name'), 'weird_name');
    });

    test('empty / all-punctuation returns empty string', () {
      expect(GardenPhotosService.slugFor(''), '');
      expect(GardenPhotosService.slugFor('!!!'), '');
    });
  });

  group('GardenPhotosService.photoPathFor', () {
    late Directory tempDir;
    late GardenPhotosService svc;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('garden_photos_test_');
      svc = GardenPhotosService.instance;
      svc.resetCache();
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
      svc.resetCache();
    });

    test('returns null when folder is empty', () {
      expect(svc.photoPathFor('Lucille OG', dir: tempDir.path), isNull);
    });

    test('returns null when folder does not exist', () {
      expect(
        svc.photoPathFor('Lucille OG', dir: '${tempDir.path}/does-not-exist'),
        isNull,
      );
    });

    test('finds .jpg for a matching strain', () {
      final path = '${tempDir.path}/lucille_og.jpg';
      File(path).writeAsBytesSync([0xFF, 0xD8]);
      expect(svc.photoPathFor('Lucille OG', dir: tempDir.path), path);
    });

    test('finds .png fallback when .jpg absent', () {
      final path = '${tempDir.path}/purple_punch.png';
      File(path).writeAsBytesSync([0x89, 0x50, 0x4E, 0x47]);
      expect(svc.photoPathFor('Purple Punch', dir: tempDir.path), path);
    });

    test('finds .webp fallback', () {
      final path = '${tempDir.path}/blue_dream.webp';
      File(path).writeAsBytesSync([0x52, 0x49, 0x46, 0x46]);
      expect(svc.photoPathFor('Blue Dream', dir: tempDir.path), path);
    });

    test('prefers jpg over png when both exist', () {
      final jpg = '${tempDir.path}/wedding_cake.jpg';
      final png = '${tempDir.path}/wedding_cake.png';
      File(jpg).writeAsBytesSync([0xFF, 0xD8]);
      File(png).writeAsBytesSync([0x89, 0x50, 0x4E, 0x47]);
      expect(svc.photoPathFor('Wedding Cake', dir: tempDir.path), jpg);
    });

    test('slug-with-digit resolves', () {
      final path = '${tempDir.path}/gorilla_glue_4.jpg';
      File(path).writeAsBytesSync([0xFF, 0xD8]);
      expect(svc.photoPathFor('Gorilla Glue #4', dir: tempDir.path), path);
    });

    test('cache remembers negatives too', () {
      // First lookup: no file, cache negative.
      expect(svc.photoPathFor('OG Kush', dir: tempDir.path), isNull);
      // Now create the file — a cache reset is required to see it.
      final path = '${tempDir.path}/og_kush.jpg';
      File(path).writeAsBytesSync([0xFF, 0xD8]);
      expect(svc.photoPathFor('OG Kush', dir: tempDir.path), isNull,
          reason: 'cached negative should persist without resetCache');
      svc.resetCache();
      expect(svc.photoPathFor('OG Kush', dir: tempDir.path), path);
    });

    test('empty strain name never matches', () {
      // Even if a file at "/.jpg" existed we would not open it — slug empty.
      expect(svc.photoPathFor('', dir: tempDir.path), isNull);
    });
  });
}

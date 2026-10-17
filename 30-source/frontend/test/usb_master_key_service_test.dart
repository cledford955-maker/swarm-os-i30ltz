import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:swarm_flutter/services/usb_master_key_service.dart';

String sha(String s) => sha256.convert(utf8.encode(s)).toString();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('UsbMasterKeyService Tests', () {
    late Directory tempDir;
    late Directory stick;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      tempDir = Directory.systemTemp.createTempSync('swarm_usb_test_');
      stick = Directory('${tempDir.path}/stick')..createSync();
      UsbMasterKeyService.keyHashFileOverride = '${tempDir.path}/cfg/usb_master_key.sha256';
    });

    tearDown(() {
      UsbMasterKeyService.keyHashFileOverride = null;
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    });

    String secretOn(Directory d) {
      final line = File('${d.path}/swarm_master.key')
          .readAsLinesSync()
          .firstWhere((l) => l.startsWith('KEY='));
      return line.substring(4);
    }

    test('writes a random key and registers only its hash', () async {
      final ok = await UsbMasterKeyService.writeMasterKeyToDrive(stick.path);
      expect(ok, isTrue);

      final secret = secretOn(stick);
      expect(secret, matches(RegExp(r'^[0-9a-f]{64}$')));
      expect(secret, isNot(UsbMasterKeyService.defaultMagicToken));
      expect(File('${stick.path}/swarm_master.key').readAsStringSync(), contains('SYSTEM=SWARM_OS'));

      expect(await UsbMasterKeyService.readKeyHash(), sha(secret));
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(UsbMasterKeyService.prefKeySecret), isNull);

      final found = UsbMasterKeyService.checkDirectoryForKey(stick.path, sha(secret));
      expect(found, isNotNull);
      expect(found!.keyContent, isEmpty); // the secret stays on the stick
    });

    test('a second stick retires the first', () async {
      final other = Directory('${tempDir.path}/stick2')..createSync();
      await UsbMasterKeyService.writeMasterKeyToDrive(stick.path);
      await UsbMasterKeyService.writeMasterKeyToDrive(other.path);
      final hash = await UsbMasterKeyService.readKeyHash();
      expect(UsbMasterKeyService.checkDirectoryForKey(other.path, hash!), isNotNull);
      expect(UsbMasterKeyService.checkDirectoryForKey(stick.path, hash), isNull);
    });

    test('custom secret is used as given', () async {
      final ok = await UsbMasterKeyService.writeMasterKeyToDrive(
        stick.path,
        customSecret: 'TEST_SECRET_KEY_123',
      );
      expect(ok, isTrue);
      expect(secretOn(stick), 'TEST_SECRET_KEY_123');
      expect(await UsbMasterKeyService.readKeyHash(), sha('TEST_SECRET_KEY_123'));
    });

    test('refuses the public default token and short secrets', () async {
      expect(
        () => UsbMasterKeyService.writeMasterKeyToDrive(stick.path,
            customSecret: UsbMasterKeyService.defaultMagicToken),
        throwsArgumentError,
      );
      expect(
        () => UsbMasterKeyService.writeMasterKeyToDrive(stick.path, customSecret: 'short'),
        throwsArgumentError,
      );
      expect(await UsbMasterKeyService.readKeyHash(), isNull);
    });

    test('refuses to write to protected mounts', () async {
      expect(
        () => UsbMasterKeyService.writeMasterKeyToDrive('/mnt/Lucy'),
        throwsA(isA<Exception>()),
      );
      expect(
        () => UsbMasterKeyService.writeMasterKeyToDrive('/mnt/swarmbuild'),
        throwsA(isA<Exception>()),
      );
      expect(
        () => UsbMasterKeyService.writeMasterKeyToDrive('/run/media/i30ltz/lucy-master'),
        throwsA(isA<Exception>()),
      );
    });

    test('refuses to write through a symlink already on the stick', () async {
      final victim = File('${tempDir.path}/host_file')..writeAsStringSync('keep me');
      Link('${stick.path}/swarm_master.key').createSync(victim.path);
      final ok = await UsbMasterKeyService.writeMasterKeyToDrive(stick.path);
      expect(ok, isFalse);
      expect(victim.readAsStringSync(), 'keep me');
      expect(await UsbMasterKeyService.readKeyHash(), isNull);
    });

    test('with no registered key nothing unlocks', () async {
      expect(await UsbMasterKeyService.readKeyHash(), isNull);
      for (final content in [
        'KEY=anything-at-all-here',
        'KEY=${UsbMasterKeyService.defaultMagicToken}',
        'SWARM_MASTER_KEY_V1',
        'just some text',
      ]) {
        expect(UsbMasterKeyService.verifyKeyFile(content, null), isFalse, reason: content);
        expect(UsbMasterKeyService.verifyKeyFile(content, ''), isFalse, reason: content);
      }
      // A key file on a stick is not even looked at without a registered key.
      File('${stick.path}/master.key').writeAsStringSync('KEY=whatever-123456');
      expect(await UsbMasterKeyService.scanForMasterKey(), isNull);
    });

    test('only an exact KEY= line with the registered secret passes', () {
      const secret = 'correct-horse-battery-staple';
      final hash = sha(secret);
      bool v(String c) => UsbMasterKeyService.verifyKeyFile(c, hash);

      expect(v('KEY=$secret'), isTrue);
      expect(v('# comment\nSYSTEM=SWARM_OS\nKEY=$secret\n'), isTrue);
      expect(v('  KEY=$secret  '), isTrue);
      expect(v('KEY=${secret}X'), isFalse);
      expect(v('KEY=X$secret'), isFalse);
      expect(v(secret), isFalse); // bare secret, no KEY= line
      expect(v('prefix $secret suffix'), isFalse);
      expect(v('XKEY=$secret'), isFalse);
      expect(v('SHA256=$hash'), isFalse); // the hash is not a key
      expect(v('KEY=$hash'), isFalse);
      expect(v('key=$secret'), isFalse);
      expect(UsbMasterKeyService.verifyKeyFile('KEY=$secret', hash.toUpperCase()), isTrue);
      expect(UsbMasterKeyService.verifyKeyFile('KEY=$secret', 'not-a-hash'), isFalse);
    });

    test('the default token never passes, even if its hash were registered', () {
      const t = UsbMasterKeyService.defaultMagicToken;
      expect(UsbMasterKeyService.verifyKeyFile('KEY=$t', sha(t)), isFalse);
    });

    test('symlinked key files and folders on the stick are ignored', () {
      const secret = 'correct-horse-battery-staple';
      final outside = Directory('${tempDir.path}/host')..createSync();
      File('${outside.path}/swarm_master.key').writeAsStringSync('KEY=$secret\n');

      Link('${stick.path}/swarm_master.key').createSync('${outside.path}/swarm_master.key');
      Link('${stick.path}/.swarm').createSync(outside.path);
      expect(UsbMasterKeyService.checkDirectoryForKey(stick.path, sha(secret)), isNull);

      // The same content as a real file on the stick is accepted.
      Link('${stick.path}/swarm_master.key').deleteSync();
      File('${stick.path}/swarm_master.key').writeAsStringSync('KEY=$secret\n');
      expect(UsbMasterKeyService.checkDirectoryForKey(stick.path, sha(secret)), isNotNull);
    });

    test('a real .swarm folder works, an oversized file does not', () {
      const secret = 'correct-horse-battery-staple';
      Directory('${stick.path}/.swarm').createSync();
      final f = File('${stick.path}/.swarm/swarm.key')..writeAsStringSync('KEY=$secret\n');
      expect(UsbMasterKeyService.checkDirectoryForKey(stick.path, sha(secret)), isNotNull);

      f.writeAsStringSync('KEY=$secret\n${'#' * 5000}\n');
      expect(UsbMasterKeyService.checkDirectoryForKey(stick.path, sha(secret)), isNull);
    });

    test('legacy plaintext pref becomes a hash and is removed', () async {
      SharedPreferences.setMockInitialValues({UsbMasterKeyService.prefKeySecret: 'an-old-custom-secret'});
      expect(await UsbMasterKeyService.readKeyHash(), sha('an-old-custom-secret'));
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(UsbMasterKeyService.prefKeySecret), isNull);
    });

    test('legacy default-token pref is dropped, not registered', () async {
      SharedPreferences.setMockInitialValues(
          {UsbMasterKeyService.prefKeySecret: UsbMasterKeyService.defaultMagicToken});
      expect(await UsbMasterKeyService.readKeyHash(), isNull);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(UsbMasterKeyService.prefKeySecret), isNull);
    });

    test('supports standard key file variations', () {
      expect(UsbMasterKeyService.supportedKeyFiles.contains('swarm_master.key'), isTrue);
      expect(UsbMasterKeyService.supportedKeyFiles.contains('swarm.key'), isTrue);
      expect(UsbMasterKeyService.supportedKeyFiles.contains('.swarm_master.key'), isTrue);
      expect(UsbMasterKeyService.supportedKeyFiles.contains('master.key'), isTrue);
      expect(UsbMasterKeyService.supportedKeyFiles.contains('lucille.key'), isTrue);
    });
  });
}

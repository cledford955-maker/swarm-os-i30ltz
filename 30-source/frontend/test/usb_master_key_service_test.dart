import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:swarm_flutter/services/usb_master_key_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('UsbMasterKeyService Tests', () {
    late Directory tempDir;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      tempDir = Directory.systemTemp.createTempSync('swarm_usb_test_');
    });

    tearDown(() {
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    });

    test('writes and detects master key file', () async {
      final ok = await UsbMasterKeyService.writeMasterKeyToDrive(
        tempDir.path,
        customSecret: 'TEST_SECRET_KEY_123',
      );
      expect(ok, isTrue);

      final keyFile = File('${tempDir.path}/swarm_master.key');
      expect(keyFile.existsSync(), isTrue);
      final content = keyFile.readAsStringSync();
      expect(content.contains('SYSTEM=SWARM_OS'), isTrue);
      expect(content.contains('KEY=TEST_SECRET_KEY_123'), isTrue);
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

    test('accepts default magic token and custom secrets', () async {
      final writeDefault = await UsbMasterKeyService.writeMasterKeyToDrive(tempDir.path);
      expect(writeDefault, isTrue);

      final keyFile = File('${tempDir.path}/swarm_master.key');
      expect(keyFile.readAsStringSync().contains('SWARM_MASTER_KEY_V1'), isTrue);
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

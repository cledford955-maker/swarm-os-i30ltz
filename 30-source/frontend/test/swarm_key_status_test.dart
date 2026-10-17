import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:swarm_flutter/services/usb_master_key_service.dart';

void main() {
  late Directory d;
  setUp(() => d = Directory.systemTemp.createTempSync('swk'));
  tearDown(() => d.deleteSync(recursive: true));

  UsbMasterKeyInfo? read(String body) {
    final f = File('${d.path}/status')..writeAsStringSync(body);
    return UsbMasterKeyService.readSwarmKeyStatus(path: f.path);
  }

  test('present key is reported with its serial', () {
    final k = read('{"present": true, "serial": "SWK-ABCDE-12345"}\n');
    expect(k, isNotNull);
    expect(k!.driveLabel, 'SWARM key SWK-ABCDE-12345');
    expect(k.keyContent, isEmpty); // no secret ever reaches the app
  });

  test('absent / false / garbage / odd serials are all "no key"', () {
    expect(read('{"present": false}'), isNull);
    expect(read('not json'), isNull);
    expect(read('[]'), isNull);
    expect(read('{"present": true}'), isNull);
    expect(read('{"present": true, "serial": "bad serial; rm -rf"}'), isNull);
    expect(read('{"present": "yes", "serial": "SWK-1"}'), isNull);
    expect(UsbMasterKeyService.readSwarmKeyStatus(path: '${d.path}/missing'), isNull);
  });
}

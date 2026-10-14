import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:swarm_flutter/services/gamepad_service.dart';
import 'package:swarm_flutter/services/pad_navigator.dart';

/// One kernel js_event: u32 time, i16 value, u8 type, u8 number (little-endian).
List<int> ev(int type, int number, int value) {
  final b = ByteData(8);
  b.setUint32(0, 1234, Endian.little);
  b.setInt16(4, value, Endian.little);
  b.setUint8(6, type);
  b.setUint8(7, number);
  return b.buffer.asUint8List().toList();
}

void main() {
  group('PadNavigator', () {
    test('buttons: A select, B back, Y shuffle, Start useKey; release ignored', () {
      final p = PadNavigator();
      expect(p.feed(1, 0, 1), [PadAction.select]);
      expect(p.feed(1, 0, 0), isEmpty);
      expect(p.feed(1, 1, 1), [PadAction.back]);
      expect(p.feed(1, 3, 1), [PadAction.shuffle]);
      expect(p.feed(1, 7, 1), [PadAction.useKey]);
      expect(p.feed(1, 2, 1), isEmpty); // X is not used on the lock screen
    });

    test('d-pad axes fire once per push and re-arm after release', () {
      final p = PadNavigator();
      expect(p.feed(2, 6, 32767), [PadAction.right]);
      expect(p.feed(2, 6, 32767), isEmpty); // held: no repeat spam
      expect(p.feed(2, 6, 0), isEmpty);
      expect(p.feed(2, 6, -32767), [PadAction.left]);
      expect(p.feed(2, 6, 0), isEmpty);
      expect(p.feed(2, 7, -32767), [PadAction.up]);
      expect(p.feed(2, 7, 0), isEmpty);
      expect(p.feed(2, 7, 32767), [PadAction.down]);
    });

    test('left stick needs a firm push and hysteresis; drift does nothing', () {
      final p = PadNavigator();
      expect(p.feed(2, 0, 9000), isEmpty);   // light drift
      expect(p.feed(2, 0, 20000), isEmpty);  // not past 73 %
      expect(p.feed(2, 0, 28000), [PadAction.right]);
      expect(p.feed(2, 0, 18000), isEmpty);  // still not centred: stays armed-off
      expect(p.feed(2, 0, 28000), isEmpty);
      expect(p.feed(2, 0, 3000), isEmpty);   // centred
      expect(p.feed(2, 0, 28000), [PadAction.right]);
      expect(p.feed(2, 1, 30000), [PadAction.down]);
    });

    test('init replay events and unrelated axes are ignored', () {
      final p = PadNavigator();
      expect(p.feed(0x81, 0, 1), isEmpty);      // button, init flag
      expect(p.feed(0x82, 6, 32767), isEmpty);  // axis, init flag
      expect(p.feed(2, 2, 32767), isEmpty);     // trigger axis
      expect(p.feed(2, 3, 32767), isEmpty);     // right stick
    });

    test('decodes raw js_event bytes, several events per read, negative values', () {
      final p = PadNavigator();
      final bytes = [...ev(1, 0, 1), ...ev(2, 6, -32767), ...ev(2, 7, 32767)];
      expect(p.feedBytes(bytes), [PadAction.select, PadAction.left, PadAction.down]);
      expect(p.feedBytes([1, 2, 3]), isEmpty); // short read: nothing, no crash
    });
  });

  test('GamepadService publishes pad actions from raw joystick bytes', () async {
    final svc = GamepadService();
    final got = <PadAction>[];
    final sub = svc.padActions.listen(got.add);
    svc.feedJoystickBytes([...ev(1, 0, 1), ...ev(2, 7, 32767)]);
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();
    expect(got, [PadAction.select, PadAction.down]);
  });
}

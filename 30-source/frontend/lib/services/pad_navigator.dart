/// Turns raw Linux joystick events (`/dev/input/js0`, 8-byte `js_event`) into menu actions.
///
/// Pure and stateful only for edge detection, so it is easy to test. Used by the lock screen,
/// which has to work with a controller before anything else (and before the desktop shell
/// starts the full [GamepadService] features).
///
/// Mapping (standard Xbox-style pad as the kernel `joydev` driver reports it):
///   D-pad  = axes 6/7        left stick = axes 0/1 (edge-triggered past 60 %)
///   A = select   B = back/clear   Y = shuffle   Start = use the hardware key
enum PadAction { up, down, left, right, select, back, shuffle, useKey }

class PadNavigator {
  static const int jsEventButton = 0x01;
  static const int jsEventAxis = 0x02;
  static const int jsEventInit = 0x80; // initial-state replay on open; never a real press

  static const int _dpadX = 6, _dpadY = 7, _stickX = 0, _stickY = 1;
  static const int _press = 24000;   // ~73 % of 32767: counts as a push
  static const int _release = 12000; // must come back below this before the next push

  final Map<int, int> _dir = {}; // axis -> -1, 0, +1 (last accepted direction)

  /// Feed one decoded event; returns the actions it triggers (usually 0 or 1).
  List<PadAction> feed(int type, int number, int value) {
    if (type & jsEventInit != 0) return const [];
    switch (type) {
      case jsEventButton:
        if (value != 1) return const []; // act on press, not release
        switch (number) {
          case 0: return const [PadAction.select];
          case 1: return const [PadAction.back];
          case 3: return const [PadAction.shuffle];
          case 7: return const [PadAction.useKey];
        }
        return const [];
      case jsEventAxis:
        if (number != _dpadX && number != _dpadY && number != _stickX && number != _stickY) {
          return const [];
        }
        final last = _dir[number] ?? 0;
        int now = last;
        if (value >= _press) {
          now = 1;
        } else if (value <= -_press) {
          now = -1;
        } else if (value.abs() < _release) {
          now = 0;
        }
        _dir[number] = now;
        if (now == last || now == 0) return const [];
        final horizontal = number == _dpadX || number == _stickX;
        if (horizontal) return [now > 0 ? PadAction.right : PadAction.left];
        return [now > 0 ? PadAction.down : PadAction.up];
    }
    return const [];
  }

  /// Decode a chunk of raw bytes (a multiple of 8 bytes per read) and feed every event.
  List<PadAction> feedBytes(List<int> bytes) {
    final out = <PadAction>[];
    for (var i = 0; i + 8 <= bytes.length; i += 8) {
      var value = bytes[i + 4] | (bytes[i + 5] << 8); // int16 little-endian
      if (value >= 0x8000) value -= 0x10000;
      out.addAll(feed(bytes[i + 6], bytes[i + 7], value));
    }
    return out;
  }
}

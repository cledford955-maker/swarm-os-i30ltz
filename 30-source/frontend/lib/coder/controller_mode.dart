import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─── Linux joystick event (js.h) ─────────────────────────────────────────────
// struct js_event { uint32 time; int16 value; uint8 type; uint8 number; }
// type 0x01 = button, 0x02 = axis, 0x80 = init flag
const _jsButton = 0x01;
const _jsAxis   = 0x02;
const _jsInit   = 0x80;

class ControllerEvent {
  final ControllerEventType type;
  final int index;     // button/axis index
  final int value;     // button: 0/1, axis: -32767..32767

  const ControllerEvent({required this.type, required this.index, required this.value});
}

enum ControllerEventType { button, axis }

// ─── Default button→action map ────────────────────────────────────────────────
enum ControllerAction {
  none,
  radialMenu,
  virtualKeyboard,
  save,
  closeTab,
  nextTab,
  prevTab,
  gitPanel,
  terminal,
  search,
  run,
  split,
}

const defaultButtonMap = <int, ControllerAction>{
  0:  ControllerAction.save,           // A / Cross
  1:  ControllerAction.closeTab,       // B / Circle
  2:  ControllerAction.nextTab,        // X / Square
  3:  ControllerAction.prevTab,        // Y / Triangle
  4:  ControllerAction.virtualKeyboard,// LB / L1
  5:  ControllerAction.radialMenu,     // RB / R1
  6:  ControllerAction.terminal,       // LT / L2
  7:  ControllerAction.run,            // RT / R2
  8:  ControllerAction.search,         // Select / Share
  9:  ControllerAction.gitPanel,       // Start / Options
  10: ControllerAction.split,          // L3 (left stick click)
};

// ─── Singleton controller mode ────────────────────────────────────────────────
class ControllerMode extends ChangeNotifier {
  static final ControllerMode instance = ControllerMode._();
  ControllerMode._();

  bool _active = false;
  bool _connected = false;
  String? _devicePath;
  Map<int, ControllerAction> _buttonMap = Map.of(defaultButtonMap);

  bool get active => _active;
  bool get connected => _connected;
  String? get devicePath => _devicePath;
  Map<int, ControllerAction> get buttonMap => Map.unmodifiable(_buttonMap);

  final _eventController = StreamController<ControllerEvent>.broadcast();
  Stream<ControllerEvent> get events => _eventController.stream;

  final _actionController = StreamController<ControllerAction>.broadcast();
  Stream<ControllerAction> get actions => _actionController.stream;

  Process? _jsProcess;
  StreamSubscription? _jsSubscription;
  Timer? _reconnectTimer;

  static const _kButtonMap = 'controller_button_map';

  // ── Lifecycle ────────────────────────────────────────────────────────────

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_kButtonMap);
    if (raw != null) {
      try {
        final m = <int, ControllerAction>{};
        for (final entry in raw.split(';')) {
          if (entry.isEmpty) continue;
          final parts = entry.split(':');
          if (parts.length == 2) {
            final btn = int.tryParse(parts[0]);
            final act = int.tryParse(parts[1]);
            if (btn != null && act != null && act < ControllerAction.values.length) {
              m[btn] = ControllerAction.values[act];
            }
          }
        }
        _buttonMap = m;
      } catch (_) {}
    }
    _startDetection();
  }

  void enable() {
    _active = true;
    notifyListeners();
    _startDetection();
  }

  void disable() {
    _active = false;
    _disconnect();
    notifyListeners();
  }

  @override
  void dispose() {
    _disconnect();
    _reconnectTimer?.cancel();
    _eventController.close();
    _actionController.close();
    super.dispose();
  }

  // ── Button map ───────────────────────────────────────────────────────────

  Future<void> setButtonAction(int button, ControllerAction action) async {
    _buttonMap[button] = action;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    final s = _buttonMap.entries.map((e) => '${e.key}:${e.value.index}').join(';');
    p.setString(_kButtonMap, s);
  }

  Future<void> resetButtonMap() async {
    _buttonMap = Map.of(defaultButtonMap);
    notifyListeners();
    (await SharedPreferences.getInstance()).remove(_kButtonMap);
  }

  // ── Device detection & reading ───────────────────────────────────────────

  void _startDetection() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer.periodic(const Duration(seconds: 3), (_) => _tryConnect());
    _tryConnect();
  }

  Future<void> _tryConnect() async {
    if (_connected) return;
    for (final path in ['/dev/input/js0', '/dev/input/js1', '/dev/input/js2']) {
      if (File(path).existsSync()) {
        await _connect(path);
        return;
      }
    }
  }

  Future<void> _connect(String path) async {
    try {
      _jsProcess = await Process.start('cat', [path]);
      _devicePath = path;
      _connected = true;
      notifyListeners();

      final buf = <int>[];
      _jsSubscription = _jsProcess!.stdout.listen(
        (data) {
          buf.addAll(data);
          while (buf.length >= 8) {
            final chunk = buf.sublist(0, 8);
            buf.removeRange(0, 8);
            _parseEvent(Uint8List.fromList(chunk));
          }
        },
        onDone: _handleDisconnect,
        onError: (_) => _handleDisconnect(),
      );
    } catch (_) {}
  }

  void _parseEvent(Uint8List data) {
    // little-endian: [time:4][value:2][type:1][number:1]
    final bd = ByteData.sublistView(data);
    final value  = bd.getInt16(4, Endian.little);
    final type   = bd.getUint8(6) & ~_jsInit;
    final number = bd.getUint8(7);

    if (type == _jsButton) {
      final evt = ControllerEvent(type: ControllerEventType.button, index: number, value: value);
      _eventController.add(evt);
      if (_active && value == 1) {
        final action = _buttonMap[number] ?? ControllerAction.none;
        if (action != ControllerAction.none) _actionController.add(action);
      }
    } else if (type == _jsAxis) {
      _eventController.add(ControllerEvent(type: ControllerEventType.axis, index: number, value: value));
    }
  }

  void _handleDisconnect() {
    _jsProcess = null;
    _jsSubscription = null;
    if (_connected) {
      _connected = false;
      _devicePath = null;
      notifyListeners();
    }
  }

  void _disconnect() {
    _jsProcess?.kill();
    _jsSubscription?.cancel();
    _handleDisconnect();
  }

  // ── Axis helpers ─────────────────────────────────────────────────────────

  // Simulate d-pad navigation actions from axis events
  void injectAxisNavigation(int axis, int value) {
    if (!_active) return;
    const dead = 12000;
    if (axis == 0) {
      // X axis → left/right
      if (value > dead) _actionController.add(ControllerAction.nextTab);
      if (value < -dead) _actionController.add(ControllerAction.prevTab);
    }
  }
}

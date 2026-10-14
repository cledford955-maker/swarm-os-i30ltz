import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'pad_navigator.dart';

/// Gamepad & Controller Virtual Mouse Service
///
/// Features:
/// 1. When Left Trigger (LT / L2) is held:
///    - Right Thumbstick moves the Virtual Mouse Cursor smoothly.
///    - Right Trigger (RT / R2) performs a Primary Click (Left-click).
///    - Right Bumper (RB / R1) performs a Secondary Click (Right-click).
/// 2. When Left Trigger is released:
///    - D-pad and Left Stick navigate focus between buttons and cards.
///    - Button A triggers focused item.
///    - Button B goes back / closes drawers.
///    - Button X toggles Left App Drawer.
///    - Button Y toggles Right Settings Drawer.
class GamepadService extends ChangeNotifier {
  static final GamepadService _instance = GamepadService._internal();
  factory GamepadService() => _instance;
  GamepadService._internal();

  // Virtual Cursor State
  Offset _cursorPosition = const Offset(640, 360);
  Offset get cursorPosition => _cursorPosition;

  bool _isLeftTriggerHeld = false;
  bool get isLeftTriggerHeld => _isLeftTriggerHeld;

  bool _isVirtualCursorActive = false;
  bool get isVirtualCursorActive => _isVirtualCursorActive;

  // Joystick state
  double _rightStickX = 0.0;
  double _rightStickY = 0.0;

  // Callbacks for drawer toggles
  VoidCallback? onToggleLeftDrawer;
  VoidCallback? onToggleRightDrawer;
  VoidCallback? onCloseDrawers;

  StreamSubscription<List<int>>? _jsSubscription;
  Timer? _cursorLoopTimer;
  Size _screenSize = const Size(1920, 1080);

  bool _initialized = false;

  // Menu actions (D-pad / stick / A / B / Y / Start) for screens that run before the desktop
  // shell, such as the lock screen. Broadcast: any number of screens may listen.
  final PadNavigator _pad = PadNavigator();
  final StreamController<PadAction> _padActions = StreamController<PadAction>.broadcast();
  Stream<PadAction> get padActions => _padActions.stream;

  /// Test hook: feed raw js_event bytes exactly as read from /dev/input/js0.
  @visibleForTesting
  void feedJoystickBytes(List<int> bytes) => _emitPadActions(bytes);

  void _emitPadActions(List<int> bytes) {
    for (final a in _pad.feedBytes(bytes)) {
      _padActions.add(a);
    }
  }

  void updateScreenSize(Size size) {
    _screenSize = size;
  }

  void initialize({
    VoidCallback? toggleLeft,
    VoidCallback? toggleRight,
    VoidCallback? closeDrawers,
  }) {
    // Callbacks may arrive later than the first start (the lock screen starts the service
    // with none; the desktop shell adds its drawer handlers after unlock).
    if (toggleLeft != null) onToggleLeftDrawer = toggleLeft;
    if (toggleRight != null) onToggleRightDrawer = toggleRight;
    if (closeDrawers != null) onCloseDrawers = closeDrawers;
    if (_initialized) return;
    _initialized = true;

    // Listen to hardware keyboard / gamepad keys via Flutter Services
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);

    // Start polling / reading Linux joystick device (/dev/input/js0)
    _startJoystickDeviceReader();

    // Start cursor animation & movement loop (60 FPS)
    _cursorLoopTimer = Timer.periodic(const Duration(milliseconds: 16), (_) {
      _updateCursorPosition();
    });
  }

  void disposeService() {
    _cursorLoopTimer?.cancel();
    _jsSubscription?.cancel();
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    _initialized = false;
  }

  /// Direct Linux Joystick (/dev/input/js0) driver
  Future<void> _startJoystickDeviceReader() async {
    try {
      final jsFile = File('/dev/input/js0');
      if (!await jsFile.exists()) {
        // If js0 doesn't exist yet, retry in 3 seconds
        Timer(const Duration(seconds: 3), _startJoystickDeviceReader);
        return;
      }

      final stream = jsFile.openRead();
      _jsSubscription = stream.listen((chunk) {
        _parseJsEvents(chunk);
      }, onError: (_) {
        _jsSubscription?.cancel();
        Timer(const Duration(seconds: 3), _startJoystickDeviceReader);
      });
    } catch (_) {
      // Fallback to keyboard/gamepad key events
    }
  }

  void _parseJsEvents(List<int> bytes) {
    _emitPadActions(bytes);
    // Linux js_event: 8 bytes
    // uint32 time (4 bytes), int16 value (2 bytes), uint8 type (1 byte), uint8 number (1 byte)
    final byteData = ByteData.sublistView(Uint8List.fromList(bytes));
    for (int i = 0; i + 8 <= byteData.lengthInBytes; i += 8) {
      final value = byteData.getInt16(i + 4, Endian.little);
      final type = byteData.getUint8(i + 6);
      final number = byteData.getUint8(i + 7);

      // type 1 = Button, type 2 = Axis
      if (type == 1) {
        _handleJsButton(number, value == 1);
      } else if (type == 2) {
        _handleJsAxis(number, value / 32767.0);
      }
    }
  }

  void _handleJsButton(int button, bool pressed) {
    switch (button) {
      case 0: // Button A
        if (pressed) {
          if (_isLeftTriggerHeld) {
            triggerPrimaryClick();
          } else {
            // Standard focus activate
            _simulateKey(LogicalKeyboardKey.enter);
          }
        }
        break;
      case 1: // Button B
        if (pressed) {
          if (onCloseDrawers != null) onCloseDrawers!();
        }
        break;
      case 2: // Button X
        if (pressed) {
          if (onToggleLeftDrawer != null) onToggleLeftDrawer!();
        }
        break;
      case 3: // Button Y
        if (pressed) {
          if (onToggleRightDrawer != null) onToggleRightDrawer!();
        }
        break;
      case 4: // Left Bumper (LB)
        if (pressed) {
          if (onToggleLeftDrawer != null) onToggleLeftDrawer!();
        }
        break;
      case 5: // Right Bumper (RB)
        if (pressed && _isLeftTriggerHeld) {
          triggerSecondaryClick(); // Right Click!
        }
        break;
      case 6: // Back
        if (pressed && onCloseDrawers != null) onCloseDrawers!();
        break;
      case 7: // Start
        if (pressed && onToggleRightDrawer != null) onToggleRightDrawer!();
        break;
    }
  }

  void _handleJsAxis(int axis, double normValue) {
    const deadzone = 0.15;
    // Axis mapping:
    // Axis 2 or 5: Left / Right triggers
    // Axis 3, 4: Right thumbstick X, Y
    if (axis == 2 || axis == 5) {
      // Left Trigger detection (LT / L2)
      final wasHeld = _isLeftTriggerHeld;
      _isLeftTriggerHeld = normValue > 0.2;
      _isVirtualCursorActive = _isLeftTriggerHeld;
      if (wasHeld != _isLeftTriggerHeld) {
        notifyListeners();
      }
    }

    if (axis == 3) {
      // Right Stick X
      _rightStickX = normValue.abs() > deadzone ? normValue : 0.0;
    } else if (axis == 4) {
      // Right Stick Y
      _rightStickY = normValue.abs() > deadzone ? normValue : 0.0;
    }

    // Right Trigger (RT / R2) click detection when LT is held
    if (axis == 5 && normValue > 0.6 && _isLeftTriggerHeld) {
      triggerPrimaryClick();
    }
  }

  /// Keyboard & Gamepad Flutter event handler (works with standard mapped gamepads)
  bool _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      // Left Trigger simulated via GameButtonLeftTrigger or Left Alt / Left Shift in testing
      if (event.logicalKey == LogicalKeyboardKey.gameButtonLeft1 ||
          event.logicalKey == LogicalKeyboardKey.gameButtonLeft2 ||
          event.logicalKey == LogicalKeyboardKey.altLeft) {
        _isLeftTriggerHeld = true;
        _isVirtualCursorActive = true;
        notifyListeners();
        return false;
      }

      // Right Trigger click simulation
      if (_isLeftTriggerHeld &&
          (event.logicalKey == LogicalKeyboardKey.gameButtonRight2 ||
              event.logicalKey == LogicalKeyboardKey.space)) {
        triggerPrimaryClick();
        return true;
      }

      // Right Bumper right-click simulation
      if (_isLeftTriggerHeld &&
          (event.logicalKey == LogicalKeyboardKey.gameButtonRight1 ||
              event.logicalKey == LogicalKeyboardKey.contextMenu)) {
        triggerSecondaryClick();
        return true;
      }
    } else if (event is KeyUpEvent) {
      if (event.logicalKey == LogicalKeyboardKey.gameButtonLeft1 ||
          event.logicalKey == LogicalKeyboardKey.gameButtonLeft2 ||
          event.logicalKey == LogicalKeyboardKey.altLeft) {
        _isLeftTriggerHeld = false;
        _isVirtualCursorActive = false;
        notifyListeners();
        return false;
      }
    }
    return false;
  }

  void _updateCursorPosition() {
    if (!_isLeftTriggerHeld) return;
    if (_rightStickX == 0.0 && _rightStickY == 0.0) return;

    // Movement speed multiplier
    const speed = 18.0;
    double newX = _cursorPosition.dx + (_rightStickX * speed);
    double newY = _cursorPosition.dy + (_rightStickY * speed);

    // Constrain within screen bounds
    newX = newX.clamp(0.0, _screenSize.width);
    newY = newY.clamp(0.0, _screenSize.height);

    _cursorPosition = Offset(newX, newY);
    notifyListeners();

    // Dispatch hover event so UI updates hover effects under the virtual cursor
    final hoverEvent = PointerHoverEvent(
      position: _cursorPosition,
      kind: PointerDeviceKind.mouse,
    );
    GestureBinding.instance.handlePointerEvent(hoverEvent);
  }

  /// Simulates Primary Click (Left-click) at current virtual cursor position
  void triggerPrimaryClick() {
    final downEvent = PointerDownEvent(
      position: _cursorPosition,
      kind: PointerDeviceKind.mouse,
      buttons: kPrimaryMouseButton,
    );
    GestureBinding.instance.handlePointerEvent(downEvent);

    Timer(const Duration(milliseconds: 60), () {
      final upEvent = PointerUpEvent(
        position: _cursorPosition,
        kind: PointerDeviceKind.mouse,
      );
      GestureBinding.instance.handlePointerEvent(upEvent);
    });
  }

  /// Simulates Secondary Click (Right-click) at current virtual cursor position
  void triggerSecondaryClick() {
    final downEvent = PointerDownEvent(
      position: _cursorPosition,
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
    GestureBinding.instance.handlePointerEvent(downEvent);

    Timer(const Duration(milliseconds: 60), () {
      final upEvent = PointerUpEvent(
        position: _cursorPosition,
        kind: PointerDeviceKind.mouse,
      );
      GestureBinding.instance.handlePointerEvent(upEvent);
    });
  }

  void _simulateKey(LogicalKeyboardKey key) {
    // Allows D-pad / buttons to trigger standard enter/tab actions
    final now = Duration(milliseconds: DateTime.now().millisecondsSinceEpoch);
    HardwareKeyboard.instance.handleKeyEvent(
      KeyDownEvent(
        physicalKey: const PhysicalKeyboardKey(0),
        logicalKey: key,
        timeStamp: now,
        synthesized: true,
      ),
    );
    HardwareKeyboard.instance.handleKeyEvent(
      KeyUpEvent(
        physicalKey: const PhysicalKeyboardKey(0),
        logicalKey: key,
        timeStamp: now + const Duration(milliseconds: 50),
        synthesized: true,
      ),
    );
  }

  // Manual cursor control for touchscreen / mobile joystick widget
  void setVirtualStick(double x, double y) {
    _rightStickX = x;
    _rightStickY = y;
  }

  void setTriggerHeld(bool held) {
    _isLeftTriggerHeld = held;
    _isVirtualCursorActive = held;
    notifyListeners();
  }
}

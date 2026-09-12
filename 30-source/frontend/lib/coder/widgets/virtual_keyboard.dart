import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import '../../theme/swarm_colors.dart';

// ─── Key definition ───────────────────────────────────────────────────────────
class _VKey {
  final String label;
  final String? shift;     // shifted label (null = same as label.toUpperCase)
  final double width;      // relative units
  final LogicalKeyboardKey? logical;
  final bool isSpecial;

  const _VKey(this.label, {this.shift, this.width = 1.0, this.logical, this.isSpecial = false});
}

const _rows = [
  // Number row
  [
    _VKey('`', shift: '~'), _VKey('1', shift: '!'), _VKey('2', shift: '@'), _VKey('3', shift: '#'),
    _VKey('4', shift: r'$'), _VKey('5', shift: '%'), _VKey('6', shift: '^'), _VKey('7', shift: '&'),
    _VKey('8', shift: '*'), _VKey('9', shift: '('), _VKey('0', shift: ')'), _VKey('-', shift: '_'),
    _VKey('=', shift: '+'), _VKey('⌫', width: 1.8, logical: LogicalKeyboardKey.backspace, isSpecial: true),
  ],
  // QWERTY
  [
    _VKey('Tab', width: 1.5, logical: LogicalKeyboardKey.tab, isSpecial: true),
    _VKey('q'), _VKey('w'), _VKey('e'), _VKey('r'), _VKey('t'),
    _VKey('y'), _VKey('u'), _VKey('i'), _VKey('o'), _VKey('p'),
    _VKey('[', shift: '{'), _VKey(']', shift: '}'), _VKey('\\', shift: '|', width: 1.3),
  ],
  // ASDF
  [
    _VKey('Caps', width: 1.7, logical: LogicalKeyboardKey.capsLock, isSpecial: true),
    _VKey('a'), _VKey('s'), _VKey('d'), _VKey('f'), _VKey('g'),
    _VKey('h'), _VKey('j'), _VKey('k'), _VKey('l'),
    _VKey(';', shift: ':'), _VKey("'", shift: '"'),
    _VKey('↵', width: 2.1, logical: LogicalKeyboardKey.enter, isSpecial: true),
  ],
  // ZXCV
  [
    _VKey('⇧', width: 2.3, logical: LogicalKeyboardKey.shiftLeft, isSpecial: true),
    _VKey('z'), _VKey('x'), _VKey('c'), _VKey('v'), _VKey('b'),
    _VKey('n'), _VKey('m'), _VKey(',', shift: '<'), _VKey('.', shift: '>'),
    _VKey('/', shift: '?'),
    _VKey('⇧', width: 2.7, logical: LogicalKeyboardKey.shiftLeft, isSpecial: true),
  ],
  // Bottom
  [
    _VKey('Ctrl', width: 1.4, logical: LogicalKeyboardKey.controlLeft, isSpecial: true),
    _VKey('Alt', width: 1.2, logical: LogicalKeyboardKey.altLeft, isSpecial: true),
    _VKey('', width: 6.0, logical: LogicalKeyboardKey.space),  // spacebar
    _VKey('Alt', width: 1.2, logical: LogicalKeyboardKey.altLeft, isSpecial: true),
    _VKey('←', width: 1.0, logical: LogicalKeyboardKey.arrowLeft, isSpecial: true),
    _VKey('↑', width: 1.0, logical: LogicalKeyboardKey.arrowUp, isSpecial: true),
    _VKey('↓', width: 1.0, logical: LogicalKeyboardKey.arrowDown, isSpecial: true),
    _VKey('→', width: 1.0, logical: LogicalKeyboardKey.arrowRight, isSpecial: true),
  ],
];

// ─── Virtual keyboard widget ─────────────────────────────────────────────────
class VirtualKeyboard extends StatefulWidget {
  final FocusNode? targetFocus;
  final VoidCallback? onClose;

  const VirtualKeyboard({super.key, this.targetFocus, this.onClose});

  @override
  State<VirtualKeyboard> createState() => _VirtualKeyboardState();
}

class _VirtualKeyboardState extends State<VirtualKeyboard> {
  bool _shift = false;
  bool _caps = false;
  bool _ctrl = false;
  bool _alt = false;

  bool get _upper => _shift ^ _caps;

  void _tap(_VKey key) {
    final logical = key.logical;
    if (logical == LogicalKeyboardKey.shiftLeft) { setState(() => _shift = !_shift); return; }
    if (logical == LogicalKeyboardKey.capsLock)  { setState(() => _caps = !_caps); return; }
    if (logical == LogicalKeyboardKey.controlLeft) { setState(() => _ctrl = !_ctrl); return; }
    if (logical == LogicalKeyboardKey.altLeft)    { setState(() => _alt = !_alt); return; }

    final target = widget.targetFocus ?? FocusManager.instance.primaryFocus;
    if (target == null) return;

    if (logical != null) {
      // Send special keys via simulated KeyDownEvent
      if (logical == LogicalKeyboardKey.backspace) {
        _sendBackspace(target);
      } else if (logical == LogicalKeyboardKey.enter) {
        _sendChar(target, '\n');
      } else if (logical == LogicalKeyboardKey.space) {
        _sendChar(target, ' ');
      } else if (logical == LogicalKeyboardKey.tab) {
        _sendChar(target, '  ');
      } else if (logical == LogicalKeyboardKey.arrowLeft) {
        _sendArrow(target, -1);
      } else if (logical == LogicalKeyboardKey.arrowRight) {
        _sendArrow(target, 1);
      }
      return;
    }

    // Printable character
    String char = key.label;
    if (char.isEmpty) char = ' ';
    if (char.length == 1) {
      if (_upper) char = key.shift ?? char.toUpperCase();
      _sendChar(target, char);
    }

    if (_shift) setState(() => _shift = false);
  }

  void _sendChar(FocusNode target, String char) {
    final es = target.context?.findAncestorStateOfType<EditableTextState>();
    if (es == null) return;
    final v = es.currentTextEditingValue;
    final newText = v.text.replaceRange(
      v.selection.start < 0 ? v.text.length : v.selection.start,
      v.selection.end < 0 ? v.text.length : v.selection.end,
      char,
    );
    final newOffset = (v.selection.start < 0 ? v.text.length : v.selection.start) + char.length;
    es.updateEditingValue(TextEditingValue(text: newText, selection: TextSelection.collapsed(offset: newOffset)));
  }

  void _sendBackspace(FocusNode target) {
    final es = target.context?.findAncestorStateOfType<EditableTextState>();
    if (es == null) return;
    final v = es.currentTextEditingValue;
    if (v.text.isEmpty) return;
    if (v.selection.isCollapsed) {
      final pos = v.selection.baseOffset;
      if (pos <= 0) return;
      final newText = v.text.substring(0, pos - 1) + v.text.substring(pos);
      es.updateEditingValue(TextEditingValue(text: newText, selection: TextSelection.collapsed(offset: pos - 1)));
    } else {
      final newText = v.text.replaceRange(v.selection.start, v.selection.end, '');
      es.updateEditingValue(TextEditingValue(text: newText, selection: TextSelection.collapsed(offset: v.selection.start)));
    }
  }

  void _sendArrow(FocusNode target, int delta) {
    final es = target.context?.findAncestorStateOfType<EditableTextState>();
    if (es == null) return;
    final v = es.currentTextEditingValue;
    final newPos = (v.selection.baseOffset + delta).clamp(0, v.text.length);
    es.updateEditingValue(v.copyWith(selection: TextSelection.collapsed(offset: newPos)));
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: SwarmColors.bgSurface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
          border: const Border(top: BorderSide(color: SwarmColors.border)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 20, offset: const Offset(0, -4))],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Drag handle + close
          Row(children: [
            const SizedBox(width: 8),
            Expanded(
              child: Center(
                child: Container(width: 40, height: 4, margin: const EdgeInsets.symmetric(vertical: 6), decoration: BoxDecoration(color: SwarmColors.border, borderRadius: BorderRadius.circular(2))),
              ),
            ),
            if (widget.onClose != null)
              IconButton(icon: const Icon(Icons.keyboard_hide_rounded, size: 18), color: SwarmColors.textMuted, onPressed: widget.onClose, padding: const EdgeInsets.all(6), constraints: const BoxConstraints()),
            const SizedBox(width: 6),
          ]),
          // Rows
          ..._rows.map((row) => Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 3),
            child: Row(children: row.map((key) => _buildKey(key)).toList()),
          )),
          const SizedBox(height: 6),
        ]),
      ),
    );
  }

  Widget _buildKey(_VKey key) {
    final bool isShiftKey = key.logical == LogicalKeyboardKey.shiftLeft;
    final bool isCtrlKey  = key.logical == LogicalKeyboardKey.controlLeft;
    final bool isAltKey   = key.logical == LogicalKeyboardKey.altLeft;
    final bool isCapsKey  = key.logical == LogicalKeyboardKey.capsLock;

    final bool toggled = (isShiftKey && _shift) || (isCapsKey && _caps) || (isCtrlKey && _ctrl) || (isAltKey && _alt);

    String displayLabel = key.label;
    if (!key.isSpecial && key.label.length == 1) {
      displayLabel = _upper ? (key.shift ?? key.label.toUpperCase()) : key.label;
    } else if (key.label.isEmpty) {
      displayLabel = 'Space';
    }

    final Color bgColor = toggled
        ? SwarmColors.accent.withValues(alpha: 0.25)
        : (key.isSpecial ? SwarmColors.bgElevated : const Color(0xFF16122A));
    final Color borderColor = toggled ? SwarmColors.accent : SwarmColors.border;
    final Color textColor = toggled ? SwarmColors.accent : (key.isSpecial ? SwarmColors.textSecondary : SwarmColors.textPrimary);

    return Expanded(
      flex: (key.width * 100).round(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: GestureDetector(
          onTap: () => _tap(key),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 80),
            height: 38,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: borderColor, width: toggled ? 1.5 : 0.7),
            ),
            child: Center(
              child: Text(
                displayLabel,
                style: TextStyle(fontSize: displayLabel.length > 3 ? 9 : 11, color: textColor, fontFamily: key.isSpecial ? null : 'monospace', fontWeight: key.isSpecial ? FontWeight.w600 : FontWeight.normal),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Floating keyboard overlay ────────────────────────────────────────────────
OverlayEntry? _kbEntry;

void showVirtualKeyboard(BuildContext context, {FocusNode? targetFocus}) {
  if (_kbEntry != null) return;
  late OverlayEntry entry;
  entry = OverlayEntry(builder: (_) => Positioned(
    bottom: 0, left: 0, right: 0,
    child: VirtualKeyboard(
      targetFocus: targetFocus,
      onClose: () { entry.remove(); _kbEntry = null; },
    ),
  ));
  _kbEntry = entry;
  Overlay.of(context).insert(entry);
}

void hideVirtualKeyboard() {
  _kbEntry?.remove();
  _kbEntry = null;
}

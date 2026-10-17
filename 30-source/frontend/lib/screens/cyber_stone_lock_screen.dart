import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../services/lucille_voice_service.dart';
import '../services/swarm_config.dart';
import '../services/usb_master_key_service.dart';
import '../services/gamepad_service.dart';
import '../services/pad_navigator.dart';
import '../theme/swarm_text_styles.dart';

/// Stone glyph representation
class StoneGlyph {
  final int id;
  final String name;
  final String symbol;
  final Color stoneColor;
  final Color glowColor;
  final IconData icon;
  final String runePattern;

  const StoneGlyph({
    required this.id,
    required this.name,
    required this.symbol,
    required this.stoneColor,
    required this.glowColor,
    required this.icon,
    this.runePattern = '∴',
  });
}

const List<StoneGlyph> kAllCyberStoneGlyphs = [
  StoneGlyph(id: 0,  name: 'Obsidian Hex',    symbol: '⬢', stoneColor: Color(0xFF1E2430), glowColor: Color(0xFF00E5FF), icon: Icons.hexagon,              runePattern: '∷'),
  StoneGlyph(id: 1,  name: 'Sapphire Delta',  symbol: '▲', stoneColor: Color(0xFF162544), glowColor: Color(0xFF2979FF), icon: Icons.change_history,        runePattern: '⁂'),
  StoneGlyph(id: 2,  name: 'Amethyst Nova',   symbol: '✦', stoneColor: Color(0xFF2A163B), glowColor: Color(0xFFD500F9), icon: Icons.auto_awesome,          runePattern: '✧'),
  StoneGlyph(id: 3,  name: 'Emerald Helix',   symbol: '☯', stoneColor: Color(0xFF143322), glowColor: Color(0xFF00E676), icon: Icons.all_inclusive,         runePattern: '⊕'),
  StoneGlyph(id: 4,  name: 'Solar Citrine',   symbol: '☼', stoneColor: Color(0xFF382E13), glowColor: Color(0xFFFFD600), icon: Icons.wb_sunny,              runePattern: '✺'),
  StoneGlyph(id: 5,  name: 'Ruby Plasma',     symbol: '⛧', stoneColor: Color(0xFF3A1218), glowColor: Color(0xFFFF1744), icon: Icons.local_fire_department, runePattern: '⋆'),
  StoneGlyph(id: 6,  name: 'Titanium Prism',  symbol: '◈', stoneColor: Color(0xFF212936), glowColor: Color(0xFF00B0FF), icon: Icons.diamond,               runePattern: '⌘'),
  StoneGlyph(id: 7,  name: 'Cyber Wasp',      symbol: '⚝', stoneColor: Color(0xFF32281A), glowColor: Color(0xFFFFAB00), icon: Icons.pest_control,          runePattern: '⋅'),
  StoneGlyph(id: 8,  name: 'Ion Surge',       symbol: '⚡', stoneColor: Color(0xFF172B3C), glowColor: Color(0xFF00E5FF), icon: Icons.flash_on,              runePattern: '∼'),
  StoneGlyph(id: 9,  name: 'Aether Core',     symbol: '◉', stoneColor: Color(0xFF2D163D), glowColor: Color(0xFFAA00FF), icon: Icons.radio_button_checked,  runePattern: '◎'),
  StoneGlyph(id: 10, name: 'Lucille Crown',   symbol: '♛', stoneColor: Color(0xFF3B152B), glowColor: Color(0xFFFF4081), icon: Icons.favorite,              runePattern: '✶'),
  StoneGlyph(id: 11, name: 'Omega Circuit',   symbol: 'Ω', stoneColor: Color(0xFF192A32), glowColor: Color(0xFF00B0FF), icon: Icons.memory,                runePattern: '∞'),
];

class CyberStoneLockScreen extends StatefulWidget {
  /// When true, the screen restarts the main-cipher setup flow. The main
  /// pattern (and the garden pattern) get wiped and the user is walked
  /// through both steps again.
  final bool isReconfiguring;

  /// When true, ONLY the garden cipher is reset. The main pattern is left
  /// untouched — the user has to enter it once to prove ownership, then
  /// picks a new garden pattern (or skips). Wired from Settings → "Change
  /// garden cipher".
  final bool isReconfiguringGarden;
  final VoidCallback? onUnlocked;

  const CyberStoneLockScreen({
    super.key,
    this.isReconfiguring = false,
    this.isReconfiguringGarden = false,
    this.onUnlocked,
  });

  @override
  State<CyberStoneLockScreen> createState() => _CyberStoneLockScreenState();
}

class _CyberStoneLockScreenState extends State<CyberStoneLockScreen>
    with TickerProviderStateMixin {
  static const String _prefKeyPattern = 'cyber_stone_cipher_master_pattern';
  static const String _prefKeyGarden = 'cyber_stone_cipher_garden_pattern';

  // Core animation controllers
  late AnimationController _lightningController;  // perimeter lightning
  late AnimationController _stoneLightController; // per-stone lightning arcs
  late AnimationController _pulseController;      // ambient glow pulse
  late AnimationController _shakeController;      // wrong-pattern shake
  late AnimationController _selectController;     // stone-tap flash

  // Auto-shuffle timer — stones swap positions every ~3-4s (forces glyph recognition)
  Timer? _shuffleTimer;
  bool _isShuffling = false;

  final LucilleVoiceService _voice = LucilleVoiceService();
  final _rng = Random();

  List<int>? _storedPattern;
  List<int>? _gardenPattern;       // hidden second cipher → garden mode
  final List<int> _currentInput = [];
  bool _isLoading = true;
  bool _isSettingUpNewPattern = false;
  bool _isSettingUpGardenPattern = false;  // second cipher setup phase
  bool _isAccessDenied = false;
  bool _totpEnabled = false;        // true once LucyServer confirms TOTP enrolled
  int _focusedIndex = 0;
  int? _lastSelectedIndex;

  // Admin bypass: 3× TL then 3× BR
  int _adminTopLeftCount = 0;
  int _adminBottomRightCount = 0;

  // Hardware USB Master Key
  Timer? _usbScanTimer;
  UsbMasterKeyInfo? _detectedUsbKey;
  bool _isScanningUsb = false;
  StreamSubscription<PadAction>? _padSub;

  late List<StoneGlyph> _displayedStones;
  late final FocusNode _screenFocusNode;

  @override
  void initState() {
    super.initState();
    _displayedStones = List.from(kAllCyberStoneGlyphs);
    _screenFocusNode = FocusNode();

    _lightningController = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1200),
    )..repeat();

    _stoneLightController = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 800),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this, duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _shakeController = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 400),
    );

    _selectController = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 280),
    );

    _loadMasterPattern();
    _checkTotpStatus();
    _startAutoShuffle();
    _startUsbKeyScan();
    // Controller: start reading the pad now (the desktop shell only starts it after unlock).
    GamepadService().initialize();
    _padSub = GamepadService().padActions.listen(_onPad);
  }

  @override
  void dispose() {
    _padSub?.cancel();
    _usbScanTimer?.cancel();
    _shuffleTimer?.cancel();
    _screenFocusNode.dispose();
    _lightningController.dispose();
    _stoneLightController.dispose();
    _pulseController.dispose();
    _shakeController.dispose();
    _selectController.dispose();
    super.dispose();
  }

  // ── Auto-shuffle: swap 2 random stones every 3-4 seconds ─────────────────

  void _startAutoShuffle() {
    _scheduleNextShuffle();
  }

  void _scheduleNextShuffle() {
    final delay = Duration(milliseconds: 2800 + _rng.nextInt(1800));
    _shuffleTimer = Timer(delay, _doAutoShuffle);
  }

  void _doAutoShuffle() {
    if (!mounted) return;
    // Pick 2 non-adjacent stones to swap
    final a = _rng.nextInt(12);
    var b = _rng.nextInt(12);
    while (b == a) {
      b = _rng.nextInt(12);
    }

    setState(() {
      _isShuffling = true;
      final tmp = _displayedStones[a];
      _displayedStones[a] = _displayedStones[b];
      _displayedStones[b] = tmp;
      // Reset keyboard focus if it landed on a swapped slot
      if (_focusedIndex == a) {
        _focusedIndex = b;
      } else if (_focusedIndex == b) { _focusedIndex = a; }
      _lastSelectedIndex = null;
    });

    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _isShuffling = false);
    });

    _scheduleNextShuffle();
  }

  // ── Pattern storage ───────────────────────────────────────────────────────

  Future<void> _loadMasterPattern() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefKeyPattern);
    final rawGarden = prefs.getString(_prefKeyGarden);
    setState(() {
      if (raw != null && raw.isNotEmpty) {
        try { _storedPattern = (jsonDecode(raw) as List).map((e) => e as int).toList(); } catch (_) {}
      }
      if (rawGarden != null && rawGarden.isNotEmpty) {
        try { _gardenPattern = (jsonDecode(rawGarden) as List).map((e) => e as int).toList(); } catch (_) {}
      }
      _isSettingUpNewPattern = widget.isReconfiguring || _storedPattern == null || _storedPattern!.isEmpty;
      _isLoading = false;
    });
    if (_isSettingUpNewPattern) {
      _voice.speak('Welcome to SWARM OS. Select your stone cipher sequence.');
    } else {
      _voice.speak('Stone cipher perimeter active. Enter your glyph sequence.');
    }
  }

  // ── Hardware USB Master Key ───────────────────────────────────────────────

  void _startUsbKeyScan() {
    _scanUsbKey();
    _usbScanTimer = Timer.periodic(const Duration(milliseconds: 1800), (_) {
      _scanUsbKey();
    });
  }

  Future<void> _scanUsbKey() async {
    if (_isScanningUsb || !mounted) return;
    _isScanningUsb = true;
    try {
      final key = await UsbMasterKeyService.scanForMasterKey();
      if (!mounted) return;
      if (key != null && _detectedUsbKey == null) {
        setState(() => _detectedUsbKey = key);
        _voice.speak('Hardware master key detected on flash drive. Override authorized.');
      } else if (key == null && _detectedUsbKey != null) {
        setState(() => _detectedUsbKey = null);
      }
    } catch (_) {
    } finally {
      _isScanningUsb = false;
    }
  }

  void _unlockWithUsbKey() {
    HapticFeedback.heavyImpact();
    _voice.speak('Hardware master key verified. Welcome.');
    _unlockSuccess(isAdminBypass: true);
  }

  Future<void> _resetWithUsbKey() async {
    HapticFeedback.heavyImpact();
    _voice.speak('Master key authorized. Stone cipher reset.');
    await _resetCipherPattern();
  }

  Future<void> _openCreateMasterKeyDialog() async {
    // A new key unlocks this screen, so on the live lock screen making one needs proof first: a
    // key that already works (SWARM hardware key or a registered stick) or the admin password as
    // LucyServer checks it. During cipher setup the user has just got in (or it is first boot).
    if (!_isSettingUpNewPattern) {
      final proven = await UsbMasterKeyService.scanForMasterKey() != null ||
          await _promptAdminPassword(
            title: 'Make USB Master Key',
            message: 'Enter your admin login password to make a new USB key.',
            allowShortcuts: false,
          );
      if (!mounted) return;
      if (!proven) {
        _voice.speak('Master key creation cancelled.');
        return;
      }
    }
    _screenFocusNode.unfocus();
    List<UsbDriveTarget> targets = [];
    bool loading = true;
    String? statusMessage;

    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (dialogCtx, setModalState) {
            void loadDrives() async {
              setModalState(() {
                loading = true;
                statusMessage = null;
              });
              final found = await UsbMasterKeyService.listAvailableUsbDrives();
              if (!dialogCtx.mounted) return;
              setModalState(() {
                targets = found;
                loading = false;
              });
            }

            if (loading && targets.isEmpty && statusMessage == null) {
              loadDrives();
            }

            return AlertDialog(
              backgroundColor: const Color(0xFF070A10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Color(0xFF00E5FF), width: 1.5),
              ),
              title: const Row(
                children: [
                  Icon(Icons.usb, color: Color(0xFF00E5FF)),
                  SizedBox(width: 10),
                  Text('Create USB Master Key', style: TextStyle(color: Color(0xFF00E5FF), fontSize: 18)),
                ],
              ),
              content: SizedBox(
                width: 480,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Insert any cheap USB flash drive (FAT32, exFAT, etc.). SWARM OS will write a master key file (swarm_master.key) with a new random secret; it unlocks this machine or resets the stone cipher whenever plugged in. Making a new key retires any older USB key. Keep the stick private.',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                    const SizedBox(height: 16),
                    if (loading)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child: CircularProgressIndicator(color: Color(0xFF00E5FF)),
                        ),
                      )
                    else if (statusMessage != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF143322),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF00E676)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle, color: Color(0xFF00E676), size: 20),
                            const SizedBox(width: 8),
                            Expanded(child: Text(statusMessage!, style: const TextStyle(color: Colors.white, fontSize: 13))),
                          ],
                        ),
                      )
                    else if (targets.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF161F2E),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: Column(
                          children: [
                            const Icon(Icons.usb_off, color: Colors.white38, size: 36),
                            const SizedBox(height: 8),
                            const Text(
                              'No USB flash drives detected.',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Plug in a flash drive and tap Refresh.',
                              style: TextStyle(color: Colors.white54, fontSize: 12),
                            ),
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              onPressed: loadDrives,
                              icon: const Icon(Icons.refresh, size: 16, color: Color(0xFF00E5FF)),
                              label: const Text('Refresh', style: TextStyle(color: Color(0xFF00E5FF))),
                            ),
                          ],
                        ),
                      )
                    else ...[
                      const Text(
                        'Select target USB drive:',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const SizedBox(height: 8),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 200),
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: targets.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (_, idx) {
                            final drive = targets[idx];
                            return Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFF121B28),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: drive.hasExistingKey ? const Color(0xFF00E676) : Colors.white24),
                              ),
                              child: ListTile(
                                leading: Icon(Icons.usb, color: drive.hasExistingKey ? const Color(0xFF00E676) : const Color(0xFF00E5FF)),
                                title: Text(drive.displayName, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                                subtitle: Text(
                                  '${drive.size}  •  ${drive.mountPath}${drive.hasExistingKey ? "  •  (Key exists)" : ""}',
                                  style: TextStyle(color: drive.hasExistingKey ? const Color(0xFF00E676) : Colors.white54, fontSize: 11),
                                ),
                                trailing: ElevatedButton(
                                  onPressed: () async {
                                    setModalState(() => loading = true);
                                    final ok = await UsbMasterKeyService.writeMasterKeyToDrive(drive.mountPath);
                                    if (!dialogCtx.mounted) return;
                                    setModalState(() {
                                      loading = false;
                                      if (ok) {
                                        statusMessage = 'Master key saved to ${drive.displayName}! You can now use this flash stick as your master key.';
                                        _voice.speak('USB master key created successfully.');
                                      } else {
                                        statusMessage = 'Error writing master key to drive.';
                                      }
                                    });
                                    _scanUsbKey();
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF00E5FF),
                                    foregroundColor: Colors.black,
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  ),
                                  child: Text(drive.hasExistingKey ? 'Rewrite' : 'Write Key', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogCtx).pop(),
                  child: const Text('Close', style: TextStyle(color: Colors.white60)),
                ),
              ],
            );
          },
        );
      },
    );
    if (mounted) _screenFocusNode.requestFocus();
  }

  // ── TOTP 2FA ──────────────────────────────────────────────────────────────

  Future<void> _checkTotpStatus() async {
    try {
      final resp = await http.get(
        Uri.parse('${SwarmConfig.httpBase}/api/settings/totp/status'),
        headers: SwarmConfig.authHeaders,
      );
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        if (mounted) setState(() => _totpEnabled = data['enabled'] == true);
      }
    } catch (_) {
      // LucyServer may not be up yet at early boot — fail open for TOTP only
      // (cipher is still required; TOTP adds a second factor when available).
    }
  }

  /// Shows a 6-digit TOTP input dialog after a successful cipher match.
  /// Returns true only if the code is accepted by LucyServer.
  Future<bool> _showTotpChallenge() async {
    final codeCtrl = TextEditingController();
    String? errorText;
    bool verifying = false;

    final accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) {
          Future<void> submit() async {
            final code = codeCtrl.text.trim();
            if (code.length != 6) return;
            setDlg(() { verifying = true; errorText = null; });
            try {
              final resp = await http.post(
                Uri.parse('${SwarmConfig.httpBase}/api/settings/totp/check'),
                headers: SwarmConfig.authHeaders,
                body: jsonEncode({'code': code}),
              );
              if (!ctx.mounted) return;
              if (resp.statusCode == 200) {
                Navigator.of(ctx).pop(true);
              } else {
                setDlg(() { verifying = false; errorText = 'Invalid code. Try the next one.'; });
                codeCtrl.clear();
              }
            } catch (_) {
              if (!ctx.mounted) return;
              setDlg(() { verifying = false; errorText = 'LucyServer unreachable — cannot verify.'; });
            }
          }

          return AlertDialog(
            backgroundColor: const Color(0xFF070A10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Color(0xFF00E5FF), width: 1),
            ),
            title: const Text('Phone Verification', style: TextStyle(color: Color(0xFF00E5FF), fontSize: 16)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Enter the 6-digit code from your authenticator app.',
                    style: TextStyle(color: Color(0xFF9AA5B4), fontSize: 13)),
                const SizedBox(height: 16),
                TextField(
                  controller: codeCtrl,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  onChanged: (v) { if (v.length == 6) submit(); },
                  onSubmitted: (_) => submit(),
                  style: const TextStyle(color: Colors.white, fontSize: 22, letterSpacing: 6),
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    counterText: '',
                    filled: true,
                    fillColor: const Color(0xFF111827),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFF2D3748)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFF00E5FF)),
                    ),
                    errorText: errorText,
                    errorStyle: const TextStyle(color: Color(0xFFFF4444)),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel', style: TextStyle(color: Color(0xFF6B7280))),
              ),
              ElevatedButton(
                onPressed: verifying ? null : submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00E5FF),
                  foregroundColor: Colors.black,
                ),
                child: verifying
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Verify'),
              ),
            ],
          );
        },
      ),
    );
    return accepted == true;
  }

  // ── Input handling ────────────────────────────────────────────────────────

  void _onStoneTapped(int posIndex, StoneGlyph stone) {
    if (_isAccessDenied) return;

    // Corner-tap gesture (3× top-left, then 3× bottom-right) opens the
    // "forgotten cipher" recovery prompt. It used to call _unlockSuccess()
    // directly here with zero verification — a full, trivially-discoverable
    // auth bypass (anyone tapping the two corners six times was in, no
    // password/fingerprint/anything). Found+fixed 2026-09-11: it now only
    // *offers* recovery via _attemptRecoveryUnlock(), which requires the
    // bcrypt-verified login password from LucyServer and fails closed if
    // that service is unreachable or no password was ever configured.
    if (posIndex == 0) {
      if (_adminBottomRightCount == 0) {
        _adminTopLeftCount++;
      } else { _adminTopLeftCount = 1; _adminBottomRightCount = 0; }
    } else if (posIndex == 11 && _adminTopLeftCount >= 3) {
      _adminBottomRightCount++;
      if (_adminBottomRightCount >= 3) {
        _adminTopLeftCount = 0;
        _adminBottomRightCount = 0;
        _attemptRecoveryUnlock();
        return;
      }
    } else {
      _adminTopLeftCount = 0;
      _adminBottomRightCount = 0;
    }

    setState(() {
      _lastSelectedIndex = posIndex;
      final isSetup = _isSettingUpNewPattern || _isSettingUpGardenPattern;
      final maxLen = isSetup ? 4 : max(_storedPattern?.length ?? 4, _gardenPattern?.length ?? 0);
      if (_currentInput.length < maxLen) {
        _currentInput.add(stone.id);
        HapticFeedback.mediumImpact();
      }
      // In unlock mode: check against both patterns as soon as length matches either
      if (!isSetup) {
        final mainLen = _storedPattern?.length ?? 4;
        final gardenLen = _gardenPattern?.length ?? 0;
        final inputLen = _currentInput.length;
        if ((inputLen == mainLen && mainLen > 0) || (inputLen == gardenLen && gardenLen > 0)) {
          unawaited(_validateAndUnlock());
        }
      }
    });
    _selectController.forward(from: 0.0);
  }

  Future<void> _saveNewCipherPattern() async {
    if (_isSettingUpGardenPattern) {
      await _saveGardenPattern();
      return;
    }
    if (_currentInput.length != 4) {
      _voice.speak('Select 4 stone glyphs.');
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKeyPattern, jsonEncode(_currentInput));
    setState(() {
      _storedPattern = List.from(_currentInput);
      _currentInput.clear();
      _isSettingUpNewPattern = false;
      _lastSelectedIndex = null;
    });
    HapticFeedback.heavyImpact();

    // Offer to set the recovery password right here, while we already have
    // the user's attention — this used to be a silent gap: a device could
    // reach a fully-configured cipher with no recovery password ever set,
    // so the corner-tap "forgotten cipher" prompt (_attemptRecoveryUnlock)
    // had nothing to verify against and just failed closed. Skippable, same
    // pattern as the garden cipher step right after it.
    await _showSetRecoveryPasswordDialog();

    if (!mounted) return;
    setState(() {
      // Offer garden cipher setup
      _isSettingUpGardenPattern = true;
    });
    _voice.speak('Main cipher locked. Now set your secret garden cipher, or press skip.');
  }

  /// Skippable "set a recovery password" step shown once, right after the
  /// main cipher is created. Calls LucyServer's existing
  /// /api/settings/login_password (task #20) — the same store
  /// VerifyLoginPassword checks during recovery.
  Future<void> _showSetRecoveryPasswordDialog() async {
    _voice.speak('Optional: set a recovery password in case you forget your cipher.');
    final controller = TextEditingController();
    String? errorText;
    bool saving = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            Future<void> submit() async {
              final password = controller.text;
              if (password.isEmpty) return;
              setDialogState(() { saving = true; errorText = null; });
              final ok = await _setRecoveryPassword(password);
              if (!dialogContext.mounted) return;
              if (ok) {
                Navigator.of(dialogContext).pop();
              } else {
                setDialogState(() {
                  saving = false;
                  errorText = _lastRecoveryError ?? 'Could not save password.';
                });
              }
            }

            return AlertDialog(
              backgroundColor: const Color(0xFF070A10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: Color(0xFF00E5FF), width: 1),
              ),
              title: const Text('Set Recovery Password', style: TextStyle(color: Color(0xFF00E5FF))),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'If you ever forget your stone cipher, this password unlocks '
                    'recovery (tap the top-left stone 3×, then bottom-right 3×). '
                    'You can skip this, but there will be no way back in without it.',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    obscureText: true,
                    autofocus: true,
                    enabled: !saving,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Recovery password',
                      hintStyle: const TextStyle(color: Colors.white38),
                      errorText: errorText,
                      enabledBorder: const UnderlineInputBorder(
                        borderSide: BorderSide(color: Color(0xFF00E5FF)),
                      ),
                    ),
                    onSubmitted: (_) => submit(),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Skip', style: TextStyle(color: Colors.white54)),
                ),
                TextButton(
                  onPressed: saving ? null : submit,
                  child: saving
                      ? const SizedBox(
                          width: 16, height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00E5FF)),
                        )
                      : const Text('Set Password', style: TextStyle(color: Color(0xFF00E5FF))),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Returns true only on an explicit 200 from LucyServer. No fallback —
  /// if LucyServer isn't reachable yet, the dialog surfaces the error and
  /// the user can retry or skip; it never silently pretends success.
  Future<bool> _setRecoveryPassword(String password) async {
    try {
      final resp = await http
          .post(
            Uri.parse('${SwarmConfig.httpBase}/api/settings/login_password'),
            headers: SwarmConfig.authHeaders,
            body: jsonEncode({'password': password}),
          )
          .timeout(const Duration(seconds: 5));
      if (resp.statusCode == 200) return true;
      try {
        final body = jsonDecode(resp.body) as Map<String, dynamic>;
        _lastRecoveryError = body['error'] as String? ?? 'Could not save password.';
      } catch (_) {
        _lastRecoveryError = 'Could not save password.';
      }
      return false;
    } catch (_) {
      _lastRecoveryError = 'LucyServer unavailable — try again in a moment, or skip.';
      return false;
    }
  }

  Future<void> _saveGardenPattern() async {
    if (_currentInput.length != 4) {
      _voice.speak('Garden cipher needs 4 glyphs.');
      return;
    }
    // Must differ from main pattern
    if (_currentInput.length == _storedPattern?.length) {
      bool same = true;
      for (int i = 0; i < _currentInput.length; i++) {
        if (_currentInput[i] != _storedPattern![i]) { same = false; break; }
      }
      if (same) {
        _voice.speak('Garden cipher cannot match your main cipher. Try again.');
        setState(() { _currentInput.clear(); _lastSelectedIndex = null; });
        return;
      }
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKeyGarden, jsonEncode(_currentInput));
    setState(() {
      _gardenPattern = List.from(_currentInput);
      _isSettingUpGardenPattern = false;
    });
    _voice.speak('Garden cipher armed. Entering the SWARM.');
    HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 500));
    _proceedToDesktop();
  }

  void _skipGardenSetup() {
    setState(() {
      _isSettingUpGardenPattern = false;
      _currentInput.clear();
      _lastSelectedIndex = null;
    });
    _voice.speak('Entering the SWARM.');
    Future.delayed(const Duration(milliseconds: 300), _proceedToDesktop);
  }

  bool _patternMatches(List<int> input, List<int>? stored) {
    if (stored == null || input.length != stored.length) return false;
    for (int i = 0; i < input.length; i++) {
      if (input[i] != stored[i]) return false;
    }
    return true;
  }

  Future<void> _validateAndUnlock() async {
    if (_storedPattern == null) {
      // Defensive only — should be unreachable. The sole caller only invokes
      // this when !isSetup, and every path that nulls _storedPattern (initial
      // load with nothing saved, _resetCipherPattern) sets
      // _isSettingUpNewPattern = true in the same setState. Never treat a
      // missing pattern as an unlock condition; that is the exact shape of
      // the corner-tap bypass this screen was already fixed for once.
      return;
    }

    final bool mainMatch = _patternMatches(_currentInput, _storedPattern);
    final bool gardenMatch = _gardenPattern != null && _patternMatches(_currentInput, _gardenPattern);

    // Garden-cipher-only reset flow: user must prove ownership with the MAIN
    // cipher (garden match doesn't count — otherwise anyone with garden
    // access could rotate the garden without the owner's consent), then we
    // wipe only the garden pattern and enter garden-setup phase in place.
    if (widget.isReconfiguringGarden && mainMatch) {
      if (_totpEnabled) {
        _voice.speak('Cipher accepted. Enter your phone code.');
        final totpOk = await _showTotpChallenge();
        if (!mounted) return;
        if (!totpOk) {
          _onAccessDenied();
          return;
        }
      }
      await _startGardenOnlyReset();
      return;
    }

    if (mainMatch || gardenMatch) {
      // Cipher accepted. If TOTP is enrolled, require a phone code before
      // proceeding — cipher alone is not enough when 2FA is active.
      if (_totpEnabled) {
        _voice.speak('Cipher accepted. Enter your phone code.');
        final totpOk = await _showTotpChallenge();
        if (!mounted) return;
        if (!totpOk) {
          // User cancelled or entered wrong code — deny and reset.
          _onAccessDenied();
          return;
        }
      }
      _unlockSuccess(isAdminBypass: false, gardenMode: gardenMatch);
    } else if (_currentInput.length >= (_storedPattern?.length ?? 4)) {
      // Only deny once input is long enough that no match is possible
      _onAccessDenied();
    }
    // Otherwise still building input — wait
  }

  void _onAccessDenied() {
    setState(() => _isAccessDenied = true);
    HapticFeedback.heavyImpact();
    _shakeController.forward(from: 0.0);
    _voice.speak('Cipher mismatch. Access denied.');
    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted) {
        setState(() {
        _currentInput.clear();
        _lastSelectedIndex = null;
        _isAccessDenied = false;
        _adminTopLeftCount = 0;
        _adminBottomRightCount = 0;
      });
      }
    });
  }

  Future<bool> _isPasswordConfigured() async {
    try {
      final resp = await http
          .post(
            Uri.parse('${SwarmConfig.httpBase}/api/settings/verify_login_password'),
            headers: SwarmConfig.authHeaders,
            body: jsonEncode({'password': '__probe_check__'}),
          )
          .timeout(const Duration(seconds: 3));
      if (resp.statusCode == 401) {
        try {
          final body = jsonDecode(resp.body) as Map<String, dynamic>;
          if (body['error'] == 'No login password configured') {
            return false;
          }
        } catch (_) {}
      }
      return true;
    } catch (_) {
      // LucyServer down or slow (e.g. still starting at boot) is "unknown", not "no password":
      // returning false here gave anyone a free cipher reset. The password prompt that follows
      // then fails closed with "Recovery service unavailable".
      return true;
    }
  }

  /// Forgotten-cipher recovery: prompts for the admin login password and
  /// verifies it against LucyServer's bcrypt hash before unlocking.
  /// If no admin password is configured, offers direct cipher reset.
  Future<void> _attemptRecoveryUnlock() async {
    HapticFeedback.mediumImpact();
    final isConfigured = await _isPasswordConfigured();
    if (!isConfigured) {
      if (!mounted) return;
      _screenFocusNode.unfocus();
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF070A10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFF00E5FF), width: 1),
          ),
          title: const Text('Cipher Recovery', style: TextStyle(color: Color(0xFF00E5FF))),
          content: const Text(
            'No admin recovery password is configured on this system. Would you like to reset the stone cipher now to set a new 4-stone pattern?',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00E5FF),
                foregroundColor: Colors.black,
              ),
              child: const Text('Reset Cipher'),
            ),
          ],
        ),
      );
      if (mounted) _screenFocusNode.requestFocus();
      if (confirm == true) {
        await _resetCipherPattern();
      }
      return;
    }

    _voice.speak('Recovery requested. Enter your admin password.');
    final ok = await _promptAdminPassword(
      title: 'Cipher Recovery',
      message: 'Enter your admin login password to unlock.',
    );
    if (ok) {
      _unlockSuccess(isAdminBypass: true);
    } else {
      _voice.speak('Recovery cancelled.');
    }
  }

  /// "CHANGE CIPHER" is shown right on the live /lock screen.
  /// If no admin password is configured, prompts to reset directly.
  /// Otherwise, requires admin password confirmation.
  Future<void> _confirmAndResetCipher() async {
    HapticFeedback.mediumImpact();
    final isConfigured = await _isPasswordConfigured();
    if (!isConfigured) {
      if (!mounted) return;
      _screenFocusNode.unfocus();
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF070A10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFFD500F9), width: 1),
          ),
          title: const Text('Reset Stone Cipher', style: TextStyle(color: Color(0xFFD500F9))),
          content: const Text(
            'No admin password is configured on this system. Erase the current stone cipher and set a new 4-stone pattern now?',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD500F9),
                foregroundColor: Colors.white,
              ),
              child: const Text('Reset Cipher'),
            ),
          ],
        ),
      );
      if (mounted) _screenFocusNode.requestFocus();
      if (confirm == true) {
        await _resetCipherPattern();
      } else {
        _voice.speak('Cipher change cancelled.');
      }
      return;
    }

    final ok = await _promptAdminPassword(
      title: 'Confirm Cipher Change',
      message: 'Enter your admin login password to erase the current cipher and set a new one.',
    );
    if (ok) {
      await _resetCipherPattern();
    } else {
      _voice.speak('Cipher change cancelled.');
    }
  }

  String? _lastRecoveryError;

  /// Shared admin-password dialog for both recovery unlock and cipher reset.
  /// Returns true on an explicit LucyServer accept, or if user resets when no password is set.
  /// [allowShortcuts] false hides "Bypass with Master Key" and "Reset Cipher Now" (both return
  /// true), so only a password LucyServer accepts gets through.
  Future<bool> _promptAdminPassword({
    required String title,
    required String message,
    bool allowShortcuts = true,
  }) async {
    _screenFocusNode.unfocus();
    final controller = TextEditingController();
    final textFocusNode = FocusNode();
    String? errorText;
    bool verifying = false;
    bool noPasswordConfigured = false;

    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            Future<void> submit() async {
              final password = controller.text;
              setDialogState(() { verifying = true; errorText = null; });
              final accepted = await _verifyRecoveryPassword(password);
              if (!dialogContext.mounted) return;
              if (accepted) {
                Navigator.of(dialogContext).pop(true);
              } else {
                setDialogState(() {
                  verifying = false;
                  if (_lastRecoveryError == 'No login password configured') {
                    noPasswordConfigured = allowShortcuts;
                    errorText = allowShortcuts
                        ? 'No admin password configured on this system. Tap below to reset directly.'
                        : 'No admin password is set on this system. Make the key during cipher setup instead.';
                  } else {
                    errorText = _lastRecoveryError ?? 'Incorrect password.';
                  }
                });
              }
            }

            return AlertDialog(
              backgroundColor: const Color(0xFF070A10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: Color(0xFF00E5FF), width: 1),
              ),
              title: Text(title, style: const TextStyle(color: Color(0xFF00E5FF))),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_detectedUsbKey != null && allowShortcuts) ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D1B2A),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF00E5FF)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.usb, color: Color(0xFF00E5FF), size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'USB Master Key detected (${_detectedUsbKey!.driveLabel}). You can bypass the password directly.',
                              style: const TextStyle(color: Color(0xFF00E5FF), fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  Text(message, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    focusNode: textFocusNode,
                    obscureText: true,
                    autofocus: true,
                    enabled: !verifying,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Admin password',
                      hintStyle: const TextStyle(color: Colors.white38),
                      errorText: errorText,
                      enabledBorder: const UnderlineInputBorder(
                        borderSide: BorderSide(color: Color(0xFF00E5FF)),
                      ),
                    ),
                    onSubmitted: (_) => submit(),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: verifying ? null : () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
                ),
                if (_detectedUsbKey != null && allowShortcuts)
                  ElevatedButton.icon(
                    onPressed: () => Navigator.of(dialogContext).pop(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00E5FF),
                      foregroundColor: Colors.black,
                    ),
                    icon: const Icon(Icons.usb, size: 16, color: Colors.black),
                    label: const Text('Bypass with Master Key', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                if (noPasswordConfigured)
                  ElevatedButton(
                    onPressed: () => Navigator.of(dialogContext).pop(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD500F9),
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Reset Cipher Now'),
                  ),
                TextButton(
                  onPressed: verifying ? null : submit,
                  child: verifying
                      ? const SizedBox(
                          width: 16, height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00E5FF)),
                        )
                      : const Text('Verify', style: TextStyle(color: Color(0xFF00E5FF))),
                ),
              ],
            );
          },
        );
      },
    );
    controller.dispose();
    textFocusNode.dispose();
    if (mounted) _screenFocusNode.requestFocus();
    return ok == true;
  }

  /// Returns true only on an explicit 200 from LucyServer's
  /// verify_login_password endpoint. Any other outcome — 401, timeout,
  /// connection refused (LucyServer not up yet) — is treated as failure;
  /// there is no fallback path that unlocks anyway.
  Future<bool> _verifyRecoveryPassword(String password) async {
    try {
      final resp = await http
          .post(
            Uri.parse('${SwarmConfig.httpBase}/api/settings/verify_login_password'),
            headers: SwarmConfig.authHeaders,
            body: jsonEncode({'password': password}),
          )
          .timeout(const Duration(seconds: 5));
      if (resp.statusCode == 200) return true;
      try {
        final body = jsonDecode(resp.body) as Map<String, dynamic>;
        _lastRecoveryError = body['error'] as String? ?? 'Incorrect password.';
      } catch (_) {
        _lastRecoveryError = 'Incorrect password.';
      }
      return false;
    } catch (_) {
      _lastRecoveryError = 'Recovery service unavailable. Try again in a moment.';
      return false;
    }
  }

  void _unlockSuccess({required bool isAdminBypass, bool gardenMode = false}) {
    HapticFeedback.heavyImpact();
    if (gardenMode) {
      _voice.speak('Welcome to the garden.');
    } else {
      _voice.speak(isAdminBypass ? 'Admin override confirmed. Welcome.' : 'Cipher accepted. Welcome to the SWARM.');
    }
    _proceedToDesktop(gardenMode: gardenMode);
  }

  void _proceedToDesktop({bool gardenMode = false}) {
    if (widget.onUnlocked != null) {
      widget.onUnlocked!();
    } else if (context.mounted) { context.go(gardenMode ? '/garden' : '/'); }
  }

  void _clearInput() {
    setState(() {
      _currentInput.clear();
      _lastSelectedIndex = null;
      _adminTopLeftCount = 0;
      _adminBottomRightCount = 0;
      _isAccessDenied = false;
    });
    HapticFeedback.selectionClick();
  }

  Future<void> _resetCipherPattern() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefKeyPattern);
    await prefs.remove(_prefKeyGarden);
    setState(() {
      _storedPattern = null;
      _gardenPattern = null;
      _currentInput.clear();
      _lastSelectedIndex = null;
      _isSettingUpNewPattern = true;
      _isSettingUpGardenPattern = false;
    });
    _voice.speak('Cipher erased. Select a new stone pattern.');
  }

  /// Called from the garden-only reconfigure flow after the main cipher is
  /// verified. Erases only the garden pattern and switches the UI into the
  /// garden-setup phase; the main pattern is left untouched.
  Future<void> _startGardenOnlyReset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefKeyGarden);
    if (!mounted) return;
    setState(() {
      _gardenPattern = null;
      _currentInput.clear();
      _lastSelectedIndex = null;
      _isSettingUpGardenPattern = true;
      _isSettingUpNewPattern = false;
    });
    _voice.speak('Main cipher confirmed. Select a new secret garden cipher, or press skip.');
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF04060A),
        body: Center(child: CircularProgressIndicator(color: Color(0xFF00E5FF))),
      );
    }

    final isSetup = _isSettingUpNewPattern || _isSettingUpGardenPattern;
    final targetSlots = isSetup ? 4 : max(_storedPattern?.length ?? 4, _gardenPattern?.length ?? 0);
    final accent = _isAccessDenied
        ? const Color(0xFFFF1744)
        : _isSettingUpGardenPattern ? const Color(0xFF4CAF50)
        : _isSettingUpNewPattern    ? const Color(0xFFFFD600)
        : const Color(0xFF00E5FF);

    return Scaffold(
      backgroundColor: const Color(0xFF030508),
      body: KeyboardListener(
        focusNode: _screenFocusNode,
        onKeyEvent: _handleKey,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Cosmic background
            const _CosmicBackground(),

            // ── LEFT STONE COLUMN ─────────────────────────────────────
            Positioned(
              left: 0, top: 0, bottom: 0,
              width: 88,
              child: CustomPaint(
                painter: _StoneColumnPainter(
                  glowColor: const Color(0xFF00E5FF),
                  lightningAnim: _stoneLightController,
                  side: _ColumnSide.left,
                ),
              ),
            ),

            // ── RIGHT STONE COLUMN ────────────────────────────────────
            Positioned(
              right: 0, top: 0, bottom: 0,
              width: 88,
              child: CustomPaint(
                painter: _StoneColumnPainter(
                  glowColor: const Color(0xFFD500F9),
                  lightningAnim: _stoneLightController,
                  side: _ColumnSide.right,
                ),
              ),
            ),

            // ── MAIN PANEL ────────────────────────────────────────────
            Center(
              child: SingleChildScrollView(
                child: AnimatedBuilder(
                  animation: _shakeController,
                  builder: (_, child) => Transform.translate(
                    offset: Offset(_shakeController.isAnimating
                        ? sin(_shakeController.value * pi * 8) * 12
                        : 0.0, 0),
                    child: child,
                  ),
                  child: Container(
                    width: 880,
                    margin: const EdgeInsets.symmetric(vertical: 24),
                    padding: const EdgeInsets.fromLTRB(28, 26, 28, 26),
                    decoration: BoxDecoration(
                      color: const Color(0xFF070A10),
                      borderRadius: BorderRadius.circular(26),
                      border: Border.all(color: accent.withValues(alpha: 0.65), width: 2.0),
                      boxShadow: [
                        BoxShadow(color: accent.withValues(alpha: 0.30), blurRadius: 55, spreadRadius: 5),
                        BoxShadow(color: const Color(0xFFD500F9).withValues(alpha: 0.12), blurRadius: 80),
                      ],
                    ),
                    child: CustomPaint(
                      painter: _ElectricPerimeterPainter(
                        animation: _lightningController,
                        isError: _isAccessDenied,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildHeader(accent),
                          if (_detectedUsbKey != null) ...[
                            const SizedBox(height: 16),
                            _buildUsbMasterKeyBanner(accent),
                          ],
                          const SizedBox(height: 20),
                          _buildInputSlots(targetSlots, accent),
                          const SizedBox(height: 24),
                          _buildStoneGrid(),
                          const SizedBox(height: 22),
                          _buildActions(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Controller input (see PadNavigator): same moves as the arrow keys / Enter / Backspace.
  void _onPad(PadAction a) {
    if (!mounted) return;
    if (ModalRoute.of(context)?.isCurrent == false) return; // a dialog is open on top: leave the pad to it
    switch (a) {
      case PadAction.right:   setState(() => _focusedIndex = (_focusedIndex + 1) % 12); break;
      case PadAction.left:    setState(() => _focusedIndex = (_focusedIndex - 1 + 12) % 12); break;
      case PadAction.down:    setState(() => _focusedIndex = (_focusedIndex + 3) % 12); break;
      case PadAction.up:      setState(() => _focusedIndex = (_focusedIndex - 3 + 12) % 12); break;
      case PadAction.select:  _onStoneTapped(_focusedIndex, _displayedStones[_focusedIndex]); break;
      case PadAction.back:    _clearInput(); break;
      case PadAction.shuffle: _doAutoShuffle(); break;
      case PadAction.useKey:  if (_detectedUsbKey != null) _unlockWithUsbKey(); break;
    }
  }

  void _handleKey(KeyEvent event) {
    if (event is! KeyDownEvent) return;
    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      setState(() => _focusedIndex = (_focusedIndex + 1) % 12);
    } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) { setState(() => _focusedIndex = (_focusedIndex - 1 + 12) % 12); }
    else if (event.logicalKey == LogicalKeyboardKey.arrowDown)  { setState(() => _focusedIndex = (_focusedIndex + 3) % 12); }
    else if (event.logicalKey == LogicalKeyboardKey.arrowUp)    { setState(() => _focusedIndex = (_focusedIndex - 3 + 12) % 12); }
    else if (event.logicalKey == LogicalKeyboardKey.enter || event.logicalKey == LogicalKeyboardKey.gameButtonA) {
      _onStoneTapped(_focusedIndex, _displayedStones[_focusedIndex]);
    } else if (event.logicalKey == LogicalKeyboardKey.backspace || event.logicalKey == LogicalKeyboardKey.delete) {
      _clearInput();
    } else if (event.logicalKey == LogicalKeyboardKey.gameButtonY) {
      _doAutoShuffle();
    }
  }

  // ── Sub-builders ──────────────────────────────────────────────────────────

  Widget _buildHeader(Color accent) {
    return Row(
      children: [
        AnimatedBuilder(
          animation: _pulseController,
          builder: (_, __) => Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.10 + _pulseController.value * 0.06),
              shape: BoxShape.circle,
              border: Border.all(color: accent.withValues(alpha: 0.7), width: 2),
              boxShadow: [BoxShadow(color: accent.withValues(alpha: 0.4 + _pulseController.value * 0.2), blurRadius: 18)],
            ),
            child: Icon(_isSettingUpNewPattern ? Icons.lock_reset : Icons.shield, color: accent, size: 28),
          ),
        ),
        const SizedBox(width: 18),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _isSettingUpGardenPattern
                    ? 'SET GARDEN CIPHER  (OPTIONAL)'
                    : _isSettingUpNewPattern ? 'SETUP STONE CIPHER' : 'SWARM OS — STONE CIPHER LOGIN',
                style: SwarmTextStyles.title.copyWith(
                  color: accent, fontWeight: FontWeight.bold, letterSpacing: 2.4, fontSize: 19,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _isSettingUpGardenPattern
                    ? 'Secret second cipher — unlocks private garden mode. Must differ from main. 4 glyphs.'
                    : _isSettingUpNewPattern
                        ? 'Stones shuffle continuously — learn by glyph, not position. Select 4 in sequence.'
                        : 'Find your glyphs — the stones move. Tap them by symbol, not position.',
                style: SwarmTextStyles.bodySmall.copyWith(color: Colors.white.withValues(alpha: 0.50), fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        _iconBtn(Icons.shuffle, 'Force Shuffle', _doAutoShuffle, const Color(0xFF00E5FF)),
      ],
    );
  }

  Widget _iconBtn(IconData icon, String tip, VoidCallback fn, Color color) {
    return Tooltip(
      message: tip,
      child: InkWell(
        onTap: fn,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
      ),
    );
  }

  Widget _buildUsbMasterKeyBanner(Color accent) {
    final label = _detectedUsbKey?.driveLabel ?? 'USB Flash Drive';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF071927),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF00E5FF), width: 1.5),
        boxShadow: const [
          BoxShadow(color: Color(0x6600E5FF), blurRadius: 18, spreadRadius: 1),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF00E5FF).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF00E5FF), width: 1),
                ),
                child: const Icon(Icons.usb, color: Color(0xFF00E5FF), size: 22),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'HARDWARE MASTER KEY DETECTED',
                    style: TextStyle(
                      color: Color(0xFF00E5FF),
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      letterSpacing: 1.4,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Flash Drive: $label  •  Hardware Override Ready',
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: _unlockWithUsbKey,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00E5FF),
                  foregroundColor: Colors.black,
                  elevation: 6,
                  shadowColor: const Color(0xFF00E5FF),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.lock_open, size: 18, color: Colors.black),
                label: const Text('UNLOCK', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.1)),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: _resetWithUsbKey,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFD500F9), width: 1.5),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.restart_alt, size: 18, color: Color(0xFFD500F9)),
                label: const Text('RESET CIPHER', style: TextStyle(color: Color(0xFFD500F9), fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInputSlots(int targetSlots, Color accent) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF040608),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _isAccessDenied
            ? const Color(0xFFFF1744).withValues(alpha: 0.6) : const Color(0xFF1B2433)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(targetSlots, (i) {
          final filled = i < _currentInput.length;
          final glyph = filled
              ? kAllCyberStoneGlyphs.firstWhere((g) => g.id == _currentInput[i])
              : null;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 54, height: 54,
            margin: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              gradient: filled ? LinearGradient(
                begin: Alignment.topLeft, end: Alignment.bottomRight,
                colors: [glyph!.stoneColor, Color.lerp(glyph.stoneColor, Colors.black, 0.5)!],
              ) : null,
              color: filled ? null : const Color(0xFF0E121A),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: filled ? glyph!.glowColor : accent.withValues(alpha: 0.22), width: filled ? 2 : 1),
              boxShadow: filled ? [BoxShadow(color: glyph!.glowColor.withValues(alpha: 0.5), blurRadius: 14)] : null,
            ),
            child: Center(child: filled
                ? Text(glyph!.symbol, style: TextStyle(color: glyph.glowColor, fontSize: 24))
                : Container(width: 10, height: 10,
                    decoration: BoxDecoration(color: accent.withValues(alpha: 0.25), shape: BoxShape.circle))),
          );
        }),
      ),
    );
  }

  Widget _buildStoneGrid() {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 150),
      opacity: _isShuffling ? 0.65 : 1.0,
      child: AnimatedSwitcher(
      duration: const Duration(milliseconds: 280),
      child: GridView.builder(
        key: ValueKey(_displayedStones.map((s) => s.id).join()),
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,       // 3 columns × 4 rows = 12 BIG stones
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 1.0,   // square stones — solid and heavy
        ),
        itemCount: 12,
        itemBuilder: (_, i) {
          final stone = _displayedStones[i];
          return _StoneTile(
            stone: stone,
            posIndex: i,
            isFocused: _focusedIndex == i,
            isSelected: _lastSelectedIndex == i,
            pulseAnim: _pulseController,
            lightningAnim: _stoneLightController,
            selectAnim: _selectController,
            onTap: () => _onStoneTapped(i, stone),
          );
        },
      ),
    ),
    );
  }

  Widget _buildActions() {
    return Row(
      children: [
        OutlinedButton.icon(
          onPressed: _clearInput,
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Colors.white24),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          icon: const Icon(Icons.refresh, color: Colors.white60, size: 18),
          label: Text('CLEAR', style: SwarmTextStyles.labelSmall.copyWith(color: Colors.white60)),
        ),
        const SizedBox(width: 12),
        if (!_isSettingUpNewPattern && !_isSettingUpGardenPattern) ...[
          TextButton.icon(
            onPressed: _confirmAndResetCipher,
            icon: const Icon(Icons.restart_alt, color: Color(0xFFD500F9), size: 18),
            label: Text('CHANGE CIPHER', style: SwarmTextStyles.labelSmall.copyWith(color: const Color(0xFFD500F9))),
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            onPressed: _openCreateMasterKeyDialog,
            icon: const Icon(Icons.usb, color: Color(0xFF00E5FF), size: 18),
            label: Text('USB MASTER KEY', style: SwarmTextStyles.labelSmall.copyWith(color: const Color(0xFF00E5FF))),
          ),
        ],
        const Spacer(),
        if (_isSettingUpGardenPattern) ...[
          // Skip garden setup
          OutlinedButton(
            onPressed: _skipGardenSetup,
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFF4CAF50), width: 1),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('SKIP GARDEN', style: SwarmTextStyles.labelSmall.copyWith(color: const Color(0xFF4CAF50))),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: _currentInput.length == 4 ? _saveGardenPattern : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2E7D32),
              foregroundColor: Colors.white,
              disabledBackgroundColor: const Color(0xFF1B2433),
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Text('🌿', style: TextStyle(fontSize: 16)),
            label: Text('ARM GARDEN  ${_currentInput.length}/4',
                style: SwarmTextStyles.labelSmall.copyWith(
                  color: _currentInput.length == 4 ? Colors.white : Colors.white30,
                  fontWeight: FontWeight.bold)),
          ),
        ] else if (_isSettingUpNewPattern) ...[
          OutlinedButton.icon(
            onPressed: _openCreateMasterKeyDialog,
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFF00E5FF), width: 1),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.usb, color: Color(0xFF00E5FF), size: 18),
            label: Text('MAKE USB KEY', style: SwarmTextStyles.labelSmall.copyWith(color: const Color(0xFF00E5FF))),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: _currentInput.length == 4 ? _saveNewCipherPattern : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00E5FF),
              foregroundColor: Colors.black,
              disabledBackgroundColor: const Color(0xFF1B2433),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.check_circle, size: 20),
            label: Text('ACTIVATE CIPHER  ${_currentInput.length}/4',
                style: SwarmTextStyles.labelSmall.copyWith(
                  color: _currentInput.length == 4 ? Colors.black : Colors.white30,
                  fontWeight: FontWeight.bold)),
          ),
        ]
        else
          // Used to show a "BYPASS: TL×3 → BR×3" badge here, spelling out the
          // exact corner-tap combo on the permanently-visible lock screen —
          // found 2026-09-11 right after the corner-tap bypass itself was
          // fixed to require password verification: displaying the recovery
          // gesture's exact taps defeats the point of gating it. A user
          // should discover recovery by trying, not read it off the screen.
          const SizedBox.shrink(),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// STONE TILE — big, sculpted, lightning-charged
// ═══════════════════════════════════════════════════════════════════════════

class _StoneTile extends StatelessWidget {
  final StoneGlyph stone;
  final int posIndex;
  final bool isFocused;
  final bool isSelected;
  final Animation<double> pulseAnim;
  final Animation<double> lightningAnim;
  final Animation<double> selectAnim;
  final VoidCallback onTap;

  const _StoneTile({
    required this.stone,
    required this.posIndex,
    required this.isFocused,
    required this.isSelected,
    required this.pulseAnim,
    required this.lightningAnim,
    required this.selectAnim,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedBuilder(
        animation: Listenable.merge([pulseAnim, lightningAnim]),
        builder: (_, __) {
          final glowMul = isFocused ? 0.7 + pulseAnim.value * 0.3 : 0.18 + pulseAnim.value * 0.1;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: isFocused ? const Color(0xFF00E5FF).withValues(alpha: 0.95)
                    : stone.glowColor.withValues(alpha: 0.55),
                width: isFocused ? 3.0 : 2.0,
              ),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.9), offset: const Offset(5, 6), blurRadius: 10),
                BoxShadow(color: stone.glowColor.withValues(alpha: glowMul), blurRadius: isFocused ? 28 : 14, spreadRadius: isFocused ? 3 : 0),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Stone surface + lightning arcs
                  CustomPaint(
                    painter: _StoneLightningPainter(
                      stone: stone,
                      pulse: pulseAnim.value,
                      lightning: lightningAnim.value,
                      isFocused: isFocused,
                    ),
                  ),

                  // Outer concentric ring
                  Positioned.fill(
                    child: Padding(
                      padding: const EdgeInsets.all(9),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: stone.glowColor.withValues(alpha: 0.20), width: 1.0),
                        ),
                      ),
                    ),
                  ),

                  // Inner ring
                  Positioned.fill(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: stone.glowColor.withValues(alpha: 0.28), width: 0.8),
                        ),
                      ),
                    ),
                  ),

                  // Corner marks
                  Positioned(top: 8, left: 10,
                    child: Text(stone.runePattern, style: TextStyle(color: stone.glowColor.withValues(alpha: 0.38), fontSize: 10))),
                  Positioned(top: 8, right: 10,
                    child: Text('${posIndex + 1}', style: TextStyle(color: stone.glowColor.withValues(alpha: 0.52), fontSize: 9, fontWeight: FontWeight.bold))),

                  // Horizontal groove
                  Positioned(bottom: 38, left: 14, right: 14,
                    child: Container(height: 0.8, color: stone.glowColor.withValues(alpha: 0.14))),

                  // Big symbol + name
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 6),
                      Text(
                        stone.symbol,
                        style: TextStyle(
                          fontSize: 52,
                          color: isFocused ? const Color(0xFF00E5FF) : stone.glowColor,
                          shadows: [
                            Shadow(color: stone.glowColor.withValues(alpha: isFocused ? 1.0 : 0.75), blurRadius: isFocused ? 24 : 14),
                            Shadow(color: stone.glowColor.withValues(alpha: 0.35), blurRadius: 36),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Row(children: [
                          Expanded(child: Container(height: 0.6, color: stone.glowColor.withValues(alpha: 0.28))),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              stone.name.toUpperCase(),
                              style: TextStyle(color: stone.glowColor.withValues(alpha: 0.88), fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.6),
                              maxLines: 1, overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Expanded(child: Container(height: 0.6, color: stone.glowColor.withValues(alpha: 0.28))),
                        ]),
                      ),
                    ],
                  ),

                  // Tap flash
                  if (isSelected)
                    AnimatedBuilder(
                      animation: selectAnim,
                      builder: (_, __) => Opacity(
                        opacity: ((1 - selectAnim.value) * 0.5).clamp(0, 1),
                        child: Container(
                          decoration: BoxDecoration(color: stone.glowColor, borderRadius: BorderRadius.circular(20)),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// PAINTERS
// ═══════════════════════════════════════════════════════════════════════════

/// Carved stone texture + animated lightning arcs emanating from center
class _StoneLightningPainter extends CustomPainter {
  final StoneGlyph stone;
  final double pulse;
  final double lightning;
  final bool isFocused;

  _StoneLightningPainter({required this.stone, required this.pulse, required this.lightning, required this.isFocused});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    // ── Base stone gradient ──────────────────────────────────────
    final bgPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft, end: Alignment.bottomRight,
        colors: [
          Color.lerp(stone.stoneColor, Colors.white, 0.05)!,
          stone.stoneColor,
          Color.lerp(stone.stoneColor, Colors.black, 0.58)!,
        ],
        stops: const [0.0, 0.42, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // ── Vignette ─────────────────────────────────────────────────
    final vignette = Paint()
      ..shader = RadialGradient(
        center: Alignment.center, radius: 0.70,
        colors: [Colors.transparent, Colors.black.withValues(alpha: 0.5)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), vignette);

    // ── Diagonal scratch texture ─────────────────────────────────
    final scratchPaint = Paint()
      ..color = stone.glowColor.withValues(alpha: 0.04)
      ..strokeWidth = 0.6
      ..style = PaintingStyle.stroke;
    for (int i = -6; i < 14; i++) {
      final x = i * 20.0;
      canvas.drawLine(Offset(x, 0), Offset(x + size.height * 0.4, size.height), scratchPaint);
    }

    // ── Center glow pulse ─────────────────────────────────────────
    final centerGlow = Paint()
      ..shader = RadialGradient(
        center: Alignment.center, radius: 0.5,
        colors: [stone.glowColor.withValues(alpha: 0.06 + pulse * 0.06), Colors.transparent],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), centerGlow);

    // ── Lightning arcs from center ───────────────────────────────
    // 4-8 arcs per stone, color-matched, animated by lightning value
    final rng = Random((stone.id * 100 + (lightning * 30).toInt()));
    final numArcs = isFocused ? 8 : 4;
    final boltAlpha = isFocused ? 0.65 + pulse * 0.25 : 0.28 + pulse * 0.12;

    final boltPaint = Paint()
      ..color = stone.glowColor.withValues(alpha: boltAlpha)
      ..strokeWidth = isFocused ? 1.2 : 0.7
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < numArcs; i++) {
      final angle = (i / numArcs) * pi * 2 + lightning * pi * 0.5 + stone.id * 0.3;
      final dist = size.width * (0.30 + rng.nextDouble() * 0.22);

      final endX = cx + cos(angle) * dist;
      final endY = cy + sin(angle) * dist;

      // Zigzag bolt path
      final path = Path()..moveTo(cx, cy);
      final steps = 4 + rng.nextInt(3);
      for (int s = 1; s <= steps; s++) {
        final t = s / steps;
        final tx = cx + (endX - cx) * t;
        final ty = cy + (endY - cy) * t;
        final jitter = (1 - t) * 10;
        path.lineTo(tx + (rng.nextDouble() - 0.5) * jitter, ty + (rng.nextDouble() - 0.5) * jitter);
      }

      canvas.drawPath(path, boltPaint);

      // Glow tip at arc end
      canvas.drawCircle(
        Offset(endX, endY),
        isFocused ? 2.5 : 1.4,
        Paint()..color = stone.glowColor.withValues(alpha: boltAlpha * 0.8)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
    }
  }

  @override
  bool shouldRepaint(_StoneLightningPainter old) =>
      old.lightning != lightning || old.pulse != pulse || old.isFocused != isFocused;
}

/// Tall ornate stone column with flutes, capitals, and animated edge lightning
class _StoneColumnPainter extends CustomPainter {
  final Color glowColor;
  final Animation<double> lightningAnim;
  final _ColumnSide side;

  _StoneColumnPainter({required this.glowColor, required this.lightningAnim, required this.side})
      : super(repaint: lightningAnim);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final isLeft = side == _ColumnSide.left;

    // ── Column shaft background ────────────────────────────────────
    final shaftPaint = Paint()
      ..shader = LinearGradient(
        begin: isLeft ? Alignment.centerRight : Alignment.centerLeft,
        end: isLeft ? Alignment.centerLeft : Alignment.centerRight,
        colors: const [
          Color(0xFF141820),
          Color(0xFF0A0D14),
          Color(0xFF060810),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), shaftPaint);

    // ── Fluted vertical channels ──────────────────────────────────
    const fluteCount = 5;
    final fluteW = w / fluteCount;
    final flutePaint = Paint()
      ..color = glowColor.withValues(alpha: 0.07)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;
    final fluteFill = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft, end: Alignment.centerRight,
        colors: [Colors.transparent, glowColor.withValues(alpha: 0.04), Colors.transparent],
      ).createShader(Rect.fromLTWH(0, 0, fluteW, h));

    for (int f = 0; f < fluteCount; f++) {
      final fx = f * fluteW;
      // Flute fill
      canvas.drawRect(Rect.fromLTWH(fx + 2, 80, fluteW - 4, h - 160), fluteFill);
      // Flute edge line
      canvas.drawLine(Offset(fx + 2, 80), Offset(fx + 2, h - 80), flutePaint);
    }

    // ── Capital (top ornamental block) ────────────────────────────
    _drawCapital(canvas, size, isLeft, top: true);
    _drawCapital(canvas, size, isLeft, top: false);

    // ── Glow edge (inner edge of column, facing the panel) ───────
    final edgeX = isLeft ? w : 0.0;
    final edgePaint = Paint()
      ..shader = LinearGradient(
        begin: isLeft ? Alignment.centerRight : Alignment.centerLeft,
        end: isLeft ? Alignment.centerLeft : Alignment.centerRight,
        colors: [glowColor.withValues(alpha: 0.0), glowColor.withValues(alpha: 0.25)],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawRect(Rect.fromLTWH(isLeft ? w - 12 : 0, 0, 12, h), edgePaint);

    // ── Animated lightning on inner edge ──────────────────────────
    final rng = Random((lightningAnim.value * 60).toInt());
    final boltPaint = Paint()
      ..color = glowColor.withValues(alpha: 0.55)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    const numBolts = 5;
    for (int i = 0; i < numBolts; i++) {
      final sy = rng.nextDouble() * h;
      final ey = sy + 30 + rng.nextDouble() * 60;
      final path = Path()..moveTo(edgeX, sy);
      for (double y = sy + 12; y < ey && y < h; y += 10) {
        path.lineTo(
          edgeX + (isLeft ? -1 : 1) * (rng.nextDouble() * 8 + 2),
          y,
        );
      }
      path.lineTo(edgeX, min(ey, h));
      canvas.drawPath(path, boltPaint);
    }

    // ── Rune dots on shaft ────────────────────────────────────────
    final dotPaint = Paint()..color = glowColor.withValues(alpha: 0.18);
    for (int i = 0; i < 6; i++) {
      final dy = 100.0 + i * (h - 200) / 5;
      canvas.drawCircle(Offset(w / 2, dy), 2.5, dotPaint);
    }
  }

  void _drawCapital(Canvas canvas, Size size, bool isLeft, {required bool top}) {
    final w = size.width;
    final h = size.height;
    final y = top ? 0.0 : h - 80.0;

    // Abacus (top slab)
    final paint1 = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [Color(0xFF252C3A), Color(0xFF151820)],
      ).createShader(Rect.fromLTWH(0, top ? y : y + 60, w, 20));
    canvas.drawRect(Rect.fromLTWH(0, top ? y : y + 60, w, 20), paint1);

    // Echinus (rounded middle)
    final paint2 = Paint()..color = const Color(0xFF1A2030);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(3, top ? y + 18 : y + 34, w - 6, 28), const Radius.circular(4)),
      paint2,
    );

    // Necking grooves
    final groovePaint = Paint()..color = glowColor.withValues(alpha: 0.22)..strokeWidth = 1;
    for (int g = 0; g < 3; g++) {
      final gy = top ? y + 48 + g * 5.0 : y + 24 + g * 5.0;
      canvas.drawLine(Offset(6, gy), Offset(w - 6, gy), groovePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _StoneColumnPainter old) =>
      old.lightningAnim.value != lightningAnim.value;
}

enum _ColumnSide { left, right }

// ── Electric perimeter painter ────────────────────────────────────────────

class _ElectricPerimeterPainter extends CustomPainter {
  final Animation<double> animation;
  final bool isError;
  _ElectricPerimeterPainter({required this.animation, required this.isError}) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final rng = Random((animation.value * 90).toInt());
    final primary = isError ? const Color(0xFFFF1744) : const Color(0xFF00E5FF);
    final secondary = isError ? const Color(0xFFFF5252) : const Color(0xFFD500F9);

    final p1 = Paint()..color = primary.withValues(alpha: 0.6)..strokeWidth = 1.6..style = PaintingStyle.stroke;
    final p2 = Paint()..color = secondary.withValues(alpha: 0.6)..strokeWidth = 1.6..style = PaintingStyle.stroke;

    for (int i = 0; i < 8; i++) {
      final sx = rng.nextDouble() * size.width;
      final sy = rng.nextBool() ? 0.0 : size.height;
      final ex = sx + (rng.nextDouble() * 60 - 30);
      final ey = sy == 0 ? 20.0 : size.height - 20;
      final path = Path()
        ..moveTo(sx, sy)
        ..lineTo(sx + (ex - sx) / 2 + (rng.nextDouble() * 12 - 6), (sy + ey) / 2)
        ..lineTo(ex, ey);
      canvas.drawPath(path, rng.nextBool() ? p1 : p2);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => true;
}

// ── Cosmic background ─────────────────────────────────────────────────────

class _CosmicBackground extends StatelessWidget {
  const _CosmicBackground();
  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center, radius: 1.5,
            colors: [Color(0xFF0E1520), Color(0xFF07090F), Color(0xFF020408)],
          ),
        ),
      ),
      CustomPaint(painter: _StarsPainter(), size: Size.infinite),
    ]);
  }
}

class _StarsPainter extends CustomPainter {
  static final _pts = List.generate(160, (i) => Offset((i * 137.5 % 1000) / 1000, (i * 97.3 % 1000) / 1000));
  @override
  void paint(Canvas canvas, Size size) {
    final p1 = Paint()..color = Colors.white.withValues(alpha: 0.16);
    final p2 = Paint()..color = Colors.white.withValues(alpha: 0.08);
    for (int i = 0; i < _pts.length; i++) {
      final r = i % 5 == 0 ? 1.3 : (i % 3 == 0 ? 0.8 : 0.5);
      canvas.drawCircle(Offset(_pts[i].dx * size.width, _pts[i].dy * size.height), r, i % 7 == 0 ? p1 : p2);
    }
  }
  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}

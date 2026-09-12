import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/telemetry_providers.dart';
import '../providers/sentinel_providers.dart';
import '../theme/swarm_colors.dart';
import '../theme/swarm_text_styles.dart';
import '../services/lucille_voice_service.dart';

/// Live terminal window that renders SSE log output and accepts command input.
/// This is the content widget rendered inside an OsWindow for each agent.
class AgentTerminalPanel extends ConsumerStatefulWidget {
  final String agentId;
  final String agentName;
  final Color accentColor;

  const AgentTerminalPanel({
    super.key,
    required this.agentId,
    required this.agentName,
    required this.accentColor,
  });

  @override
  ConsumerState<AgentTerminalPanel> createState() => _AgentTerminalPanelState();
}

class _AgentTerminalPanelState extends ConsumerState<AgentTerminalPanel> {
  final TextEditingController _inputCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  bool _autoScroll = true;

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _sendCommand(String cmd) {
    final trimmed = cmd.trim();
    if (trimmed.isEmpty) return;

    if (trimmed == '420' || trimmed.toLowerCase() == 'weed' || trimmed.toLowerCase() == 'stoner') {
      final voice = LucilleVoiceService();
      if (!voice.is420StonerMode) {
        voice.toggle420Mode();
      }
      ref.read(terminalLogProvider.notifier).addLog(
        '🌿💨 [EASTER EGG UNLOCKED] 420 HERBAL HIVE • DR. BOLTZ STONER MODE ACTIVATED!\n'
        '   • 🍇 Granddaddy Purple (Indica · 28% THC)\n'
        '   • ⛽ Sour Diesel (Sativa · 26% THC)\n'
        '   • 🌲 OG Kush (Hybrid · 27% THC)\n'
        '   • 🍨 Gelato #33 (Hybrid · 29% THC)\n'
        '   • 👄 Lucille Haze (Flagship Sativa · 31% THC)\n'
        '   Crystalline buds & resin trichomes mapped across the honeycomb wasp nest!',
      );
      voice.speak('Aallright mannn... welcome to the 420 Hive, dude! We got that Granddaddy Purple and Sour Diesel flowing through the wasp nest, man... all chill vibes here.');
      _inputCtrl.clear();
      return;
    }

    ref.read(sentinelClientProvider).sendCommand(trimmed);
    _inputCtrl.clear();
  }

  void _scrollToBottom() {
    if (_autoScroll && _scrollCtrl.hasClients) {
      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final logs = ref.watch(terminalLogProvider);

    // Auto-scroll after each rebuild
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

    return Column(
      children: [
        // Terminal Output
        Expanded(
          child: NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification is ScrollUpdateNotification) {
                final atBottom = _scrollCtrl.position.pixels >= _scrollCtrl.position.maxScrollExtent - 40;
                if (_autoScroll != atBottom) {
                  setState(() => _autoScroll = atBottom);
                }
              }
              return false;
            },
            child: ListView.builder(
              controller: _scrollCtrl,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              itemCount: logs.isEmpty ? 1 : logs.length,
              itemBuilder: (context, index) {
                if (logs.isEmpty) {
                  return Text(
                    '> Waiting for ${widget.agentName} subsystem...',
                    style: SwarmTextStyles.terminal.copyWith(color: SwarmColors.textMuted),
                  );
                }
                final line = logs[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: SelectableText(
                    line,
                    style: SwarmTextStyles.terminal.copyWith(
                      color: _lineColor(line),
                    ),
                  ),
                );
              },
            ),
          ),
        ),

        // Scroll-to-bottom button
        if (!_autoScroll)
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(right: 14, bottom: 4),
              child: GestureDetector(
                onTap: () {
                  setState(() => _autoScroll = true);
                  _scrollToBottom();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: SwarmColors.accent.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: SwarmColors.accent.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.arrow_downward, size: 10, color: SwarmColors.accent),
                      const SizedBox(width: 4),
                      Text('Jump to bottom', style: SwarmTextStyles.codeSmall.copyWith(fontSize: 9, color: SwarmColors.accent)),
                    ],
                  ),
                ),
              ),
            ),
          ),

        // Command Input
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: const BoxDecoration(
            color: SwarmColors.bgElevated,
            border: Border(top: BorderSide(color: SwarmColors.border)),
          ),
          child: Row(
            children: [
              Text('❯ ', style: SwarmTextStyles.terminal.copyWith(color: widget.accentColor)),
              Expanded(
                child: TextField(
                  controller: _inputCtrl,
                  contextMenuBuilder: (BuildContext context, EditableTextState editableTextState) {
                    return AdaptiveTextSelectionToolbar.editableText(
                      editableTextState: editableTextState,
                    );
                  },
                  style: SwarmTextStyles.terminal.copyWith(color: SwarmColors.textPrimary),
                  decoration: const InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    hintText: 'Enter command...',
                    hintStyle: TextStyle(color: SwarmColors.textMuted, fontSize: 12),
                  ),
                  onSubmitted: _sendCommand,
                  autofocus: true,
                ),
              ),
              // Paste button
              InkWell(
                onTap: () async {
                  final data = await Clipboard.getData(Clipboard.kTextPlain);
                  if (data?.text != null && data!.text!.isNotEmpty) {
                    final current = _inputCtrl.text;
                    _inputCtrl.text = current + data.text!;
                    _inputCtrl.selection = TextSelection.collapsed(offset: _inputCtrl.text.length);
                  }
                },
                borderRadius: BorderRadius.circular(4),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  margin: const EdgeInsets.only(right: 6),
                  decoration: BoxDecoration(
                    color: SwarmColors.bgSurface,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: SwarmColors.border),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.content_paste_rounded, size: 11, color: SwarmColors.accentCyan),
                      SizedBox(width: 3),
                      Text(
                        'PASTE',
                        style: TextStyle(
                          fontFamily: 'JetBrains Mono',
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: SwarmColors.accentCyan,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Clear button
              GestureDetector(
                onTap: () => ref.read(terminalLogProvider.notifier).clear(),
                child: const Icon(Icons.clear_all, size: 16, color: SwarmColors.textMuted),
              ),
              const SizedBox(width: 8),
              // Send button
              GestureDetector(
                onTap: () => _sendCommand(_inputCtrl.text),
                child: Icon(Icons.send, size: 16, color: widget.accentColor),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Color _lineColor(String line) {
    if (line.contains('[EXIT')) return SwarmColors.textMuted;
    if (line.contains('error') || line.contains('Error') || line.contains('ERROR')) return SwarmColors.statusCritical;
    if (line.contains('warning') || line.contains('Warning')) return SwarmColors.statusIdle;
    if (line.contains('root@') || line.startsWith('❯') || line.startsWith('#')) return widget.accentColor;
    if (line.startsWith('⚡') || line.startsWith('🟢') || line.startsWith('🔴')) return SwarmColors.statusOnline;
    return SwarmColors.textPrimary;
  }
}

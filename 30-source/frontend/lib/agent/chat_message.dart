import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/swarm_colors.dart';
import '../theme/swarm_text_styles.dart';
import '../models/agent.dart';
import '../services/lucille_voice_service.dart';
import 'agent_chat.dart';

/// Renders a single chat message bubble with right-click context menu and 1-tap copy.
class ChatMessageBubble extends StatelessWidget {
  final ChatMsg message;
  final Agent agent;
  final void Function(String cmd)? onRunCommand;

  const ChatMessageBubble({
    super.key,
    required this.message,
    required this.agent,
    this.onRunCommand,
  });

  void _copyToClipboard(BuildContext context, String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: Color(0xFF160F2C),
        duration: Duration(seconds: 2),
        content: Row(
          children: [
            Icon(Icons.check_circle_rounded, color: SwarmColors.success, size: 16),
            SizedBox(width: 8),
            Text('Copied message to clipboard!', style: TextStyle(color: Colors.white, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  void _showContextMenu(BuildContext context, Offset position) {
    final RenderBox overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    showMenu(
      context: context,
      position: RelativeRect.fromRect(
        position & const Size(40, 40),
        Offset.zero & overlay.size,
      ),
      color: const Color(0xFF160F2C),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: SwarmColors.border),
      ),
      items: [
        PopupMenuItem(
          onTap: () => _copyToClipboard(context, message.text),
          child: const Row(
            children: [
              Icon(Icons.content_copy_rounded, size: 14, color: SwarmColors.accent),
              SizedBox(width: 8),
              Text('Copy Message', style: TextStyle(color: Colors.white, fontSize: 12)),
            ],
          ),
        ),
        if (!message.isUser && message.text.isNotEmpty)
          PopupMenuItem(
            onTap: () => LucilleVoiceService().speak(message.text, agentId: agent.id),
            child: Row(
              children: [
                Icon(Icons.volume_up_rounded, size: 14, color: agent.accent),
                const SizedBox(width: 8),
                const Text('Speak Message', style: TextStyle(color: Colors.white, fontSize: 12)),
              ],
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isUser) ...[
            // Agent avatar
            Container(
              width: 28,
              height: 28,
              margin: const EdgeInsets.only(right: 10, top: 2),
              decoration: BoxDecoration(
                color: agent.accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: agent.accent.withValues(alpha: 0.3)),
              ),
              child: Icon(agent.icon, size: 14, color: agent.accent),
            ),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (!isUser)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4, left: 2),
                    child: Row(
                      children: [
                        Text(
                          agent.name,
                          style: SwarmTextStyles.label.copyWith(
                            fontSize: 10,
                            color: agent.accent,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (message.isStreaming) ...[
                          const SizedBox(width: 6),
                          _StreamingDots(color: agent.accent),
                        ],
                      ],
                    ),
                  ),
                // Message bubble wrapped with right-click handler
                GestureDetector(
                  onSecondaryTapDown: (details) => _showContextMenu(context, details.globalPosition),
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 680),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isUser
                          ? agent.accent.withValues(alpha: 0.12)
                          : SwarmColors.bgElevated,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(12),
                        topRight: const Radius.circular(12),
                        bottomLeft: Radius.circular(isUser ? 12 : 2),
                        bottomRight: Radius.circular(isUser ? 2 : 12),
                      ),
                      border: Border.all(
                        color: isUser
                            ? agent.accent.withValues(alpha: 0.25)
                            : SwarmColors.border,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        message.isStreaming && message.text.isEmpty
                            ? _TypingIndicator(color: agent.accent)
                            : _MessageContent(
                                text: message.text,
                                isUser: isUser,
                                onRunCommand: onRunCommand,
                              ),
                        if (!message.isStreaming && message.text.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              InkWell(
                                onTap: () => _copyToClipboard(context, message.text),
                                borderRadius: BorderRadius.circular(4),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isUser ? Colors.black.withValues(alpha: 0.25) : SwarmColors.bgSurface,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: isUser ? agent.accent.withValues(alpha: 0.4) : SwarmColors.border,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.content_copy_rounded,
                                        size: 11,
                                        color: isUser ? Colors.white70 : SwarmColors.textMuted,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'COPY',
                                        style: TextStyle(
                                          color: isUser ? Colors.white70 : SwarmColors.textMuted,
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          fontFamily: 'JetBrains Mono',
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              if (!isUser) ...[
                                const SizedBox(width: 6),
                                InkWell(
                                  onTap: () => LucilleVoiceService().speak(message.text, agentId: agent.id),
                                  borderRadius: BorderRadius.circular(4),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: SwarmColors.bgSurface,
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: SwarmColors.border),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.volume_up_rounded,
                                          size: 11,
                                          color: agent.accent.withValues(alpha: 0.8),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'SPEAK',
                                          style: TextStyle(
                                            color: agent.accent.withValues(alpha: 0.8),
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                            fontFamily: 'JetBrains Mono',
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (isUser) ...[
            // User avatar
            Container(
              width: 28,
              height: 28,
              margin: const EdgeInsets.only(left: 10, top: 2),
              decoration: BoxDecoration(
                color: SwarmColors.agentPurple.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: SwarmColors.agentPurple.withValues(alpha: 0.4)),
              ),
              child: const Icon(Icons.person_rounded, size: 14, color: SwarmColors.agentPurple),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Message Content (markdown-aware) ────────────────────────────────────────

class _MessageContent extends StatelessWidget {
  final String text;
  final bool isUser;
  final void Function(String)? onRunCommand;

  const _MessageContent({
    required this.text,
    required this.isUser,
    this.onRunCommand,
  });

  @override
  Widget build(BuildContext context) {
    final parts = _parseCodeBlocks(text);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: parts.map((part) {
        if (part is _TextPart) {
          return SelectableText(
            part.text,
            contextMenuBuilder: (BuildContext context, EditableTextState editableTextState) {
              return AdaptiveTextSelectionToolbar.editableText(
                editableTextState: editableTextState,
              );
            },
            style: SwarmTextStyles.body.copyWith(
              fontSize: 13,
              height: 1.6,
              color: SwarmColors.textPrimary,
            ),
          );
        } else if (part is _CodePart) {
          return _CodeBlock(code: part.code, lang: part.lang, onRun: onRunCommand);
        } else if (part is _ImagePart) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                part.url,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => 
                  const Text('Failed to load image', style: TextStyle(color: Colors.red)),
              ),
            ),
          );
        }
        return const SizedBox.shrink();
      }).toList(),
    );
  }

  List<dynamic> _parseCodeBlocks(String text) {
    final parts = <dynamic>[];
    
    final regex = RegExp(r'!\[([^\]]*)\]\(([^)]+)\)|```([a-zA-Z0-9_-]*)\n([\s\S]*?)```');
    int lastEnd = 0;

    for (final match in regex.allMatches(text)) {
      if (match.start > lastEnd) {
        parts.add(_TextPart(text.substring(lastEnd, match.start).trim()));
      }
      
      if (match.group(2) != null) {
        parts.add(_ImagePart(url: match.group(2)!));
      } else {
        parts.add(_CodePart(lang: match.group(3) ?? 'bash', code: match.group(4)?.trim() ?? ''));
      }
      lastEnd = match.end;
    }

    if (lastEnd < text.length) {
      final remaining = text.substring(lastEnd).trim();
      if (remaining.isNotEmpty) parts.add(_TextPart(remaining));
    }

    if (parts.isEmpty) parts.add(_TextPart(text));
    return parts;
  }
}

class _TextPart {
  final String text;
  _TextPart(this.text);
}

class _ImagePart {
  final String url;
  _ImagePart({required this.url});
}

class _CodePart {
  final String lang;
  final String code;
  _CodePart({required this.lang, required this.code});
}

// ─── Code Block ──────────────────────────────────────────────────────────────

class _CodeBlock extends StatefulWidget {
  final String code;
  final String lang;
  final void Function(String)? onRun;

  const _CodeBlock({required this.code, required this.lang, this.onRun});

  @override
  State<_CodeBlock> createState() => _CodeBlockState();
}

class _CodeBlockState extends State<_CodeBlock> {
  bool _copied = false;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.code));
    setState(() => _copied = true);
    await Future<void>.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _copied = false);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: SwarmColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: SwarmColors.border)),
            ),
            child: Row(
              children: [
                const Icon(Icons.terminal_rounded, size: 13, color: SwarmColors.accent),
                const SizedBox(width: 6),
                Text(
                  widget.lang.toUpperCase(),
                  style: SwarmTextStyles.label.copyWith(
                    fontSize: 9,
                    color: SwarmColors.accent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                // Copy button
                _IconAction(
                  icon: _copied ? Icons.check_rounded : Icons.content_copy_rounded,
                  label: _copied ? 'Copied!' : 'Copy',
                  color: _copied ? SwarmColors.statusOnline : SwarmColors.textMuted,
                  onTap: _copy,
                ),
                const SizedBox(width: 8),
                // Run in Terminal button
                if (widget.onRun != null)
                  _IconAction(
                    icon: Icons.play_arrow_rounded,
                    label: 'Run in Terminal',
                    color: SwarmColors.accentCyan,
                    onTap: () => widget.onRun!(widget.code),
                  ),
              ],
            ),
          ),
          // Code body
          Padding(
            padding: const EdgeInsets.all(12),
            child: SelectableText(
              widget.code,
              contextMenuBuilder: (BuildContext context, EditableTextState editableTextState) {
                return AdaptiveTextSelectionToolbar.editableText(
                  editableTextState: editableTextState,
                );
              },
              style: SwarmTextStyles.codeSmall.copyWith(
                fontSize: 12,
                color: const Color(0xFFE2E8F0),
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IconAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _IconAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: SwarmTextStyles.codeSmall.copyWith(
                fontSize: 9.5,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

class _StreamingDots extends StatefulWidget {
  final Color color;
  const _StreamingDots({required this.color});

  @override
  State<_StreamingDots> createState() => _StreamingDotsState();
}

class _StreamingDotsState extends State<_StreamingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (i) {
          final offset = (i * 0.33);
          final val = ((_ctrl.value + offset) % 1.0);
          final opacity = (val < 0.5 ? val * 2 : (1.0 - val) * 2).clamp(0.2, 1.0);
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1.5),
            child: Container(
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.color.withValues(alpha: opacity),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _TypingIndicator extends StatelessWidget {
  final Color color;
  const _TypingIndicator({required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(
              strokeWidth: 1.8,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'Lucille is reasoning...',
            style: SwarmTextStyles.codeSmall.copyWith(
              fontSize: 11,
              color: color.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }
}

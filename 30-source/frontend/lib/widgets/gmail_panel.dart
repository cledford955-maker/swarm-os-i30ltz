// Swarm OS — Gmail Agent Panel
// Home screen widget: inbox view, compose, reply, search, labels

import 'package:flutter/material.dart';
import '../services/google_hub_service.dart';

class GmailPanel extends StatefulWidget {
  final GoogleHubService? service;
  const GmailPanel({super.key, this.service});

  @override
  State<GmailPanel> createState() => _GmailPanelState();
}

class _GmailPanelState extends State<GmailPanel> {
  late final GoogleHubService _hub;
  final TextEditingController _searchCtrl = TextEditingController();

  List<Map<String, dynamic>> _messages = [];
  Map<String, dynamic>? _selectedMessage;
  bool _loading = true;
  bool _composing = false; // ignore: unused_field — set in compose flow
  bool _authenticated = false;
  int _unreadCount = 0;
  String _currentView = 'inbox'; // inbox, message, compose, search

  // Compose fields
  final _toCtrl = TextEditingController();
  final _subjectCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  String? _replyToId;
  String? _replyThreadId; // ignore: unused_field — set in reply flow

  @override
  void initState() {
    super.initState();
    _hub = widget.service ?? GoogleHubService();
    _checkAuth();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _toCtrl.dispose();
    _subjectCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkAuth() async {
    final auth = await _hub.isAuthenticated;
    if (mounted) {
      setState(() => _authenticated = auth);
      if (auth) {
        _loadInbox();
        _loadUnread();
      } else {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _doLogin() async {
    setState(() => _loading = true);
    try {
      await _hub.login();
      await _checkAuth();
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Login failed: $e'), backgroundColor: const Color(0xFF5C1A1A)),
        );
      }
    }
  }

  Future<void> _loadInbox({String? query, bool unreadOnly = false}) async {
    setState(() => _loading = true);
    try {
      final msgs = await _hub.getInbox(query: query, unreadOnly: unreadOnly);
      if (mounted) {
        setState(() {
          _messages = msgs;
          _loading = false;
          _currentView = 'inbox';
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadUnread() async {
    final count = await _hub.getUnreadCount();
    if (mounted) setState(() => _unreadCount = count);
  }

  Future<void> _openMessage(Map<String, dynamic> msgRef) async {
    setState(() => _loading = true);
    try {
      final msg = await _hub.getMessage(msgRef['id']);
      if (msg != null && mounted) {
        setState(() {
          _selectedMessage = msg;
          _currentView = 'message';
          _loading = false;
        });
        // Mark as read
        if (msg['unread'] == true) {
          await _hub.markRead(msg['id']);
          _loadUnread();
        }
      } else {
        setState(() => _loading = false);
      }
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  void _startCompose({String? replyTo, String? threadId, String? to, String? subject}) {
    _toCtrl.text = to ?? '';
    _subjectCtrl.text = subject ?? '';
    _bodyCtrl.clear();
    _replyToId = replyTo;
    _replyThreadId = threadId;
    setState(() {
      _composing = true;
      _currentView = 'compose';
    });
  }

  Future<void> _send() async {
    if (_toCtrl.text.trim().isEmpty || _bodyCtrl.text.trim().isEmpty) return;

    setState(() => _loading = true);

    Map<String, dynamic>? result;
    if (_replyToId != null) {
      result = await _hub.replyEmail(
        _replyToId!,
        body: _bodyCtrl.text.trim(),
      );
    } else {
      result = await _hub.sendEmail(
        to: _toCtrl.text.trim(),
        subject: _subjectCtrl.text.trim(),
        body: _bodyCtrl.text.trim(),
      );
    }

    if (result != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Email sent'), backgroundColor: Color(0xFF1A5C2B)),
      );
      _toCtrl.clear();
      _subjectCtrl.clear();
      _bodyCtrl.clear();
      _replyToId = null;
      setState(() => _composing = false);
      _loadInbox();
    } else {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('❌ Send failed'), backgroundColor: Color(0xFF5C1A1A)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2A2A4A), width: 1),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 20, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(),
          if (!_authenticated) _buildLoginPrompt(),
          if (_authenticated && _currentView == 'inbox') ...[
            _buildSearchBar(),
            Expanded(child: _buildInboxList()),
          ],
          if (_authenticated && _currentView == 'message')
            Expanded(child: _buildMessageView()),
          if (_authenticated && _currentView == 'compose')
            Expanded(child: _buildComposeView()),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFF2A2A4A), width: 1)),
      ),
      child: Row(
        children: [
          Icon(
            _authenticated ? Icons.mail : Icons.mail_outline,
            color: _authenticated ? const Color(0xFFEA4335) : Colors.white24,
            size: 22,
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text('Gmail', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
          ),
          if (_unreadCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFEA4335).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$_unreadCount',
                style: const TextStyle(color: Color(0xFFEA4335), fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          const SizedBox(width: 8),
          if (_authenticated && _currentView != 'inbox')
            GestureDetector(
              onTap: () => setState(() {
                _currentView = 'inbox';
                _selectedMessage = null;
                _composing = false;
              }),
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(Icons.inbox, color: Colors.white54, size: 20),
              ),
            ),
          if (_authenticated)
            GestureDetector(
              onTap: () => _startCompose(),
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(Icons.edit, color: Colors.white54, size: 20),
              ),
            ),
          if (_authenticated)
            GestureDetector(
              onTap: () => _loadInbox(),
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(Icons.refresh, color: Colors.white38, size: 20),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLoginPrompt() {
    return Expanded(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.mail_outline, color: Colors.white.withValues(alpha: 0.1), size: 56),
            const SizedBox(height: 16),
            Text('Connect Gmail', style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 16)),
            const SizedBox(height: 8),
            Text(
              'Sign in with Google to access your email',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.15), fontSize: 12),
            ),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: _doLogin,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF4285F4),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_loading)
                      const SizedBox(
                        width: 16, height: 16,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    else
                      const Icon(Icons.login, color: Colors.white, size: 16),
                    const SizedBox(width: 8),
                    const Text('Sign in with Google',
                        style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: TextField(
        controller: _searchCtrl,
        style: const TextStyle(color: Colors.white, fontSize: 13),
        decoration: InputDecoration(
          hintText: 'Search mail...',
          hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
          prefixIcon: Icon(Icons.search, color: Colors.white.withValues(alpha: 0.3), size: 18),
          filled: true,
          fillColor: const Color(0xFF1A1A2E),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
        ),
        onSubmitted: (query) {
          if (query.isNotEmpty) {
            _loadInbox(query: query);
          } else {
            _loadInbox();
          }
        },
      ),
    );
  }

  Widget _buildInboxList() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFEA4335), strokeWidth: 2));
    }

    if (_messages.isEmpty) {
      return Center(
        child: Text('No messages', style: TextStyle(color: Colors.white.withValues(alpha: 0.2))),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      itemCount: _messages.length,
      itemBuilder: (ctx, i) {
        final msg = _messages[i];
        final unread = msg['unread'] == true;
        final starred = msg['starred'] == true;

        return GestureDetector(
          onTap: () => _openMessage(msg),
          child: Container(
            margin: const EdgeInsets.only(bottom: 4),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: unread ? const Color(0xFF1A1A3E) : const Color(0xFF141425),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: unread ? const Color(0xFF4285F4).withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.05),
              ),
            ),
            child: Row(
              children: [
                if (starred)
                  const Padding(
                    padding: EdgeInsets.only(right: 6),
                    child: Icon(Icons.star, color: Color(0xFFFBBC04), size: 14),
                  ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _extractName(msg['from'] ?? ''),
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: unread ? FontWeight.w700 : FontWeight.w400,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (msg['has_attachments'] == true)
                            Padding(
                              padding: const EdgeInsets.only(left: 4),
                              child: Icon(Icons.attach_file, color: Colors.white.withValues(alpha: 0.3), size: 12),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        msg['subject'] ?? '(no subject)',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: unread ? 0.9 : 0.6),
                          fontSize: 12,
                          fontWeight: unread ? FontWeight.w600 : FontWeight.w400,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        msg['snippet'] ?? '',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (unread)
                  Container(
                    width: 8, height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFF4285F4),
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMessageView() {
    if (_loading || _selectedMessage == null) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFEA4335), strokeWidth: 2));
    }

    final msg = _selectedMessage!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Subject
          Text(
            msg['subject'] ?? '(no subject)',
            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          // From
          Row(
            children: [
              CircleAvatar(
                backgroundColor: const Color(0xFF4285F4),
                radius: 16,
                child: Text(
                  (msg['from'] ?? '?')[0].toUpperCase(),
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(msg['from'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 12)),
                    Text('To: ${msg['to'] ?? ''}',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 10)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(msg['date'] ?? '', style: TextStyle(color: Colors.white.withValues(alpha: 0.25), fontSize: 10)),
          const SizedBox(height: 16),
          const Divider(color: Color(0xFF2A2A4A)),
          const SizedBox(height: 8),
          // Body
          SelectableText(
            msg['body'] ?? msg['snippet'] ?? '',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13, height: 1.5),
          ),
          // Attachments
          if ((msg['attachments'] as List? ?? []).isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('Attachments', style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 11)),
            const SizedBox(height: 4),
            ...((msg['attachments'] as List).map((a) => Container(
                  margin: const EdgeInsets.only(bottom: 4),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A2E),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.attach_file, color: Colors.white.withValues(alpha: 0.3), size: 14),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          a['filename'] ?? 'attachment',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ))),
          ],
          const SizedBox(height: 20),
          // Action buttons
          Row(
            children: [
              _actionButton('Reply', Icons.reply, () {
                _startCompose(
                  replyTo: msg['id'],
                  threadId: msg['thread_id'],
                  to: msg['from'],
                  subject: 'Re: ${msg['subject']}',
                );
              }),
              const SizedBox(width: 8),
              _actionButton('Forward', Icons.forward, () {
                _startCompose(subject: 'Fwd: ${msg['subject']}');
              }),
              const SizedBox(width: 8),
              _actionButton('Archive', Icons.archive_outlined, () async {
                await _hub.archiveMessage(msg['id']);
                _loadInbox();
              }),
              const SizedBox(width: 8),
              _actionButton('Trash', Icons.delete_outline, () async {
                await _hub.trashMessage(msg['id']);
                _loadInbox();
              }, color: Colors.redAccent.withValues(alpha: 0.7)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildComposeView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _toCtrl,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: _inputDec('To'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _subjectCtrl,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: _inputDec('Subject'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _bodyCtrl,
            style: const TextStyle(color: Colors.white70, fontSize: 13),
            maxLines: 10,
            minLines: 5,
            decoration: _inputDec('Compose email...'),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (_replyToId != null)
                Text('Replying to thread',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.25), fontSize: 10)),
              const Spacer(),
              GestureDetector(
                onTap: () => setState(() {
                  _composing = false;
                  _currentView = 'inbox';
                }),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text('Cancel', style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 12)),
                ),
              ),
              GestureDetector(
                onTap: _loading ? null : _send,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4285F4),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 16, height: 16,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.send, color: Colors.white, size: 14),
                            SizedBox(width: 6),
                            Text('Send', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDec(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.2)),
      filled: true,
      fillColor: const Color(0xFF1A1A2E),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
    );
  }

  Widget _actionButton(String label, IconData icon, VoidCallback onTap, {Color? color}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color ?? Colors.white54, size: 14),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(color: color ?? Colors.white54, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  String _extractName(String from) {
    if (from.contains('<')) {
      return from.substring(0, from.indexOf('<')).trim();
    }
    return from;
  }
}
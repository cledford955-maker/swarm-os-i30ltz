import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../theme/swarm_colors.dart';
import '../../theme/swarm_text_styles.dart';

class PublisherPortalPanel extends StatefulWidget {
  const PublisherPortalPanel({super.key});

  @override
  State<PublisherPortalPanel> createState() => _PublisherPortalPanelState();
}

class _PublisherPortalPanelState extends State<PublisherPortalPanel> {
  int _step = 0;

  // Step 0 — Basic Info
  final _nameCtrl        = TextEditingController();
  final _publisherCtrl   = TextEditingController(text: 'swarm.io');
  final _descCtrl        = TextEditingController();
  final _versionCtrl     = TextEditingController(text: '1.0.0');
  final _tagsCtrl        = TextEditingController();
  String _category       = 'Tools';
  final _formKey         = GlobalKey<FormState>();

  // Step 1 — Package
  String? _packagePath;
  String? _packageName;
  int _packageBytes = 0;

  // Step 2 — Signing
  String? _keystorePath;
  String? _packageSha256;
  String? _signature;
  String? _signError;
  bool _signing = false;

  // Step 3 — Preview / Submitted
  bool _submitted = false;

  static const _categories = ['Languages', 'Linters', 'Themes', 'Snippets', 'Android', 'AI', 'Git', 'Tools'];
  static const _steps = ['Basic Info', 'Package', 'Signing', 'Preview'];

  @override
  void dispose() {
    _nameCtrl.dispose(); _publisherCtrl.dispose(); _descCtrl.dispose();
    _versionCtrl.dispose(); _tagsCtrl.dispose();
    super.dispose();
  }

  // ── Step actions ─────────────────────────────────────────────────────────

  bool _validateInfo() => _formKey.currentState?.validate() ?? false;

  Future<void> _pickPackage() async {
    final r = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: ['vsix', 'zip', 'tar', 'gz']);
    if (r == null) return;
    final path = r.path;
    if (path == null) return;
    final f = File(path);
    final size = await f.length();
    setState(() {
      _packagePath  = path;
      _packageName  = r.name;
      _packageBytes = size;
      _packageSha256 = null;
      _signature     = null;
      _signError     = null;
    });
  }

  Future<void> _pickKeystore() async {
    final r = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: ['jks', 'keystore', 'p12', 'pfx']);
    if (r == null) return;
    if (r.path != null) setState(() => _keystorePath = r.path);
  }

  Future<void> _signPackage() async {
    if (_packagePath == null) return;
    setState(() => _signing = true);
    final bytes = await File(_packagePath!).readAsBytes();
    final digest = sha256.convert(bytes);
    final hex = digest.toString();

    // The digest is always real. The MAC is keyed by the keystore's actual
    // bytes — previously this hashed only the keystore *path*, so the selected
    // key material never affected the result. Without a keystore there is no
    // key, so no signature is produced rather than falling back to a
    // well-known default.
    String? sig;
    String? err;
    if (_keystorePath == null) {
      err = 'Select a keystore to sign — no key, no signature.';
    } else {
      try {
        final keyBytes = await File(_keystorePath!).readAsBytes();
        final mac = Hmac(sha256, keyBytes).convert(digest.bytes);
        sig = 'HMAC-SHA256-${mac.toString().substring(0, 32).toUpperCase()}';
      } catch (e) {
        err = 'Could not read keystore: $e';
      }
    }

    setState(() {
      _packageSha256 = hex;
      _signature = sig;
      _signError = err;
      _signing = false;
    });
  }

  void _submit() => setState(() => _submitted = true);

  void _reset() {
    setState(() {
      _step = 0; _submitted = false;
      _packagePath = null; _packageName = null; _packageBytes = 0;
      _keystorePath = null; _packageSha256 = null; _signature = null; _signError = null;
      _nameCtrl.clear(); _descCtrl.clear(); _versionCtrl.text = '1.0.0';
      _tagsCtrl.clear(); _category = 'Tools';
    });
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_submitted) return _SuccessScreen(name: _nameCtrl.text, version: _versionCtrl.text, onReset: _reset);

    return Column(children: [
      // Header
      Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: SwarmColors.border))),
        child: Row(children: [
          const Icon(Icons.publish_rounded, size: 16, color: SwarmColors.accent),
          const SizedBox(width: 8),
          Text('Developer Publishing Portal', style: SwarmTextStyles.h2.copyWith(fontSize: 13)),
        ]),
      ),
      // Step indicator
      _StepBar(current: _step, labels: _steps),
      const Divider(height: 1, color: SwarmColors.border),
      // Step content
      Expanded(child: SingleChildScrollView(
        padding: const EdgeInsets.all(14),
        child: switch (_step) {
          0 => _buildInfoStep(),
          1 => _buildPackageStep(),
          2 => _buildSigningStep(),
          3 => _buildPreviewStep(),
          _ => const SizedBox(),
        },
      )),
      // Navigation
      _NavBar(
        step: _step,
        total: _steps.length,
        canNext: _canNext(),
        onBack: () => setState(() => _step--),
        onNext: _onNext,
      ),
    ]);
  }

  bool _canNext() => switch (_step) {
    0 => true,
    1 => _packagePath != null,
    2 => _signature != null,
    3 => true,
    _ => false,
  };

  void _onNext() {
    if (_step == 0 && !_validateInfo()) return;
    if (_step == _steps.length - 1) { _submit(); return; }
    setState(() => _step++);
  }

  // ── Step 0: Basic Info ────────────────────────────────────────────────────
  Widget _buildInfoStep() => Form(
    key: _formKey,
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const _SLabel('EXTENSION DETAILS'),
      _Field(label: 'Name', ctrl: _nameCtrl, hint: 'My Awesome Extension', validator: (v) => (v ?? '').isEmpty ? 'Required' : null),
      const SizedBox(height: 10),
      _Field(label: 'Publisher', ctrl: _publisherCtrl, hint: 'swarm.io', validator: (v) => (v ?? '').isEmpty ? 'Required' : null),
      const SizedBox(height: 10),
      _Field(label: 'Version', ctrl: _versionCtrl, hint: '1.0.0', validator: (v) {
        if ((v ?? '').isEmpty) return 'Required';
        if (!RegExp(r'^\d+\.\d+\.\d+').hasMatch(v!)) return 'Must be semver (e.g. 1.0.0)';
        return null;
      }),
      const SizedBox(height: 10),
      _Field(label: 'Description', ctrl: _descCtrl, hint: 'Short description visible in marketplace', maxLines: 3, validator: (v) => (v ?? '').isEmpty ? 'Required' : null),
      const SizedBox(height: 10),
      const _SLabel('CATEGORY'),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: SwarmColors.bgElevated,
          border: Border.all(color: SwarmColors.border),
          borderRadius: BorderRadius.circular(4),
        ),
        child: DropdownButton<String>(
          value: _category,
          isExpanded: true,
          underline: const SizedBox.shrink(),
          dropdownColor: SwarmColors.bgElevated,
          style: const TextStyle(fontSize: 12, color: SwarmColors.textPrimary),
          items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
          onChanged: (v) { if (v != null) setState(() => _category = v); },
        ),
      ),
      const SizedBox(height: 10),
      const _SLabel('TAGS (comma-separated)'),
      _Field(label: 'Tags', ctrl: _tagsCtrl, hint: 'dart, flutter, productivity'),
    ]),
  );

  // ── Step 1: Package ───────────────────────────────────────────────────────
  Widget _buildPackageStep() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const _SLabel('EXTENSION PACKAGE'),
    const Text('Upload a .vsix or .zip archive containing your extension manifest and code.', style: TextStyle(fontSize: 11, color: SwarmColors.textMuted, height: 1.5)),
    const SizedBox(height: 14),
    InkWell(
      onTap: _pickPackage,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: SwarmColors.bgElevated,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _packagePath != null ? SwarmColors.accent : SwarmColors.border, style: BorderStyle.solid),
        ),
        child: _packagePath == null
            ? Column(children: [
                const Icon(Icons.upload_file_rounded, size: 36, color: SwarmColors.textDisabled),
                const SizedBox(height: 8),
                const Text('Click to select .vsix / .zip', style: TextStyle(fontSize: 12, color: SwarmColors.textMuted)),
                const SizedBox(height: 4),
                const Text('Max 50 MB', style: TextStyle(fontSize: 10, color: SwarmColors.textDisabled)),
              ])
            : Row(children: [
                const Icon(Icons.inventory_2_rounded, size: 28, color: SwarmColors.agentEmerald),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(_packageName!, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: SwarmColors.textPrimary)),
                  Text(_formatSize(_packageBytes), style: const TextStyle(fontSize: 10, color: SwarmColors.textMuted)),
                ])),
                const Icon(Icons.check_circle_rounded, size: 18, color: SwarmColors.agentEmerald),
              ]),
      ),
    ),
    if (_packagePath != null) ...[
      const SizedBox(height: 14),
      const _SLabel('PACKAGE REQUIREMENTS'),
      ..._checkRequirements().map((r) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          Icon(r.$2 ? Icons.check_circle_rounded : Icons.warning_rounded, size: 13, color: r.$2 ? SwarmColors.agentEmerald : SwarmColors.agentAmber),
          const SizedBox(width: 6),
          Text(r.$1, style: TextStyle(fontSize: 11, color: r.$2 ? SwarmColors.textSecondary : SwarmColors.agentAmber)),
        ]),
      )),
    ],
  ]);

  List<(String, bool)> _checkRequirements() => [
    ('Package size under 50 MB', _packageBytes < 52428800),
    ('Valid file extension (.vsix/.zip)', _packageName?.endsWith('.vsix') == true || _packageName?.endsWith('.zip') == true),
    ('File name matches pattern', RegExp(r'^[a-zA-Z0-9._-]+$').hasMatch(_packageName ?? '')),
  ];

  // ── Step 2: Signing ───────────────────────────────────────────────────────
  Widget _buildSigningStep() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const _SLabel('PACKAGE SIGNING'),
    const Text('Sign your extension package to ensure authenticity. Users see a verified badge in the marketplace.', style: TextStyle(fontSize: 11, color: SwarmColors.textMuted, height: 1.5)),
    const SizedBox(height: 14),
    // SHA256 hash
    Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: SwarmColors.bgElevated, borderRadius: BorderRadius.circular(6), border: Border.all(color: SwarmColors.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('SHA-256 Fingerprint', style: TextStyle(fontSize: 10, color: SwarmColors.textMuted, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(
          _packageSha256 ?? 'Compute after signing below',
          style: const TextStyle(fontFamily: 'monospace', fontSize: 10, color: SwarmColors.agentCyan),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ]),
    ),
    const SizedBox(height: 12),
    // Keystore picker
    const _SLabel('SIGNING KEYSTORE (optional)'),
    InkWell(
      onTap: _pickKeystore,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(color: SwarmColors.bgElevated, borderRadius: BorderRadius.circular(6), border: Border.all(color: SwarmColors.border)),
        child: Row(children: [
          const Icon(Icons.vpn_key_rounded, size: 16, color: SwarmColors.textMuted),
          const SizedBox(width: 8),
          Expanded(child: Text(_keystorePath?.split('/').last ?? 'Select keystore (default: Swarm built-in)', style: const TextStyle(fontSize: 11, color: SwarmColors.textSecondary))),
          const Icon(Icons.folder_open_rounded, size: 14, color: SwarmColors.textMuted),
        ]),
      ),
    ),
    const SizedBox(height: 14),
    // Sign button
    SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _signing ? null : _signPackage,
        icon: _signing ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black)) : const Icon(Icons.draw_rounded, size: 14),
        label: Text(_signing ? 'Signing...' : 'Sign Package', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        style: ElevatedButton.styleFrom(backgroundColor: SwarmColors.accent, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(vertical: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6))),
      ),
    ),
    if (_signature != null) ...[
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: SwarmColors.agentEmerald.withValues(alpha: 0.07), borderRadius: BorderRadius.circular(6), border: Border.all(color: SwarmColors.agentEmerald.withValues(alpha: 0.3))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.verified_rounded, size: 14, color: SwarmColors.agentEmerald),
            const SizedBox(width: 6),
            const Text('Package signed successfully', style: TextStyle(fontSize: 11, color: SwarmColors.agentEmerald, fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 6),
          Text('Signature: $_signature', style: const TextStyle(fontFamily: 'monospace', fontSize: 10, color: SwarmColors.textMuted)),
        ]),
      ),
    ],
    if (_signError != null) ...[
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: SwarmColors.error.withValues(alpha: 0.07), borderRadius: BorderRadius.circular(6), border: Border.all(color: SwarmColors.error.withValues(alpha: 0.3))),
        child: Row(children: [
          const Icon(Icons.error_outline_rounded, size: 14, color: SwarmColors.error),
          const SizedBox(width: 6),
          Expanded(child: Text(_signError!, style: const TextStyle(fontSize: 11, color: SwarmColors.error))),
        ]),
      ),
    ],
  ]);

  // ── Step 3: Preview ───────────────────────────────────────────────────────
  Widget _buildPreviewStep() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const _SLabel('MARKETPLACE PREVIEW'),
    const Text('This is how your extension will appear to users.', style: TextStyle(fontSize: 11, color: SwarmColors.textMuted)),
    const SizedBox(height: 14),
    // Preview card
    Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: SwarmColors.bgElevated, borderRadius: BorderRadius.circular(8), border: Border.all(color: SwarmColors.accent.withValues(alpha: 0.25))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(color: SwarmColors.accent.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8), border: Border.all(color: SwarmColors.accent.withValues(alpha: 0.4))),
            child: const Icon(Icons.extension_rounded, size: 20, color: SwarmColors.accent),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_nameCtrl.text.isEmpty ? 'Extension Name' : _nameCtrl.text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: SwarmColors.textPrimary)),
            Text('${_publisherCtrl.text} · v${_versionCtrl.text}', style: const TextStyle(fontSize: 10, color: SwarmColors.textMuted)),
          ])),
          if (_signature != null)
            const Tooltip(message: 'Verified Publisher', child: Icon(Icons.verified_rounded, size: 16, color: SwarmColors.agentEmerald)),
        ]),
        const SizedBox(height: 8),
        Text(_descCtrl.text.isEmpty ? 'No description provided.' : _descCtrl.text, style: const TextStyle(fontSize: 11, color: SwarmColors.textSecondary, height: 1.4)),
        const SizedBox(height: 10),
        Wrap(spacing: 4, runSpacing: 4, children: [
          _TagChip(_category, SwarmColors.accent),
          ..._tagsCtrl.text.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).map((t) => _TagChip(t, SwarmColors.textMuted)),
        ]),
      ]),
    ),
    const SizedBox(height: 16),
    // Submission summary
    const _SLabel('SUBMISSION SUMMARY'),
    _SummaryRow('Package', _packageName ?? '—'),
    _SummaryRow('Size', _formatSize(_packageBytes)),
    _SummaryRow('SHA-256', _packageSha256?.substring(0, 16) != null ? '${_packageSha256!.substring(0, 16)}…' : '—'),
    _SummaryRow('Signature', _signature ?? '—'),
    _SummaryRow('Category', _category),
    const SizedBox(height: 16),
    const Text('By publishing, you agree to the Swarm OS Extension Marketplace Terms of Service and confirm that your extension does not contain malicious code.', style: TextStyle(fontSize: 10, color: SwarmColors.textDisabled, height: 1.5)),
  ]);

  static String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1048576) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / 1048576).toStringAsFixed(1)} MB';
  }

}

// ─── Success screen ───────────────────────────────────────────────────────────
class _SuccessScreen extends StatelessWidget {
  final String name, version;
  final VoidCallback onReset;
  const _SuccessScreen({required this.name, required this.version, required this.onReset});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.check_circle_rounded, size: 64, color: SwarmColors.agentEmerald),
            const SizedBox(height: 16),
            Text('$name v$version', style: SwarmTextStyles.h2, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            const Text('Your extension has been submitted for review.\nTypically takes 1–2 business days.', style: TextStyle(fontSize: 12, color: SwarmColors.textMuted, height: 1.5), textAlign: TextAlign.center),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: onReset,
              icon: const Icon(Icons.add_rounded, size: 14),
              label: const Text('Publish another'),
              style: OutlinedButton.styleFrom(foregroundColor: SwarmColors.accent, side: const BorderSide(color: SwarmColors.accent), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6))),
            ),
          ]),
        ),
      );
}

// ─── Step indicator bar ───────────────────────────────────────────────────────
class _StepBar extends StatelessWidget {
  final int current;
  final List<String> labels;
  const _StepBar({required this.current, required this.labels});

  @override
  Widget build(BuildContext context) => Container(
        color: SwarmColors.bgSurface,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(children: List.generate(labels.length * 2 - 1, (i) {
          if (i.isOdd) return Expanded(child: Container(height: 1, color: i ~/ 2 < current ? SwarmColors.accent : SwarmColors.border));
          final idx = i ~/ 2;
          final done = idx < current;
          final active = idx == current;
          return Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 22, height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: done ? SwarmColors.accent : (active ? SwarmColors.accent.withValues(alpha: 0.2) : SwarmColors.bgElevated),
                border: Border.all(color: active || done ? SwarmColors.accent : SwarmColors.border, width: active ? 2 : 1),
              ),
              child: Center(child: done
                  ? const Icon(Icons.check_rounded, size: 12, color: Colors.black)
                  : Text('${idx + 1}', style: TextStyle(fontSize: 10, color: active ? SwarmColors.accent : SwarmColors.textDisabled, fontWeight: FontWeight.bold))),
            ),
            const SizedBox(height: 3),
            Text(labels[idx], style: TextStyle(fontSize: 9, color: active ? SwarmColors.accent : (done ? SwarmColors.textMuted : SwarmColors.textDisabled))),
          ]);
        })),
      );
}

// ─── Nav bar ─────────────────────────────────────────────────────────────────
class _NavBar extends StatelessWidget {
  final int step, total;
  final bool canNext;
  final VoidCallback onBack, onNext;
  const _NavBar({required this.step, required this.total, required this.canNext, required this.onBack, required this.onNext});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: const BoxDecoration(border: Border(top: BorderSide(color: SwarmColors.border))),
        child: Row(children: [
          if (step > 0)
            OutlinedButton.icon(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back_rounded, size: 14),
              label: const Text('Back', style: TextStyle(fontSize: 12)),
              style: OutlinedButton.styleFrom(foregroundColor: SwarmColors.textMuted, side: const BorderSide(color: SwarmColors.border), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8)),
            ),
          const Spacer(),
          ElevatedButton.icon(
            onPressed: canNext ? onNext : null,
            icon: Icon(step == total - 1 ? Icons.publish_rounded : Icons.arrow_forward_rounded, size: 14),
            label: Text(step == total - 1 ? 'Publish' : 'Next', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(backgroundColor: step == total - 1 ? SwarmColors.agentEmerald : SwarmColors.accent, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6))),
          ),
        ]),
      );
}

// ─── Small helpers ────────────────────────────────────────────────────────────
class _SLabel extends StatelessWidget {
  final String text;
  const _SLabel(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: SwarmColors.textMuted, letterSpacing: 1.2)),
      );
}

class _Field extends StatelessWidget {
  final String label, hint;
  final TextEditingController ctrl;
  final int maxLines;
  final String? Function(String?)? validator;
  const _Field({required this.label, required this.ctrl, required this.hint, this.maxLines = 1, this.validator});

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    _SLabel(label.toUpperCase()),
    TextFormField(
      controller: ctrl,
      maxLines: maxLines,
      validator: validator,
      style: const TextStyle(fontSize: 12, color: SwarmColors.textPrimary, fontFamily: 'monospace'),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: SwarmColors.textDisabled, fontSize: 11),
        isDense: true,
        filled: true,
        fillColor: SwarmColors.bgElevated,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: SwarmColors.border)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      ),
    ),
  ]);
}

class _SummaryRow extends StatelessWidget {
  final String k, v;
  const _SummaryRow(this.k, this.v);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          SizedBox(width: 80, child: Text(k, style: const TextStyle(fontSize: 11, color: SwarmColors.textMuted))),
          Expanded(child: Text(v, style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: SwarmColors.textSecondary), overflow: TextOverflow.ellipsis)),
        ]),
      );
}

class _TagChip extends StatelessWidget {
  final String label;
  final Color color;
  const _TagChip(this.label, this.color);
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(3), border: Border.all(color: color.withValues(alpha: 0.3))),
        child: Text(label, style: TextStyle(fontSize: 9, color: color, fontWeight: FontWeight.bold)),
      );
}

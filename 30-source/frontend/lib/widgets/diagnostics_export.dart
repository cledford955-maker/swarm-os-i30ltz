import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

/// Runs the same collector on the development host and installed/live SWARM.
class DiagnosticsExport extends StatefulWidget {
  const DiagnosticsExport({super.key});

  @override
  State<DiagnosticsExport> createState() => _DiagnosticsExportState();
}

class _DiagnosticsExportState extends State<DiagnosticsExport> {
  bool _busy = false;
  bool _includeJournal = false;
  String? _result;
  bool _failed = false;

  Future<void> _export() async {
    setState(() {
      _busy = true;
      _result = null;
      _failed = false;
    });
    try {
      final folder = await FilePicker.getDirectoryPath(
        dialogTitle: 'Save SWARM diagnostic bundle',
      );
      if (folder == null || !mounted) return;
      const candidates = [
        '/usr/local/bin/swarm-diagnostics',
        '/mnt/Lucy/70-scripts/collect_swarm_diagnostics.py',
      ];
      final script = candidates.where((p) => File(p).existsSync()).firstOrNull;
      if (script == null) {
        throw StateError('SWARM diagnostic collector is not installed.');
      }
      final process = await Process.run('python3', [
        script,
        '--output-dir',
        folder,
        if (_includeJournal) '--include-journal',
      ]);
      if (process.exitCode != 0) {
        throw StateError('Collection failed: ${process.stderr}');
      }
      final path = process.stdout.toString().trim();
      if (path.isEmpty || !await File(path).exists()) {
        throw StateError('Collector did not produce an archive.');
      }
      if (mounted) setState(() => _result = 'Saved diagnostic bundle:\n$path');
    } catch (error) {
      if (mounted) {
        setState(() {
          _failed = true;
          _result = error.toString();
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Export diagnostics',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text(
                'Collect system details, SWARM service state and local health checks from this machine. Nothing is uploaded.'),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Include recent SWARM service logs'),
              subtitle: const Text(
                  'Credentials are redacted where recognized. Review logs before sharing.'),
              value: _includeJournal,
              onChanged: _busy
                  ? null
                  : (value) => setState(() => _includeJournal = value ?? false),
              controlAffinity: ListTileControlAffinity.leading,
            ),
            FilledButton.icon(
              onPressed: _busy ? null : _export,
              icon: _busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.archive_outlined),
              label: Text(
                  _busy ? 'Collecting diagnostics…' : 'Save diagnostic bundle'),
            ),
            if (_result != null) ...[
              const SizedBox(height: 12),
              SelectableText(_result!,
                  style: TextStyle(
                      color: _failed
                          ? Theme.of(context).colorScheme.error
                          : null)),
            ],
          ]),
        ),
      );
}

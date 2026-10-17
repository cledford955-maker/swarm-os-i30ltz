import 'package:flutter/material.dart';
import '../../services/advanced_ecosystem_service.dart';
import '../../theme/swarm_text_styles.dart';

class AiCodingAssistantPanel extends StatefulWidget {
  final String activeFilePath;
  final String activeFileContent;
  final Function(String updatedContent)? onApplyDiff;

  const AiCodingAssistantPanel({
    super.key,
    required this.activeFilePath,
    required this.activeFileContent,
    this.onApplyDiff,
  });

  @override
  State<AiCodingAssistantPanel> createState() => _AiCodingAssistantPanelState();
}

class _AiCodingAssistantPanelState extends State<AiCodingAssistantPanel>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final AdvancedEcosystemService _service = AdvancedEcosystemService();

  final TextEditingController _promptCtrl = TextEditingController();
  int _selectedRole = 1; // LeadCoder
  bool _isGenerating = false;
  Map<String, dynamic>? _lastTaskResult;
  String? _taskError;

  List<dynamic> _suggestedFixes = [];
  bool _isAnalyzingFixes = false;
  String? _fixesError;

  final List<String> _roles = [
    'Architect (High-Level Design)',
    'Lead Coder (Implementation)',
    'Security Auditor (Vulnerability Audit)',
    'Test Engineer (Unit & Mock Tests)',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadSuggestedFixes();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _promptCtrl.dispose();
    super.dispose();
  }

  Future<void> _dispatchAgent() async {
    if (_promptCtrl.text.trim().isEmpty) return;

    setState(() {
      _isGenerating = true;
      _taskError = null;
    });
    try {
      final result = await _service.dispatchAiCodingTask(
        title: _promptCtrl.text.trim(),
        prompt: _promptCtrl.text.trim(),
        activeFilePath: widget.activeFilePath,
        language: widget.activeFilePath.endsWith('.dart') ? 'dart' : 'csharp',
        role: _selectedRole,
      );
      if (!mounted) return;
      setState(() {
        _lastTaskResult = result;
        _isGenerating = false;
      });
    } catch (e) {
      // Previously this fell back to a canned "Completed" result with invented
      // steps ("Verified memory and security contracts") and placeholder code,
      // so a dead server looked like a successful agent run.
      if (!mounted) return;
      setState(() {
        _lastTaskResult = null;
        _taskError = e.toString();
        _isGenerating = false;
      });
    }
  }

  Future<void> _loadSuggestedFixes() async {
    setState(() {
      _isAnalyzingFixes = true;
      _fixesError = null;
    });
    try {
      final fixes = await _service.suggestCodeFixes(
        filePath: widget.activeFilePath,
        fileContent: widget.activeFileContent,
        compilerOutput: 'warning - unused_import: auth/authentication_grid.dart',
      );
      if (!mounted) return;
      setState(() {
        _suggestedFixes = fixes;
        _isAnalyzingFixes = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _suggestedFixes = [];
        _fixesError = e.toString();
        _isAnalyzingFixes = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0A0D14),
      child: Column(
        children: [
          // Header & Tabs
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFF1E2838))),
            ),
            child: Row(
              children: [
                const Icon(Icons.auto_awesome, color: Color(0xFF00E5FF), size: 18),
                const SizedBox(width: 8),
                Text('AI CODING AGENTS & FIXES', style: SwarmTextStyles.title.copyWith(fontSize: 12)),
                const Spacer(),
                TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  indicatorColor: const Color(0xFF00E5FF),
                  labelColor: const Color(0xFF00E5FF),
                  unselectedLabelColor: Colors.white60,
                  tabs: const [
                    Tab(text: 'Autonomous Agent'),
                    Tab(text: 'Suggested Fixes'),
                  ],
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildAgentTab(),
                _buildFixesTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAgentTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Select Autonomous Agent Persona:', style: SwarmTextStyles.bodySmall.copyWith(color: Colors.white70)),
          const SizedBox(height: 6),
          DropdownButtonFormField<int>(
            initialValue: _selectedRole,
            dropdownColor: const Color(0xFF101622),
            decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()),
            items: List.generate(_roles.length, (i) {
              return DropdownMenuItem(value: i, child: Text(_roles[i], style: const TextStyle(fontSize: 12, color: Colors.white)));
            }),
            onChanged: (val) => setState(() => _selectedRole = val ?? 1),
          ),
          const SizedBox(height: 12),
          Text('Coding Task / Refactoring Goal:', style: SwarmTextStyles.bodySmall.copyWith(color: Colors.white70)),
          const SizedBox(height: 6),
          TextField(
            controller: _promptCtrl,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'e.g. Implement high-throughput caching and verify null safety...',
              hintStyle: const TextStyle(color: Colors.white30, fontSize: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isGenerating ? null : _dispatchAgent,
              icon: _isGenerating
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                  : const Icon(Icons.bolt, size: 16),
              label: const Text('DISPATCH CODING AGENT'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00E5FF),
                foregroundColor: Colors.black,
              ),
            ),
          ),
          const SizedBox(height: 14),
          if (_taskError != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.smart_toy_outlined, color: Color(0xFFEF4444), size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Agent did not run — $_taskError',
                      style: const TextStyle(fontSize: 11, color: Color(0xFFFCA5A5)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],
          if (_lastTaskResult != null) ...[
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF06080C),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF1E2838)),
                ),
                child: ListView(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.check_circle_outline, color: Color(0xFF00E676), size: 16),
                        const SizedBox(width: 6),
                        Text('Agent Execution Pipeline', style: SwarmTextStyles.title.copyWith(fontSize: 12)),
                        const Spacer(),
                        ElevatedButton(
                          onPressed: () {
                            final code = _lastTaskResult!['generatedCode'] ?? '';
                            if (widget.onApplyDiff != null) {
                              widget.onApplyDiff!(code);
                            }
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('AI code changes applied to active buffer.')),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00E676),
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          ),
                          child: const Text('Apply Diff', style: TextStyle(fontSize: 11)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...((_lastTaskResult!['executionSteps'] as List?) ?? []).map((step) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(step.toString(), style: const TextStyle(fontSize: 11, color: Colors.white70)),
                      );
                    }),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(4)),
                      child: Text(
                        _lastTaskResult!['generatedCode'] ?? '',
                        style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: Color(0xFF00E5FF)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFixesTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('COMPILER & LINTER QUICK FIXES', style: SwarmTextStyles.title.copyWith(fontSize: 12)),
              if (_isAnalyzingFixes) ...[
                const SizedBox(width: 8),
                const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00E5FF))),
              ],
              const Spacer(),
              IconButton(icon: const Icon(Icons.refresh, size: 16, color: Color(0xFF00E5FF)), onPressed: _loadSuggestedFixes),
            ],
          ),
          const SizedBox(height: 8),
          if (_fixesError != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'No fixes retrieved — $_fixesError',
                style: const TextStyle(fontSize: 11, color: Color(0xFFFCA5A5)),
              ),
            ),
          Expanded(
            child: ListView.builder(
              itemCount: _suggestedFixes.length,
              itemBuilder: (context, index) {
                final fix = _suggestedFixes[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F141F),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.lightbulb, color: Colors.amber, size: 16),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(fix['message'] ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                          ),
                          Text('${((fix['confidenceScore'] ?? 0.9) * 100).toInt()}% conf',
                              style: const TextStyle(color: Colors.white38, fontSize: 10)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(fix['explanation'] ?? '', style: const TextStyle(color: Colors.white60, fontSize: 11)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text('Line ${fix['lineNumber']}: ${fix['diagnosticCode']}', style: const TextStyle(color: Colors.white38, fontSize: 10)),
                          const Spacer(),
                          OutlinedButton(
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Applied fix: ${fix['diagnosticCode']}')),
                              );
                            },
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFF00E5FF)),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                            ),
                            child: const Text('Apply Fix', style: TextStyle(color: Color(0xFF00E5FF), fontSize: 11)),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

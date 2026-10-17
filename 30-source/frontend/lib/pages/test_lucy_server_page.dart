import 'package:flutter/material.dart';
import '../services/lucy_server_client.dart';

class TestLucyServerPage extends StatefulWidget {
  const TestLucyServerPage({super.key});

  @override
  State<TestLucyServerPage> createState() => _TestLucyServerPageState();
}

class _TestLucyServerPageState extends State<TestLucyServerPage> {
  final _client = LucyServerClient();
  final _promptController = TextEditingController(text: 'Hello, Lucy!');
  final _modelController = TextEditingController(text: 'openai/gpt-4o-mini');
  
  bool _isLoading = false;
  bool _autoRoute = true;
  String _response = '';

  Future<void> _submit() async {
    if (_promptController.text.isEmpty) return;

    setState(() {
      _isLoading = true;
      _response = '';
    });

    try {
      await for (final chunk in _client.streamLucyChat(
        modelId: _modelController.text,
        autoRoute: _autoRoute,
        messages: [
          {'role': 'user', 'content': _promptController.text}
        ],
      )) {
        setState(() {
          _response += chunk;
        });
      }
    } catch (e) {
      setState(() {
        _response += '\n\n[ERROR]: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _promptController.dispose();
    _modelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Test LucyServer'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _modelController,
              decoration: const InputDecoration(labelText: 'Model ID (e.g. openai/gpt-4o-mini)'),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Checkbox(
                  value: _autoRoute,
                  onChanged: (val) {
                    if (val != null) setState(() => _autoRoute = val);
                  },
                ),
                const Text('Enable Swarm Auto-Routing'),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _promptController,
              decoration: const InputDecoration(labelText: 'Prompt'),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isLoading ? null : _submit,
              child: _isLoading ? const CircularProgressIndicator() : const Text('Send to LucyServer'),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SingleChildScrollView(
                  child: Text(_response.isEmpty ? 'Waiting for response...' : _response),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

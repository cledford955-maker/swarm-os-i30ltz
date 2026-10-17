import 'package:flutter/material.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _darkMode = true;
  bool _notifications = true;
  String _selectedModel = 'gpt-4';
  String _apiEndpoint = 'http://localhost:8000';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          _buildSectionHeader(theme, 'Appearance'),
          SwitchListTile(
            title: const Text('Dark Mode'),
            subtitle: const Text('Use dark theme'),
            value: _darkMode,
            onChanged: (value) => setState(() => _darkMode = value),
            secondary: const Icon(Icons.dark_mode),
          ),
          const Divider(),
          _buildSectionHeader(theme, 'Notifications'),
          SwitchListTile(
            title: const Text('Enable Notifications'),
            subtitle: const Text('Receive agent status updates'),
            value: _notifications,
            onChanged: (value) => setState(() => _notifications = value),
            secondary: const Icon(Icons.notifications),
          ),
          const Divider(),
          _buildSectionHeader(theme, 'AI Model'),
          ListTile(
            leading: const Icon(Icons.psychology),
            title: const Text('Model'),
            subtitle: Text(_selectedModel),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showModelPicker(context),
          ),
          const Divider(),
          _buildSectionHeader(theme, 'Backend'),
          ListTile(
            leading: const Icon(Icons.dns),
            title: const Text('API Endpoint'),
            subtitle: Text(_apiEndpoint),
            trailing: const Icon(Icons.edit),
            onTap: () => _showEndpointEditor(context),
          ),
          const Divider(),
          _buildSectionHeader(theme, 'About'),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('Version'),
            subtitle: Text('SwarmOS v5.0.0-beta'),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(ThemeData theme, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  void _showModelPicker(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Select Model'),
        children:
            ['gpt-4', 'gpt-3.5-turbo', 'claude-3', 'llama-3'].map((model) {
          return SimpleDialogOption(
            onPressed: () {
              setState(() => _selectedModel = model);
              Navigator.pop(context);
            },
            child: ListTile(
              title: Text(model),
              leading: Icon(
                model == _selectedModel ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  void _showEndpointEditor(BuildContext context) {
    final controller = TextEditingController(text: _apiEndpoint);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('API Endpoint'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'http://localhost:8000',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              setState(() => _apiEndpoint = controller.text);
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

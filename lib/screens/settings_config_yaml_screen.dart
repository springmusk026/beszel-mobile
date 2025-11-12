import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';

import '../api/pb_client.dart';

class SettingsConfigYamlScreen extends StatefulWidget {
  const SettingsConfigYamlScreen({super.key});

  @override
  State<SettingsConfigYamlScreen> createState() => _SettingsConfigYamlScreenState();
}

class _SettingsConfigYamlScreenState extends State<SettingsConfigYamlScreen> {
  String? _configContent;
  bool _loading = false;
  String? _error;

  Future<void> _fetchConfig() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await pb.send<Map<String, dynamic>>('/api/beszel/config-yaml', body: {});
      setState(() {
        _configContent = response['config'] as String?;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to fetch configuration: $e';
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchConfig();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('YAML Configuration'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _fetchConfig,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _loading && _configContent == null
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _configContent == null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                      const SizedBox(height: 16),
                      ElevatedButton(onPressed: _fetchConfig, child: const Text('Retry')),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'YAML Configuration',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Export your current systems configuration. Systems may be managed in a config.yml file inside your data directory.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 16),
                      Card(
                        color: Theme.of(context).colorScheme.errorContainer,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Icon(Icons.warning, color: Theme.of(context).colorScheme.onErrorContainer),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Caution: Existing systems not defined in config.yml will be deleted. Please make regular backups.',
                                  style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (_configContent != null) ...[
                        const SizedBox(height: 24),
                        const Text('Configuration:', style: TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        Card(
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            child: SelectableText(
                              _configContent!,
                              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
    );
  }
}


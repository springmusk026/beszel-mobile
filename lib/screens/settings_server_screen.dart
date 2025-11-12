import 'package:flutter/material.dart';

import '../api/pb_client.dart';
import '../services/auth_service.dart';

class SettingsServerScreen extends StatefulWidget {
  const SettingsServerScreen({super.key, this.onConfigured});

  final VoidCallback? onConfigured;

  @override
  State<SettingsServerScreen> createState() => _SettingsServerScreenState();
}

class _SettingsServerScreenState extends State<SettingsServerScreen> {
  final _controller = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _controller.text = PocketBaseManager.instance.baseUrl.value;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isFirstTime = widget.onConfigured != null;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Server Connection'),
        automaticallyImplyLeading: !isFirstTime, // Hide back button on first time
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ) : const Text('Save'),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Base URL', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextField(
              controller: _controller,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.link),
                hintText: 'https://your-beszel-instance',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 12),
            Text(
              'Changing the base URL will log you out and require re-authentication.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const Spacer(),
            FilledButton.icon(
              onPressed: _saving ? null : _restoreDefault,
              icon: const Icon(Icons.restore),
              label: const Text('Restore default URL'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    final raw = _controller.text.trim();
    if (raw.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a URL')));
      return;
    }
    setState(() => _saving = true);
    try {
      await AuthService().logout();
      await PocketBaseManager.instance.setBaseUrl(raw);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Base URL updated')));
      
      // If this is the first-time configuration, trigger callback
      if (widget.onConfigured != null) {
        widget.onConfigured!();
      } else {
        // Otherwise, navigate to login
        Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update base URL: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _restoreDefault() async {
    _controller.text = PocketBaseManager.defaultBaseUrl;
    await _save();
  }
}



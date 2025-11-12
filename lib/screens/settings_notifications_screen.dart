import 'dart:async';

import 'package:flutter/material.dart';

import '../api/pb_client.dart';
import '../models/user_settings.dart';
import '../services/settings_service.dart';

class SettingsNotificationsScreen extends StatefulWidget {
  const SettingsNotificationsScreen({super.key});

  @override
  State<SettingsNotificationsScreen> createState() => _SettingsNotificationsScreenState();
}

class _SettingsNotificationsScreenState extends State<SettingsNotificationsScreen> {
  final _svc = SettingsService();
  final _emailController = TextEditingController();
  final Map<int, TextEditingController> _webhookControllers = {};

  Future<UserSettings>? _future;
  UserSettings? _current;
  bool _initialized = false;
  bool _saving = false;

  List<String> _emails = const [];
  List<String> _webhooks = const [];

  @override
  void initState() {
    super.initState();
    _future = _svc.fetchOrCreate();
  }

  @override
  void dispose() {
    _emailController.dispose();
    for (final controller in _webhookControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving ? const CircularProgressIndicator() : const Text('Save'),
          ),
        ],
      ),
      body: FutureBuilder<UserSettings>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && !_initialized) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('Failed to load notifications settings'));
          }
          final settings = snapshot.data ?? _current;
          if (settings == null) {
            return const SizedBox.shrink();
          }
          if (!_initialized || settings.id != _current?.id) {
            _current = settings;
            _emails = List<String>.from(settings.emails);
            _webhooks = List<String>.from(settings.webhooks);
            _resetWebhookControllers();
            _initialized = true;
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Email notifications', style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _emailController,
                        decoration: const InputDecoration(
                          labelText: 'Add email',
                          hintText: 'user@example.com',
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                        keyboardType: TextInputType.emailAddress,
                        onSubmitted: _addEmail,
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _emails
                            .map(
                              (email) => Chip(
                                label: Text(email),
                                onDeleted: () {
                                  setState(() => _emails.remove(email));
                                },
                              ),
                            )
                            .toList(),
                      ),
                      if (_emails.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            'No email addresses configured. Leave blank to disable email notifications.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Webhook / Push notifications', style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Text(
                        'Beszel uses Shoutrrr for integrating with notification services.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 12),
                      ..._buildWebhookInputs(),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: OutlinedButton.icon(
                          onPressed: () => setState(() => _webhooks = [..._webhooks, '']),
                          icon: const Icon(Icons.add),
                          label: const Text('Add URL'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _buildWebhookInputs() {
    if (_webhooks.isEmpty) {
      return [
        Text(
          'No webhook URLs configured. Add one to receive push notifications.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
      ];
    }
    final List<Widget> widgets = [];
    for (var i = 0; i < _webhooks.length; i++) {
      widgets.add(Card(
        margin: const EdgeInsets.only(bottom: 12),
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _webhookControllers.putIfAbsent(
                  i,
                  () {
                    final c = TextEditingController(text: _webhooks[i]);
                    c.addListener(() => _webhooks[i] = c.text);
                    return c;
                  },
                ),
                decoration: const InputDecoration(
                  labelText: 'Webhook URL',
                  prefixIcon: Icon(Icons.link),
                ),
                keyboardType: TextInputType.url,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: _webhooks[i].isEmpty ? null : () => _sendTest(_webhooks[i]),
                    icon: const Icon(Icons.send),
                    label: const Text('Send test'),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Remove URL',
                    onPressed: () => _removeWebhook(i),
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ),
            ],
          ),
        ),
      ));
    }
    return widgets;
  }

  Future<void> _save() async {
    if (_current == null) return;
    setState(() => _saving = true);
    try {
      final updated = _current!.copyWith(
        emails: List<String>.from(_emails),
        webhooks: List<String>.from(_webhooks),
      );
      final saved = await _svc.update(updated);
      setState(() {
        _current = saved;
        _initialized = false;
        _future = Future.value(saved);
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Notifications settings saved')));
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  void _addEmail(String email) {
    final trimmed = email.trim();
    if (trimmed.isEmpty) return;
    setState(() {
      if (!_emails.contains(trimmed)) {
        _emails = [..._emails, trimmed];
      }
      _emailController.clear();
    });
  }

  void _removeWebhook(int index) {
    final controller = _webhookControllers.remove(index);
    controller?.dispose();
    setState(() {
      _webhooks = List<String>.from(_webhooks)..removeAt(index);
      _resetWebhookControllers();
    });
  }

  void _resetWebhookControllers() {
    for (final controller in _webhookControllers.values) {
      controller.dispose();
    }
    _webhookControllers.clear();
  }

  Future<void> _sendTest(String url) async {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sending test notification…')));
    try {
      final res = await pb.send<Map<String, dynamic>>(
        '/api/beszel/test-notification',
        method: 'POST',
        body: {'url': url},
      );
      if ((res['err'] ?? '').toString().isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Test notification sent')));
      } else {
        throw Exception(res['err']);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send test notification: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }
}



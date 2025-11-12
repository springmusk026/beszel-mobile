import 'package:flutter/material.dart';

import '../api/pb_client.dart';
import '../models/user_settings.dart';
import '../services/settings_service.dart';
import '../theme/theme_controller.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _svc = SettingsService();
  Future<UserSettings>? _future;
  UserSettings? _editing;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _future = _svc.fetchOrCreate();
  }

  Future<void> _save() async {
    final s = _editing;
    if (s == null) return;
    setState(() => _saving = true);
    try {
      final updated = await _svc.update(s);
      setState(() => _editing = updated);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Settings saved')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
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
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('Failed to load settings'));
          }
          final s = _editing ?? snapshot.data!;
          _editing ??= s;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: ListTile(
                  leading: const Icon(Icons.cloud),
                  title: const Text('Server connection'),
                  subtitle: const Text('Set the Beszel Hub base URL'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).pushNamed('/settings/server'),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.key),
                  title: const Text('Tokens & Fingerprints'),
                  subtitle: const Text('Manage agent tokens and system fingerprints'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).pushNamed('/settings/tokens'),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.notifications_outlined),
                  title: const Text('Notifications'),
                  subtitle: const Text('Configure emails and webhook destinations'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).pushNamed('/settings/notifications'),
                ),
              ),
              if (pb.authStore.record?.data['role'] == 'admin') ...[
                const SizedBox(height: 12),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.code),
                    title: const Text('YAML Configuration'),
                    subtitle: const Text('Export systems configuration (Admin only)'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).pushNamed('/settings/config-yaml'),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Appearance', style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 12),
                      ValueListenableBuilder<ThemeMode>(
                        valueListenable: ThemeController.instance.themeMode,
                        builder: (context, mode, _) {
                          return SegmentedButton<ThemeMode>(
                            segments: const [
                              ButtonSegment(value: ThemeMode.light, icon: Icon(Icons.light_mode), label: Text('Light')),
                              ButtonSegment(value: ThemeMode.dark, icon: Icon(Icons.dark_mode), label: Text('Dark')),
                              ButtonSegment(value: ThemeMode.system, icon: Icon(Icons.brightness_auto), label: Text('System')),
                            ],
                            selected: {mode},
                            onSelectionChanged: (sel) {
                              final m = sel.first;
                              ThemeController.instance.setThemeMode(m);
                            },
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _dropdown<String>(
                label: 'Chart Time',
                value: s.chartTime,
                items: const ['1m', '1h', '12h', '24h', '1w', '30d'],
                onChanged: (v) => setState(() => _editing = s.copyWith(chartTime: v)),
              ),
              const SizedBox(height: 12),
              _dropdown<String>(
                label: 'Temperature Unit',
                value: s.unitTemp ?? 'Celsius',
                items: const ['Celsius', 'Fahrenheit'],
                onChanged: (v) => setState(() => _editing = s.copyWith(unitTemp: v)),
              ),
              const SizedBox(height: 12),
              _dropdown<String>(
                label: 'Network Unit',
                value: s.unitNet ?? 'Bytes',
                items: const ['Bytes'],
                onChanged: (v) => setState(() => _editing = s.copyWith(unitNet: v)),
              ),
              const SizedBox(height: 12),
              _dropdown<String>(
                label: 'Disk Unit',
                value: s.unitDisk ?? 'Bytes',
                items: const ['Bytes'],
                onChanged: (v) => setState(() => _editing = s.copyWith(unitDisk: v)),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _dropdown<T>({
    required String label,
    required T value,
    required List<T> items,
    required ValueChanged<T?> onChanged,
  }) {
    final T selected = items.contains(value) ? value : items.first;
    return InputDecorator(
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: selected,
          isExpanded: true,
          items: items.map((e) => DropdownMenuItem<T>(value: e, child: Text(e.toString()))).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}



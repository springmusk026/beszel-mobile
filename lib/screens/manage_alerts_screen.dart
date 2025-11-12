import 'package:flutter/material.dart';

import '../api/pb_client.dart';
import '../models/system_record.dart';

class ManageAlertsScreen extends StatefulWidget {
  const ManageAlertsScreen({super.key, required this.system});

  final SystemRecord system;

  @override
  State<ManageAlertsScreen> createState() => _ManageAlertsScreenState();
}

class _ManageAlertsScreenState extends State<ManageAlertsScreen> {
  final Map<String, _AlertState> _alertStates = {};
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadAlerts();
  }

  Future<void> _loadAlerts() async {
    try {
      final alerts = await pb.collection('alerts').getList(
        filter: 'system="${widget.system.id}"',
        fields: 'id,name,value,min,triggered',
      );
      setState(() {
        for (final alert in alerts.items) {
          final name = alert.data['name']?.toString() ?? '';
          _alertStates[name] = _AlertState(
            id: alert.id,
            enabled: true,
            value: (alert.data['value'] as num?)?.toDouble() ?? 80.0,
            min: (alert.data['min'] as num?)?.toInt() ?? 10,
          );
        }
      });
    } catch (e) {
      // Alerts might not exist yet, that's okay
    }
  }

  Future<void> _toggleAlert(String alertName, bool enabled) async {
    setState(() {
      _loading = true;
      final state = _alertStates[alertName] ?? _AlertState(enabled: false, value: 80.0, min: 10);
      _alertStates[alertName] = state.copyWith(enabled: enabled);
    });
    try {
      if (enabled) {
        final state = _alertStates[alertName]!;
        await pb.send<Map<String, dynamic>>(
          '/api/beszel/user-alerts',
          body: {
            'name': alertName,
            'value': state.value.toInt(),
            'min': state.min,
            'systems': [widget.system.id],
            'overwrite': true,
          },
        );
      } else {
        // Delete alert - try to delete by ID first, then fallback to API endpoint
        final state = _alertStates[alertName];
        if (state?.id != null) {
          try {
            await pb.collection('alerts').delete(state!.id!);
          } catch (_) {
            // If delete by ID fails, try the API endpoint
            await pb.send<Map<String, dynamic>>(
              '/api/beszel/user-alerts',
              body: {
                'name': alertName,
                'systems': [widget.system.id],
              },
            );
          }
        } else {
          // No ID, use API endpoint
          await pb.send<Map<String, dynamic>>(
            '/api/beszel/user-alerts',
            body: {
              'name': alertName,
              'systems': [widget.system.id],
            },
          );
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Alert ${enabled ? 'enabled' : 'disabled'}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update alert: $e')),
        );
      }
      // Revert on error
      setState(() {
        final state = _alertStates[alertName]!;
        _alertStates[alertName] = state.copyWith(enabled: !enabled);
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _updateAlert(String alertName, double value, int min) async {
    setState(() {
      _loading = true;
      final state = _alertStates[alertName] ?? _AlertState(enabled: false, value: 80.0, min: 10);
      _alertStates[alertName] = state.copyWith(value: value, min: min);
    });
    try {
      await pb.send<Map<String, dynamic>>(
        '/api/beszel/user-alerts',
        body: {
          'name': alertName,
          'value': value.toInt(),
          'min': min,
          'systems': [widget.system.id],
          'overwrite': true,
        },
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Alert updated')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update alert: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Manage Alerts • ${widget.system.name}')),
      body: _loading && _alertStates.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: _alertTypes.entries.map((entry) {
                final alertName = entry.key;
                final alertInfo = entry.value;
                final state = _alertStates[alertName] ?? _AlertState(enabled: false, value: alertInfo.defaultValue, min: 10);
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ExpansionTile(
                    leading: Icon(alertInfo.icon),
                    title: Text(alertInfo.name),
                    subtitle: Text(alertInfo.description),
                    trailing: Switch(
                      value: state.enabled,
                      onChanged: _loading ? null : (enabled) => _toggleAlert(alertName, enabled),
                    ),
                    children: state.enabled
                        ? [
                            if (alertInfo.maxValue > alertInfo.minValue)
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Threshold: ${state.value.toInt()}${alertInfo.unit}'),
                                    Slider(
                                      value: state.value.clamp(alertInfo.minValue, alertInfo.maxValue),
                                      min: alertInfo.minValue,
                                      max: alertInfo.maxValue,
                                      divisions: (alertInfo.maxValue - alertInfo.minValue).round(),
                                      label: '${state.value.toInt()}${alertInfo.unit}',
                                      onChanged: _loading
                                          ? null
                                          : (v) {
                                              setState(() {
                                                _alertStates[alertName] = state.copyWith(value: v);
                                              });
                                            },
                                      onChangeEnd: (v) => _updateAlert(alertName, v, state.min),
                                    ),
                                  ],
                                ),
                              )
                            else
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                child: Text(
                                  'No configurable threshold for this alert.',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ),
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Duration: ${state.min} minutes'),
                                  Slider(
                                    value: state.min.toDouble(),
                                    min: 1,
                                    max: 60,
                                    divisions: 59,
                                    label: '${state.min} minutes',
                                    onChanged: _loading
                                        ? null
                                        : (v) {
                                            setState(() {
                                              _alertStates[alertName] = state.copyWith(min: v.toInt());
                                            });
                                          },
                                    onChangeEnd: (v) => _updateAlert(alertName, state.value, v.toInt()),
                                  ),
                                ],
                              ),
                            ),
                          ]
                        : [],
                  ),
                );
              }).toList(),
            ),
    );
  }
}

class _AlertState {
  final String? id;
  final bool enabled;
  final double value;
  final int min;

  _AlertState({this.id, required this.enabled, required this.value, required this.min});

  _AlertState copyWith({String? id, bool? enabled, double? value, int? min}) {
    return _AlertState(
      id: id ?? this.id,
      enabled: enabled ?? this.enabled,
      value: value ?? this.value,
      min: min ?? this.min,
    );
  }
}

class _AlertInfo {
  final String name;
  final String description;
  final IconData icon;
  final String unit;
  final double defaultValue;
  final double minValue;
  final double maxValue;

  const _AlertInfo({
    required this.name,
    required this.description,
    required this.icon,
    required this.unit,
    required this.defaultValue,
    required this.minValue,
    required this.maxValue,
  });
}

const _alertTypes = <String, _AlertInfo>{
  'CPU': _AlertInfo(
    name: 'CPU Usage',
    description: 'Alert when CPU usage exceeds threshold',
    icon: Icons.speed,
    unit: '%',
    defaultValue: 80.0,
    minValue: 0,
    maxValue: 100,
  ),
  'Memory': _AlertInfo(
    name: 'Memory Usage',
    description: 'Alert when memory usage exceeds threshold',
    icon: Icons.memory,
    unit: '%',
    defaultValue: 80.0,
    minValue: 0,
    maxValue: 100,
  ),
  'Disk': _AlertInfo(
    name: 'Disk Usage',
    description: 'Alert when disk usage exceeds threshold',
    icon: Icons.storage,
    unit: '%',
    defaultValue: 80.0,
    minValue: 0,
    maxValue: 100,
  ),
  'Status': _AlertInfo(
    name: 'System Status',
    description: 'Alert when system connection is down',
    icon: Icons.warning,
    unit: '',
    defaultValue: 0,
    minValue: 0,
    maxValue: 0,
  ),
};


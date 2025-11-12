import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';

import '../models/system_record.dart';
import '../services/alerts_service.dart';
import '../services/systems_service.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  final _svc = AlertsService();
  final _systemsService = SystemsService();
  final Map<String, SystemRecord> _systemsById = {};
  StreamSubscription<List<SystemRecord>>? _systemsSub;
  late Future<List<RecordModel>> _future;

  @override
  void initState() {
    super.initState();
    _future = _svc.fetchActive();
    _svc.subscribeActive();
    _systemsSub = _systemsService.stream.listen((systems) {
      setState(() {
        _systemsById
          ..clear()
          ..addEntries(systems.map((s) => MapEntry(s.id, s)));
      });
    });
    _systemsService.fetchAll();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Active Alerts')),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() => _future = _svc.fetchActive());
          await _future;
        },
        child: StreamBuilder<List<RecordModel>>(
          stream: _svc.stream,
          initialData: const <RecordModel>[],
          builder: (context, snapshot) {
            final items = snapshot.data ?? const <RecordModel>[];
            if (items.isEmpty && (snapshot.connectionState == ConnectionState.waiting)) {
              return const Center(child: CircularProgressIndicator());
            }
            if (items.isEmpty) {
              return const Center(child: Text('No active alerts'));
            }
            return ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final r = items[index];
                final name = r.data['name']?.toString() ?? '';
                final systemId = r.data['system']?.toString() ?? '';
                final systemName = (r.data['expand']?['system']?['name']?.toString()) ?? systemId;
                final value = _num(r.data['value']);
                final min = _num(r.data['min']);
                final updated = r.data['updated']?.toString();
                final time = _formatTime(updated);
                final system = _systemsById[systemId];
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Theme.of(context).colorScheme.error,
                      child: const Icon(Icons.warning_amber_rounded, color: Colors.white),
                    ),
                    title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(systemName),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 12,
                            runSpacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.equalizer, size: 14),
                                  const SizedBox(width: 4),
                                  Text('Value $value'),
                                ],
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.flag, size: 14),
                                  const SizedBox(width: 4),
                                  Text('Threshold $min'),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Chip(
                          label: const Text('ACTIVE'),
                          labelStyle: TextStyle(color: Theme.of(context).colorScheme.onPrimary, fontWeight: FontWeight.w600),
                          backgroundColor: Theme.of(context).colorScheme.error,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                        ),
                        if (time != null) ...[
                          const SizedBox(height: 4),
                          Text(time, style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ],
                    ),
                    onTap: () {
                      Navigator.of(context).pushNamed(
                        '/system',
                        arguments: system ?? _systemRecordStub(systemId: systemId, systemName: systemName),
                      );
                    },
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  SystemRecord _systemRecordStub({required String systemId, required String systemName}) {
    return SystemRecord(
      id: systemId,
      name: systemName,
      host: '—',
      status: 'up',
      port: '—',
      info: const {},
    );
  }

  String? _formatTime(String? iso) {
    if (iso == null) return null;
    try {
      final dt = DateTime.parse(iso).toUtc();
      final diff = DateTime.now().toUtc().difference(dt);
      if (diff.inMinutes < 1) return 'just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      return '${diff.inDays}d ago';
    } catch (_) {
      return null;
    }
  }

  num _num(dynamic v) {
    if (v is num) return v;
    if (v is String) return num.tryParse(v) ?? 0;
    return 0;
  }

  @override
  void dispose() {
    _systemsSub?.cancel();
    _svc.unsubscribe();
    super.dispose();
  }
}


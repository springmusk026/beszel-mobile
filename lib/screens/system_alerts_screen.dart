import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';

import '../models/system_record.dart';
import '../services/alerts_service.dart';

class SystemAlertsScreen extends StatefulWidget {
  const SystemAlertsScreen({super.key, required this.system});

  final SystemRecord system;

  @override
  State<SystemAlertsScreen> createState() => _SystemAlertsScreenState();
}

class _SystemAlertsScreenState extends State<SystemAlertsScreen> {
  final _svc = AlertsService();
  late Future<List<RecordModel>> _future;

  @override
  void initState() {
    super.initState();
    _future = _svc.fetchHistory(systemId: widget.system.id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Alerts • ${widget.system.name}')),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() => _future = _svc.fetchHistory(systemId: widget.system.id));
          await _future;
        },
        child: FutureBuilder<List<RecordModel>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return const Center(child: Text('Failed to load alerts history'));
            }
            final items = snapshot.data ?? const <RecordModel>[];
            if (items.isEmpty) {
              return const Center(child: Text('No alerts history found'));
            }
            return ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: items.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final r = items[index];
                final name = r.data['name']?.toString() ?? '';
                final val = r.data['val']?.toString() ?? '';
                final created = r.data['created']?.toString() ?? '';
                final resolved = r.data['resolved']?.toString();
                return ListTile(
                  title: Text(name),
                  subtitle: Text('Value: $val • Created: $created'),
                  trailing: Text(resolved == null ? 'ACTIVE' : 'RESOLVED',
                      style: TextStyle(color: resolved == null ? Colors.red : Colors.green)),
                );
              },
            );
          },
        ),
      ),
    );
  }
}



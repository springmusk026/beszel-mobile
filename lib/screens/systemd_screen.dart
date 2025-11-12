import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';

import '../models/system_record.dart';
import '../services/systemd_service.dart';
import '../api/pb_client.dart';

class SystemdScreen extends StatefulWidget {
  const SystemdScreen({super.key, required this.system});

  final SystemRecord system;

  @override
  State<SystemdScreen> createState() => _SystemdScreenState();
}

class _SystemdScreenState extends State<SystemdScreen> {
  final _svc = SystemdService();
  late Future<List<RecordModel>> _future;

  @override
  void initState() {
    super.initState();
    _future = _svc.fetchForSystem(widget.system.id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('systemd • ${widget.system.name}')),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() => _future = _svc.fetchForSystem(widget.system.id));
          await _future;
        },
        child: FutureBuilder<List<RecordModel>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    'Failed to load services\n${snapshot.error}',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }
            final items = snapshot.data ?? const <RecordModel>[];
            if (items.isEmpty) {
              return const Center(child: Text('No services found'));
            }
            return ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final r = items[index];
                final name = r.data['name']?.toString() ?? '';
                final state = r.data['state']?.toString() ?? '';
                final sub = r.data['sub']?.toString() ?? '';
                final cpu = r.data['cpu']?.toString() ?? '0';
                final mem = r.data['memory']?.toString() ?? '0';
                final stateColor = _stateColor(state, context);
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(backgroundColor: stateColor, child: const Icon(Icons.miscellaneous_services, color: Colors.white)),
                    title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Wrap(
                        spacing: 12,
                        runSpacing: 6,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.info_outline, size: 14),
                              const SizedBox(width: 4),
                              Text('$state/$sub'),
                            ],
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.speed, size: 14),
                              const SizedBox(width: 4),
                              Text('CPU $cpu%'),
                            ],
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.memory, size: 14),
                              const SizedBox(width: 4),
                              Text('MEM $mem MB'),
                            ],
                          ),
                        ],
                      ),
                    ),
                    trailing: Chip(
                      label: Text(state),
                      backgroundColor: stateColor.withOpacity(0.2),
                      labelStyle: TextStyle(color: stateColor, fontWeight: FontWeight.w600),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                    ),
                    onTap: () => _openDetails(context, name),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Color _stateColor(String state, BuildContext context) {
    final s = state.toLowerCase();
    if (s == 'active') return Colors.green;
    if (s == 'failed') return Colors.red;
    return Theme.of(context).colorScheme.outline;
  }

  Future<void> _openDetails(BuildContext context, String serviceName) async {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return FutureBuilder<Map<String, dynamic>>(
          future: pb.send<Map<String, dynamic>>(
            '/api/beszel/systemd/info',
            query: {'system': widget.system.id, 'service': serviceName},
          ),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (snapshot.hasError) {
              return Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Failed to load service details', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Text(snapshot.error.toString(), style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close),
                        label: const Text('Close'),
                      ),
                    ),
                  ],
                ),
              );
            }
            final details = snapshot.data ?? const {};
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(serviceName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  _kv('Active State', '${details['ActiveState'] ?? '—'} (${details['SubState'] ?? '—'})'),
                  _kv('Main PID', (details['MainPID'] ?? '').toString()),
                  _kv('CPU Usage (ns)', (details['CPUUsageNSec'] ?? '').toString()),
                  _kv('Memory Current', (details['MemoryCurrent'] ?? '').toString()),
                  _kv('Memory Peak', (details['MemoryPeak'] ?? '').toString()),
                  _kv('Tasks Current', (details['TasksCurrent'] ?? '').toString()),
                  _kv('Restarts', (details['NRestarts'] ?? '').toString()),
                  _kv('Fragment Path', (details['FragmentPath'] ?? '').toString()),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.icon(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.check),
                      label: const Text('Done'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(k, style: const TextStyle(fontWeight: FontWeight.w600)),
          Flexible(child: Text(v, textAlign: TextAlign.right)),
        ],
      ),
    );
  }
}



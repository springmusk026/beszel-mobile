import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';

import '../models/system_record.dart';
import '../services/containers_service.dart';

class ContainersScreen extends StatefulWidget {
  const ContainersScreen({super.key, required this.system});

  final SystemRecord system;

  @override
  State<ContainersScreen> createState() => _ContainersScreenState();
}

class _ContainersScreenState extends State<ContainersScreen> {
  final _svc = ContainersService();
  late Future<List<RecordModel>> _future;

  @override
  void initState() {
    super.initState();
    _future = _svc.fetchForSystem(widget.system.id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Containers • ${widget.system.name}')),
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
              return const Center(child: Text('Failed to load containers'));
            }
            final items = snapshot.data ?? const <RecordModel>[];
            if (items.isEmpty) {
              return const Center(child: Text('No containers found'));
            }
            return ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final r = items[index];
                final name = r.data['name']?.toString() ?? '';
                final image = r.data['image']?.toString() ?? '';
                final cpu = r.data['cpu']?.toString() ?? '0';
                final mem = r.data['memory']?.toString() ?? '0';
                final net = r.data['net']?.toString() ?? '0';
                final status = r.data['status']?.toString() ?? '';
                final health = r.data['health']?.toString() ?? '';
                final statusColor = _statusColor(status, context);
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: statusColor,
                      child: const Icon(Icons.dns, color: Colors.white),
                    ),
                    title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(image),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 12,
                            runSpacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
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
                                  Text('MEM $mem GB'),
                                ],
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.network_check, size: 14),
                                  const SizedBox(width: 4),
                                  Text('NET $net MB/s'),
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
                          label: Text(health.isEmpty ? status : '$status • $health'),
                          labelStyle: TextStyle(color: Theme.of(context).colorScheme.onPrimary, fontWeight: FontWeight.w600),
                          backgroundColor: statusColor,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                        ),
                      ],
                    ),
                    onTap: () => Navigator.of(context).pushNamed(
                      '/container-details',
                      arguments: {
                        'systemId': widget.system.id,
                        'containerId': r.id,
                        'containerName': name,
                      },
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Color _statusColor(String status, BuildContext context) {
    final s = status.toLowerCase();
    if (s.contains('up') || s.contains('running') || s.contains('healthy')) {
      return Colors.green;
    }
    if (s.contains('exited') || s.contains('down') || s.contains('unhealthy')) {
      return Colors.red;
    }
    return Theme.of(context).colorScheme.outline;
  }
}



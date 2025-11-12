import 'package:flutter/material.dart';

import '../models/system_record.dart';
import '../services/smart_service.dart';

class SystemSmartScreen extends StatefulWidget {
  const SystemSmartScreen({super.key, required this.system});

  final SystemRecord system;

  @override
  State<SystemSmartScreen> createState() => _SystemSmartScreenState();
}

class _SystemSmartScreenState extends State<SystemSmartScreen> {
  final _svc = SmartService();
  late Future<List<SmartDiskData>> _future;

  @override
  void initState() {
    super.initState();
    _future = _svc.fetchSmart(widget.system.id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('S.M.A.R.T. • ${widget.system.name}')),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() => _future = _svc.fetchSmart(widget.system.id));
          await _future;
        },
        child: FutureBuilder<List<SmartDiskData>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Failed to load S.M.A.R.T. data'),
                      const SizedBox(height: 8),
                      Text(
                        snapshot.error.toString(),
                        style: Theme.of(context).textTheme.bodySmall,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () {
                          setState(() => _future = _svc.fetchSmart(widget.system.id));
                        },
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              );
            }
            final disks = snapshot.data ?? const <SmartDiskData>[];
            if (disks.isEmpty) {
              return const Center(child: Text('No S.M.A.R.T. data available'));
            }
            return ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: disks.length,
              itemBuilder: (context, index) {
                final disk = disks[index];
                return Card(
                  child: ExpansionTile(
                    title: Text(disk.device, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(disk.model ?? 'Unknown model'),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 12,
                          runSpacing: 6,
                          children: [
                            _chip(Icons.confirmation_number, disk.serialNumber ?? 'Unknown SN'),
                            _chip(Icons.storage, _formatCapacity(disk.capacity)),
                            _chip(Icons.thermostat, _formatTemp(disk.temperature)),
                            _chip(Icons.category, (disk.deviceType ?? 'Unknown').toUpperCase()),
                            _statusChip(disk.status ?? 'Unknown'),
                          ],
                        ),
                      ],
                    ),
                    children: [
                      if (disk.attributes.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(16),
                          child: Text('No attributes reported.'),
                        )
                      else
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Attributes', style: Theme.of(context).textTheme.titleMedium),
                              const SizedBox(height: 12),
                              _buildAttributeTable(disk),
                            ],
                          ),
                        ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _chip(IconData icon, String label) {
    return Chip(
      avatar: Icon(icon, size: 16),
      label: Text(label),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  Widget _statusChip(String status) {
    Color color;
    switch (status.toUpperCase()) {
      case 'PASSED':
        color = Colors.green;
        break;
      case 'FAILED':
        color = Colors.red;
        break;
      default:
        color = Colors.orange;
    }
    return Chip(
      label: Text(status.toUpperCase()),
      backgroundColor: color.withOpacity(0.2),
      labelStyle: TextStyle(color: color, fontWeight: FontWeight.w600),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  Widget _buildAttributeTable(SmartDiskData disk) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('ID')),
          DataColumn(label: Text('Name')),
          DataColumn(label: Text('Value')),
          DataColumn(label: Text('Worst')),
          DataColumn(label: Text('Threshold')),
          DataColumn(label: Text('Raw')),
          DataColumn(label: Text('Failed')),
        ],
        rows: disk.attributes
            .map(
              (attr) => DataRow(
                cells: [
                  DataCell(Text(attr.id?.toString() ?? '')),
                  DataCell(Text(attr.name)),
                  DataCell(Text(attr.value?.toString() ?? attr.rawString ?? '')),
                  DataCell(Text(attr.worst?.toString() ?? '')),
                  DataCell(Text(attr.threshold?.toString() ?? '')),
                  DataCell(Text(attr.rawString ?? attr.rawValue?.toString() ?? '')),
                  DataCell(Text(attr.whenFailed ?? '')),
                ],
              ),
            )
            .toList(),
      ),
    );
  }

  String _formatCapacity(num? bytes) {
    if (bytes == null) return 'Unknown capacity';
    const units = ['B', 'KB', 'MB', 'GB', 'TB', 'PB'];
    double value = bytes.toDouble();
    var unitIndex = 0;
    while (value >= 1024 && unitIndex < units.length - 1) {
      value /= 1024;
      unitIndex++;
    }
    return '${value.toStringAsFixed(value >= 10 ? 1 : 2)} ${units[unitIndex]}';
  }

  String _formatTemp(num? temp) {
    if (temp == null) return 'Temp N/A';
    return '${temp.toString()} °C';
  }
}



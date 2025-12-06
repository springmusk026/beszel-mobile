import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pocketbase/pocketbase.dart';

import '../api/pb_client.dart';
import '../models/system_record.dart';
import '../services/alerts_service.dart';
import '../services/auth_service.dart';
import '../services/systems_service.dart';

class SystemsScreen extends StatefulWidget {
  const SystemsScreen({super.key});

  @override
  State<SystemsScreen> createState() => _SystemsScreenState();
}

class _AlertCard extends StatelessWidget {
  const _AlertCard({required this.alert, required this.systems});

  final RecordModel alert;
  final List<SystemRecord> systems;

  @override
  Widget build(BuildContext context) {
    final systemId = alert.data['system']?.toString() ?? '';
    SystemRecord? target;
    for (final system in systems) {
      if (system.id == systemId) {
        target = system;
        break;
      }
    }
    final expanded = alert.expand?['system'];
    String? expandedName;
    if (expanded != null) {
      if (expanded is RecordModel) {
        final record = expanded as RecordModel;
        expandedName = record.data['name']?.toString();
      } else if (expanded is List) {
        final list = expanded;
        if (list.isNotEmpty) {
          final first = list.first;
          if (first is RecordModel) {
            expandedName = first.data['name']?.toString();
          }
        }
      }
    }
    final systemName = target?.name ?? expandedName ?? 'System';
    final alertKey = alert.data['name']?.toString() ?? 'Alert';
    final displayName = _displayName(alertKey);
    final unit = _unit(alertKey);
    final value = alert.data['value'];
    final min = alert.data['min'];
    final description =
        value != null && min != null ? '$value$unit for $min min' : 'Triggered';
    final timestamp = alert.data['updated']?.toString() ?? '';

    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 160, maxWidth: 240),
      child: InkWell(
        onTap: target != null
            ? () => Navigator.of(context).pushNamed('/system', arguments: target)
            : null,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceVariant,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(systemName, style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(displayName, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 8),
              Text(description, style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 8),
              Text(timestamp,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Theme.of(context).colorScheme.outline)),
            ],
          ),
        ),
      ),
    );
  }

  String _displayName(String key) {
    switch (key.toLowerCase()) {
      case 'cpu':
        return 'CPU usage';
      case 'memory':
        return 'Memory usage';
      case 'disk':
        return 'Disk usage';
      case 'status':
        return 'Connection status';
      default:
        return key;
    }
  }

  String _unit(String key) {
    switch (key.toLowerCase()) {
      case 'cpu':
      case 'memory':
      case 'disk':
        return '%';
      default:
        return '';
    }
  }
}


enum _SortBy { name, status, cpu, mem, disk }

class _SystemsScreenState extends State<SystemsScreen> {
  final _systemsService = SystemsService();
  final _auth = AuthService();
  final AlertsService _alertsService = AlertsService();
  late Future<List<SystemRecord>> _future;
  final TextEditingController _searchController = TextEditingController();
  StreamSubscription<List<RecordModel>>? _alertsSub;

  _SortBy _sortBy = _SortBy.name;
  bool _ascending = true;
  List<RecordModel> _activeAlerts = const [];
  bool _alertsLoading = true;
  String? _alertsError;

  @override
  void initState() {
    super.initState();
    _future = _systemsService.fetchAll();
    _systemsService.subscribe();
    _alertsService.subscribeActive();
    _alertsSub = _alertsService.stream.listen((alerts) {
      if (!mounted) return;
      setState(() {
        _activeAlerts = alerts;
        _alertsLoading = false;
      });
    });
    _loadActiveAlerts();
  }

  Future<void> _logout() async {
    await _auth.logout();
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }

  Future<void> _loadActiveAlerts() async {
    try {
      setState(() {
        _alertsLoading = true;
        _alertsError = null;
      });
      final alerts = await _alertsService.fetchActive();
      if (!mounted) return;
      setState(() {
        _activeAlerts = alerts;
        _alertsLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _alertsError = 'Failed to load active alerts';
        _alertsLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Systems'),
        actions: [
          IconButton(
            onPressed: () async {
              final result = await Navigator.of(context).pushNamed('/add-system');
              if (result == true) {
                setState(() {
                  _future = _systemsService.fetchAll();
                });
              }
            },
            icon: const Icon(Icons.add),
            tooltip: 'Add System',
          ),
          IconButton(
            onPressed: _openSearchSortSheet,
            icon: const Icon(Icons.more_vert),
            tooltip: 'More',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await _systemsService.fetchAll();
          await _loadActiveAlerts();
        },
        child: StreamBuilder<List<SystemRecord>>(
          stream: _systemsService.stream,
          initialData: const <SystemRecord>[],
          builder: (context, snapshot) {
            final items = snapshot.data ?? const <SystemRecord>[];
            if (items.isEmpty) {
              return FutureBuilder<List<SystemRecord>>(
                future: _future,
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final list = snap.data ?? const <SystemRecord>[];
                  if (list.isEmpty) {
                    return const Center(child: Text('No systems found'));
                  }
                  return _buildList(context, list);
                },
              );
            }
            return _buildList(context, items);
          },
        ),
      ),
    );
  }

  Future<void> _deleteSystem(SystemRecord system) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${system.name}?'),
        content: Text('This action cannot be undone. This will permanently delete all current records for ${system.name} from the database.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await pb.collection('systems').delete(system.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${system.name} deleted')));
        setState(() {
          _future = _systemsService.fetchAll();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to delete: $e')));
      }
    }
  }

  Future<void> _pauseResumeSystem(SystemRecord system) async {
    try {
      final newStatus = system.status == 'paused' ? 'pending' : 'paused';
      await pb.collection('systems').update(system.id, body: {'status': newStatus});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${system.name} ${newStatus == 'paused' ? 'paused' : 'resumed'}')),
        );
        setState(() {
          _future = _systemsService.fetchAll();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update: $e')));
      }
    }
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$label copied to clipboard')));
  }

  @override
  void dispose() {
    _alertsSub?.cancel();
    unawaited(_alertsService.unsubscribe());
    unawaited(_systemsService.unsubscribe());
    _searchController.dispose();
    super.dispose();
  }

  Widget _buildList(BuildContext context, List<SystemRecord> items) {
    final query = _searchController.text.trim().toLowerCase();
    List<SystemRecord> filtered = List<SystemRecord>.from(items);
    if (query.isNotEmpty) {
      filtered = filtered.where((s) {
        final name = s.name.toLowerCase();
        final host = s.host.toLowerCase();
        return name.contains(query) || host.contains(query);
      }).toList();
    }

    filtered.sort((a, b) {
      int cmp = 0;
      switch (_sortBy) {
        case _SortBy.name:
          cmp = a.name.toLowerCase().compareTo(b.name.toLowerCase());
          break;
        case _SortBy.status:
          cmp = _statusRank(a.status).compareTo(_statusRank(b.status));
          break;
        case _SortBy.cpu:
          cmp = _num(b.info['cpu']).compareTo(_num(a.info['cpu']));
          break;
        case _SortBy.mem:
          cmp = _num(b.info['mp']).compareTo(_num(a.info['mp']));
          break;
        case _SortBy.disk:
          cmp = _num(b.info['dp']).compareTo(_num(a.info['dp']));
          break;
      }
      return _ascending ? cmp : -cmp;
    });

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: filtered.length + (_shouldShowAlertsSection ? 1 : 0),
      itemBuilder: (context, index) {
        if (_shouldShowAlertsSection && index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildAlertsSection(filtered),
          );
        }
        final offset = _shouldShowAlertsSection ? 1 : 0;
        final s = filtered[index - offset];
        final theme = Theme.of(context);
        final statusColor = _statusColor(s.status, context);
        final statusTextColor = _statusLabelTextColor(statusColor);
        final cpuPercent = _percent(s.info['cpu']);
        final memPercent = _percent(s.info['mp']);
        final diskPercent = _percent(s.info['dp']);
        final netIn = _num(s.info['nr'] ?? s.info['net_in']).toDouble();
        final netOut = _num(s.info['ns'] ?? s.info['net_out']).toDouble();
        final diskRead = _num(s.info['dr'] ?? s.info['disk_read']).toDouble();
        final diskWrite = _num(s.info['dw'] ?? s.info['disk_write']).toDouble();

        int containersTotal = 0;
        int containersRunning = 0;
        final containersData = s.info['containers'] ?? s.info['container_count'] ?? s.info['containers_count'];
        if (containersData is Map) {
          containersTotal = _num(containersData['total'] ?? containersData['all'] ?? containersData['count']).toInt();
          containersRunning = _num(containersData['running'] ?? containersData['active'] ?? containersData['up']).toInt();
          if (containersTotal == 0 && containersData['items'] is List) {
            final items = containersData['items'] as List;
            containersTotal = items.length;
            containersRunning = items.where((item) {
              if (item is Map) {
                final status = item['status']?.toString().toLowerCase();
                return status == 'running' || status == 'online';
              }
              return false;
            }).length;
          }
        } else if (containersData is List) {
          containersTotal = containersData.length;
        } else if (containersData != null) {
          containersTotal = _num(containersData).toInt();
        }

        final infoPills = <Widget>[];
        if (netIn > 0) {
          infoPills.add(_InfoPill(
            icon: Icons.cloud_download_outlined,
            label: 'Inbound',
            value: _formatRate(netIn),
            color: Colors.indigo,
          ));
        }
        if (netOut > 0) {
          infoPills.add(_InfoPill(
            icon: Icons.cloud_upload_outlined,
            label: 'Outbound',
            value: _formatRate(netOut),
            color: Colors.teal,
          ));
        }
        if (diskRead > 0) {
          infoPills.add(_InfoPill(
            icon: Icons.sd_card_outlined,
            label: 'Disk read',
            value: _formatRate(diskRead),
            color: Colors.deepOrange,
          ));
        }
        if (diskWrite > 0) {
          infoPills.add(_InfoPill(
            icon: Icons.save_alt_outlined,
            label: 'Disk write',
            value: _formatRate(diskWrite),
            color: Colors.purple,
          ));
        }
        if (containersTotal > 0) {
          final runningLabel = containersRunning > 0 ? '$containersRunning running · ' : '';
          infoPills.add(_InfoPill(
            icon: Icons.dns_outlined,
            label: 'Containers',
            value: '$runningLabel$containersTotal total',
            color: Colors.blueGrey,
          ));
        }

        return Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => Navigator.of(context).pushNamed('/system', arguments: s),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 280),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    statusColor.withOpacity(0.14),
                    theme.colorScheme.surfaceVariant.withOpacity(0.05),
                  ],
                ),
                border: Border.all(color: statusColor.withOpacity(0.18)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _StatusPulse(color: statusColor),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s.name,
                              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${s.host}:${s.port}',
                              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                      _StatusLabel(
                        label: s.status.toUpperCase(),
                        background: statusColor.withOpacity(0.2),
                        foreground: statusTextColor,
                        borderColor: statusColor.withOpacity(0.4),
                      ),
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert),
                        onSelected: (value) async {
                          switch (value) {
                            case 'edit':
                              final result = await Navigator.of(context).pushNamed('/add-system', arguments: s);
                              if (result == true) {
                                setState(() {
                                  _future = _systemsService.fetchAll();
                                });
                              }
                              break;
                            case 'pause':
                            case 'resume':
                              await _pauseResumeSystem(s);
                              break;
                            case 'copy_name':
                              _copyToClipboard(s.name, 'System name');
                              break;
                            case 'copy_host':
                              _copyToClipboard('${s.host}:${s.port}', 'Host');
                              break;
                            case 'delete':
                              await _deleteSystem(s);
                              break;
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, size: 18), SizedBox(width: 8), Text('Edit')])),
                          PopupMenuItem(
                            value: s.status == 'paused' ? 'resume' : 'pause',
                            child: Row(
                              children: [
                                Icon(s.status == 'paused' ? Icons.play_circle : Icons.pause_circle, size: 18),
                                const SizedBox(width: 8),
                                Text(s.status == 'paused' ? 'Resume' : 'Pause'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(value: 'copy_name', child: Row(children: [Icon(Icons.copy, size: 18), SizedBox(width: 8), Text('Copy name')])),
                          const PopupMenuItem(value: 'copy_host', child: Row(children: [Icon(Icons.copy, size: 18), SizedBox(width: 8), Text('Copy host')])),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(children: [Icon(Icons.delete, size: 18, color: Colors.red), SizedBox(width: 8), Text('Delete', style: TextStyle(color: Colors.red))]),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      ConstrainedBox(
                        constraints: const BoxConstraints(minWidth: 160, maxWidth: 280),
                        child: _MetricGauge(
                          icon: Icons.speed,
                          color: Colors.deepOrangeAccent,
                          label: 'CPU usage',
                          value: cpuPercent,
                        ),
                      ),
                      ConstrainedBox(
                        constraints: const BoxConstraints(minWidth: 160, maxWidth: 280),
                        child: _MetricGauge(
                          icon: Icons.memory,
                          color: Colors.blueAccent,
                          label: 'Memory usage',
                          value: memPercent,
                        ),
                      ),
                      ConstrainedBox(
                        constraints: const BoxConstraints(minWidth: 160, maxWidth: 280),
                        child: _MetricGauge(
                          icon: Icons.storage,
                          color: Colors.teal,
                          label: 'Disk usage',
                          value: diskPercent,
                        ),
                      ),
                    ],
                  ),
                  if (infoPills.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: infoPills,
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  bool get _shouldShowAlertsSection =>
      _alertsLoading || _alertsError != null || _activeAlerts.isNotEmpty;

  Widget _buildAlertsSection(List<SystemRecord> systems) {
    if (_alertsLoading) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: const [
              SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
              SizedBox(width: 12),
              Text('Loading active alerts…'),
            ],
          ),
        ),
      );
    }
    if (_alertsError != null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Active Alerts', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text(_alertsError!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _loadActiveAlerts,
                  child: const Text('Retry'),
                ),
              ),
            ],
          ),
        ),
      );
    }
    if (_activeAlerts.isEmpty) {
      return const SizedBox.shrink();
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Active Alerts', style: TextStyle(fontWeight: FontWeight.w600)),
                TextButton(
                  onPressed: () => Navigator.of(context).pushNamed('/alerts'),
                  child: const Text('See all'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _activeAlerts.map((alert) => _AlertCard(alert: alert, systems: systems)).toList(),
            ),
          ],
        ),
      ),
    );
  }

  void _openSearchSortSheet() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search by name or host',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text('Sort by:'),
                  const SizedBox(width: 8),
                  PopupMenuButton<_SortBy>(
                    icon: const Icon(Icons.sort),
                    tooltip: 'Sort',
                    onSelected: (value) => setState(() => _sortBy = value),
                    itemBuilder: (context) => [
                      _menuItem(_SortBy.name, 'Name', Icons.sort_by_alpha),
                      _menuItem(_SortBy.status, 'Status', Icons.check_circle),
                      _menuItem(_SortBy.cpu, 'CPU', Icons.speed),
                      _menuItem(_SortBy.mem, 'Memory', Icons.memory),
                      _menuItem(_SortBy.disk, 'Disk', Icons.storage),
                    ],
                  ),
                  const SizedBox(width: 8),
                  FilledButton.tonalIcon(
                    onPressed: () => setState(() => _ascending = !_ascending),
                    icon: Icon(_ascending ? Icons.arrow_upward : Icons.arrow_downward),
                    label: Text(_ascending ? 'Ascending' : 'Descending'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: () {
                      _searchController.clear();
                      setState(() {});
                    },
                    icon: const Icon(Icons.clear),
                    label: const Text('Clear search'),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    icon: const Icon(Icons.check),
                    label: const Text('Done'),
                  ),
                ],
              ),
              const Divider(height: 24),
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('Logout'),
                onTap: () async {
                  Navigator.of(context).pop();
                  await _logout();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  PopupMenuItem<_SortBy> _menuItem(_SortBy value, String label, IconData icon) {
    return PopupMenuItem<_SortBy>(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 8),
          Text(label),
          const Spacer(),
          if (_sortBy == value) const Icon(Icons.check, size: 18),
        ],
      ),
    );
  }

  double _percent(dynamic value) {
    final doubleValue = _num(value).toDouble();
    if (!doubleValue.isFinite || doubleValue.isNaN) {
      return 0;
    }
    return doubleValue.clamp(0, 100).toDouble();
  }

  String _formatRate(double value) {
    final magnitude = value.abs();
    if (magnitude >= 1024) {
      return '${(magnitude / 1024).toStringAsFixed(1)} GB/s';
    }
    if (magnitude >= 1) {
      return '${magnitude.toStringAsFixed(1)} MB/s';
    }
    return '${(magnitude * 1024).toStringAsFixed(0)} KB/s';
  }

  Color _statusLabelTextColor(Color base) {
    return base.computeLuminance() > 0.45 ? Colors.black87 : Colors.white;
  }

  Color _statusColor(String status, BuildContext context) {
    switch (status) {
      case 'up':
        return Colors.green;
      case 'down':
        return Colors.red;
      case 'paused':
        return Colors.amber;
      case 'pending':
        return Theme.of(context).colorScheme.outline;
      default:
        return Theme.of(context).colorScheme.outline;
    }
  }

  int _statusRank(String status) {
    switch (status) {
      case 'up':
        return 0;
      case 'paused':
        return 1;
      case 'pending':
        return 2;
      case 'down':
        return 3;
      default:
        return 4;
    }
  }

  num _num(dynamic v) {
    if (v is num) return v;
    if (v is String) return num.tryParse(v) ?? 0;
    return 0;
  }
}

class _StatusPulse extends StatelessWidget {
  const _StatusPulse({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 16,
      width: 16,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.45),
            blurRadius: 16,
            spreadRadius: 2,
          ),
        ],
      ),
    );
  }
}

class _StatusLabel extends StatelessWidget {
  const _StatusLabel({
    required this.label,
    required this.background,
    required this.foreground,
    required this.borderColor,
  });

  final String label;
  final Color background;
  final Color foreground;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
      ),
    );
  }
}

class _MetricGauge extends StatelessWidget {
  const _MetricGauge({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final Color color;
  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final target = value.clamp(0, 100);
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 420),
      tween: Tween<double>(begin: 0, end: target.toDouble()),
      curve: Curves.easeOutCubic,
      builder: (context, animated, _) {
        final progress = (animated / 100).clamp(0.0, 1.0);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                Text(
                  '${animated.toStringAsFixed(0)}%',
                  style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                color: color,
                backgroundColor: color.withOpacity(0.18),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600, color: color),
          ),
          const SizedBox(width: 6),
          Text(
            value,
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}



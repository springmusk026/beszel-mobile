import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';

import '../models/system_record.dart';
import '../services/alerts_service.dart';
import '../services/system_stats_service.dart';
import '../services/systems_service.dart';

class HomeOverviewScreen extends StatefulWidget {
  const HomeOverviewScreen({super.key});

  @override
  State<HomeOverviewScreen> createState() => _HomeOverviewScreenState();
}

class _HomeOverviewScreenState extends State<HomeOverviewScreen> {
  final SystemsService _systemsService = SystemsService();
  final AlertsService _alertsService = AlertsService();
  final SystemStatsService _statsService = SystemStatsService();

  late Future<void> _future;
  List<SystemRecord> _systems = const <SystemRecord>[];
  List<RecordModel> _alerts = const <RecordModel>[];
  Map<String, Map<String, dynamic>> _latestStats = <String, Map<String, dynamic>>{};
  String? _error;

  @override
  void initState() {
    super.initState();
    _future = _loadInitial();
  }

  Future<Map<String, Map<String, dynamic>>> _fetchLatestStatsMap(List<SystemRecord> systems) async {
    if (systems.isEmpty) return <String, Map<String, dynamic>>{};
    final futures = systems.map((system) => _fetchLatestStatsForSystem(system.id)).toList();
    final results = await Future.wait(futures);
    final map = <String, Map<String, dynamic>>{};
    for (var i = 0; i < systems.length; i++) {
      final stats = results[i];
      if (stats != null && stats.isNotEmpty) {
        map[systems[i].id] = stats;
      }
    }
    return map;
  }

  Future<Map<String, dynamic>?> _fetchLatestStatsForSystem(String systemId) async {
    try {
      final record = await _statsService.fetchLatest(systemId);
      final stats = record?.data['stats'];
      if (stats is Map) {
        return Map<String, dynamic>.from(stats);
      }
    } catch (_) {
      // Ignore individual fetch issues; we'll rely on system info as a fallback.
    }
    return null;
  }

  @override
  void dispose() {
    _statsService.dispose();
    super.dispose();
  }

  Future<void> _loadInitial() async {
    try {
      final systems = await _systemsService.fetchAll();
      final alerts = await _alertsService.fetchActive();
      final stats = await _fetchLatestStatsMap(systems);
      if (!mounted) return;
      setState(() {
        _systems = systems;
        _alerts = alerts;
        _latestStats = stats;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load data: $e';
        _latestStats = <String, Map<String, dynamic>>{};
      });
    }
  }

  Future<void> _refresh() async {
    try {
      final systems = await _systemsService.fetchAll();
      final alerts = await _alertsService.fetchActive();
      final stats = await _fetchLatestStatsMap(systems);
      if (!mounted) return;
      setState(() {
        _systems = systems;
        _alerts = alerts;
        _latestStats = stats;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to refresh: $e';
        _latestStats = <String, Map<String, dynamic>>{};
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Welcome back',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            Text(
              'Quick snapshot of your fleet status.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => setState(() {
              _future = _refresh();
            }),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<void>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting && _systems.isEmpty && _alerts.isEmpty) {
              return ListView(
                physics: AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(height: 320, child: Center(child: CircularProgressIndicator())),
                ],
              );
            }
            if (_error != null && _systems.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  _ErrorBanner(
                    message: _error!,
                    onRetry: () {
                      setState(() {
                        _future = _loadInitial();
                      });
                    },
                  ),
                ],
              );
            }
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              children: [
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _ErrorBanner(
                      message: _error!,
                      onRetry: () {
                        setState(() {
                          _future = _refresh();
                        });
                      },
                    ),
                  ),
                _SummaryGrid(systems: _systems, alerts: _alerts),
                const SizedBox(height: 24),
                _FleetInsights(systems: _systems, stats: _latestStats),
                const SizedBox(height: 24),
                _ResourceSnapshot(systems: _systems),
                const SizedBox(height: 24),
                _TopSystemsSection(systems: _systems),
                const SizedBox(height: 24),
                _ActiveAlertsSection(alerts: _alerts, systems: _systems),
                const SizedBox(height: 32),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({required this.systems, required this.alerts});

  final List<SystemRecord> systems;
  final List<RecordModel> alerts;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = systems.length;
    final up = systems.where((s) => s.status == 'up').length;
    final down = systems.where((s) => s.status == 'down').length;
    final paused = systems.where((s) => s.status == 'paused').length;
    final pending = systems.where((s) => s.status == 'pending').length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 520;
        final crossAxisCount = isWide ? 4 : 2;
        return GridView.count(
          crossAxisCount: crossAxisCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: isWide ? 1.4 : 1.0,
          children: [
            _SummaryCard(
              label: 'Total Systems',
              value: total.toString(),
              icon: Icons.storage,
              color: theme.colorScheme.primary,
            ),
            _SummaryCard(
              label: 'Online',
              value: up.toString(),
              icon: Icons.check_circle,
              color: Colors.green,
              description: total > 0 ? '${((up / total) * 100).toStringAsFixed(0)}% healthy' : 'No systems',
            ),
            _SummaryCard(
              label: 'Alerts',
              value: alerts.length.toString(),
              icon: Icons.warning,
              color: Colors.orange,
              description: alerts.isEmpty ? 'All clear' : 'Needs attention',
            ),
            _SummaryCard(
              label: 'Unhealthy',
              value: (down + paused + pending).toString(),
              icon: Icons.error_outline,
              color: Colors.redAccent,
              description: '${down} down · ${paused} paused · ${pending} pending',
            ),
          ],
        );
      },
    );
  }
}

class _ResourceSnapshot extends StatelessWidget {
  const _ResourceSnapshot({required this.systems});

  final List<SystemRecord> systems;

  num _num(dynamic value) {
    if (value is num) return value;
    if (value is String) return num.tryParse(value) ?? 0;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    if (systems.isEmpty) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    final cpuAverage = systems.map((s) => _num(s.info['cpu'])).fold<num>(0, (a, b) => a + b) / systems.length;
    final memAverage = systems.map((s) => _num(s.info['mp'])).fold<num>(0, (a, b) => a + b) / systems.length;
    final diskAverage = systems.map((s) => _num(s.info['dp'])).fold<num>(0, (a, b) => a + b) / systems.length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.dashboard_customize_outlined),
                const SizedBox(width: 8),
                Text('Resource Snapshot', style: theme.textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 12,
              children: [
                _MetricChip(label: 'Avg CPU', value: '${cpuAverage.toStringAsFixed(1)}%'),
                _MetricChip(label: 'Avg Memory', value: '${memAverage.toStringAsFixed(1)}%'),
                _MetricChip(label: 'Avg Disk', value: '${diskAverage.toStringAsFixed(1)}%'),
                _MetricChip(label: 'Tracked systems', value: systems.length.toString()),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FleetInsights extends StatelessWidget {
  const _FleetInsights({required this.systems, required this.stats});

  final List<SystemRecord> systems;
  final Map<String, Map<String, dynamic>> stats;

  double _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }

  int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    if (systems.isEmpty) {
      return const SizedBox.shrink();
    }

    double totalIn = 0;
    double totalOut = 0;
    double totalDiskRead = 0;
    double totalDiskWrite = 0;
    int containersTotal = 0;
    int containersRunning = 0;

    bool hasInboundData = false;
    bool hasOutboundData = false;
    bool hasDiskReadData = false;
    bool hasDiskWriteData = false;
    bool hasContainerData = false;

    int inboundSystems = 0;
    int outboundSystems = 0;
    int diskReadSystems = 0;
    int diskWriteSystems = 0;
    int containerSystems = 0;

    for (final system in systems) {
      final statMap = stats[system.id];
      final info = system.info;

      final inboundValue = statMap?['nr'] ?? info['nr'] ?? info['net_in'];
      if (inboundValue != null) {
        hasInboundData = true;
        inboundSystems++;
        totalIn += _asDouble(inboundValue);
      }

      final outboundValue = statMap?['ns'] ?? info['ns'] ?? info['net_out'];
      if (outboundValue != null) {
        hasOutboundData = true;
        outboundSystems++;
        totalOut += _asDouble(outboundValue);
      }

      final diskReadValue = statMap?['dr'] ?? info['dr'] ?? info['disk_read'];
      if (diskReadValue != null) {
        hasDiskReadData = true;
        diskReadSystems++;
        totalDiskRead += _asDouble(diskReadValue);
      }

      final diskWriteValue = statMap?['dw'] ?? info['dw'] ?? info['disk_write'];
      if (diskWriteValue != null) {
        hasDiskWriteData = true;
        diskWriteSystems++;
        totalDiskWrite += _asDouble(diskWriteValue);
      }

      final dynamic containers = info['containers'] ?? info['container_count'] ?? info['containers_count'];
      if (containers != null) {
        hasContainerData = true;
        containerSystems++;
        if (containers is Map) {
          int totalForSystem = _asInt(containers['total'] ?? containers['all'] ?? containers['count']);
          int runningForSystem = _asInt(containers['running'] ?? containers['active'] ?? containers['up']);
          if (totalForSystem == 0 && containers['items'] is List) {
            final items = containers['items'] as List;
            totalForSystem = items.length;
            runningForSystem = items.where((item) {
              if (item is Map) {
                final status = item['status']?.toString().toLowerCase();
                return status == 'running' || status == 'online';
              }
              return false;
            }).length;
          }
          containersTotal += totalForSystem;
          containersRunning += runningForSystem;
        } else if (containers is List) {
          containersTotal += containers.length;
        } else {
          containersTotal += _asInt(containers);
        }
      }
    }

    String _formatRate(double value) {
      if (value >= 1024) {
        return '${(value / 1024).toStringAsFixed(1)} GB/s';
      }
      return '${value.toStringAsFixed(1)} MB/s';
    }

    final metrics = [
      _InsightMetric(
        icon: Icons.cloud_download_outlined,
        color: Colors.indigo,
        label: 'Inbound traffic',
        value: hasInboundData ? _formatRate(totalIn) : 'No data',
        caption: hasInboundData ? 'Across $inboundSystems systems' : 'Awaiting metrics',
      ),
      _InsightMetric(
        icon: Icons.cloud_upload_outlined,
        color: Colors.teal,
        label: 'Outbound traffic',
        value: hasOutboundData ? _formatRate(totalOut) : 'No data',
        caption: hasOutboundData ? 'Across $outboundSystems systems' : 'Awaiting metrics',
      ),
      _InsightMetric(
        icon: Icons.sd_card_outlined,
        color: Colors.deepOrange,
        label: 'Disk read',
        value: hasDiskReadData ? _formatRate(totalDiskRead) : 'No data',
        caption: hasDiskReadData ? 'Across $diskReadSystems systems' : 'Awaiting metrics',
      ),
      _InsightMetric(
        icon: Icons.save_alt_outlined,
        color: Colors.purple,
        label: 'Disk write',
        value: hasDiskWriteData ? _formatRate(totalDiskWrite) : 'No data',
        caption: hasDiskWriteData ? 'Across $diskWriteSystems systems' : 'Awaiting metrics',
      ),
      _InsightMetric(
        icon: Icons.dns_outlined,
        color: Colors.blueGrey,
        label: 'Containers',
        value: hasContainerData
            ? containersRunning > 0
                ? '$containersRunning running · $containersTotal total'
                : '$containersTotal total'
            : 'No data',
        caption: hasContainerData ? 'Reported by $containerSystems systems' : 'No container metrics yet',
      ),
    ];

    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.insights_outlined),
                const SizedBox(width: 8),
                Text('Fleet Activity', style: theme.textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final twoColumns = constraints.maxWidth > 560;
                final tileWidth = twoColumns ? (constraints.maxWidth - 12) / 2 : constraints.maxWidth;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: metrics
                      .map(
                        (metric) => SizedBox(
                          width: twoColumns ? tileWidth : constraints.maxWidth,
                          child: _InsightTile(metric: metric),
                        ),
                      )
                      .toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _InsightMetric {
  const _InsightMetric({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    this.caption,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final String? caption;
}

class _InsightTile extends StatelessWidget {
  const _InsightTile({required this.metric});

  final _InsightMetric metric;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: metric.color.withOpacity(0.08),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: metric.color.withOpacity(0.18),
                  shape: BoxShape.circle,
                ),
                padding: const EdgeInsets.all(8),
                child: Icon(metric.icon, color: metric.color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  metric.label,
                  style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            metric.value,
            style: textTheme.headlineSmall?.copyWith(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          if (metric.caption != null) ...[
            const SizedBox(height: 4),
            Text(
              metric.caption!,
              style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }
}

class _TopSystemsSection extends StatelessWidget {
  const _TopSystemsSection({required this.systems});

  final List<SystemRecord> systems;

  num _num(dynamic value) {
    if (value is num) return value;
    if (value is String) return num.tryParse(value) ?? 0;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    if (systems.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text('Top Systems'),
              SizedBox(height: 8),
              Text('No systems available yet.'),
            ],
          ),
        ),
      );
    }

    final sorted = List<SystemRecord>.from(systems)
      ..sort((a, b) => _num(b.info['cpu']).compareTo(_num(a.info['cpu'])));
    final top = sorted.take(3).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(Icons.star_outline),
                SizedBox(width: 8),
                Text(
                  'Top CPU Utilization',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...top.map((system) {
              final cpu = _num(system.info['cpu']).toStringAsFixed(1);
              final mem = _num(system.info['mp']).toStringAsFixed(1);
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  child: Text(system.name.isNotEmpty ? system.name[0].toUpperCase() : '?'),
                ),
                title: Text(system.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text('${system.host}:${system.port}'),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('CPU $cpu%', style: const TextStyle(fontWeight: FontWeight.w600)),
                    Text('MEM $mem%', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  ],
                ),
                onTap: () {
                  Navigator.of(context).pushNamed('/system', arguments: system);
                },
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _ActiveAlertsSection extends StatelessWidget {
  const _ActiveAlertsSection({required this.alerts, required this.systems});

  final List<RecordModel> alerts;
  final List<SystemRecord> systems;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: theme.colorScheme.error),
                const SizedBox(width: 8),
                Text('Active Alerts', style: theme.textTheme.titleMedium),
                const Spacer(),
                if (alerts.isNotEmpty)
                  TextButton(
                    onPressed: () => Navigator.of(context).pushNamed('/alerts'),
                    child: const Text('View all'),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (alerts.isEmpty)
              Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green.shade400),
                  const SizedBox(width: 8),
                  const Text('No active alerts.'),
                ],
              )
            else
              Column(
                children: alerts.take(4).map((alert) {
                  final systemName = _systemName(alert);
                  final updated = alert.data['updated']?.toString();
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.sensors, color: Colors.orange),
                    title: Text(alert.data['name']?.toString() ?? 'Alert'),
                    subtitle: Text(systemName ?? 'Unknown system'),
                    trailing: Text(updated != null ? _relativeTime(updated) : ''),
                    onTap: () {
                      final systemId = alert.data['system']?.toString();
                      if (systemId != null) {
                        final system = systems.firstWhere(
                          (s) => s.id == systemId,
                          orElse: () => SystemRecord(
                            id: systemId,
                            name: systemName ?? systemId,
                            host: '',
                            status: 'pending',
                            port: '',
                            info: const <String, dynamic>{},
                          ),
                        );
                        Navigator.of(context).pushNamed('/system', arguments: system);
                      }
                    },
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  String? _systemName(RecordModel alert) {
  final expanded = alert.expand?['system'];

  if (expanded case RecordModel systemRecord) {
    // Single related record
    return systemRecord.data['name']?.toString();
  }

  if (expanded case List<RecordModel> systemRecords) {
    // Multiple related records
    return systemRecords.first.data['name']?.toString();
  }

  // Fallback: just return the raw system field
  return alert.data['system']?.toString();
}

  String _relativeTime(String isoString) {
    try {
      final dt = DateTime.parse(isoString).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
      if (diff.inHours < 24) return '${diff.inHours} h ago';
      return '${diff.inDays} d ago';
    } catch (_) {
      return '';
    }
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.description,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String? description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: color.withOpacity(.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.all(8),
                  child: Icon(icon, color: color),
                ),
                const Spacer(),
                Text(
                  value,
                  style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(label, style: theme.textTheme.bodyLarge),
            if (description != null) ...[
              const SizedBox(height: 4),
              Text(
                description!,
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: RichText(
        text: TextSpan(
          style: Theme.of(context).textTheme.bodyMedium,
          children: [
            TextSpan(text: '$label: ', style: const TextStyle(fontWeight: FontWeight.w600)),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: theme.colorScheme.onErrorContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: theme.colorScheme.onErrorContainer),
              ),
            ),
            TextButton(
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}



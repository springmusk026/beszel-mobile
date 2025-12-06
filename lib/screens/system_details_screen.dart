import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';

import '../api/pb_client.dart';
import '../models/system_record.dart';
import '../services/settings_service.dart' as app_settings;
import '../services/system_stats_service.dart';
import '../widgets/system_charts.dart';

class SystemDetailsScreen extends StatefulWidget {
  const SystemDetailsScreen({super.key, required this.system});

  final SystemRecord system;

  @override
  State<SystemDetailsScreen> createState() => _SystemDetailsScreenState();
}

class _SystemDetailsScreenState extends State<SystemDetailsScreen> {
  final _statsSvc = SystemStatsService();
  final _settingsSvc = app_settings.SettingsService();
  StreamSubscription<RecordModel?>? _statsSub;
  Future<RecordModel?>? _future;
  RecordModel? _latest;
  List<RecordModel> _chartRecords = const [];
  bool _chartsLoading = true;
  String? _chartsError;
  String _chartTime = '1h';

  @override
  void initState() {
    super.initState();
    _future = _fetchLatestStats(widget.system.id);
    _statsSvc.subscribeToSystem(widget.system.id);
    _statsSub = _statsSvc.stream.listen((rec) {
      if (!mounted || rec == null) return;
      setState(() {
        _latest = rec;
        _chartRecords = _updateChartRecords(_chartRecords, rec, _chartTime);
      });
    });
    _loadCharts();
  }

  Future<RecordModel?> _fetchLatestStats(String systemId) async {
    final svc = pb.collection('system_stats');
    final res = await svc.getList(
      page: 1,
      perPage: 1,
      filter: 'system="$systemId"',
      sort: '-created',
      fields: 'stats,created',
    );
    if (res.items.isEmpty) return null;
    return res.items.first;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.system.name),
        actions: [
          IconButton(
            onPressed: () => Navigator.of(context).pushNamed('/containers', arguments: widget.system),
            icon: const Icon(Icons.dns),
            tooltip: 'Containers',
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pushNamed('/systemd', arguments: widget.system),
            icon: const Icon(Icons.settings_applications),
            tooltip: 'systemd',
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pushNamed('/system-alerts', arguments: widget.system),
            icon: const Icon(Icons.notifications_active),
            tooltip: 'Alerts history',
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pushNamed('/manage-alerts', arguments: widget.system),
            icon: const Icon(Icons.settings),
            tooltip: 'Manage alerts',
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pushNamed('/system-smart', arguments: widget.system),
            icon: const Icon(Icons.sd_storage),
            tooltip: 'S.M.A.R.T.',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() {
            _future = _fetchLatestStats(widget.system.id);
          });
          await _future;
          await _loadCharts();
        },
        child: FutureBuilder<RecordModel?>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting && _latest == null) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError && _latest == null) {
              return const Center(child: Text('Failed to load stats'));
            }
            final record = _latest ?? snapshot.data;
            final stats = (record?.data['stats'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
            final created = record?.data['created']?.toString();
            final theme = Theme.of(context);
            final statusColor = _statusColor(widget.system.status, context);
            final statusOnColor = _statusOnColor(statusColor);
            final cpuPercent = _percent(stats['cpu']);
            final memPercent = _percent(stats['mp']);
            final diskPercent = _percent(stats['dp']);
            final swapPercent = _percent(stats['sp'] ?? stats['swap']);

            final loadAverage = _formatLoad(stats);
            final uptime = stats['uptime_human']?.toString() ?? _formatDuration(stats['uptime'] ?? stats['uptime_seconds']);
            final temp = stats['temp'] ?? stats['temperature'];
            final gpuTemp = stats['gpu_temp'] ?? stats['gpuTemperature'];
            final battery = stats['battery'] ?? stats['battery_percent'];

            final netSent = _num(stats['ns']).toDouble();
            final netRecv = _num(stats['nr']).toDouble();
            final diskRead = _num(stats['dr']).toDouble();
            final diskWrite = _num(stats['dw']).toDouble();
            final memUsed = _formatBytes(stats['mu'] ?? stats['memory_used']);
            final memTotal = _formatBytes(stats['mt'] ?? stats['memory_total']);
            final swapUsed = _formatBytes(stats['su'] ?? stats['swap_used']);
            final swapTotal = _formatBytes(stats['st'] ?? stats['swap_total']);

            final infoPills = <Widget>[];
            if (loadAverage != '—') {
              infoPills.add(_InfoPill(icon: Icons.timeline, label: 'Load 1/5/15', value: loadAverage, color: Colors.indigo));
            }
            if (uptime != null) {
              infoPills.add(_InfoPill(icon: Icons.schedule_outlined, label: 'Uptime', value: uptime, color: Colors.blueGrey));
            }
            if (temp != null) {
              infoPills.add(_InfoPill(icon: Icons.thermostat, label: 'CPU temp', value: '${temp.toString()}°C', color: Colors.deepOrange));
            }
            if (gpuTemp != null) {
              infoPills.add(_InfoPill(icon: Icons.memory_outlined, label: 'GPU temp', value: '${gpuTemp.toString()}°C', color: Colors.purple));
            }
            if (battery != null) {
              infoPills.add(_InfoPill(icon: Icons.battery_charging_full, label: 'Battery', value: '${_percent(battery).toStringAsFixed(0)}%', color: Colors.teal));
            }

            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                _OverviewHeader(
                  system: widget.system,
                  statusColor: statusColor,
                  statusTextColor: statusOnColor,
                  agentVersion: widget.system.version,
                  group: widget.system.info['group']?.toString(),
                  lastUpdated: created,
                  uptime: uptime,
                  memorySummary: memTotal != null && memUsed != null ? '$memUsed / $memTotal used' : null,
                ),
                const SizedBox(height: 16),
                if (stats.isNotEmpty) ...[
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.monitor_heart, color: theme.colorScheme.primary),
                              const SizedBox(width: 8),
                              Text('Performance', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Wrap(
                            spacing: 20,
                            runSpacing: 20,
                            children: [
                              _MetricGauge(icon: Icons.speed, color: Colors.deepOrangeAccent, label: 'CPU usage', value: cpuPercent),
                              _MetricGauge(icon: Icons.memory, color: Colors.blueAccent, label: 'Memory usage', value: memPercent),
                              _MetricGauge(icon: Icons.storage, color: Colors.teal, label: 'Disk usage', value: diskPercent),
                              if (swapPercent > 0)
                                _MetricGauge(icon: Icons.swap_vert, color: Colors.purpleAccent, label: 'Swap usage', value: swapPercent),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 16,
                            runSpacing: 12,
                            children: [
                              if (memTotal != null && memUsed != null)
                                _MiniStat(label: 'Memory', value: '$memUsed / $memTotal', icon: Icons.memory, color: Colors.blueAccent),
                              if (swapTotal != null && swapUsed != null)
                                _MiniStat(label: 'Swap', value: '$swapUsed / $swapTotal', icon: Icons.swap_horiz, color: Colors.purpleAccent),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.sync_alt, color: theme.colorScheme.secondary),
                              const SizedBox(width: 8),
                              Text('Throughput', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              _InfoPill(icon: Icons.cloud_upload_outlined, label: 'Network sent', value: _formatRate(netSent), color: Colors.teal),
                              _InfoPill(icon: Icons.cloud_download_outlined, label: 'Network recv', value: _formatRate(netRecv), color: Colors.indigo),
                              _InfoPill(icon: Icons.sd_card_outlined, label: 'Disk read', value: _formatRate(diskRead), color: Colors.deepOrange),
                              _InfoPill(icon: Icons.save_alt_outlined, label: 'Disk write', value: _formatRate(diskWrite), color: Colors.purple),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (infoPills.isNotEmpty)
                    Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.insights_outlined, color: theme.colorScheme.tertiary),
                                const SizedBox(width: 8),
                                Text('Environment', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                              ],
                            ),
                            const SizedBox(height: 20),
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: infoPills,
                            ),
                          ],
                        ),
                      ),
                    ),
                ] else ...[
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('No live metrics yet', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 8),
                          Text(
                            'We have not received any telemetry for this system. Data will appear here as soon as the agent sends stats.',
                            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Chart Time', style: TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 12),
                        SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(value: '1m', label: Text('1m')),
                            ButtonSegment(value: '1h', label: Text('1h')),
                            ButtonSegment(value: '12h', label: Text('12h')),
                            ButtonSegment(value: '24h', label: Text('24h')),
                            ButtonSegment(value: '1w', label: Text('1w')),
                            ButtonSegment(value: '30d', label: Text('30d')),
                          ],
                          selected: {_chartTime},
                          onSelectionChanged: (Set<String> selection) async {
                            final newTime = selection.first;
                            setState(() => _chartTime = newTime);
                            await _settingsSvc.update((await _settingsSvc.fetchOrCreate()).copyWith(chartTime: newTime));
                            await _loadCharts();
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                SystemCharts(
                  records: _chartRecords,
                  loading: _chartsLoading,
                  error: _chartsError,
                  onRetry: () => _loadCharts(),
                  chartTime: _chartTime,
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _loadCharts() async {
    setState(() {
      _chartsLoading = true;
      _chartsError = null;
    });
    try {
      final settings = await _settingsSvc.fetchOrCreate();
      final records = await _statsSvc.fetchSeries(widget.system.id, settings.chartTime);
      if (!mounted) return;
      setState(() {
        _chartTime = settings.chartTime;
        _chartRecords = records;
        _chartsLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _chartsError = 'Failed to load charts';
        _chartsLoading = false;
      });
    }
  }

  String _formatLoad(Map<String, dynamic> s) {
    final la = s['la'];
    if (la is List && la.length == 3) {
      return '${la[0]}/${la[1]}/${la[2]}';
    }
    final l1 = s['l1'];
    final l5 = s['l5'];
    final l15 = s['l15'];
    if (l1 != null && l5 != null && l15 != null) {
      return '$l1/$l5/$l15';
    }
    return '—';
  }

  Color _statusColor(String status, BuildContext context) {
    switch (status) {
      case 'up':
        return Colors.green;
      case 'down':
        return Colors.redAccent;
      case 'paused':
        return Colors.amber;
      case 'pending':
        return Theme.of(context).colorScheme.outline;
      default:
        return Theme.of(context).colorScheme.outline;
    }
  }

  Color _statusOnColor(Color color) => color.computeLuminance() > 0.45 ? Colors.black87 : Colors.white;

  double _percent(dynamic value) {
    final numValue = _num(value);
    if (numValue == 0) return 0;
    final percent = numValue.toDouble();
    if (!percent.isFinite) return 0;
    return percent.clamp(0, 100);
  }

  num _num(dynamic value) {
    if (value is num) return value;
    if (value is String) {
      return num.tryParse(value.replaceAll('%', '').trim()) ?? 0;
    }
    return 0;
  }

  String _formatRate(double value) {
    final magnitude = value.abs();
    if (magnitude >= 1024) {
      return '${(value / 1024).toStringAsFixed(1)} GB/s';
    }
    if (magnitude >= 1) {
      return '${value.toStringAsFixed(1)} MB/s';
    }
    return '${(value * 1024).toStringAsFixed(0)} KB/s';
  }

  String? _formatBytes(dynamic raw) {
    if (raw == null) return null;
    if (raw is String && raw.trim().isNotEmpty && double.tryParse(raw) == null) {
      return raw;
    }
    final bytes = _num(raw).toDouble();
    if (bytes <= 0) return null;
    const units = ['B', 'KB', 'MB', 'GB', 'TB', 'PB'];
    var value = bytes;
    var unitIndex = 0;
    while (value >= 1024 && unitIndex < units.length - 1) {
      value /= 1024;
      unitIndex++;
    }
    final decimals = value >= 100 ? 0 : 1;
    return '${value.toStringAsFixed(decimals)} ${units[unitIndex]}';
  }

  String? _formatDuration(dynamic value) {
    if (value == null) return null;
    if (value is String && value.trim().isNotEmpty) {
      return value;
    }
    final seconds = _num(value).toInt();
    if (seconds <= 0) return null;
    final duration = Duration(seconds: seconds);
    final parts = <String>[];
    final days = duration.inDays;
    final hours = duration.inHours.remainder(24);
    final minutes = duration.inMinutes.remainder(60);
    final secs = duration.inSeconds.remainder(60);
    if (days > 0) parts.add('${days}d');
    if (hours > 0) parts.add('${hours}h');
    if (minutes > 0) parts.add('${minutes}m');
    if (parts.isEmpty) parts.add('${secs}s');
    return parts.join(' ');
  }

  List<RecordModel> _updateChartRecords(List<RecordModel> current, RecordModel record, String chartTime) {
    final list = List<RecordModel>.from(current);
    final idx = list.indexWhere((r) => r.id == record.id);
    if (idx >= 0) {
      list[idx] = record;
    } else {
      list.add(record);
    }
    list.sort((a, b) {
      final aCreated = a.data['created']?.toString();
      final bCreated = b.data['created']?.toString();
      if (aCreated == null || bCreated == null) return 0;
      try {
        return DateTime.parse(aCreated).compareTo(DateTime.parse(bCreated));
      } catch (_) {
        return 0;
      }
    });
    final duration = _durationForChartTime(chartTime);
    if (duration != null) {
      final cutoff = DateTime.now().toUtc().subtract(duration);
      list.removeWhere((r) {
        final createdRaw = r.data['created']?.toString();
        if (createdRaw == null) return false;
        try {
          final created = DateTime.parse(createdRaw).toUtc();
          return created.isBefore(cutoff);
        } catch (_) {
          return false;
        }
      });
    }
    return list;
  }

  Duration? _durationForChartTime(String chartTime) {
    switch (chartTime) {
      case '1m':
        return const Duration(minutes: 1);
      case '1h':
        return const Duration(hours: 1);
      case '12h':
        return const Duration(hours: 12);
      case '24h':
        return const Duration(hours: 24);
      case '1w':
        return const Duration(days: 7);
      case '30d':
        return const Duration(days: 30);
    }
    return null;
  }

  @override
  void dispose() {
    _statsSub?.cancel();
    _statsSvc.dispose();
    super.dispose();
  }
}

class _OverviewHeader extends StatelessWidget {
  const _OverviewHeader({
    required this.system,
    required this.statusColor,
    required this.statusTextColor,
    this.agentVersion,
    this.group,
    this.lastUpdated,
    this.uptime,
    this.memorySummary,
  });

  final SystemRecord system;
  final Color statusColor;
  final Color statusTextColor;
  final String? agentVersion;
  final String? group;
  final String? lastUpdated;
  final String? uptime;
  final String? memorySummary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              statusColor.withOpacity(0.18),
              theme.colorScheme.surfaceVariant.withOpacity(0.06),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        system.name,
                        style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.public, size: 18),
                          const SizedBox(width: 6),
                          Text('${system.host}:${system.port}', style: theme.textTheme.bodyMedium),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: statusColor.withOpacity(0.5)),
                  ),
                  child: Text(
                    system.status.toUpperCase(),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: statusTextColor,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 18,
              runSpacing: 12,
              children: [
                if (agentVersion != null && agentVersion!.isNotEmpty)
                  _InfoRow(icon: Icons.router, label: 'Agent', value: agentVersion!),
                if (lastUpdated != null) _InfoRow(icon: Icons.update, label: 'Last update', value: lastUpdated!),
                if (uptime != null) _InfoRow(icon: Icons.schedule, label: 'Uptime', value: uptime!),
                if (group != null && group!.isNotEmpty)
                  _InfoRow(icon: Icons.location_on_outlined, label: 'Group', value: group!),
                if (memorySummary != null) _InfoRow(icon: Icons.memory, label: 'Memory', value: memorySummary!),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 160),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Text('$label: ', style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
          Flexible(
            child: Text(
              value,
              style: theme.textTheme.bodySmall,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
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
    final clamped = value.clamp(0, 100);
    return SizedBox(
      width: 200,
      child: TweenAnimationBuilder<double>(
        duration: const Duration(milliseconds: 420),
        tween: Tween<double>(begin: 0, end: clamped.toDouble()),
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
                    style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
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
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600, color: color)),
              Text(value, style: theme.textTheme.bodySmall),
            ],
          ),
        ],
      ),
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600, color: color)),
              Text(value, style: theme.textTheme.bodySmall),
            ],
          ),
        ],
      ),
    );
  }
}

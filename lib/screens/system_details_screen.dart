import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';

import '../api/pb_client.dart';
import '../models/system_record.dart';
import '../services/settings_service.dart' as app_settings;
import '../services/system_stats_service.dart';
import '../widgets/system_charts.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_radius.dart';
import '../animations/app_durations.dart';
import '../animations/app_curves.dart';
import '../widgets/skeleton_loader.dart';

class SystemDetailsScreen extends StatefulWidget {
  const SystemDetailsScreen({super.key, required this.system});

  final SystemRecord system;

  @override
  State<SystemDetailsScreen> createState() => _SystemDetailsScreenState();
}

class _SystemDetailsScreenState extends State<SystemDetailsScreen>
    with SingleTickerProviderStateMixin {
  final _statsSvc = SystemStatsService();
  final _settingsSvc = app_settings.SettingsService();
  StreamSubscription<RecordModel?>? _statsSub;
  Future<RecordModel?>? _future;
  RecordModel? _latest;
  List<RecordModel> _chartRecords = const [];
  bool _chartsLoading = true;
  bool _initialLoading = true;
  String? _chartsError;
  String _chartTime = '1h';

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: AppDurations.medium,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: AppCurves.enter,
    );

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
    if (!mounted) return null;
    setState(() => _initialLoading = false);
    _fadeController.forward();
    if (res.items.isEmpty) return null;
    return res.items.first;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          _buildSliverAppBar(context, innerBoxIsScrolled),
        ],
        body: RefreshIndicator(
          onRefresh: _handleRefresh,
          color: colorScheme.primary,
          child: _buildBody(context),
        ),
      ),
    );
  }

  Widget _buildSliverAppBar(BuildContext context, bool innerBoxIsScrolled) {
    final theme = Theme.of(context);
    final statusColor = AppColors.getStatusColor(widget.system.status);

    return SliverAppBar(
      expandedHeight: 140,
      floating: false,
      pinned: true,
      elevation: innerBoxIsScrolled ? 2 : 0,
      backgroundColor: theme.colorScheme.surface,
      foregroundColor: theme.colorScheme.onSurface,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.only(left: 56, bottom: 16, right: 16),
        title: Text(
          widget.system.name,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                statusColor.withValues(alpha: 0.15),
                theme.colorScheme.surface,
              ],
            ),
          ),
        ),
      ),
      actions: _buildAppBarActions(context),
    );
  }

  List<Widget> _buildAppBarActions(BuildContext context) {
    return [
      _ActionButton(
        icon: Icons.dns_outlined,
        tooltip: 'Containers',
        onPressed: () => Navigator.of(context).pushNamed('/containers', arguments: widget.system),
      ),
      _ActionButton(
        icon: Icons.settings_applications_outlined,
        tooltip: 'systemd',
        onPressed: () => Navigator.of(context).pushNamed('/systemd', arguments: widget.system),
      ),
      _ActionButton(
        icon: Icons.notifications_outlined,
        tooltip: 'Alerts',
        onPressed: () => Navigator.of(context).pushNamed('/system-alerts', arguments: widget.system),
      ),
      PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert),
        tooltip: 'More options',
        onSelected: (value) {
          switch (value) {
            case 'manage-alerts':
              Navigator.of(context).pushNamed('/manage-alerts', arguments: widget.system);
              break;
            case 'smart':
              Navigator.of(context).pushNamed('/system-smart', arguments: widget.system);
              break;
          }
        },
        itemBuilder: (context) => [
          const PopupMenuItem(value: 'manage-alerts', child: Text('Manage Alerts')),
          const PopupMenuItem(value: 'smart', child: Text('S.M.A.R.T.')),
        ],
      ),
    ];
  }

  Widget _buildBody(BuildContext context) {
    return FutureBuilder<RecordModel?>(
      future: _future,
      builder: (context, snapshot) {
        if (_initialLoading) {
          return _buildLoadingSkeleton(context);
        }

        if (snapshot.hasError && _latest == null) {
          return _buildErrorState(context);
        }

        final record = _latest ?? snapshot.data;
        final stats = (record?.data['stats'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
        final created = record?.data['created']?.toString();

        return FadeTransition(
          opacity: _fadeAnimation,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.all(AppSpacing.lg),
            children: [
              _buildStatusHeader(context, created),
              SizedBox(height: AppSpacing.lg),
              if (stats.isNotEmpty) ...[
                _buildPerformanceSection(context, stats),
                SizedBox(height: AppSpacing.lg),
                _buildThroughputSection(context, stats),
                SizedBox(height: AppSpacing.lg),
                _buildEnvironmentSection(context, stats),
              ] else
                _buildNoDataCard(context),
              SizedBox(height: AppSpacing.xl),
              _buildChartTimeSelector(context),
              SizedBox(height: AppSpacing.lg),
              SystemCharts(
                records: _chartRecords,
                loading: _chartsLoading,
                error: _chartsError,
                onRetry: () => _loadCharts(),
                chartTime: _chartTime,
              ),
              SizedBox(height: AppSpacing.xxl),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLoadingSkeleton(BuildContext context) {
    return ListView(
      padding: EdgeInsets.all(AppSpacing.lg),
      children: [
        // Status header skeleton
        Card(
          shape: RoundedRectangleBorder(borderRadius: AppRadius.largeBorderRadius),
          child: Padding(
            padding: EdgeInsets.all(AppSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const SkeletonLoader(width: 120, height: 24),
                    const Spacer(),
                    SkeletonLoader(width: 80, height: 28, borderRadius: AppRadius.circular),
                  ],
                ),
                SizedBox(height: AppSpacing.lg),
                const SkeletonLoader(width: 200, height: 16),
                SizedBox(height: AppSpacing.md),
                const SkeletonLoader(width: 160, height: 14),
              ],
            ),
          ),
        ),
        SizedBox(height: AppSpacing.lg),
        // Performance section skeleton
        Card(
          shape: RoundedRectangleBorder(borderRadius: AppRadius.largeBorderRadius),
          child: Padding(
            padding: EdgeInsets.all(AppSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SkeletonLoader(width: 140, height: 20),
                SizedBox(height: AppSpacing.xl),
                Wrap(
                  spacing: AppSpacing.lg,
                  runSpacing: AppSpacing.lg,
                  children: List.generate(4, (_) => const _MetricGaugeSkeleton()),
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: AppSpacing.lg),
        // Throughput section skeleton
        Card(
          shape: RoundedRectangleBorder(borderRadius: AppRadius.largeBorderRadius),
          child: Padding(
            padding: EdgeInsets.all(AppSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SkeletonLoader(width: 120, height: 20),
                SizedBox(height: AppSpacing.xl),
                Wrap(
                  spacing: AppSpacing.md,
                  runSpacing: AppSpacing.md,
                  children: List.generate(4, (_) => const SkeletonLoader(width: 150, height: 56, borderRadius: AppRadius.medium)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorState(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.errorLight,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.error_outline, size: 48, color: AppColors.error),
            ),
            SizedBox(height: AppSpacing.lg),
            Text('Failed to load stats', style: theme.textTheme.titleMedium),
            SizedBox(height: AppSpacing.sm),
            Text(
              'Pull down to refresh',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusHeader(BuildContext context, String? lastUpdated) {
    final theme = Theme.of(context);
    final statusColor = AppColors.getStatusColor(widget.system.status);
    final uptime = _latest != null
        ? _formatDuration((_latest!.data['stats'] as Map?)?['uptime'] ?? (_latest!.data['stats'] as Map?)?['uptime_seconds'])
        : null;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.largeBorderRadius),
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.xl),
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
                      Row(
                        children: [
                          Icon(Icons.dns, size: 20, color: theme.colorScheme.primary),
                          SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              '${widget.system.host}:${widget.system.port}',
                              style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      if (widget.system.info['group'] != null) ...[
                        SizedBox(height: AppSpacing.sm),
                        Row(
                          children: [
                            Icon(Icons.folder_outlined, size: 16, color: theme.colorScheme.onSurfaceVariant),
                            SizedBox(width: AppSpacing.xs),
                            Text(
                              widget.system.info['group'].toString(),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                _StatusBadge(status: widget.system.status, color: statusColor),
              ],
            ),
            SizedBox(height: AppSpacing.lg),
            Divider(height: 1, color: theme.colorScheme.outlineVariant),
            SizedBox(height: AppSpacing.lg),
            Wrap(
              spacing: AppSpacing.xl,
              runSpacing: AppSpacing.md,
              children: [
                if (widget.system.version != null && widget.system.version!.isNotEmpty)
                  _QuickInfo(icon: Icons.memory, label: 'Agent', value: widget.system.version!),
                if (uptime != null)
                  _QuickInfo(icon: Icons.schedule_outlined, label: 'Uptime', value: uptime),
                if (lastUpdated != null)
                  _QuickInfo(icon: Icons.update, label: 'Updated', value: _formatTimestamp(lastUpdated)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPerformanceSection(BuildContext context, Map<String, dynamic> stats) {
    final theme = Theme.of(context);
    final cpuPercent = _percent(stats['cpu']);
    final memPercent = _percent(stats['mp']);
    final diskPercent = _percent(stats['dp']);
    final swapPercent = _percent(stats['sp'] ?? stats['swap']);
    final memUsed = _formatBytes(stats['mu'] ?? stats['memory_used']);
    final memTotal = _formatBytes(stats['mt'] ?? stats['memory_total']);
    final swapUsed = _formatBytes(stats['su'] ?? stats['swap_used']);
    final swapTotal = _formatBytes(stats['st'] ?? stats['swap_total']);

    return _SectionCard(
      icon: Icons.speed_outlined,
      title: 'Performance',
      iconColor: theme.colorScheme.primary,
      child: Column(
        children: [
          // Main gauges in a responsive grid
          LayoutBuilder(
            builder: (context, constraints) {
              final crossAxisCount = constraints.maxWidth > 500 ? 4 : 2;
              return GridView.count(
                crossAxisCount: crossAxisCount,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: AppSpacing.lg,
                crossAxisSpacing: AppSpacing.lg,
                childAspectRatio: 1.3,
                children: [
                  _CircularGauge(
                    value: cpuPercent,
                    label: 'CPU',
                    color: _getGaugeColor(cpuPercent),
                    icon: Icons.memory,
                  ),
                  _CircularGauge(
                    value: memPercent,
                    label: 'Memory',
                    color: _getGaugeColor(memPercent),
                    icon: Icons.storage,
                    subtitle: memUsed != null && memTotal != null ? '$memUsed / $memTotal' : null,
                  ),
                  _CircularGauge(
                    value: diskPercent,
                    label: 'Disk',
                    color: _getGaugeColor(diskPercent),
                    icon: Icons.sd_storage,
                  ),
                  if (swapPercent > 0)
                    _CircularGauge(
                      value: swapPercent,
                      label: 'Swap',
                      color: _getGaugeColor(swapPercent),
                      icon: Icons.swap_vert,
                      subtitle: swapUsed != null && swapTotal != null ? '$swapUsed / $swapTotal' : null,
                    )
                  else
                    const SizedBox.shrink(),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildThroughputSection(BuildContext context, Map<String, dynamic> stats) {
    final theme = Theme.of(context);
    final netSent = _num(stats['ns']).toDouble();
    final netRecv = _num(stats['nr']).toDouble();
    final diskRead = _num(stats['dr']).toDouble();
    final diskWrite = _num(stats['dw']).toDouble();

    return _SectionCard(
      icon: Icons.swap_horiz,
      title: 'Throughput',
      iconColor: theme.colorScheme.secondary,
      child: Row(
        children: [
          Expanded(
            child: Column(
              children: [
                _ThroughputTile(
                  icon: Icons.arrow_upward,
                  label: 'Network Out',
                  value: _formatRate(netSent),
                  color: AppColors.success,
                ),
                SizedBox(height: AppSpacing.md),
                _ThroughputTile(
                  icon: Icons.arrow_downward,
                  label: 'Network In',
                  value: _formatRate(netRecv),
                  color: theme.colorScheme.primary,
                ),
              ],
            ),
          ),
          SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              children: [
                _ThroughputTile(
                  icon: Icons.upload_file,
                  label: 'Disk Read',
                  value: _formatRate(diskRead),
                  color: AppColors.warning,
                ),
                SizedBox(height: AppSpacing.md),
                _ThroughputTile(
                  icon: Icons.download,
                  label: 'Disk Write',
                  value: _formatRate(diskWrite),
                  color: Colors.purple,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnvironmentSection(BuildContext context, Map<String, dynamic> stats) {
    final theme = Theme.of(context);
    final loadAverage = _formatLoad(stats);
    final temp = stats['temp'] ?? stats['temperature'];
    final gpuTemp = stats['gpu_temp'] ?? stats['gpuTemperature'];
    final battery = stats['battery'] ?? stats['battery_percent'];

    final items = <Widget>[];
    if (loadAverage != '—') {
      items.add(_EnvironmentChip(icon: Icons.timeline, label: 'Load', value: loadAverage));
    }
    if (temp != null) {
      items.add(_EnvironmentChip(icon: Icons.thermostat, label: 'CPU Temp', value: '$temp°C', color: _getTempColor(temp)));
    }
    if (gpuTemp != null) {
      items.add(_EnvironmentChip(icon: Icons.videocam, label: 'GPU Temp', value: '$gpuTemp°C', color: _getTempColor(gpuTemp)));
    }
    if (battery != null) {
      items.add(_EnvironmentChip(icon: Icons.battery_std, label: 'Battery', value: '${_percent(battery).toStringAsFixed(0)}%'));
    }

    if (items.isEmpty) return const SizedBox.shrink();

    return _SectionCard(
      icon: Icons.eco_outlined,
      title: 'Environment',
      iconColor: theme.colorScheme.tertiary,
      child: Wrap(
        spacing: AppSpacing.md,
        runSpacing: AppSpacing.md,
        children: items,
      ),
    );
  }

  Widget _buildNoDataCard(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.largeBorderRadius),
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          children: [
            Icon(Icons.hourglass_empty, size: 48, color: theme.colorScheme.onSurfaceVariant),
            SizedBox(height: AppSpacing.lg),
            Text('No metrics yet', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
            SizedBox(height: AppSpacing.sm),
            Text(
              'Data will appear here once the agent sends stats.',
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartTimeSelector(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.largeBorderRadius),
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.access_time, size: 18, color: theme.colorScheme.primary),
                SizedBox(width: AppSpacing.sm),
                Text('Time Range', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
              ],
            ),
            SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<String>(
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
            ),
          ],
        ),
      ),
    );
  }

  // Helper methods
  Future<void> _handleRefresh() async {
    setState(() {
      _future = _fetchLatestStats(widget.system.id);
    });
    await _future;
    await _loadCharts();
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

  Color _getGaugeColor(double value) {
    if (value >= 90) return AppColors.error;
    if (value >= 70) return AppColors.warning;
    return AppColors.success;
  }

  Color _getTempColor(dynamic temp) {
    final t = _num(temp).toDouble();
    if (t >= 80) return AppColors.error;
    if (t >= 60) return AppColors.warning;
    return AppColors.success;
  }

  String _formatLoad(Map<String, dynamic> s) {
    final la = s['la'];
    if (la is List && la.length == 3) {
      return '${la[0]} / ${la[1]} / ${la[2]}';
    }
    final l1 = s['l1'];
    final l5 = s['l5'];
    final l15 = s['l15'];
    if (l1 != null && l5 != null && l15 != null) {
      return '$l1 / $l5 / $l15';
    }
    return '—';
  }

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

  String _formatTimestamp(String timestamp) {
    try {
      final dt = DateTime.parse(timestamp);
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inSeconds < 60) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      return '${diff.inDays}d ago';
    } catch (_) {
      return timestamp;
    }
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
    _fadeController.dispose();
    _statsSub?.cancel();
    _statsSvc.dispose();
    super.dispose();
  }
}

// ============================================================================
// Supporting Widgets
// ============================================================================

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon),
      tooltip: tooltip,
      onPressed: onPressed,
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status, required this.color});

  final String status;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = color.computeLuminance() > 0.5 ? Colors.black87 : Colors.white;

    return AnimatedContainer(
      duration: AppDurations.medium,
      curve: AppCurves.standard,
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: AppRadius.circularBorderRadius,
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: AppSpacing.sm),
          Text(
            status.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: textColor,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickInfo extends StatelessWidget {
  const _QuickInfo({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
        SizedBox(width: AppSpacing.xs),
        Text(
          '$label: ',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        Text(
          value,
          style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.icon,
    required this.title,
    required this.iconColor,
    required this.child,
  });

  final IconData icon;
  final String title;
  final Color iconColor;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.largeBorderRadius),
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.1),
                    borderRadius: AppRadius.smallBorderRadius,
                  ),
                  child: Icon(icon, size: 20, color: iconColor),
                ),
                SizedBox(width: AppSpacing.md),
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            SizedBox(height: AppSpacing.xl),
            child,
          ],
        ),
      ),
    );
  }
}

class _CircularGauge extends StatelessWidget {
  const _CircularGauge({
    required this.value,
    required this.label,
    required this.color,
    required this.icon,
    this.subtitle,
  });

  final double value;
  final String label;
  final Color color;
  final IconData icon;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final clamped = value.clamp(0.0, 100.0);

    return TweenAnimationBuilder<double>(
      duration: AppDurations.metricGauge,
      tween: Tween<double>(begin: 0, end: clamped),
      curve: AppCurves.enter,
      builder: (context, animated, _) {
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 72,
              height: 72,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 72,
                    height: 72,
                    child: CircularProgressIndicator(
                      value: animated / 100,
                      strokeWidth: 6,
                      backgroundColor: color.withValues(alpha: 0.15),
                      valueColor: AlwaysStoppedAnimation(color),
                      strokeCap: StrokeCap.round,
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${animated.toStringAsFixed(0)}%',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(height: AppSpacing.sm),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            if (subtitle != null) ...[
              SizedBox(height: 2),
              Text(
                subtitle!,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 10,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        );
      },
    );
  }
}

class _ThroughputTile extends StatelessWidget {
  const _ThroughputTile({
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
      padding: EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: AppRadius.mediumBorderRadius,
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: AppRadius.smallBorderRadius,
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  value,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EnvironmentChip extends StatelessWidget {
  const _EnvironmentChip({
    required this.icon,
    required this.label,
    required this.value,
    this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chipColor = color ?? theme.colorScheme.primary;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: chipColor.withValues(alpha: 0.08),
        borderRadius: AppRadius.mediumBorderRadius,
        border: Border.all(color: chipColor.withValues(alpha: 0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: chipColor),
          SizedBox(width: AppSpacing.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 10,
                ),
              ),
              Text(
                value,
                style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricGaugeSkeleton extends StatelessWidget {
  const _MetricGaugeSkeleton();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 100,
      child: Column(
        children: [
          SkeletonLoader.circular(size: 72),
          SizedBox(height: AppSpacing.sm),
          const SkeletonLoader(width: 60, height: 14),
        ],
      ),
    );
  }
}

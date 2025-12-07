import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';

import '../animations/app_durations.dart';
import '../animations/app_curves.dart';
import '../animations/staggered_animation_mixin.dart';
import '../models/system_record.dart';
import '../services/alerts_service.dart';
import '../services/system_stats_service.dart';
import '../services/systems_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_radius.dart';
import '../widgets/skeleton_loader.dart';

class HomeOverviewScreen extends StatefulWidget {
  const HomeOverviewScreen({super.key});

  @override
  State<HomeOverviewScreen> createState() => _HomeOverviewScreenState();
}

class _HomeOverviewScreenState extends State<HomeOverviewScreen>
    with TickerProviderStateMixin, StaggeredAnimationMixin {
  final SystemsService _systemsService = SystemsService();
  final AlertsService _alertsService = AlertsService();
  final SystemStatsService _statsService = SystemStatsService();

  late Future<void> _future;
  List<SystemRecord> _systems = const <SystemRecord>[];
  List<RecordModel> _alerts = const <RecordModel>[];
  Map<String, Map<String, dynamic>> _latestStats = <String, Map<String, dynamic>>{};
  String? _error;
  bool _isLoading = true;
  bool _hasLoadedOnce = false;

  static const int _sectionCount = 5;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _future = _loadInitial();
  }

  void _initAnimations() {
    initStaggeredAnimation(itemCount: _sectionCount);
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
    } catch (_) {}
    return null;
  }

  @override
  void dispose() {
    _statsService.dispose();
    super.dispose();
  }

  Future<void> _loadInitial() async {
    setState(() => _isLoading = true);
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
        _isLoading = false;
        _hasLoadedOnce = true;
      });
      playStaggeredAnimation();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load data';
        _latestStats = <String, Map<String, dynamic>>{};
        _isLoading = false;
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
      playStaggeredAnimation();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Failed to refresh');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            expandedHeight: 140,
            floating: false,
            pinned: true,
            elevation: innerBoxIsScrolled ? 2 : 0,
            backgroundColor: theme.colorScheme.surface,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 16, bottom: 16, right: 56),
              title: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Dashboard',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    'Fleet overview',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      theme.colorScheme.primary.withValues(alpha: 0.08),
                      theme.colorScheme.surface,
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              IconButton(
                tooltip: 'Refresh',
                onPressed: () => setState(() => _future = _refresh()),
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
        ],
        body: RefreshIndicator(
          onRefresh: _refresh,
          color: theme.colorScheme.primary,
          child: FutureBuilder<void>(
            future: _future,
            builder: (context, snapshot) {
              if (_isLoading && !_hasLoadedOnce) {
                return _buildSkeletonContent();
              }
              if (_error != null && _systems.isEmpty) {
                return _buildErrorState(context);
              }
              return AnimatedSwitcher(
                duration: AppDurations.normal,
                child: _buildContent(),
              );
            },
          ),
        ),
      ),
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
              child: Icon(Icons.cloud_off, size: 48, color: AppColors.error),
            ),
            SizedBox(height: AppSpacing.lg),
            Text('Unable to load dashboard', style: theme.textTheme.titleMedium),
            SizedBox(height: AppSpacing.sm),
            Text(
              _error ?? 'Something went wrong',
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: AppSpacing.xl),
            FilledButton.icon(
              onPressed: () => setState(() => _future = _loadInitial()),
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkeletonContent() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.all(AppSpacing.lg),
      children: [
        _HealthBarSkeleton(),
        SizedBox(height: AppSpacing.xl),
        _SummaryGridSkeleton(),
        SizedBox(height: AppSpacing.xl),
        _SectionSkeleton(height: 200),
        SizedBox(height: AppSpacing.xl),
        _SectionSkeleton(height: 180),
        SizedBox(height: AppSpacing.xxl),
      ],
    );
  }

  Widget _buildContent() {
    final up = _systems.where((s) => s.status == 'up').length;
    final total = _systems.length;
    final healthPercent = total > 0 ? (up / total * 100) : 0.0;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.all(AppSpacing.lg),
      children: [
        if (_error != null)
          Padding(
            padding: EdgeInsets.only(bottom: AppSpacing.lg),
            child: _ErrorBanner(message: _error!, onRetry: () => setState(() => _future = _refresh())),
          ),
        // Health bar
        buildStaggeredItem(
          index: 0,
          child: _HealthBar(healthPercent: healthPercent, upCount: up, totalCount: total, alertCount: _alerts.length),
        ),
        SizedBox(height: AppSpacing.xl),
        // Summary grid
        buildStaggeredItem(
          index: 1,
          child: _SummaryGrid(systems: _systems, alerts: _alerts),
        ),
        SizedBox(height: AppSpacing.xl),
        // Fleet insights
        buildStaggeredItem(
          index: 2,
          child: _FleetInsights(systems: _systems, stats: _latestStats),
        ),
        SizedBox(height: AppSpacing.xl),
        // Top systems
        buildStaggeredItem(
          index: 3,
          child: _TopSystemsSection(systems: _systems),
        ),
        SizedBox(height: AppSpacing.xl),
        // Active alerts
        buildStaggeredItem(
          index: 4,
          child: _ActiveAlertsSection(alerts: _alerts, systems: _systems),
        ),
        SizedBox(height: AppSpacing.xxl),
      ],
    );
  }
}

// ============================================================================
// Health Bar - New prominent health indicator
// ============================================================================

class _HealthBar extends StatelessWidget {
  const _HealthBar({
    required this.healthPercent,
    required this.upCount,
    required this.totalCount,
    required this.alertCount,
  });

  final double healthPercent;
  final int upCount;
  final int totalCount;
  final int alertCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final healthColor = _getHealthColor(healthPercent);
    final hasAlerts = alertCount > 0;

    return Container(
      padding: EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            healthColor.withValues(alpha: 0.15),
            healthColor.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: AppRadius.largeBorderRadius,
        border: Border.all(color: healthColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _AnimatedHealthIcon(color: healthColor, isHealthy: healthPercent >= 80),
              SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getHealthLabel(healthPercent),
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: healthColor,
                      ),
                    ),
                    SizedBox(height: AppSpacing.xs),
                    Text(
                      '$upCount of $totalCount systems online',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (hasAlerts)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.15),
                    borderRadius: AppRadius.circularBorderRadius,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.warning_amber, size: 16, color: AppColors.warning),
                      SizedBox(width: AppSpacing.xs),
                      Text(
                        '$alertCount',
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.warning,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          SizedBox(height: AppSpacing.lg),
          TweenAnimationBuilder<double>(
            duration: AppDurations.chart,
            tween: Tween(begin: 0, end: healthPercent / 100),
            curve: AppCurves.enter,
            builder: (context, value, _) {
              return ClipRRect(
                borderRadius: AppRadius.smallBorderRadius,
                child: LinearProgressIndicator(
                  value: value,
                  minHeight: 8,
                  backgroundColor: healthColor.withValues(alpha: 0.15),
                  valueColor: AlwaysStoppedAnimation(healthColor),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Color _getHealthColor(double percent) {
    if (percent >= 80) return AppColors.success;
    if (percent >= 50) return AppColors.warning;
    return AppColors.error;
  }

  String _getHealthLabel(double percent) {
    if (percent >= 90) return 'Excellent Health';
    if (percent >= 80) return 'Good Health';
    if (percent >= 50) return 'Needs Attention';
    if (percent > 0) return 'Critical';
    return 'No Systems';
  }
}

class _AnimatedHealthIcon extends StatefulWidget {
  const _AnimatedHealthIcon({required this.color, required this.isHealthy});

  final Color color;
  final bool isHealthy;

  @override
  State<_AnimatedHealthIcon> createState() => _AnimatedHealthIconState();
}

class _AnimatedHealthIconState extends State<_AnimatedHealthIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    if (widget.isHealthy) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(_AnimatedHealthIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isHealthy && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.isHealthy && _controller.isAnimating) {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: widget.isHealthy ? _pulseAnimation.value : 1.0,
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: widget.color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              widget.isHealthy ? Icons.favorite : Icons.heart_broken,
              color: widget.color,
              size: 28,
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

// ============================================================================
// Summary Grid
// ============================================================================

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

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 400;
        return Row(
          children: [
            Expanded(
              child: _StatCard(
                icon: Icons.dns,
                label: 'Total',
                value: total.toString(),
                color: theme.colorScheme.primary,
              ),
            ),
            SizedBox(width: AppSpacing.md),
            Expanded(
              child: _StatCard(
                icon: Icons.check_circle,
                label: 'Online',
                value: up.toString(),
                color: AppColors.success,
              ),
            ),
            SizedBox(width: AppSpacing.md),
            Expanded(
              child: _StatCard(
                icon: Icons.cancel,
                label: 'Down',
                value: down.toString(),
                color: AppColors.error,
              ),
            ),
            if (isWide) ...[
              SizedBox(width: AppSpacing.md),
              Expanded(
                child: _StatCard(
                  icon: Icons.pause_circle,
                  label: 'Paused',
                  value: paused.toString(),
                  color: AppColors.warning,
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
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
      padding: EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: AppRadius.mediumBorderRadius,
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          SizedBox(height: AppSpacing.sm),
          TweenAnimationBuilder<int>(
            duration: AppDurations.medium,
            tween: IntTween(begin: 0, end: int.tryParse(value) ?? 0),
            builder: (context, val, _) {
              return Text(
                val.toString(),
                style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
              );
            },
          ),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Fleet Insights
// ============================================================================

class _FleetInsights extends StatelessWidget {
  const _FleetInsights({required this.systems, required this.stats});

  final List<SystemRecord> systems;
  final Map<String, Map<String, dynamic>> stats;

  double _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    if (systems.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    double totalIn = 0, totalOut = 0, totalDiskRead = 0, totalDiskWrite = 0;
    int containersTotal = 0;

    for (final system in systems) {
      final statMap = stats[system.id];
      final info = system.info;
      totalIn += _asDouble(statMap?['nr'] ?? info['nr']);
      totalOut += _asDouble(statMap?['ns'] ?? info['ns']);
      totalDiskRead += _asDouble(statMap?['dr'] ?? info['dr']);
      totalDiskWrite += _asDouble(statMap?['dw'] ?? info['dw']);
      final containers = info['containers'];
      if (containers is Map) {
        containersTotal += (containers['total'] as int?) ?? 0;
      } else if (containers is int) {
        containersTotal += containers;
      }
    }

    String formatRate(double value) {
      if (value >= 1024) return '${(value / 1024).toStringAsFixed(1)} GB/s';
      return '${value.toStringAsFixed(1)} MB/s';
    }

    return _SectionCard(
      icon: Icons.insights,
      title: 'Fleet Activity',
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _InsightTile(icon: Icons.arrow_downward, label: 'Network In', value: formatRate(totalIn), color: theme.colorScheme.primary)),
              SizedBox(width: AppSpacing.md),
              Expanded(child: _InsightTile(icon: Icons.arrow_upward, label: 'Network Out', value: formatRate(totalOut), color: AppColors.success)),
            ],
          ),
          SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(child: _InsightTile(icon: Icons.upload_file, label: 'Disk Read', value: formatRate(totalDiskRead), color: AppColors.warning)),
              SizedBox(width: AppSpacing.md),
              Expanded(child: _InsightTile(icon: Icons.download, label: 'Disk Write', value: formatRate(totalDiskWrite), color: Colors.purple)),
            ],
          ),
          if (containersTotal > 0) ...[
            SizedBox(height: AppSpacing.md),
            _InsightTile(icon: Icons.dns, label: 'Containers', value: '$containersTotal total', color: Colors.blueGrey, fullWidth: true),
          ],
        ],
      ),
    );
  }
}

class _InsightTile extends StatelessWidget {
  const _InsightTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.fullWidth = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: AppRadius.mediumBorderRadius,
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: AppRadius.smallBorderRadius,
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                Text(value, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Top Systems Section
// ============================================================================

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
      return _SectionCard(
        icon: Icons.leaderboard,
        title: 'Top Systems',
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(AppSpacing.xl),
            child: Text('No systems available', style: Theme.of(context).textTheme.bodyMedium),
          ),
        ),
      );
    }

    final sorted = List<SystemRecord>.from(systems)
      ..sort((a, b) => _num(b.info['cpu']).compareTo(_num(a.info['cpu'])));
    final top = sorted.take(3).toList();

    return _SectionCard(
      icon: Icons.leaderboard,
      title: 'Top CPU Usage',
      child: Column(
        children: top.asMap().entries.map((entry) {
          final index = entry.key;
          final system = entry.value;
          final cpu = _num(system.info['cpu']).toDouble();
          final mem = _num(system.info['mp']).toDouble();
          return _TopSystemTile(
            rank: index + 1,
            system: system,
            cpu: cpu,
            mem: mem,
            onTap: () => Navigator.of(context).pushNamed('/system', arguments: system),
          );
        }).toList(),
      ),
    );
  }
}

class _TopSystemTile extends StatelessWidget {
  const _TopSystemTile({
    required this.rank,
    required this.system,
    required this.cpu,
    required this.mem,
    required this.onTap,
  });

  final int rank;
  final SystemRecord system;
  final double cpu;
  final double mem;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rankColor = rank == 1 ? Colors.amber : (rank == 2 ? Colors.grey : Colors.brown);

    return Padding(
      padding: EdgeInsets.only(bottom: rank < 3 ? AppSpacing.md : 0),
      child: Material(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: AppRadius.mediumBorderRadius,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.mediumBorderRadius,
          child: Padding(
            padding: EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: rankColor.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '#$rank',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: rankColor,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        system.name,
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${system.host}:${system.port}',
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _MiniGauge(value: cpu, label: 'CPU', color: _getCpuColor(cpu)),
                    SizedBox(height: AppSpacing.xs),
                    _MiniGauge(value: mem, label: 'MEM', color: theme.colorScheme.secondary),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getCpuColor(double value) {
    if (value >= 80) return AppColors.error;
    if (value >= 50) return AppColors.warning;
    return AppColors.success;
  }
}

class _MiniGauge extends StatelessWidget {
  const _MiniGauge({required this.value, required this.label, required this.color});

  final double value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label ',
          style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.2),
            borderRadius: AppRadius.smallBorderRadius,
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: (value / 100).clamp(0, 1),
            child: Container(
              decoration: BoxDecoration(
                color: color,
                borderRadius: AppRadius.smallBorderRadius,
              ),
            ),
          ),
        ),
        SizedBox(width: AppSpacing.xs),
        Text(
          '${value.toStringAsFixed(0)}%',
          style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

// ============================================================================
// Active Alerts Section
// ============================================================================

class _ActiveAlertsSection extends StatelessWidget {
  const _ActiveAlertsSection({required this.alerts, required this.systems});

  final List<RecordModel> alerts;
  final List<SystemRecord> systems;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      icon: Icons.notifications_active,
      iconColor: alerts.isEmpty ? AppColors.success : AppColors.warning,
      title: 'Active Alerts',
      trailing: alerts.isNotEmpty
          ? TextButton(
              onPressed: () => Navigator.of(context).pushNamed('/alerts'),
              child: const Text('View all'),
            )
          : null,
      child: alerts.isEmpty
          ? _NoAlertsState()
          : Column(
              children: alerts.take(3).map((alert) {
                final systemName = _systemName(alert);
                final updated = alert.data['updated']?.toString();
                return _AlertTile(
                  name: alert.data['name']?.toString() ?? 'Alert',
                  systemName: systemName ?? 'Unknown',
                  time: updated != null ? _relativeTime(updated) : '',
                  onTap: () => _navigateToSystem(context, alert),
                );
              }).toList(),
            ),
    );
  }

  String? _systemName(RecordModel alert) {
    try {
      final expanded = alert.get<RecordModel?>('expand.system');
      if (expanded != null) {
        return expanded.data['name']?.toString();
      }
    } catch (_) {}
    return alert.data['system']?.toString();
  }

  String _relativeTime(String isoString) {
    try {
      final dt = DateTime.parse(isoString).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      return '${diff.inDays}d ago';
    } catch (_) {
      return '';
    }
  }

  void _navigateToSystem(BuildContext context, RecordModel alert) {
    final systemId = alert.data['system']?.toString();
    if (systemId != null) {
      final system = systems.firstWhere(
        (s) => s.id == systemId,
        orElse: () => SystemRecord(
          id: systemId,
          name: _systemName(alert) ?? systemId,
          host: '',
          status: 'pending',
          port: '',
          info: const <String, dynamic>{},
        ),
      );
      Navigator.of(context).pushNamed('/system', arguments: system);
    }
  }
}

class _NoAlertsState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.08),
        borderRadius: AppRadius.mediumBorderRadius,
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.check_circle, color: AppColors.success, size: 24),
          ),
          SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('All Clear', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600, color: AppColors.success)),
                Text('No active alerts at this time', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AlertTile extends StatelessWidget {
  const _AlertTile({
    required this.name,
    required this.systemName,
    required this.time,
    required this.onTap,
  });

  final String name;
  final String systemName;
  final String time;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: AppSpacing.sm),
      child: Material(
        color: AppColors.warning.withValues(alpha: 0.08),
        borderRadius: AppRadius.mediumBorderRadius,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.mediumBorderRadius,
          child: Padding(
            padding: EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.15),
                    borderRadius: AppRadius.smallBorderRadius,
                  ),
                  child: Icon(Icons.warning_amber, size: 18, color: AppColors.warning),
                ),
                SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                      Text(systemName, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                    ],
                  ),
                ),
                Text(time, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                SizedBox(width: AppSpacing.sm),
                Icon(Icons.chevron_right, size: 20, color: theme.colorScheme.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// Shared Components
// ============================================================================

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.icon,
    required this.title,
    required this.child,
    this.iconColor,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final Widget child;
  final Color? iconColor;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = iconColor ?? theme.colorScheme.primary;

    return Container(
      padding: EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: AppRadius.largeBorderRadius,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: AppRadius.smallBorderRadius,
                ),
                child: Icon(icon, size: 20, color: color),
              ),
              SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          SizedBox(height: AppSpacing.lg),
          child,
        ],
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
    return Container(
      padding: EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.1),
        borderRadius: AppRadius.mediumBorderRadius,
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: AppColors.error, size: 20),
          SizedBox(width: AppSpacing.md),
          Expanded(child: Text(message, style: theme.textTheme.bodySmall)),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

// ============================================================================
// Skeleton Widgets
// ============================================================================

class _HealthBarSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: AppRadius.largeBorderRadius,
      ),
      child: Column(
        children: [
          Row(
            children: [
              const SkeletonLoader.circular(size: 56),
              SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SkeletonLoader(width: 140, height: 24),
                    SizedBox(height: AppSpacing.sm),
                    const SkeletonLoader(width: 180, height: 16),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: AppSpacing.lg),
          const SkeletonLoader(height: 8, borderRadius: AppRadius.small),
        ],
      ),
    );
  }
}

class _SummaryGridSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(
        4,
        (index) => Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: index < 3 ? AppSpacing.md : 0),
            child: Container(
              padding: EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: AppRadius.mediumBorderRadius,
              ),
              child: Column(
                children: [
                  const SkeletonLoader.circular(size: 24),
                  SizedBox(height: AppSpacing.sm),
                  const SkeletonLoader(width: 32, height: 28),
                  SizedBox(height: AppSpacing.xs),
                  const SkeletonLoader(width: 40, height: 12),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionSkeleton extends StatelessWidget {
  const _SectionSkeleton({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: AppRadius.largeBorderRadius,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SkeletonLoader(width: 32, height: 32, borderRadius: AppRadius.small),
              SizedBox(width: AppSpacing.md),
              const SkeletonLoader(width: 120, height: 20),
            ],
          ),
          SizedBox(height: AppSpacing.lg),
          SkeletonLoader(height: height - 80, borderRadius: AppRadius.medium),
        ],
      ),
    );
  }
}

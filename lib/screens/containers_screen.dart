import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';

import '../models/system_record.dart';
import '../services/containers_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_radius.dart';
import '../animations/app_durations.dart';
import '../animations/app_curves.dart';
import '../widgets/skeleton_loader.dart';
import '../widgets/empty_state.dart';

class ContainersScreen extends StatefulWidget {
  const ContainersScreen({super.key, required this.system});

  final SystemRecord system;

  @override
  State<ContainersScreen> createState() => _ContainersScreenState();
}

class _ContainersScreenState extends State<ContainersScreen>
    with SingleTickerProviderStateMixin {
  final _svc = ContainersService();
  late Future<List<RecordModel>> _future;
  bool _initialLoading = true;
  String _searchQuery = '';
  String _statusFilter = 'all';

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
    _loadContainers();
  }

  Future<void> _loadContainers() async {
    _future = _svc.fetchForSystem(widget.system.id);
    await _future;
    if (mounted) {
      setState(() => _initialLoading = false);
      _fadeController.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            expandedHeight: 120,
            floating: true,
            pinned: true,
            elevation: innerBoxIsScrolled ? 2 : 0,
            backgroundColor: theme.colorScheme.surface,
            foregroundColor: theme.colorScheme.onSurface,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 56, bottom: 16, right: 16),
              title: Text(
                'Containers',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
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
                icon: const Icon(Icons.filter_list),
                tooltip: 'Filter',
                onPressed: _showFilterSheet,
              ),
            ],
          ),
        ],
        body: RefreshIndicator(
          onRefresh: _handleRefresh,
          color: theme.colorScheme.primary,
          child: _buildBody(context),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    return FutureBuilder<List<RecordModel>>(
      future: _future,
      builder: (context, snapshot) {
        if (_initialLoading) {
          return _buildLoadingSkeleton(context);
        }

        if (snapshot.hasError) {
          return _buildErrorState(context);
        }

        final items = snapshot.data ?? const <RecordModel>[];
        final filteredItems = _filterContainers(items);

        if (items.isEmpty) {
          return EmptyState(
            icon: Icons.dns_outlined,
            title: 'No containers found',
            description: 'This system has no Docker containers running.',
          );
        }

        return FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            children: [
              _buildSearchBar(context),
              _buildStatsBar(context, items),
              Expanded(
                child: filteredItems.isEmpty
                    ? _buildNoResultsState(context)
                    : _buildContainersList(context, filteredItems),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0),
      child: TextField(
        onChanged: (value) => setState(() => _searchQuery = value),
        decoration: InputDecoration(
          hintText: 'Search containers...',
          prefixIcon: const Icon(Icons.search, size: 20),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 20),
                  onPressed: () => setState(() => _searchQuery = ''),
                )
              : null,
          filled: true,
          fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          border: OutlineInputBorder(
            borderRadius: AppRadius.mediumBorderRadius,
            borderSide: BorderSide.none,
          ),
          contentPadding: EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
        ),
      ),
    );
  }

  Widget _buildStatsBar(BuildContext context, List<RecordModel> items) {
    final theme = Theme.of(context);
    final running = items.where((c) => _isRunning(c.data['status']?.toString() ?? '')).length;
    final stopped = items.length - running;

    return Padding(
      padding: EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          _StatChip(
            label: 'Total',
            value: items.length.toString(),
            color: theme.colorScheme.primary,
            isSelected: _statusFilter == 'all',
            onTap: () => setState(() => _statusFilter = 'all'),
          ),
          SizedBox(width: AppSpacing.sm),
          _StatChip(
            label: 'Running',
            value: running.toString(),
            color: AppColors.success,
            isSelected: _statusFilter == 'running',
            onTap: () => setState(() => _statusFilter = 'running'),
          ),
          SizedBox(width: AppSpacing.sm),
          _StatChip(
            label: 'Stopped',
            value: stopped.toString(),
            color: AppColors.error,
            isSelected: _statusFilter == 'stopped',
            onTap: () => setState(() => _statusFilter = 'stopped'),
          ),
        ],
      ),
    );
  }

  Widget _buildContainersList(BuildContext context, List<RecordModel> items) {
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.xxl),
      itemCount: items.length,
      itemBuilder: (context, index) {
        return TweenAnimationBuilder<double>(
          duration: Duration(milliseconds: 200 + (index * 50).clamp(0, 300)),
          tween: Tween(begin: 0.0, end: 1.0),
          curve: AppCurves.enter,
          builder: (context, value, child) {
            return Opacity(
              opacity: value,
              child: Transform.translate(
                offset: Offset(0, 20 * (1 - value)),
                child: child,
              ),
            );
          },
          child: _ContainerCard(
            container: items[index],
            onTap: () => _navigateToDetails(items[index]),
          ),
        );
      },
    );
  }

  Widget _buildLoadingSkeleton(BuildContext context) {
    return ListView(
      padding: EdgeInsets.all(AppSpacing.lg),
      children: [
        // Search bar skeleton
        SkeletonLoader(height: 48, borderRadius: AppRadius.medium),
        SizedBox(height: AppSpacing.lg),
        // Stats bar skeleton
        Row(
          children: List.generate(
            3,
            (_) => Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: AppSpacing.sm),
                child: const SkeletonLoader(height: 40, borderRadius: AppRadius.medium),
              ),
            ),
          ),
        ),
        SizedBox(height: AppSpacing.lg),
        // Container cards skeleton
        ...List.generate(5, (_) => const _ContainerCardSkeleton()),
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
            Text('Failed to load containers', style: theme.textTheme.titleMedium),
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

  Widget _buildNoResultsState(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search_off, size: 48, color: theme.colorScheme.onSurfaceVariant),
          SizedBox(height: AppSpacing.lg),
          Text('No matching containers', style: theme.textTheme.titleMedium),
          SizedBox(height: AppSpacing.sm),
          TextButton(
            onPressed: () => setState(() {
              _searchQuery = '';
              _statusFilter = 'all';
            }),
            child: const Text('Clear filters'),
          ),
        ],
      ),
    );
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.large)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Filter by Status', style: Theme.of(context).textTheme.titleMedium),
            SizedBox(height: AppSpacing.lg),
            Wrap(
              spacing: AppSpacing.sm,
              children: [
                FilterChip(
                  label: const Text('All'),
                  selected: _statusFilter == 'all',
                  onSelected: (_) {
                    setState(() => _statusFilter = 'all');
                    Navigator.pop(context);
                  },
                ),
                FilterChip(
                  label: const Text('Running'),
                  selected: _statusFilter == 'running',
                  onSelected: (_) {
                    setState(() => _statusFilter = 'running');
                    Navigator.pop(context);
                  },
                ),
                FilterChip(
                  label: const Text('Stopped'),
                  selected: _statusFilter == 'stopped',
                  onSelected: (_) {
                    setState(() => _statusFilter = 'stopped');
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
            SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    );
  }

  List<RecordModel> _filterContainers(List<RecordModel> items) {
    return items.where((c) {
      final name = c.data['name']?.toString().toLowerCase() ?? '';
      final image = c.data['image']?.toString().toLowerCase() ?? '';
      final status = c.data['status']?.toString() ?? '';

      // Search filter
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        if (!name.contains(query) && !image.contains(query)) {
          return false;
        }
      }

      // Status filter
      if (_statusFilter == 'running' && !_isRunning(status)) {
        return false;
      }
      if (_statusFilter == 'stopped' && _isRunning(status)) {
        return false;
      }

      return true;
    }).toList();
  }

  bool _isRunning(String status) {
    final s = status.toLowerCase();
    return s.contains('up') || s.contains('running') || s.contains('healthy');
  }

  Future<void> _handleRefresh() async {
    setState(() {
      _future = _svc.fetchForSystem(widget.system.id);
    });
    await _future;
  }

  void _navigateToDetails(RecordModel container) {
    Navigator.of(context).pushNamed(
      '/container-details',
      arguments: {
        'systemId': widget.system.id,
        'containerId': container.id,
        'containerName': container.data['name']?.toString() ?? '',
      },
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }
}

// ============================================================================
// Supporting Widgets
// ============================================================================

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.label,
    required this.value,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final String value;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: AppDurations.fast,
          curve: AppCurves.standard,
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
          decoration: BoxDecoration(
            color: isSelected ? color.withValues(alpha: 0.15) : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: AppRadius.mediumBorderRadius,
            border: Border.all(
              color: isSelected ? color.withValues(alpha: 0.4) : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                value,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: isSelected ? color : theme.colorScheme.onSurface,
                ),
              ),
              SizedBox(width: AppSpacing.xs),
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isSelected ? color : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ContainerCard extends StatelessWidget {
  const _ContainerCard({
    required this.container,
    required this.onTap,
  });

  final RecordModel container;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = container.data['name']?.toString() ?? '';
    final image = container.data['image']?.toString() ?? '';
    final cpu = container.data['cpu']?.toString() ?? '0';
    final mem = container.data['memory']?.toString() ?? '0';
    final net = container.data['net']?.toString() ?? '0';
    final status = container.data['status']?.toString() ?? '';
    final health = container.data['health']?.toString() ?? '';
    final statusColor = _getStatusColor(status, context);
    final isRunning = _isRunning(status);

    return Padding(
      padding: EdgeInsets.only(bottom: AppSpacing.md),
      child: Material(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: AppRadius.largeBorderRadius,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.largeBorderRadius,
          child: Padding(
            padding: EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row
                Row(
                  children: [
                    _StatusIndicator(color: statusColor, isRunning: isRunning),
                    SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 2),
                          Text(
                            image,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    _StatusBadge(
                      status: status,
                      health: health,
                      color: statusColor,
                    ),
                  ],
                ),
                SizedBox(height: AppSpacing.md),
                // Metrics row
                Row(
                  children: [
                    _MetricPill(icon: Icons.speed, label: 'CPU', value: '$cpu%', color: _getCpuColor(cpu)),
                    SizedBox(width: AppSpacing.sm),
                    _MetricPill(icon: Icons.memory, label: 'MEM', value: '$mem GB', color: theme.colorScheme.secondary),
                    SizedBox(width: AppSpacing.sm),
                    _MetricPill(icon: Icons.swap_horiz, label: 'NET', value: '$net MB/s', color: theme.colorScheme.tertiary),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(String status, BuildContext context) {
    final s = status.toLowerCase();
    if (s.contains('up') || s.contains('running') || s.contains('healthy')) {
      return AppColors.success;
    }
    if (s.contains('exited') || s.contains('down') || s.contains('unhealthy')) {
      return AppColors.error;
    }
    return AppColors.inactive;
  }

  bool _isRunning(String status) {
    final s = status.toLowerCase();
    return s.contains('up') || s.contains('running') || s.contains('healthy');
  }

  Color _getCpuColor(String cpu) {
    final value = double.tryParse(cpu) ?? 0;
    if (value >= 80) return AppColors.error;
    if (value >= 50) return AppColors.warning;
    return AppColors.success;
  }
}

class _StatusIndicator extends StatefulWidget {
  const _StatusIndicator({required this.color, required this.isRunning});

  final Color color;
  final bool isRunning;

  @override
  State<_StatusIndicator> createState() => _StatusIndicatorState();
}

class _StatusIndicatorState extends State<_StatusIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    if (widget.isRunning) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(_StatusIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isRunning && !_pulseController.isAnimating) {
      _pulseController.repeat(reverse: true);
    } else if (!widget.isRunning && _pulseController.isAnimating) {
      _pulseController.stop();
      _pulseController.value = 1.0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: widget.color.withValues(alpha: 0.15 * _pulseAnimation.value),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: widget.color,
                shape: BoxShape.circle,
                boxShadow: widget.isRunning
                    ? [
                        BoxShadow(
                          color: widget.color.withValues(alpha: 0.4),
                          blurRadius: 8,
                          spreadRadius: 2,
                        ),
                      ]
                    : null,
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.status,
    required this.health,
    required this.color,
  });

  final String status;
  final String health;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final displayText = health.isNotEmpty ? health : _formatStatus(status);

    return Container(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: AppRadius.circularBorderRadius,
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        displayText.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  String _formatStatus(String status) {
    final s = status.toLowerCase();
    if (s.contains('running') || s.contains('up')) return 'Running';
    if (s.contains('exited')) return 'Stopped';
    if (s.contains('paused')) return 'Paused';
    return status;
  }
}

class _MetricPill extends StatelessWidget {
  const _MetricPill({
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
    return Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: AppRadius.smallBorderRadius,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            SizedBox(width: AppSpacing.xs),
            Flexible(
              child: Text(
                value,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContainerCardSkeleton extends StatelessWidget {
  const _ContainerCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: AppSpacing.md),
      child: Container(
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
                const SkeletonLoader.circular(size: 40),
                SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SkeletonLoader(width: 120, height: 16),
                      SizedBox(height: AppSpacing.xs),
                      const SkeletonLoader(width: 180, height: 12),
                    ],
                  ),
                ),
                const SkeletonLoader(width: 70, height: 24, borderRadius: AppRadius.circular),
              ],
            ),
            SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(child: SkeletonLoader(height: 32, borderRadius: AppRadius.small)),
                SizedBox(width: AppSpacing.sm),
                Expanded(child: SkeletonLoader(height: 32, borderRadius: AppRadius.small)),
                SizedBox(width: AppSpacing.sm),
                Expanded(child: SkeletonLoader(height: 32, borderRadius: AppRadius.small)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

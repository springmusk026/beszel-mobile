import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pocketbase/pocketbase.dart';

import '../api/pb_client.dart';
import '../models/system_record.dart';
import '../services/alerts_service.dart';
import '../services/auth_service.dart';
import '../services/systems_service.dart';
import '../animations/app_durations.dart';
import '../animations/app_curves.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_radius.dart';
import '../widgets/skeleton_loader.dart';
import '../widgets/empty_state.dart';

class SystemsScreen extends StatefulWidget {
  const SystemsScreen({super.key});

  @override
  State<SystemsScreen> createState() => _SystemsScreenState();
}

enum _SortBy { name, status, cpu, mem, disk }

class _SystemsScreenState extends State<SystemsScreen>
    with TickerProviderStateMixin {
  final _systemsService = SystemsService();
  final _auth = AuthService();
  final AlertsService _alertsService = AlertsService();
  late Future<List<SystemRecord>> _future;
  final TextEditingController _searchController = TextEditingController();
  StreamSubscription<List<RecordModel>>? _alertsSub;

  _SortBy _sortBy = _SortBy.name;
  bool _ascending = true;
  List<RecordModel> _activeAlerts = const [];
  bool _isInitialLoad = true;
  String _statusFilter = 'all';

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(vsync: this, duration: AppDurations.medium);
    _fadeAnimation = CurvedAnimation(parent: _fadeController, curve: AppCurves.enter);
    
    _future = _loadSystems();
    _systemsService.subscribe();
    _alertsService.subscribeActive();
    _alertsSub = _alertsService.stream.listen((alerts) {
      if (!mounted) return;
      setState(() => _activeAlerts = alerts);
    });
    _loadActiveAlerts();
  }

  Future<List<SystemRecord>> _loadSystems() async {
    final systems = await _systemsService.fetchAll();
    if (mounted) {
      setState(() => _isInitialLoad = false);
      _fadeController.forward();
    }
    return systems;
  }

  Future<void> _loadActiveAlerts() async {
    try {
      final alerts = await _alertsService.fetchActive();
      if (!mounted) return;
      setState(() => _activeAlerts = alerts);
    } catch (_) {
      // Ignore errors
    }
  }

  Future<void> _logout() async {
    await _auth.logout();
    if (mounted) Navigator.of(context).pushReplacementNamed('/login');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            expandedHeight: 140,
            floating: true,
            pinned: true,
            elevation: innerBoxIsScrolled ? 2 : 0,
            backgroundColor: theme.colorScheme.surface,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 16, bottom: 16, right: 56),
              title: Text(
                'Systems',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
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
                icon: const Icon(Icons.add),
                tooltip: 'Add System',
                onPressed: () async {
                  final result = await Navigator.of(context).pushNamed('/add-system');
                  if (result == true) setState(() => _future = _loadSystems());
                },
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                onSelected: (value) {
                  if (value == 'logout') _logout();
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'logout', child: Text('Logout')),
                ],
              ),
            ],
          ),
        ],
        body: RefreshIndicator(
          onRefresh: () async {
            await _systemsService.fetchAll();
            await _loadActiveAlerts();
          },
          color: theme.colorScheme.primary,
          child: _buildBody(context),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    return StreamBuilder<List<SystemRecord>>(
      stream: _systemsService.stream,
      initialData: const <SystemRecord>[],
      builder: (context, snapshot) {
        final items = snapshot.data ?? const <SystemRecord>[];
        if (items.isEmpty) {
          return FutureBuilder<List<SystemRecord>>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting || _isInitialLoad) {
                return _buildSkeletonList();
              }
              final list = snap.data ?? const <SystemRecord>[];
              if (list.isEmpty) {
                return EmptyState(
                  icon: Icons.dns_outlined,
                  title: 'No systems found',
                  description: 'Add your first system to start monitoring.',
                  actionLabel: 'Add System',
                  onAction: () => Navigator.of(context).pushNamed('/add-system'),
                );
              }
              return _buildContent(context, list);
            },
          );
        }
        return _buildContent(context, items);
      },
    );
  }

  Widget _buildContent(BuildContext context, List<SystemRecord> items) {
    final filtered = _filterAndSort(items);

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Column(
        children: [
          _buildSearchAndFilters(context, items),
          Expanded(
            child: filtered.isEmpty
                ? _buildNoResultsState(context)
                : _buildSystemsList(context, filtered),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilters(BuildContext context, List<SystemRecord> items) {
    final theme = Theme.of(context);
    final up = items.where((s) => s.status == 'up').length;
    final down = items.where((s) => s.status == 'down').length;
    final paused = items.where((s) => s.status == 'paused').length;

    return Container(
      padding: EdgeInsets.all(AppSpacing.lg),
      child: Column(
        children: [
          // Search bar
          TextField(
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Search systems...',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 20),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {});
                      },
                    )
                  : IconButton(
                      icon: const Icon(Icons.tune, size: 20),
                      onPressed: _showSortSheet,
                    ),
              filled: true,
              fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              border: OutlineInputBorder(
                borderRadius: AppRadius.mediumBorderRadius,
                borderSide: BorderSide.none,
              ),
              contentPadding: EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
            ),
          ),
          SizedBox(height: AppSpacing.md),
          // Status filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _FilterChip(label: 'All', count: items.length, isSelected: _statusFilter == 'all', onTap: () => setState(() => _statusFilter = 'all')),
                SizedBox(width: AppSpacing.sm),
                _FilterChip(label: 'Online', count: up, color: AppColors.success, isSelected: _statusFilter == 'up', onTap: () => setState(() => _statusFilter = 'up')),
                SizedBox(width: AppSpacing.sm),
                _FilterChip(label: 'Down', count: down, color: AppColors.error, isSelected: _statusFilter == 'down', onTap: () => setState(() => _statusFilter = 'down')),
                SizedBox(width: AppSpacing.sm),
                _FilterChip(label: 'Paused', count: paused, color: AppColors.warning, isSelected: _statusFilter == 'paused', onTap: () => setState(() => _statusFilter = 'paused')),
                if (_activeAlerts.isNotEmpty) ...[
                  SizedBox(width: AppSpacing.sm),
                  _FilterChip(label: 'Alerts', count: _activeAlerts.length, color: AppColors.error, isSelected: _statusFilter == 'alerts', onTap: () => setState(() => _statusFilter = 'alerts')),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSystemsList(BuildContext context, List<SystemRecord> items) {
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.xxl),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final system = items[index];
        final hasAlerts = _hasActiveAlerts(system.id);
        return TweenAnimationBuilder<double>(
          duration: Duration(milliseconds: 200 + (index * 40).clamp(0, 200)),
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
          child: Padding(
            padding: EdgeInsets.only(bottom: AppSpacing.md),
            child: _SystemCard(
              system: system,
              hasActiveAlerts: hasAlerts,
              onTap: () => Navigator.of(context).pushNamed('/system', arguments: system),
              onEdit: () async {
                final result = await Navigator.of(context).pushNamed('/add-system', arguments: system);
                if (result == true) setState(() => _future = _loadSystems());
              },
              onPauseResume: () => _pauseResumeSystem(system),
              onCopyName: () => _copyToClipboard(system.name, 'System name'),
              onCopyHost: () => _copyToClipboard('${system.host}:${system.port}', 'Host'),
              onDelete: () => _deleteSystem(system),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSkeletonList() {
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.all(AppSpacing.lg),
      itemCount: 5,
      itemBuilder: (context, index) => Padding(
        padding: EdgeInsets.only(bottom: AppSpacing.md),
        child: const _SystemCardSkeleton(),
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
          Text('No matching systems', style: theme.textTheme.titleMedium),
          SizedBox(height: AppSpacing.sm),
          TextButton(
            onPressed: () => setState(() {
              _searchController.clear();
              _statusFilter = 'all';
            }),
            child: const Text('Clear filters'),
          ),
        ],
      ),
    );
  }

  void _showSortSheet() {
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
            Text('Sort by', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
            SizedBox(height: AppSpacing.lg),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                _SortChip(label: 'Name', icon: Icons.sort_by_alpha, isSelected: _sortBy == _SortBy.name, onTap: () { setState(() => _sortBy = _SortBy.name); Navigator.pop(context); }),
                _SortChip(label: 'Status', icon: Icons.check_circle, isSelected: _sortBy == _SortBy.status, onTap: () { setState(() => _sortBy = _SortBy.status); Navigator.pop(context); }),
                _SortChip(label: 'CPU', icon: Icons.speed, isSelected: _sortBy == _SortBy.cpu, onTap: () { setState(() => _sortBy = _SortBy.cpu); Navigator.pop(context); }),
                _SortChip(label: 'Memory', icon: Icons.memory, isSelected: _sortBy == _SortBy.mem, onTap: () { setState(() => _sortBy = _SortBy.mem); Navigator.pop(context); }),
                _SortChip(label: 'Disk', icon: Icons.storage, isSelected: _sortBy == _SortBy.disk, onTap: () { setState(() => _sortBy = _SortBy.disk); Navigator.pop(context); }),
              ],
            ),
            SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Text('Order:', style: Theme.of(context).textTheme.bodyMedium),
                SizedBox(width: AppSpacing.md),
                ChoiceChip(
                  label: const Text('Ascending'),
                  selected: _ascending,
                  onSelected: (_) { setState(() => _ascending = true); Navigator.pop(context); },
                ),
                SizedBox(width: AppSpacing.sm),
                ChoiceChip(
                  label: const Text('Descending'),
                  selected: !_ascending,
                  onSelected: (_) { setState(() => _ascending = false); Navigator.pop(context); },
                ),
              ],
            ),
            SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    );
  }

  List<SystemRecord> _filterAndSort(List<SystemRecord> items) {
    final query = _searchController.text.trim().toLowerCase();
    List<SystemRecord> filtered = List<SystemRecord>.from(items);

    // Search filter
    if (query.isNotEmpty) {
      filtered = filtered.where((s) {
        final name = s.name.toLowerCase();
        final host = s.host.toLowerCase();
        return name.contains(query) || host.contains(query);
      }).toList();
    }

    // Status filter
    if (_statusFilter == 'alerts') {
      filtered = filtered.where((s) => _hasActiveAlerts(s.id)).toList();
    } else if (_statusFilter != 'all') {
      filtered = filtered.where((s) => s.status == _statusFilter).toList();
    }

    // Sort
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

    return filtered;
  }

  bool _hasActiveAlerts(String systemId) {
    return _activeAlerts.any((alert) => alert.data['system']?.toString() == systemId);
  }

  int _statusRank(String status) {
    switch (status) {
      case 'up': return 0;
      case 'paused': return 1;
      case 'pending': return 2;
      case 'down': return 3;
      default: return 4;
    }
  }

  num _num(dynamic v) {
    if (v is num) return v;
    if (v is String) return num.tryParse(v) ?? 0;
    return 0;
  }

  Future<void> _deleteSystem(SystemRecord system) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${system.name}?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
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
        setState(() => _future = _loadSystems());
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to delete: $e')));
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
        setState(() => _future = _loadSystems());
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$label copied')));
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _alertsSub?.cancel();
    unawaited(_alertsService.unsubscribe());
    unawaited(_systemsService.unsubscribe());
    _searchController.dispose();
    super.dispose();
  }
}

// ============================================================================
// Filter & Sort Chips
// ============================================================================

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.count,
    required this.isSelected,
    required this.onTap,
    this.color,
  });

  final String label;
  final int count;
  final bool isSelected;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chipColor = color ?? theme.colorScheme.primary;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppDurations.fast,
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: isSelected ? chipColor.withValues(alpha: 0.15) : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: AppRadius.circularBorderRadius,
          border: Border.all(
            color: isSelected ? chipColor.withValues(alpha: 0.4) : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: isSelected ? chipColor : theme.colorScheme.onSurface,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
            SizedBox(width: AppSpacing.xs),
            Container(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected ? chipColor.withValues(alpha: 0.2) : theme.colorScheme.surfaceContainerHighest,
                borderRadius: AppRadius.circularBorderRadius,
              ),
              child: Text(
                count.toString(),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: isSelected ? chipColor : theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SortChip extends StatelessWidget {
  const _SortChip({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          SizedBox(width: AppSpacing.xs),
          Text(label),
        ],
      ),
      selected: isSelected,
      onSelected: (_) => onTap(),
    );
  }
}

// ============================================================================
// System Card
// ============================================================================

class _SystemCard extends StatefulWidget {
  const _SystemCard({
    required this.system,
    required this.hasActiveAlerts,
    required this.onTap,
    required this.onEdit,
    required this.onPauseResume,
    required this.onCopyName,
    required this.onCopyHost,
    required this.onDelete,
  });

  final SystemRecord system;
  final bool hasActiveAlerts;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onPauseResume;
  final VoidCallback onCopyName;
  final VoidCallback onCopyHost;
  final VoidCallback onDelete;

  @override
  State<_SystemCard> createState() => _SystemCardState();
}

class _SystemCardState extends State<_SystemCard> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(vsync: this, duration: AppDurations.alertPulse);
    _pulseAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    if (widget.hasActiveAlerts) _pulseController.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(_SystemCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.hasActiveAlerts != oldWidget.hasActiveAlerts) {
      if (widget.hasActiveAlerts) {
        _pulseController.repeat(reverse: true);
      } else {
        _pulseController.stop();
        _pulseController.reset();
      }
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  num _num(dynamic v) {
    if (v is num) return v;
    if (v is String) return num.tryParse(v) ?? 0;
    return 0;
  }

  double _percent(dynamic value) {
    final v = _num(value).toDouble();
    return v.isFinite ? v.clamp(0, 100) : 0;
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.system;
    final theme = Theme.of(context);
    final statusColor = AppColors.getStatusColor(s.status);
    final cpuPercent = _percent(s.info['cpu']);
    final memPercent = _percent(s.info['mp']);
    final diskPercent = _percent(s.info['dp']);

    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        final pulseOpacity = widget.hasActiveAlerts ? 0.3 + (_pulseAnimation.value * 0.4) : 0.2;
        return Material(
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: AppRadius.largeBorderRadius,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: AppRadius.largeBorderRadius,
            child: AnimatedContainer(
              duration: AppDurations.medium,
              padding: EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                borderRadius: AppRadius.largeBorderRadius,
                border: Border.all(
                  color: statusColor.withValues(alpha: pulseOpacity),
                  width: widget.hasActiveAlerts ? 2 : 1,
                ),
              ),
              child: child,
            ),
          ),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              _StatusDot(color: statusColor, isOnline: s.status == 'up'),
              SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.name, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                    Text('${s.host}:${s.port}', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                  ],
                ),
              ),
              _StatusBadge(status: s.status, color: statusColor),
              _buildMenu(context, s),
            ],
          ),
          SizedBox(height: AppSpacing.lg),
          // Metrics
          Row(
            children: [
              Expanded(child: _MiniMetric(label: 'CPU', value: cpuPercent, color: _getMetricColor(cpuPercent))),
              SizedBox(width: AppSpacing.md),
              Expanded(child: _MiniMetric(label: 'MEM', value: memPercent, color: _getMetricColor(memPercent))),
              SizedBox(width: AppSpacing.md),
              Expanded(child: _MiniMetric(label: 'DISK', value: diskPercent, color: _getMetricColor(diskPercent))),
            ],
          ),
          if (widget.hasActiveAlerts) ...[
            SizedBox(height: AppSpacing.md),
            Container(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                borderRadius: AppRadius.smallBorderRadius,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.warning_amber, size: 16, color: AppColors.error),
                  SizedBox(width: AppSpacing.xs),
                  Text('Active alerts', style: theme.textTheme.labelSmall?.copyWith(color: AppColors.error, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _getMetricColor(double value) {
    if (value >= 90) return AppColors.error;
    if (value >= 70) return AppColors.warning;
    return AppColors.success;
  }

  Widget _buildMenu(BuildContext context, SystemRecord s) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, size: 20),
      onSelected: (value) {
        switch (value) {
          case 'edit': widget.onEdit(); break;
          case 'pause': case 'resume': widget.onPauseResume(); break;
          case 'copy_name': widget.onCopyName(); break;
          case 'copy_host': widget.onCopyHost(); break;
          case 'delete': widget.onDelete(); break;
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(value: 'edit', child: Text('Edit')),
        PopupMenuItem(value: s.status == 'paused' ? 'resume' : 'pause', child: Text(s.status == 'paused' ? 'Resume' : 'Pause')),
        const PopupMenuItem(value: 'copy_name', child: Text('Copy name')),
        const PopupMenuItem(value: 'copy_host', child: Text('Copy host')),
        const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.red))),
      ],
    );
  }
}

// ============================================================================
// Supporting Widgets
// ============================================================================

class _StatusDot extends StatefulWidget {
  const _StatusDot({required this.color, required this.isOnline});

  final Color color;
  final bool isOnline;

  @override
  State<_StatusDot> createState() => _StatusDotState();
}

class _StatusDotState extends State<_StatusDot> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));
    _animation = Tween<double>(begin: 0.8, end: 1.0).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    if (widget.isOnline) _controller.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(_StatusDot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isOnline && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.isOnline && _controller.isAnimating) {
      _controller.stop();
      _controller.value = 1.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) {
        return Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: widget.color,
            shape: BoxShape.circle,
            boxShadow: widget.isOnline
                ? [BoxShadow(color: widget.color.withValues(alpha: 0.5 * _animation.value), blurRadius: 8, spreadRadius: 2)]
                : null,
          ),
        );
      },
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
    return Container(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: AppRadius.circularBorderRadius,
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        status.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _MiniMetric extends StatelessWidget {
  const _MiniMetric({required this.label, required this.value, required this.color});

  final String label;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            Text('${value.toStringAsFixed(0)}%', style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600)),
          ],
        ),
        SizedBox(height: AppSpacing.xs),
        TweenAnimationBuilder<double>(
          duration: AppDurations.metricGauge,
          tween: Tween(begin: 0, end: value / 100),
          curve: AppCurves.enter,
          builder: (context, val, _) {
            return ClipRRect(
              borderRadius: AppRadius.smallBorderRadius,
              child: LinearProgressIndicator(
                value: val.clamp(0, 1),
                minHeight: 4,
                backgroundColor: color.withValues(alpha: 0.15),
                valueColor: AlwaysStoppedAnimation(color),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _SystemCardSkeleton extends StatelessWidget {
  const _SystemCardSkeleton();

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
              const SkeletonLoader.circular(size: 12),
              SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SkeletonLoader(width: 140, height: 18),
                    SizedBox(height: AppSpacing.xs),
                    const SkeletonLoader(width: 100, height: 14),
                  ],
                ),
              ),
              const SkeletonLoader(width: 60, height: 24, borderRadius: AppRadius.circular),
            ],
          ),
          SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(child: _MetricSkeleton()),
              SizedBox(width: AppSpacing.md),
              Expanded(child: _MetricSkeleton()),
              SizedBox(width: AppSpacing.md),
              Expanded(child: _MetricSkeleton()),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const SkeletonLoader(width: 30, height: 12),
            const SkeletonLoader(width: 30, height: 12),
          ],
        ),
        SizedBox(height: AppSpacing.xs),
        const SkeletonLoader(height: 4),
      ],
    );
  }
}

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
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(widget.system.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            Chip(label: Text(widget.system.status.toUpperCase())),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _kv('Host', '${widget.system.host}:${widget.system.port}'),
                        if (created != null) _kv('Last Update', created),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _sectionTitle('CPU'),
                        _kv('CPU %', stats['cpu']?.toString() ?? '—'),
                        _kv('Load 1/5/15', _formatLoad(stats)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _sectionTitle('Memory'),
                        _kv('Mem %', stats['mp']?.toString() ?? '—'),
                        _kv('Used (GB)', stats['mu']?.toString() ?? '—'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _sectionTitle('Disk'),
                        _kv('Disk %', stats['dp']?.toString() ?? '—'),
                        _kv('Read (MB/s)', stats['dr']?.toString() ?? '—'),
                        _kv('Write (MB/s)', stats['dw']?.toString() ?? '—'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _sectionTitle('Network'),
                        _kv('Sent (MB/s)', stats['ns']?.toString() ?? '—'),
                        _kv('Recv (MB/s)', stats['nr']?.toString() ?? '—'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
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
                const SizedBox(height: 16),
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

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(k, style: const TextStyle(fontWeight: FontWeight.w600)),
          Flexible(child: Text(v, textAlign: TextAlign.right)),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
    );
  }

  @override
  void dispose() {
    _statsSub?.cancel();
    _statsSvc.dispose();
    super.dispose();
  }
}



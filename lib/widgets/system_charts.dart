import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';

import '../animations/app_curves.dart';
import '../animations/app_durations.dart';

class SystemCharts extends StatefulWidget {
  const SystemCharts({
    super.key,
    required this.records,
    required this.loading,
    required this.error,
    required this.onRetry,
    required this.chartTime,
  });

  final List<RecordModel> records;
  final bool loading;
  final String? error;
  final VoidCallback onRetry;
  final String chartTime;

  @override
  State<SystemCharts> createState() => _SystemChartsState();
}

class _SystemChartsState extends State<SystemCharts> {
  // Note: Animation is handled by AnimatedSwitcher and fl_chart's built-in animation

  @override
  Widget build(BuildContext context) {
    if (widget.loading && widget.records.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (widget.error != null && widget.records.isEmpty) {
      return Column(
        children: [
          Text(widget.error!, style: const TextStyle(color: Colors.red)),
          const SizedBox(height: 8),
          ElevatedButton(onPressed: widget.onRetry, child: const Text('Retry')),
        ],
      );
    }
    if (widget.records.isEmpty) {
      return const Text('No chart data available');
    }

    final entries = _buildEntries(widget.records);
    if (entries.isEmpty) {
      return const Text('No chart data available');
    }
    final theme = Theme.of(context);
    final latestStats = entries.isNotEmpty ? entries.last.stats : <String, dynamic>{};
    final baseTime = entries.first.time;
    
    // Wrap in AnimatedSwitcher for cross-fade when time range changes
    return AnimatedSwitcher(
      duration: AppDurations.medium, // 300ms cross-fade
      switchInCurve: AppCurves.enter,
      switchOutCurve: AppCurves.exit,
      transitionBuilder: (Widget child, Animation<double> animation) {
        return FadeTransition(
          opacity: animation,
          child: child,
        );
      },
      child: Column(
        key: ValueKey<String>(widget.chartTime), // Key by chart time for cross-fade
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Charts (${_labelForChartTime(widget.chartTime)})', style: theme.textTheme.titleMedium),
        const SizedBox(height: 12),
        _chartCard(
          context,
          title: 'CPU %',
          color: Colors.blueAccent,
          spots: _spots(entries, (stats) => stats['cpu']),
          maxY: 100,
          baseTime: baseTime,
          ySuffix: '%',
          index: 0,
        ),
        const SizedBox(height: 12),
        _chartCard(
          context,
          title: 'Memory %',
          color: Colors.orangeAccent,
          spots: _spots(entries, (stats) => stats['mp']),
          maxY: 100,
          baseTime: baseTime,
          ySuffix: '%',
          index: 1,
        ),
        const SizedBox(height: 12),
        _chartCard(
          context,
          title: 'Disk %',
          color: Colors.purpleAccent,
          spots: _spots(entries, (stats) => stats['dp']),
          maxY: 100,
          baseTime: baseTime,
          ySuffix: '%',
          index: 2,
        ),
        const SizedBox(height: 12),
        _multiChartCard(
          context,
          title: 'Network (MB/s)',
          series: [
            _ChartSeries('Sent', Colors.greenAccent, _spots(entries, (stats) => stats['ns'])),
            _ChartSeries('Recv', Colors.redAccent, _spots(entries, (stats) => stats['nr'])),
          ],
          baseTime: baseTime,
          ySuffix: ' MB/s',
          leftFractionDigits: 1,
          index: 3,
        ),
        // Swap chart
        if ((latestStats['su'] as num?) != null && (latestStats['su'] as num) > 0) ...[
          const SizedBox(height: 12),
          _chartCard(
            context,
            title: 'Swap Usage (GB)',
            color: Colors.tealAccent,
            spots: _spots(entries, (stats) {
              final su = stats['su'];
              return su is num ? su : null;
            }),
            baseTime: baseTime,
            leftFractionDigits: 1,
            ySuffix: ' GB',
            index: 4,
          ),
        ],
        // CPU cores chart
        if (_hasCpuCores(latestStats)) ...[
          const SizedBox(height: 12),
          _multiChartCard(
            context,
            title: 'CPU Cores (%)',
            series: _cpuCoreSeries(entries),
            baseTime: baseTime,
            ySuffix: '%',
            index: 5,
          ),
        ],
        // Load Average chart
        if (_hasLoadAverage(latestStats)) ...[
          const SizedBox(height: 12),
          _multiChartCard(
            context,
            title: 'Load Average',
            series: _loadAverageSeries(entries),
            baseTime: baseTime,
            leftFractionDigits: 2,
            index: 6,
          ),
        ],
        // Temperature chart
        if (latestStats['t'] is Map && (latestStats['t'] as Map).isNotEmpty) ...[
          const SizedBox(height: 12),
          _temperatureChart(context, entries, latestStats['t'] as Map, baseTime, index: 7),
        ],
        // Network interfaces chart
        if (_hasNetworkInterfaces(latestStats)) ...[
          const SizedBox(height: 12),
          _multiChartCard(
            context,
            title: 'Download by Interface (MB/s)',
            series: _networkInterfaceSeries(entries, metricIndex: 1, scale: 1 / (1024 * 1024)),
            baseTime: baseTime,
            ySuffix: ' MB/s',
            leftFractionDigits: 1,
            index: 8,
          ),
          const SizedBox(height: 12),
          _multiChartCard(
            context,
            title: 'Upload by Interface (MB/s)',
            series: _networkInterfaceSeries(entries, metricIndex: 0, scale: 1 / (1024 * 1024)),
            baseTime: baseTime,
            ySuffix: ' MB/s',
            leftFractionDigits: 1,
            index: 9,
          ),
          const SizedBox(height: 12),
          _multiChartCard(
            context,
            title: 'Total Download (GB)',
            series: _networkInterfaceSeries(entries, metricIndex: 3, scale: 1 / (1024 * 1024 * 1024)),
            baseTime: baseTime,
            ySuffix: ' GB',
            leftFractionDigits: 2,
            index: 10,
          ),
          const SizedBox(height: 12),
          _multiChartCard(
            context,
            title: 'Total Upload (GB)',
            series: _networkInterfaceSeries(entries, metricIndex: 2, scale: 1 / (1024 * 1024 * 1024)),
            baseTime: baseTime,
            ySuffix: ' GB',
            leftFractionDigits: 2,
            index: 11,
          ),
        ],
        // GPU Power chart
        if (_hasGpuPower(latestStats)) ...[
          const SizedBox(height: 12),
          _gpuPowerChart(context, entries, baseTime, index: 12),
        ],
        // Battery chart
        if (latestStats['bat'] is List && (latestStats['bat'] as List).isNotEmpty) ...[
          const SizedBox(height: 12),
          _chartCard(
            context,
            title: 'Battery %',
            color: Colors.amberAccent,
            spots: _spots(entries, (stats) {
              final bat = stats['bat'];
              if (bat is List && bat.isNotEmpty) return bat[0] as num?;
              return null;
            }),
            maxY: 100,
            baseTime: baseTime,
            ySuffix: '%',
            index: 13,
          ),
        ],
        ],
      ),
    );
  }

  static String _labelForChartTime(String chartTime) {
    switch (chartTime) {
      case '1m':
        return '1 minute';
      case '1h':
        return '1 hour';
      case '12h':
        return '12 hours';
      case '24h':
        return '24 hours';
      case '1w':
        return '1 week';
      case '30d':
        return '30 days';
      default:
        return chartTime;
    }
  }

  List<_ChartEntry> _buildEntries(List<RecordModel> records) {
    final list = records
        .map((r) {
          final createdRaw = r.data['created']?.toString();
          if (createdRaw == null) return null;
          DateTime? created;
          try {
            created = DateTime.parse(createdRaw).toUtc();
          } catch (_) {
            try {
              created = DateTime.parse('${createdRaw}Z').toUtc();
            } catch (_) {
              return null;
            }
          }
          final statsMap = r.data['stats'];
          if (statsMap is! Map) return null;
          return _ChartEntry(time: created, stats: Map<String, dynamic>.from(statsMap));
        })
        .whereType<_ChartEntry>()
        .toList()
      ..sort((a, b) => a.time.compareTo(b.time));
    return list;
  }

  List<FlSpot> _spots(List<_ChartEntry> entries, num? Function(Map<String, dynamic>) selector) {
    if (entries.isEmpty) return const [];
    final base = entries.first.time;
    final List<FlSpot> spots = [];
    for (final entry in entries) {
      final value = selector(entry.stats);
      if (value == null) continue;
      final pt = FlSpot(entry.time.difference(base).inMinutes.toDouble(), value.toDouble());
      spots.add(pt);
    }
    if (spots.length == 1) {
      // duplicate to avoid zero-width chart
      final spot = spots.first;
      spots.insert(0, FlSpot(max(spot.x - 1, 0), spot.y));
    }
    return spots;
  }

  Widget _chartCard(
    BuildContext context, {
    required String title,
    required Color color,
    required List<FlSpot> spots,
    double? maxY,
    DateTime? baseTime,
    String? ySuffix,
    int leftFractionDigits = 0,
    int? tooltipFractionDigits,
    int index = 0,
  }) {
    final scheme = Theme.of(context).colorScheme;
    if (spots.isEmpty) {
      return _AnimatedChartCard(
        index: index,
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text('$title: no data', style: Theme.of(context).textTheme.bodyMedium),
          ),
        ),
      );
    }
    final double computedMaxY = maxY ?? _maxY(spots) * 1.1;
    final resolvedBase = baseTime ?? DateTime.now();
    final maxX = spots.isNotEmpty ? spots.last.x : 1.0;
    final minX = spots.isNotEmpty ? spots.first.x : 0.0;
    final chartMaxX = maxX <= minX ? minX + 1 : maxX;
    return _AnimatedChartCard(
      index: index,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 12),
              SizedBox(
                height: 160,
                child: LineChart(
                  LineChartData(
                    minY: 0,
                    maxY: computedMaxY,
                    minX: minX,
                    maxX: chartMaxX,
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: true,
                      getDrawingVerticalLine: (value) => FlLine(
                        color: scheme.outlineVariant.withOpacity(.35),
                        strokeWidth: .5,
                      ),
                      getDrawingHorizontalLine: (value) => FlLine(color: scheme.outlineVariant, strokeWidth: .5),
                    ),
                    borderData: FlBorderData(show: false),
                    titlesData: _buildTitlesData(
                      baseTime: resolvedBase,
                      maxX: maxX,
                      maxY: computedMaxY,
                      scheme: scheme,
                      leftFractionDigits: leftFractionDigits,
                      leftFormatter: (value) => _formatLeftValue(
                        value,
                        ySuffix,
                        leftFractionDigits: leftFractionDigits,
                      ),
                    ),
                    lineTouchData: _buildTouchData(
                      baseTime: resolvedBase,
                      ySuffix: ySuffix,
                      fractionDigits: tooltipFractionDigits ?? leftFractionDigits,
                      scheme: scheme,
                    ),
                    lineBarsData: [
                      LineChartBarData(
                        spots: spots,
                        isCurved: true,
                        gradient: LinearGradient(colors: [color.withOpacity(.9), color.withOpacity(.6)]),
                        barWidth: 2,
                        dotData: const FlDotData(show: false),
                        belowBarData: BarAreaData(
                          show: true,
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [color.withOpacity(.25), color.withOpacity(.05)],
                          ),
                        ),
                      ),
                    ],
                  ),
                  duration: AppDurations.slow, // 400ms for smooth value transitions
                  curve: AppCurves.standard,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _multiChartCard(
    BuildContext context, {
    required String title,
    required List<_ChartSeries> series,
    DateTime? baseTime,
    String? ySuffix,
    int leftFractionDigits = 0,
    int? tooltipFractionDigits,
    int index = 0,
  }) {
    final filtered = series.where((s) => s.spots.isNotEmpty).toList();
    if (filtered.isEmpty) {
      return _AnimatedChartCard(
        index: index,
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text('$title: no data', style: Theme.of(context).textTheme.bodyMedium),
          ),
        ),
      );
    }
    final maxY = filtered.map((s) => _maxY(s.spots)).fold<double>(0, max) * 1.1;
    final scheme = Theme.of(context).colorScheme;
    final resolvedBase = baseTime ?? DateTime.now();
    final maxX = filtered.map((s) => s.spots.isNotEmpty ? s.spots.last.x : 0.0).fold<double>(0, max);
    final minX = filtered.map((s) => s.spots.isNotEmpty ? s.spots.first.x : 0.0).fold<double>(double.infinity, min);
    final safeMinX = minX.isFinite ? minX : 0.0;
    final chartMaxX = maxX <= safeMinX ? safeMinX + 1 : max(maxX, safeMinX + 1);
    return _AnimatedChartCard(
      index: index,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 12),
              SizedBox(
                height: 160,
                child: LineChart(
                  LineChartData(
                    minY: 0,
                    maxY: maxY == 0 ? 10 : maxY,
                    minX: safeMinX,
                    maxX: chartMaxX,
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: true,
                      getDrawingVerticalLine: (value) => FlLine(
                        color: scheme.outlineVariant.withOpacity(.35),
                        strokeWidth: .5,
                      ),
                      getDrawingHorizontalLine: (value) => FlLine(color: scheme.outlineVariant, strokeWidth: .5),
                    ),
                    borderData: FlBorderData(show: false),
                    titlesData: _buildTitlesData(
                      baseTime: resolvedBase,
                      maxX: chartMaxX,
                      maxY: maxY == 0 ? 10 : maxY,
                      scheme: scheme,
                      leftFractionDigits: leftFractionDigits,
                      leftFormatter: (value) => _formatLeftValue(
                        value,
                        ySuffix,
                        leftFractionDigits: leftFractionDigits,
                      ),
                    ),
                    lineTouchData: _buildTouchData(
                      baseTime: resolvedBase,
                      ySuffix: ySuffix,
                      fractionDigits: tooltipFractionDigits ?? leftFractionDigits,
                      scheme: scheme,
                    ),
                    lineBarsData: filtered
                        .map(
                          (s) => LineChartBarData(
                            spots: s.spots,
                            isCurved: true,
                            gradient: LinearGradient(colors: [s.color.withOpacity(.9), s.color.withOpacity(.6)]),
                            barWidth: 2,
                            dotData: const FlDotData(show: false),
                            belowBarData: BarAreaData(
                              show: true,
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [s.color.withOpacity(.25), s.color.withOpacity(.05)],
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                  duration: AppDurations.slow, // 400ms for smooth value transitions
                  curve: AppCurves.standard,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                children: filtered
                    .map(
                      (s) => Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(width: 10, height: 10, color: s.color),
                          const SizedBox(width: 4),
                          Text(s.label),
                        ],
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  double _maxY(List<FlSpot> spots) {
    return spots.fold<double>(0, (prev, s) => max(prev, s.y));
  }

  bool _hasCpuCores(Map<String, dynamic> stats) {
    return stats['cpus'] is List && (stats['cpus'] as List).length > 1;
  }

  List<_ChartSeries> _cpuCoreSeries(List<_ChartEntry> entries) {
    if (entries.isEmpty) return const [];
    final first = entries.first.stats['cpus'];
    if (first is! List || first.isEmpty) return const [];
    final totalCores = first.length;
    final limit = min(totalCores, 8);
    final List<_ChartSeries> series = [];

    for (var i = 0; i < limit; i++) {
      final spots = _spotsFromCpuCore(entries, i);
      if (spots.isEmpty) continue;
      final hue = (i * 360 / limit) % 360;
      final color = HSVColor.fromAHSV(1.0, hue, 0.65, 0.52).toColor();
      series.add(_ChartSeries('Core ${i + 1}', color, spots));
    }
    return series;
  }

  bool _hasNetworkInterfaces(Map<String, dynamic> stats) {
    if (stats['ni'] is! Map) return false;
    final ni = stats['ni'] as Map;
    return ni.isNotEmpty;
  }

  List<_ChartSeries> _networkInterfaceSeries(
    List<_ChartEntry> entries, {
    required int metricIndex,
    double scale = 1.0,
  }) {
    if (entries.isEmpty) return const [];
    final ni = entries.first.stats['ni'];
    if (ni is! Map || ni.isEmpty) return const [];

    final interfaceNames = ni.keys.toList();
    final limit = min(interfaceNames.length, 6);
    final List<_ChartSeries> series = [];

    for (var i = 0; i < limit; i++) {
      final name = interfaceNames[i];
      final spots = _spotsFromNetworkInterface(entries, name, metricIndex, scale);
      if (spots.isEmpty) continue;
      final hue = (i * 360 / limit) % 360;
      final color = HSVColor.fromAHSV(1.0, hue, 0.5, 0.55).toColor();
      series.add(_ChartSeries(name.toString(), color, spots));
    }
    return series;
  }

  bool _hasLoadAverage(Map<String, dynamic> stats) {
    return stats['la'] is List || stats['l1'] != null || stats['l5'] != null || stats['l15'] != null;
  }

  List<_ChartSeries> _loadAverageSeries(List<_ChartEntry> entries) {
    final series = <_ChartSeries>[];
    // Check if we have la array (new format) or legacy l1/l5/l15
    final first = entries.isNotEmpty ? entries.first.stats : <String, dynamic>{};
    if (first['la'] is List) {
      // New format: la is [1min, 5min, 15min]
      series.add(_ChartSeries('1 min', const Color(0xFF9C27B0), _spots(entries, (stats) {
        final la = stats['la'];
        return la is List && la.length > 0 ? la[0] : null;
      })));
      series.add(_ChartSeries('5 min', const Color(0xFF2196F3), _spots(entries, (stats) {
        final la = stats['la'];
        return la is List && la.length > 1 ? la[1] : null;
      })));
      series.add(_ChartSeries('15 min', const Color(0xFFFF9800), _spots(entries, (stats) {
        final la = stats['la'];
        return la is List && la.length > 2 ? la[2] : null;
      })));
    } else {
      // Legacy format
      series.add(_ChartSeries('1 min', const Color(0xFF9C27B0), _spots(entries, (stats) => stats['l1'])));
      series.add(_ChartSeries('5 min', const Color(0xFF2196F3), _spots(entries, (stats) => stats['l5'])));
      series.add(_ChartSeries('15 min', const Color(0xFFFF9800), _spots(entries, (stats) => stats['l15'])));
    }
    return series;
  }

  bool _hasGpuPower(Map<String, dynamic> stats) {
    if (stats['g'] is! Map) return false;
    final gpus = stats['g'] as Map;
    for (final gpu in gpus.values) {
      if (gpu is Map && (gpu['p'] != null || gpu['pp'] != null)) {
        return true;
      }
    }
    return false;
  }

  Widget _temperatureChart(
    BuildContext context,
    List<_ChartEntry> entries,
    Map tempSensors,
    DateTime baseTime, {
    int index = 0,
  }) {
    final sensorNames = tempSensors.keys.toList();
    if (sensorNames.isEmpty) return const SizedBox.shrink();
    
    // Limit to 8 sensors for readability
    final limitedSensors = sensorNames.length > 8 ? sensorNames.sublist(0, 8) : sensorNames;
    
    final series = limitedSensors.map((name) {
      final hue = (sensorNames.indexOf(name) * 360 / sensorNames.length) % 360;
      final color = HSVColor.fromAHSV(1.0, hue, 0.6, 0.55).toColor();
      return _ChartSeries(
        name.toString(),
        color,
        _spots(entries, (stats) {
          final t = stats['t'];
          if (t is Map) return t[name] as num?;
          return null;
        }),
      );
    }).toList();
    
    return _multiChartCard(
      context,
      title: 'Temperature (°C)',
      series: series,
      baseTime: baseTime,
      leftFractionDigits: 1,
      ySuffix: '°C',
      index: index,
    );
  }

  Widget _gpuPowerChart(BuildContext context, List<_ChartEntry> entries, DateTime baseTime, {int index = 0}) {
    // Collect all GPU names and their power data
    final gpuData = <String, List<FlSpot>>{};
    
    for (final entry in entries) {
      final g = entry.stats['g'];
      if (g is! Map) continue;
      
      for (final entry2 in g.entries) {
        final gpuId = entry2.key;
        final gpu = entry2.value;
        if (gpu is! Map) continue;
        
        final gpuName = gpu['n']?.toString() ?? gpuId;
        final power = gpu['p'] as num? ?? gpu['pp'] as num?;
        if (power == null) continue;
        
        final time = entry.time.difference(baseTime).inMinutes.toDouble();
        gpuData.putIfAbsent(gpuName, () => []).add(FlSpot(time, power.toDouble()));
      }
    }
    
    if (gpuData.isEmpty) return const SizedBox.shrink();
    
    final series = gpuData.entries.map((e) {
      final idx = gpuData.keys.toList().indexOf(e.key);
      final hue = (idx * 360 / gpuData.length) % 360;
      final color = HSVColor.fromAHSV(1.0, hue, 0.65, 0.52).toColor();
      return _ChartSeries('${e.key} Power', color, e.value);
    }).toList();
    
    return _multiChartCard(
      context,
      title: 'GPU Power (W)',
      series: series,
      baseTime: baseTime,
      ySuffix: ' W',
      index: index,
    );
  }

  List<FlSpot> _spotsFromCpuCore(List<_ChartEntry> entries, int coreIndex) {
    if (entries.isEmpty) return const [];
    final base = entries.first.time;
    final List<FlSpot> spots = [];
    for (final entry in entries) {
      final cpus = entry.stats['cpus'];
      if (cpus is List && cpus.length > coreIndex) {
        final value = cpus[coreIndex];
        if (value is num) {
          spots.add(FlSpot(entry.time.difference(base).inMinutes.toDouble(), value.toDouble()));
        }
      }
    }
    return _ensureSpotsRenderable(spots);
  }

  List<FlSpot> _spotsFromNetworkInterface(
    List<_ChartEntry> entries,
    dynamic interfaceName,
    int index,
    double scale,
  ) {
    if (entries.isEmpty) return const [];
    final base = entries.first.time;
    final List<FlSpot> spots = [];
    for (final entry in entries) {
      final ni = entry.stats['ni'];
      if (ni is Map) {
        final ifaceData = ni[interfaceName];
        if (ifaceData is List && ifaceData.length > index) {
          final value = ifaceData[index];
          if (value is num) {
            spots.add(FlSpot(entry.time.difference(base).inMinutes.toDouble(), value.toDouble() * scale));
          }
        }
      }
    }
    return _ensureSpotsRenderable(spots);
  }

  List<FlSpot> _ensureSpotsRenderable(List<FlSpot> spots) {
    if (spots.length == 1) {
      final spot = spots.first;
      spots.insert(0, FlSpot(max(spot.x - 1, 0), spot.y));
    }
    return spots;
  }

  FlTitlesData _buildTitlesData({
    required DateTime baseTime,
    required double maxX,
    required double maxY,
    required ColorScheme scheme,
    required int leftFractionDigits,
    required String Function(double) leftFormatter,
  }) {
    final double safeMaxX = max(maxX, 1.0);
    final double safeMaxY = max(maxY, 1.0);
    final double bottomInterval = _niceInterval(safeMaxX, 4);
    final double leftInterval = _niceInterval(safeMaxY, 5);
    final double totalMinutes = safeMaxX;

    return FlTitlesData(
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          interval: bottomInterval,
          reservedSize: 36,
          getTitlesWidget: (value, meta) {
            if (value < 0 || value - safeMaxX > 0.0001) {
              return const SizedBox.shrink();
            }
            final dt = baseTime.add(Duration(minutes: value.round()));
            final label = _formatTimeLabel(dt.toLocal(), totalMinutes);
            return Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            );
          },
        ),
      ),
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          interval: leftInterval,
          reservedSize: 44,
          getTitlesWidget: (value, meta) {
            if (value < 0 || value - safeMaxY > 0.0001) {
              return const SizedBox.shrink();
            }
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Text(
                leftFormatter(value),
                style: TextStyle(
                  fontSize: 11,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            );
          },
        ),
      ),
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    );
  }

  String _formatTimeLabel(DateTime dateTime, double spanMinutes) {
    String two(int n) => n.toString().padLeft(2, '0');
    if (spanMinutes <= 60) {
      return '${two(dateTime.hour)}:${two(dateTime.minute)}';
    }
    if (spanMinutes <= 24 * 60) {
      return '${two(dateTime.hour)}:${two(dateTime.minute)}';
    }
    if (spanMinutes <= 7 * 24 * 60) {
      const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      final weekday = weekdays[dateTime.weekday - 1];
      return '$weekday ${two(dateTime.hour)}:${two(dateTime.minute)}';
    }
    if (spanMinutes <= 30 * 24 * 60) {
      return '${dateTime.month}/${dateTime.day}';
    }
    return '${dateTime.month}/${dateTime.day}/${dateTime.year % 100}';
  }

  double _niceInterval(double maxValue, int targetTicks) {
    if (maxValue <= 0 || targetTicks <= 0) return 1;
    final rawInterval = maxValue / targetTicks;
    if (rawInterval <= 0) return 1;
    final exponent = rawInterval == 0 ? 0 : (log(rawInterval) / log(10)).floor();
    final magnitude = pow(10, exponent).toDouble();
    final residual = rawInterval / magnitude;
    double nice;
    if (residual < 1.5) {
      nice = 1;
    } else if (residual < 3) {
      nice = 2;
    } else if (residual < 7) {
      nice = 5;
    } else {
      nice = 10;
    }
    final interval = nice * magnitude;
    return interval <= 0 ? 1 : interval;
  }

  String _formatLeftValue(double value, String? suffix, {int leftFractionDigits = 0}) {
    final formatted = value.toStringAsFixed(leftFractionDigits);
    if (suffix == null || suffix.isEmpty) {
      return formatted;
    }
    return '$formatted$suffix';
  }

  LineTouchData _buildTouchData({
    required DateTime baseTime,
    String? ySuffix,
    required int fractionDigits,
    required ColorScheme scheme,
  }) {
    final int clampedDigits = fractionDigits < 0
        ? 0
        : fractionDigits > 3
            ? 3
            : fractionDigits;
    return LineTouchData(
      enabled: true,
      touchTooltipData: LineTouchTooltipData(
        fitInsideHorizontally: true,
        fitInsideVertically: true,
        getTooltipItems: (touchedSpots) {
          return touchedSpots.map((spot) {
            final double value = spot.y;
            final String suffix = ySuffix ?? '';
            final String formattedValue = value.toStringAsFixed(clampedDigits);
            final String timeLabel = _formatTooltipTime(baseTime, spot.x);
            final Color textColor = scheme.onSurface;
            return LineTooltipItem(
              '$formattedValue$suffix',
              TextStyle(
                color: textColor,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
              children: [
                TextSpan(
                  text: '\n$timeLabel',
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            );
          }).toList();
        },
      ),
    );
  }

  String _formatTooltipTime(DateTime baseTime, double minutesOffset) {
    final DateTime local = baseTime.add(Duration(minutes: minutesOffset.round())).toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    final String timePart = '${two(local.hour)}:${two(local.minute)}';
    final DateTime today = DateTime.now();
    final bool sameDay = local.year == today.year && local.month == today.month && local.day == today.day;
    final bool sameYear = local.year == today.year;
    final datePart = sameDay
        ? ''
        : sameYear
            ? '${local.month}/${local.day} '
            : '${local.month}/${local.day}/${local.year % 100} ';
    return '$datePart$timePart'.trim();
  }
}

class _ChartEntry {
  _ChartEntry({required this.time, required this.stats});

  final DateTime time;
  final Map<String, dynamic> stats;
}

class _ChartSeries {
  _ChartSeries(this.label, this.color, this.spots);

  final String label;
  final Color color;
  final List<FlSpot> spots;
}

/// Animated wrapper for chart cards that provides fade-in and slide-up animation
/// on initial load with staggered delays based on index.
class _AnimatedChartCard extends StatefulWidget {
  const _AnimatedChartCard({
    required this.child,
    this.index = 0,
  });

  final Widget child;
  final int index;

  @override
  State<_AnimatedChartCard> createState() => _AnimatedChartCardState();
}

class _AnimatedChartCardState extends State<_AnimatedChartCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppDurations.chart,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: AppCurves.enter,
    ));
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: AppCurves.enter,
    ));
    
    // Stagger the animation start based on index
    Future.delayed(
      Duration(milliseconds: widget.index * 100),
      () {
        if (mounted) {
          _controller.forward();
        }
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: widget.child,
      ),
    );
  }
}



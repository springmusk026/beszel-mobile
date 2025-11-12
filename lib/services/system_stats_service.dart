import 'dart:async';
import 'package:pocketbase/pocketbase.dart';

import '../api/pb_client.dart';

class SystemStatsService {
  RecordService get _collection => pb.collection('system_stats');

  final _controller = StreamController<RecordModel?>.broadcast();
  Stream<RecordModel?> get stream => _controller.stream;

  UnsubscribeFunc? _unsub;
  String? _systemId;

  Future<RecordModel?> fetchLatest(String systemId) async {
    final res = await _collection.getList(
      page: 1,
      perPage: 1,
      filter: 'system="$systemId"',
      sort: '-created',
      fields: 'stats,created,system',
    );
    return res.items.isEmpty ? null : res.items.first;
  }

  Future<List<RecordModel>> fetchSeries(String systemId, String chartTime) async {
    final timestamp = _chartTimeToTimestamp(chartTime);
    final res = await _collection.getList(
      page: 1,
      perPage: 500,
      filter: 'system="$systemId"${timestamp != null ? ' && created>="$timestamp"' : ''}',
      sort: '+created',
      fields: 'stats,created,system',
    );
    return res.items;
  }

  String? _chartTimeToTimestamp(String chartTime) {
    final now = DateTime.now().toUtc();
    Duration? offset;
    switch (chartTime) {
      case '1m':
        offset = const Duration(minutes: 1);
        break;
      case '1h':
        offset = const Duration(hours: 1);
        break;
      case '12h':
        offset = const Duration(hours: 12);
        break;
      case '24h':
        offset = const Duration(hours: 24);
        break;
      case '1w':
        offset = const Duration(days: 7);
        break;
      case '30d':
        offset = const Duration(days: 30);
        break;
    }
    if (offset == null) return null;
    final dt = now.subtract(offset);
    return '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
  }

  Future<void> subscribeToSystem(String systemId) async {
    await unsubscribe();
    _systemId = systemId;
    _unsub = await _collection.subscribe('*', (event) {
      final data = event.record?.data ?? const <String, dynamic>{};
      if (data['system'] == _systemId) {
        _controller.add(event.record);
      }
    }, fields: 'stats,created,system');
  }

  Future<void> unsubscribe() async {
    _unsub?.call();
    _unsub = null;
    _systemId = null;
  }

  void dispose() {
    unsubscribe();
    _controller.close();
  }
}



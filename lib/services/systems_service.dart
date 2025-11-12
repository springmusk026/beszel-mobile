import 'dart:async';
import 'package:pocketbase/pocketbase.dart';

import '../api/pb_client.dart';
import '../models/system_record.dart';

class SystemsService {
  SystemsService._internal();
  static final SystemsService _instance = SystemsService._internal();
  factory SystemsService() => _instance;

  RecordService get _collection => pb.collection('systems');

  final List<SystemRecord> _systems = <SystemRecord>[];
  final _controller = StreamController<List<SystemRecord>>.broadcast();
  Stream<List<SystemRecord>> get stream => _controller.stream;

  bool _subscribed = false;
  UnsubscribeFunc? _unsub;

  Future<List<SystemRecord>> fetchAll() async {
    final records = await _collection.getFullList(
      sort: '+name',
      fields: 'id,name,host,port,info,status,updated,v',
    );
    final list = records.map((r) => SystemRecord.fromMap(r.toJson())).toList();
    _replaceAll(list);
    return List<SystemRecord>.unmodifiable(_systems);
  }

  Future<void> subscribe() async {
    if (_subscribed) return;
    _subscribed = true;
    _unsub = await _collection.subscribe('*', (event) {
      final data = event.record?.toJson() ?? {};
      final record = SystemRecord.fromMap(data);
      switch (event.action) {
        case 'create':
          _upsert(record);
          break;
        case 'update':
          _upsert(record);
          break;
        case 'delete':
          _remove(record.id);
          break;
      }
    }, fields: 'id,name,host,port,info,status,updated,v');
  }

  Future<void> unsubscribe() async {
    _unsub?.call();
    _unsub = null;
    _subscribed = false;
  }

  void _replaceAll(List<SystemRecord> list) {
    _systems
      ..clear()
      ..addAll(list);
    _systems.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    _controller.add(List<SystemRecord>.unmodifiable(_systems));
  }

  void _upsert(SystemRecord record) {
    final idx = _systems.indexWhere((s) => s.id == record.id);
    if (idx >= 0) {
      _systems[idx] = record;
    } else {
      _systems.add(record);
    }
    _systems.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    _controller.add(List<SystemRecord>.unmodifiable(_systems));
  }

  void _remove(String id) {
    _systems.removeWhere((s) => s.id == id);
    _controller.add(List<SystemRecord>.unmodifiable(_systems));
  }
}



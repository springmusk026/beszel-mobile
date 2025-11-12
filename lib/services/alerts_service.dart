import 'dart:async';
import 'package:pocketbase/pocketbase.dart';

import '../api/pb_client.dart';

class AlertsService {
  RecordService get _alerts => pb.collection('alerts');
  RecordService get _history => pb.collection('alerts_history');

  final _controller = StreamController<List<RecordModel>>.broadcast();
  Stream<List<RecordModel>> get stream => _controller.stream;
  final List<RecordModel> _active = <RecordModel>[];
  UnsubscribeFunc? _unsub;
  bool _subscribed = false;

  Future<List<RecordModel>> fetchActive() async {
    final res = await _alerts.getList(
      page: 1,
      perPage: 200,
      filter: 'triggered=true',
      sort: '-updated',
      fields: 'id,system,name,value,min,triggered,updated,expand.system.name',
      expand: 'system',
    );
    _active
      ..clear()
      ..addAll(res.items);
    _controller.add(List<RecordModel>.unmodifiable(_active));
    return List<RecordModel>.unmodifiable(_active);
  }

  Future<List<RecordModel>> fetchHistory({required String systemId, int page = 1}) async {
    final res = await _history.getList(
      page: page,
      perPage: 50,
      filter: 'system="$systemId"',
      sort: '-created',
      fields: 'alert,system,name,val,created,resolved',
    );
    return res.items;
  }

  Future<void> subscribeActive() async {
    if (_subscribed) return;
    _subscribed = true;
    _unsub = await _alerts.subscribe('*', (event) {
      final rec = event.record;
      if (rec == null) return;
      final isTriggered = rec.data['triggered'] == true;
      final idx = _active.indexWhere((r) => r.id == rec.id);
      if (event.action == 'delete') {
        if (idx >= 0) _active.removeAt(idx);
      } else {
        if (isTriggered) {
          if (idx >= 0) {
            _active[idx] = rec;
          } else {
            _active.insert(0, rec);
          }
        } else if (idx >= 0) {
          _active.removeAt(idx);
        }
      }
      _controller.add(List<RecordModel>.unmodifiable(_active));
    }, fields: 'id,system,name,value,min,triggered,updated');
  }

  Future<void> unsubscribe() async {
    _unsub?.call();
    _unsub = null;
    _subscribed = false;
  }
}



import 'package:pocketbase/pocketbase.dart';
import 'dart:async';
import '../api/pb_client.dart';

class FingerprintsService {
  RecordService get _collection => pb.collection('fingerprints');

  Future<List<RecordModel>> fetchAll() async {
    final records = await _collection.getFullList(
      expand: 'system',
      fields: 'id,fingerprint,token,system,expand.system',
    );
    final list = List<RecordModel>.from(records);
    list.sort((a, b) {
      final aName = _systemName(a);
      final bName = _systemName(b);
      return aName.compareTo(bName);
    });
    return list;
  }

  Future<void> rotateToken(String id, String newToken) async {
    await _collection.update(id, body: {'token': newToken});
  }

  Future<void> clearFingerprint(String id) async {
    await _collection.update(id, body: {'fingerprint': ''});
  }

  String _systemName(RecordModel record) {
  final expanded = record.expand?['system'];
  
  if (expanded case RecordModel systemRecord) {
    return systemRecord.data['name']?.toString() ?? '';
  }
  
  if (expanded case List records) {
    for (final item in records) {
      if (item case RecordModel systemRecord) {
        final name = systemRecord.data['name']?.toString();
        if (name != null && name.isNotEmpty) {
          return name;
        }
      }
    }
  }
  
  return record.data['system']?.toString() ?? '';
}
}




import 'package:pocketbase/pocketbase.dart';

import '../api/pb_client.dart';
import '../models/user_settings.dart';

class SettingsService {
  RecordService get _collection => pb.collection('user_settings');

  Future<UserSettings> fetchOrCreate() async {
    try {
      final rec = await _collection.getFirstListItem('');
      return UserSettings.fromMap(rec.toJson());
    } catch (_) {
      final created = await _collection.create(body: {'user': pb.authStore.record?.id});
      return UserSettings.fromMap(created.toJson());
    }
  }

  Future<UserSettings> update(UserSettings settings) async {
    final rec = await _collection.update(settings.id, body: settings.toUpdateMap());
    return UserSettings.fromMap(rec.toJson());
  }
}



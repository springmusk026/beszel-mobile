import 'package:flutter/foundation.dart';
import 'package:pocketbase/pocketbase.dart';

import '../api/pb_client.dart';

class SystemdService {
  RecordService get _collection => pb.collection('systemd_services');

  Future<List<RecordModel>> fetchForSystem(String systemId) async {
    try {
      final res = await _collection.getList(
        page: 1,
        perPage: 200,
        filter: 'system="$systemId"',
        sort: '+name',
        fields: 'system,name,state,sub,cpu,cpuPeak,memory,memPeak,updated',
        expand: 'system',
      );
      return res.items;
    } on ClientException catch (e) {
      if (e.statusCode == 404) {
        return const [];
      }
      debugPrint('systemd fetch error: ${e.statusCode} ${e.response}');
      rethrow;
    }
  }
}



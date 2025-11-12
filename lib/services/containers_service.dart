import 'package:pocketbase/pocketbase.dart';

import '../api/pb_client.dart';

class ContainersService {
  RecordService get _collection => pb.collection('containers');

  Future<List<RecordModel>> fetchForSystem(String systemId) async {
    final res = await _collection.getList(
      page: 1,
      perPage: 200,
      filter: 'system="$systemId"',
      sort: '+name',
      fields: 'id,system,name,image,cpu,memory,net,health,status,updated',
    );
    return res.items;
  }
}



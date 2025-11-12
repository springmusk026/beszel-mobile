import 'package:pocketbase/pocketbase.dart';

import '../api/pb_client.dart';

class UniversalTokenState {
  final String token;
  final bool active;
  const UniversalTokenState({required this.token, required this.active});
}

class UniversalTokenService {
  Future<UniversalTokenState> getState() async {
    final res = await pb.send<Map<String, dynamic>>('/api/beszel/universal-token');
    final token = res['token']?.toString() ?? '';
    final active = res['active'] == true;
    return UniversalTokenState(token: token, active: active);
  }

  Future<UniversalTokenState> setActive(bool active, {String token = ''}) async {
    final res = await pb.send<Map<String, dynamic>>(
      '/api/beszel/universal-token',
      query: {
        'enable': active ? 1 : 0,
        if (token.isNotEmpty) 'token': token,
      },
    );
    final newToken = res['token']?.toString() ?? '';
    final isActive = res['active'] == true;
    return UniversalTokenState(token: newToken, active: isActive);
  }
}



import 'dart:math';
import '../api/pb_client.dart';

class PublicKeyService {
  static String? _cachedKey;

  Future<String> getPublicKey() async {
    if (_cachedKey != null) return _cachedKey!;
    try {
      final response = await pb.send<Map<String, dynamic>>('/api/beszel/getkey', body: {});
      _cachedKey = response['key'] as String;
      return _cachedKey!;
    } catch (e) {
      throw Exception('Failed to fetch public key: $e');
    }
  }

  static String generateToken() {
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random.secure();
    return List.generate(32, (_) => chars[random.nextInt(chars.length)]).join();
  }
}


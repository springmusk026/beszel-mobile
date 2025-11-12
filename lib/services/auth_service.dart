import 'dart:async';

import 'package:pocketbase/pocketbase.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/pb_client.dart';

class AuthService {
  static const _tokenKey = 'pb_auth_token';

  Future<bool> isAuthenticated() async {
    // If auth store already valid, short-circuit
    if (pb.authStore.isValid) return true;
    // Try restore from shared preferences
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);
    if (token == null || token.isEmpty) return false;
    pb.authStore.save(token, pb.authStore.model);
    return pb.authStore.isValid;
  }

  Future<void> login(String email, String password) async {
    final authData = await pb.collection('users').authWithPassword(email, password);
    pb.authStore.save(authData.token, authData.record);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, authData.token);
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    pb.authStore.clear();
    pb.realtime.unsubscribe();
  }

  Future<void> refreshAuth() async {
    try {
      await pb.collection('users').authRefresh();
    } on ClientException {
      await logout();
      rethrow;
    }
  }

  Future<void> requestPasswordReset(String email) async {
    await pb.collection('users').requestPasswordReset(email);
  }

  Future<String> requestOTP(String email) async {
    final result = await pb.collection('users').requestOTP(email);
    return result.otpId;
  }

  Future<void> authWithOTP(String otpId, String otp) async {
    final authData = await pb.collection('users').authWithOTP(otpId, otp);
    pb.authStore.save(authData.token, authData.record);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, authData.token);
  }
}



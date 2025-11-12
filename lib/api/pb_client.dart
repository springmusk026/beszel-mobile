import 'package:flutter/foundation.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Global PocketBase client configured to the Beszel base URL.]

class PocketBaseManager {
  PocketBaseManager._();
  static final PocketBaseManager instance = PocketBaseManager._();

  static const String defaultBaseUrl = 'https://demo.beszel.dev/';
  static const String _prefsKey = 'pb_base_url';

  final ValueNotifier<String> baseUrl = ValueNotifier(defaultBaseUrl);
  PocketBase _client = PocketBase(defaultBaseUrl);

  PocketBase get client => _client;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefsKey);
    if (saved != null && saved.isNotEmpty) {
      await setBaseUrl(saved, persist: false);
    }
  }

  /// Check if a base URL has been explicitly configured by the user
  Future<bool> hasConfiguredBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_prefsKey) && prefs.getString(_prefsKey)?.isNotEmpty == true;
  }

  Future<void> setBaseUrl(String url, {bool persist = true}) async {
    final normalized = _normalize(url);
    baseUrl.value = normalized;
    _client = PocketBase(normalized);
    if (persist) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, normalized);
    }
  }

  Future<void> reset() async {
    await setBaseUrl(defaultBaseUrl);
  }

  String _normalize(String url) {
    var trimmed = url.trim();
    if (!trimmed.startsWith('http://') && !trimmed.startsWith('https://')) {
      trimmed = 'https://$trimmed';
    }
    // remove trailing slashes
    trimmed = trimmed.replaceAll(RegExp(r'/+$'), '');
    return trimmed;
  }
}

PocketBase get pb => PocketBaseManager.instance.client;
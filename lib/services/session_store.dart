import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/services.dart';

class StoredSession {
  const StoredSession({required this.baseUrl, required this.accessToken});

  final String baseUrl;
  final String accessToken;
}

class SessionStore {
  const SessionStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _baseUrlKey = 'base_url';
  static const _accessTokenKey = 'access_token';

  Future<StoredSession?> load() async {
    final String? baseUrl;
    final String? accessToken;
    try {
      baseUrl = await _storage.read(key: _baseUrlKey);
      accessToken = await _storage.read(key: _accessTokenKey);
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
    if (baseUrl == null ||
        baseUrl.isEmpty ||
        accessToken == null ||
        accessToken.isEmpty) {
      return null;
    }
    return StoredSession(baseUrl: baseUrl, accessToken: accessToken);
  }

  Future<void> save({
    required String baseUrl,
    required String accessToken,
  }) async {
    try {
      await _storage.write(key: _baseUrlKey, value: baseUrl);
      await _storage.write(key: _accessTokenKey, value: accessToken);
    } on MissingPluginException {
      return;
    } on PlatformException {
      return;
    }
  }

  Future<void> clear() async {
    try {
      await _storage.delete(key: _accessTokenKey);
    } on MissingPluginException {
      return;
    } on PlatformException {
      return;
    }
  }
}

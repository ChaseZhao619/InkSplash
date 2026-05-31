import '../models.dart';
import 'api_client.dart';

class ProfileService {
  const ProfileService(this._api);

  final EpaperApiClient _api;

  Future<User> getProfile(String bearerToken) async {
    final json = await _api.getJson(
      '/api/me/profile',
      bearerToken: bearerToken,
    );
    return User.fromJson(json['user'] is Map ? _map(json['user']) : json);
  }

  Future<User> updateProfile({
    required String bearerToken,
    String? displayName,
  }) async {
    final json = await _api.patchJson(
      '/api/me/profile',
      bearerToken: bearerToken,
      body: {'display_name': displayName},
    );
    return User.fromJson(json['user'] is Map ? _map(json['user']) : json);
  }

  Future<StorageSummary> getStorage(String bearerToken) async {
    final json = await _api.getJson(
      '/api/me/storage',
      bearerToken: bearerToken,
    );
    return StorageSummary.fromJson(json);
  }

  Future<UserPreferences> getPreferences(String bearerToken) async {
    final json = await _api.getJson(
      '/api/me/preferences',
      bearerToken: bearerToken,
    );
    return UserPreferences.fromJson(json);
  }

  Future<UserPreferences> updatePreferences({
    required String bearerToken,
    required UserPreferences preferences,
  }) async {
    final json = await _api.patchJson(
      '/api/me/preferences',
      bearerToken: bearerToken,
      body: preferences.toJson(),
    );
    return UserPreferences.fromJson(json);
  }
}

Map<String, dynamic> _map(Object? value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return value.map((key, value) => MapEntry('$key', value));
  }
  return const {};
}

import '../models.dart';
import 'api_client.dart';

class NotificationService {
  const NotificationService(this._api);

  final EpaperApiClient _api;

  Future<List<InkNotification>> listNotifications(String bearerToken) async {
    final json = await _api.getJson(
      '/api/me/notifications',
      bearerToken: bearerToken,
    );
    final raw = json['notifications'] ?? json['items'] ?? [];
    if (raw is! List) {
      return const [];
    }
    return raw
        .whereType<Map>()
        .map(
          (item) => InkNotification.fromJson(
            item.map((key, value) => MapEntry('$key', value)),
          ),
        )
        .toList(growable: false);
  }

  Future<void> markRead({
    required String bearerToken,
    required String notificationId,
  }) async {
    await _api.patchJson(
      '/api/me/notifications/$notificationId/read',
      bearerToken: bearerToken,
    );
  }

  Future<UserPreferences> getSettings(String bearerToken) async {
    final json = await _api.getJson(
      '/api/me/notification-settings',
      bearerToken: bearerToken,
    );
    return UserPreferences.fromJson(json);
  }

  Future<UserPreferences> updateSettings({
    required String bearerToken,
    required UserPreferences preferences,
  }) async {
    final json = await _api.patchJson(
      '/api/me/notification-settings',
      bearerToken: bearerToken,
      body: preferences.toJson(),
    );
    return UserPreferences.fromJson(json);
  }
}

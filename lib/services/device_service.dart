import '../models.dart';
import 'api_client.dart';

class DeviceBindingService {
  const DeviceBindingService(this._api);

  final EpaperApiClient _api;

  Future<AppDevice> claimDevice({
    required String bearerToken,
    required String deviceId,
    required String claimCode,
    String? nickname,
  }) async {
    final json = await _api.postJson(
      '/api/me/devices/claim',
      bearerToken: bearerToken,
      body: {
        'device_id': deviceId,
        'claim_code': claimCode,
        'nickname': nickname,
      },
    );
    return AppDevice.fromJson(json);
  }

  Future<List<AppDevice>> listDevices(String bearerToken) async {
    final json = await _api.getJson(
      '/api/me/devices',
      bearerToken: bearerToken,
    );
    final raw = json['devices'] ?? json['items'] ?? [];
    if (raw is! List) {
      return const [];
    }
    return raw
        .whereType<Map>()
        .map(
          (item) => AppDevice.fromJson(
            item.map((key, value) => MapEntry('$key', value)),
          ),
        )
        .toList(growable: false);
  }

  Future<AppDevice> createVirtualDevice({
    required String bearerToken,
    String nickname = 'Test Frame',
    String profile = 'six_color_eink',
  }) async {
    final json = await _api.postJson(
      '/api/me/devices/virtual',
      bearerToken: bearerToken,
      body: {'nickname': nickname, 'profile': profile},
    );
    return AppDevice.fromJson(
      json['device'] is Map ? _map(json['device']) : json,
    );
  }

  Future<AppDevice> getDevice({
    required String bearerToken,
    required String deviceId,
  }) async {
    final json = await _api.getJson(
      '/api/me/devices/$deviceId',
      bearerToken: bearerToken,
    );
    return AppDevice.fromJson(json);
  }

  Future<void> unbindDevice({
    required String bearerToken,
    required String deviceId,
  }) async {
    await _api.deleteJson(
      '/api/me/devices/$deviceId',
      bearerToken: bearerToken,
    );
  }

  Future<AppDevice> updateDevice({
    required String bearerToken,
    required String deviceId,
    String? nickname,
  }) async {
    final json = await _api.patchJson(
      '/api/me/devices/$deviceId',
      bearerToken: bearerToken,
      body: {'nickname': nickname},
    );
    return AppDevice.fromJson(json);
  }

  Future<DeviceManifest> assignImage({
    required String bearerToken,
    required String deviceId,
    required String imageId,
  }) async {
    final json = await _api.postJson(
      '/api/me/devices/$deviceId/assign',
      bearerToken: bearerToken,
      body: {'image_id': imageId},
    );
    return DeviceManifest.fromJson(json);
  }

  Future<DeviceInvite> createInvite({
    required String bearerToken,
    required String deviceId,
    required String email,
    required String role,
  }) async {
    final json = await _api.postJson(
      '/api/me/devices/$deviceId/invites',
      bearerToken: bearerToken,
      body: {'email': email, 'role': role},
    );
    return DeviceInvite.fromJson(json);
  }

  Future<AppDevice> acceptInvite({
    required String bearerToken,
    required String token,
  }) async {
    final json = await _api.postJson(
      '/api/me/device-invites/accept',
      bearerToken: bearerToken,
      body: {'token': token},
    );
    return AppDevice.fromJson(json);
  }

  Future<List<DeviceMember>> listMembers({
    required String bearerToken,
    required String deviceId,
  }) async {
    final json = await _api.getJson(
      '/api/me/devices/$deviceId/members',
      bearerToken: bearerToken,
    );
    final raw = json['members'] ?? [];
    if (raw is! List) {
      return const [];
    }
    return raw
        .whereType<Map>()
        .map(
          (item) => DeviceMember.fromJson(
            item.map((key, value) => MapEntry('$key', value)),
          ),
        )
        .toList(growable: false);
  }

  Future<void> removeMember({
    required String bearerToken,
    required String deviceId,
    required String userId,
  }) async {
    await _api.deleteJson(
      '/api/me/devices/$deviceId/members/$userId',
      bearerToken: bearerToken,
    );
  }

  Future<List<StatusEvent>> listStatusEvents({
    required String bearerToken,
    required String deviceId,
    int limit = 50,
  }) async {
    final json = await _api.getJson(
      '/api/me/devices/$deviceId/status-events?limit=$limit',
      bearerToken: bearerToken,
    );
    final raw = json['events'] ?? [];
    if (raw is! List) {
      return const [];
    }
    return raw
        .whereType<Map>()
        .map(
          (item) => StatusEvent.fromJson(
            item.map((key, value) => MapEntry('$key', value)),
          ),
        )
        .toList(growable: false);
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

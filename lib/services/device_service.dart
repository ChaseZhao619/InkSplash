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
}

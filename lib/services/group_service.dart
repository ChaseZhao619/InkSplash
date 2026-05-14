import '../models.dart';
import 'api_client.dart';

class GroupService {
  const GroupService(this._api);

  final EpaperApiClient _api;

  Future<List<AccountGroup>> listGroups(String bearerToken) async {
    final json = await _api.getJson('/api/me/groups', bearerToken: bearerToken);
    final raw = json['groups'] ?? json['items'] ?? [];
    if (raw is! List) {
      return const [];
    }
    return raw
        .whereType<Map>()
        .map(
          (item) => AccountGroup.fromJson(
            item.map((key, value) => MapEntry('$key', value)),
          ),
        )
        .toList(growable: false);
  }

  Future<AccountGroup> createGroup({
    required String bearerToken,
    required String name,
    required String kind,
  }) async {
    final json = await _api.postJson(
      '/api/me/groups',
      bearerToken: bearerToken,
      body: {'name': name, 'kind': kind},
    );
    return AccountGroup.fromJson(
      json['group'] is Map ? _map(json['group']) : json,
    );
  }

  Future<List<AccountGroupMember>> listMembers({
    required String bearerToken,
    required String groupId,
  }) async {
    final json = await _api.getJson(
      '/api/me/groups/$groupId/members',
      bearerToken: bearerToken,
    );
    final raw = json['members'] ?? [];
    if (raw is! List) {
      return const [];
    }
    return raw
        .whereType<Map>()
        .map(
          (item) => AccountGroupMember.fromJson(
            item.map((key, value) => MapEntry('$key', value)),
          ),
        )
        .toList(growable: false);
  }

  Future<AccountGroupInvite> createInvite({
    required String bearerToken,
    required String groupId,
    required String email,
    required String role,
  }) async {
    final json = await _api.postJson(
      '/api/me/groups/$groupId/invites',
      bearerToken: bearerToken,
      body: {'email': email, 'role': role},
    );
    return AccountGroupInvite.fromJson(
      json['invite'] is Map ? _map(json['invite']) : json,
    );
  }

  Future<AccountGroup> acceptInvite({
    required String bearerToken,
    required String code,
  }) async {
    final json = await _api.postJson(
      '/api/me/group-invites/accept',
      bearerToken: bearerToken,
      body: {'token': code},
    );
    return AccountGroup.fromJson(
      json['group'] is Map ? _map(json['group']) : json,
    );
  }

  Future<List<AppDevice>> listDevices({
    required String bearerToken,
    required String groupId,
  }) async {
    final json = await _api.getJson(
      '/api/me/groups/$groupId/devices',
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

  Future<void> shareDevice({
    required String bearerToken,
    required String groupId,
    required String deviceId,
    required String role,
  }) async {
    await _api.postJson(
      '/api/me/groups/$groupId/devices',
      bearerToken: bearerToken,
      body: {'device_id': deviceId, 'role': role},
    );
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

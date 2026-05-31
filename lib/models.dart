import 'dart:convert';

class ApiError implements Exception {
  const ApiError(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() =>
      statusCode == null ? message : 'HTTP $statusCode: $message';
}

class User {
  const User({
    required this.userId,
    required this.email,
    required this.emailVerified,
    required this.createdAt,
    this.emailVerifiedAt,
  });

  final String userId;
  final String email;
  final bool emailVerified;
  final String? emailVerifiedAt;
  final String? createdAt;

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      userId: _string(json['user_id'] ?? json['id']),
      email: _string(json['email']),
      emailVerified: json['email_verified'] == true,
      emailVerifiedAt: _nullableString(json['email_verified_at']),
      createdAt: _nullableString(json['created_at']),
    );
  }
}

class AuthSession {
  const AuthSession({
    required this.accessToken,
    required this.tokenType,
    required this.user,
  });

  final String accessToken;
  final String tokenType;
  final User user;

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    return AuthSession(
      accessToken: _string(json['access_token']),
      tokenType: _string(json['token_type'], fallback: 'bearer'),
      user: User.fromJson(_map(json['user'])),
    );
  }
}

class ProvisioningQrPayload {
  const ProvisioningQrPayload({
    required this.version,
    required this.name,
    required this.transport,
    required this.security,
    required this.proofOfPossession,
    required this.deviceId,
    required this.claimCode,
    this.softApPassword,
  });

  final String version;
  final String name;
  final String transport;
  final int security;
  final String proofOfPossession;
  final String deviceId;
  final String claimCode;
  final String? softApPassword;

  String get devicePrefix {
    final underscore = name.indexOf('_');
    return underscore > 0 ? name.substring(0, underscore + 1) : name;
  }

  bool get isBle => transport == 'ble';
  bool get isSoftAp => transport == 'softap';

  factory ProvisioningQrPayload.fromRaw(String raw) {
    var normalized = raw.trim();
    if (normalized.startsWith('data=')) {
      normalized = normalized.substring(5).trim();
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(normalized);
    } catch (_) {
      throw const FormatException('二维码内容不是有效 JSON');
    }
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('二维码内容必须是 JSON 对象');
    }
    final missing = <String>[
      if (_string(decoded['ver']).trim().isEmpty) 'ver',
      if (_string(decoded['name']).trim().isEmpty) 'name',
      if (_string(decoded['pop']).trim().isEmpty) 'pop',
      if (_string(decoded['device_id']).trim().isEmpty) 'device_id',
      if (_string(decoded['claim_code']).trim().isEmpty) 'claim_code',
    ];
    if (missing.isNotEmpty) {
      throw FormatException('二维码缺少字段：${missing.join(', ')}');
    }
    final payload = ProvisioningQrPayload(
      version: _string(decoded['ver']).trim(),
      name: _string(decoded['name']).trim(),
      transport: _string(decoded['transport']).trim(),
      security: _int(decoded['security'], fallback: 1),
      proofOfPossession: _string(decoded['pop']).trim(),
      deviceId: _string(decoded['device_id']).trim(),
      claimCode: _string(decoded['claim_code']).trim(),
      softApPassword: _nullableString(
        decoded['softap_password'] ??
            decoded['soft_ap_password'] ??
            decoded['ap_password'],
      ),
    );
    if (payload.version != 'v1') {
      throw FormatException('不支持的二维码版本：${payload.version}');
    }
    if (payload.transport != 'ble' && payload.transport != 'softap') {
      throw FormatException(
        '当前 App 只支持 BLE 或 SoftAP 配网二维码，不支持 ${payload.transport.isEmpty ? '空 transport' : payload.transport}',
      );
    }
    if (payload.security != 0 && payload.security != 1) {
      throw FormatException(
        '当前 App 只支持 Security 0 或 1，不支持 Security ${payload.security}',
      );
    }
    return payload;
  }
}

class ProvisioningDevice {
  const ProvisioningDevice({required this.name, this.serviceUuid, this.rssi});

  final String name;
  final String? serviceUuid;
  final int? rssi;

  factory ProvisioningDevice.fromJson(Map<String, dynamic> json) {
    return ProvisioningDevice(
      name: _string(json['name']),
      serviceUuid: _nullableString(json['serviceUuid'] ?? json['service_uuid']),
      rssi: _nullableInt(json['rssi']),
    );
  }
}

class WifiNetwork {
  const WifiNetwork({
    required this.ssid,
    this.rssi,
    this.channel,
    this.security,
  });

  final String ssid;
  final int? rssi;
  final int? channel;
  final int? security;

  factory WifiNetwork.fromJson(Map<String, dynamic> json) {
    return WifiNetwork(
      ssid: _string(json['ssid'] ?? json['wifiName']),
      rssi: _nullableInt(json['rssi']),
      channel: _nullableInt(json['channel']),
      security: _nullableInt(json['security'] ?? json['auth']),
    );
  }
}

class AppDevice {
  const AppDevice({
    required this.deviceId,
    this.nickname,
    this.role,
    this.shareSource,
    this.groupId,
    this.groupName,
    this.currentImageId,
    this.currentVersion,
    this.updatedAt,
    this.lastSeenAt,
    this.lastStatus,
    this.lastError,
    this.batteryMv,
    this.rssi,
    this.claimedAt,
  });

  final String deviceId;
  final String? nickname;
  final String? role;
  final String? shareSource;
  final String? groupId;
  final String? groupName;
  final String? currentImageId;
  final int? currentVersion;
  final String? updatedAt;
  final String? lastSeenAt;
  final String? lastStatus;
  final String? lastError;
  final int? batteryMv;
  final int? rssi;
  final String? claimedAt;

  factory AppDevice.fromJson(Map<String, dynamic> json) {
    return AppDevice(
      deviceId: _string(json['device_id']),
      nickname: _nullableString(json['nickname']),
      role: _nullableString(json['role']),
      shareSource: _nullableString(json['share_source']),
      groupId: _nullableString(json['group_id']),
      groupName: _nullableString(json['group_name']),
      currentImageId: _nullableString(json['current_image_id']),
      currentVersion: _nullableInt(json['current_version']),
      updatedAt: _nullableString(json['updated_at']),
      lastSeenAt: _nullableString(json['last_seen_at']),
      lastStatus: _nullableString(json['last_status']),
      lastError: _nullableString(json['last_error']),
      batteryMv: _nullableInt(json['battery_mv']),
      rssi: _nullableInt(json['rssi']),
      claimedAt: _nullableString(json['claimed_at']),
    );
  }
}

class DeviceMember {
  const DeviceMember({
    required this.userId,
    required this.email,
    required this.role,
    this.createdAt,
  });

  final String userId;
  final String email;
  final String role;
  final String? createdAt;

  factory DeviceMember.fromJson(Map<String, dynamic> json) {
    return DeviceMember(
      userId: _string(json['user_id']),
      email: _string(json['email']),
      role: _string(json['role']),
      createdAt: _nullableString(json['created_at']),
    );
  }
}

class DeviceInvite {
  const DeviceInvite({
    required this.inviteId,
    required this.deviceId,
    required this.email,
    required this.role,
    this.expiresAt,
    this.createdAt,
    this.token,
  });

  final String inviteId;
  final String deviceId;
  final String email;
  final String role;
  final String? expiresAt;
  final String? createdAt;
  final String? token;

  factory DeviceInvite.fromJson(Map<String, dynamic> json) {
    return DeviceInvite(
      inviteId: _string(json['invite_id']),
      deviceId: _string(json['device_id']),
      email: _string(json['email']),
      role: _string(json['role']),
      expiresAt: _nullableString(json['expires_at']),
      createdAt: _nullableString(json['created_at']),
      token: _nullableString(json['token']),
    );
  }
}

class AccountGroup {
  const AccountGroup({
    required this.groupId,
    required this.name,
    required this.kind,
    required this.role,
    this.createdAt,
  });

  final String groupId;
  final String name;
  final String kind;
  final String role;
  final String? createdAt;

  factory AccountGroup.fromJson(Map<String, dynamic> json) {
    return AccountGroup(
      groupId: _string(json['group_id'] ?? json['id']),
      name: _string(json['name']),
      kind: _string(json['kind'], fallback: 'family'),
      role: _string(json['role'], fallback: 'member'),
      createdAt: _nullableString(json['created_at']),
    );
  }
}

class AccountGroupMember {
  const AccountGroupMember({
    required this.userId,
    required this.email,
    required this.role,
    this.createdAt,
  });

  final String userId;
  final String email;
  final String role;
  final String? createdAt;

  factory AccountGroupMember.fromJson(Map<String, dynamic> json) {
    return AccountGroupMember(
      userId: _string(json['user_id'] ?? json['id']),
      email: _string(json['email']),
      role: _string(json['role'], fallback: 'member'),
      createdAt: _nullableString(json['created_at']),
    );
  }
}

class AccountGroupInvite {
  const AccountGroupInvite({
    required this.inviteId,
    required this.groupId,
    required this.email,
    required this.role,
    this.expiresAt,
    this.createdAt,
    this.code,
  });

  final String inviteId;
  final String groupId;
  final String email;
  final String role;
  final String? expiresAt;
  final String? createdAt;
  final String? code;

  factory AccountGroupInvite.fromJson(Map<String, dynamic> json) {
    return AccountGroupInvite(
      inviteId: _string(json['invite_id']),
      groupId: _string(json['group_id']),
      email: _string(json['email']),
      role: _string(json['role'], fallback: 'member'),
      expiresAt: _nullableString(json['expires_at']),
      createdAt: _nullableString(json['created_at']),
      code: _nullableString(json['code'] ?? json['token']),
    );
  }
}

class StatusEvent {
  const StatusEvent({
    required this.id,
    required this.deviceId,
    required this.status,
    this.version,
    this.error,
    this.batteryMv,
    this.rssi,
    this.createdAt,
  });

  final int id;
  final String deviceId;
  final int? version;
  final String status;
  final String? error;
  final int? batteryMv;
  final int? rssi;
  final String? createdAt;

  factory StatusEvent.fromJson(Map<String, dynamic> json) {
    return StatusEvent(
      id: _int(json['id']),
      deviceId: _string(json['device_id']),
      version: _nullableInt(json['version']),
      status: _string(json['status']),
      error: _nullableString(json['error']),
      batteryMv: _nullableInt(json['battery_mv']),
      rssi: _nullableInt(json['rssi']),
      createdAt: _nullableString(json['created_at']),
    );
  }
}

class DeviceManifest {
  const DeviceManifest({
    required this.deviceId,
    required this.version,
    required this.hasImage,
    this.imageId,
    this.width,
    this.height,
    this.format,
    this.palette = const [],
    this.sha256,
    this.downloadUrl,
  });

  final String deviceId;
  final int version;
  final bool hasImage;
  final String? imageId;
  final int? width;
  final int? height;
  final String? format;
  final List<List<int>> palette;
  final String? sha256;
  final String? downloadUrl;

  factory DeviceManifest.fromJson(Map<String, dynamic> json) {
    return DeviceManifest(
      deviceId: _string(json['device_id']),
      version: _int(json['version']),
      hasImage: json['has_image'] == true,
      imageId: _nullableString(json['image_id']),
      width: _nullableInt(json['width']),
      height: _nullableInt(json['height']),
      format: _nullableString(json['format']),
      palette: _palette(json['palette']),
      sha256: _nullableString(json['sha256']),
      downloadUrl: _nullableString(json['download_url']),
    );
  }
}

class ImageInfo {
  const ImageInfo({
    required this.imageId,
    required this.width,
    required this.height,
    required this.format,
    required this.palette,
    required this.sha256,
    required this.dataSize,
    required this.dataUrl,
    required this.previewUrl,
    this.createdAt,
  });

  final String imageId;
  final int width;
  final int height;
  final String format;
  final List<List<int>> palette;
  final String sha256;
  final int dataSize;
  final String dataUrl;
  final String previewUrl;
  final String? createdAt;

  factory ImageInfo.fromJson(Map<String, dynamic> json) {
    return ImageInfo(
      imageId: _string(json['image_id']),
      width: _int(json['width']),
      height: _int(json['height']),
      format: _string(json['format']),
      palette: _palette(json['palette']),
      sha256: _string(json['sha256']),
      dataSize: _int(json['data_size']),
      dataUrl: _string(json['data_url']),
      previewUrl: _string(json['preview_url']),
      createdAt: _nullableString(json['created_at']),
    );
  }
}

class InkPhoto {
  const InkPhoto({
    required this.photoId,
    required this.imageId,
    required this.previewUrl,
    this.title,
    this.dataUrl,
    this.albumIds = const [],
    this.favorite = false,
    this.tags = const [],
    this.assignedDeviceId,
    this.assignedAt,
    this.width,
    this.height,
    this.createdAt,
  });

  final String photoId;
  final String imageId;
  final String? title;
  final String previewUrl;
  final String? dataUrl;
  final List<String> albumIds;
  final bool favorite;
  final List<String> tags;
  final String? assignedDeviceId;
  final String? assignedAt;
  final int? width;
  final int? height;
  final String? createdAt;

  factory InkPhoto.fromJson(Map<String, dynamic> json) {
    return InkPhoto(
      photoId: _string(json['photo_id'] ?? json['id'] ?? json['image_id']),
      imageId: _string(json['image_id'] ?? json['id']),
      title: _nullableString(json['title'] ?? json['name']),
      previewUrl: _string(json['preview_url'] ?? json['thumbnail_url']),
      dataUrl: _nullableString(json['data_url']),
      albumIds: _stringList(json['album_ids'] ?? json['albums']),
      favorite: json['favorite'] == true || json['is_favorite'] == true,
      tags: _stringList(json['tags']),
      assignedDeviceId: _nullableString(json['assigned_device_id']),
      assignedAt: _nullableString(json['assigned_at']),
      width: _nullableInt(json['width']),
      height: _nullableInt(json['height']),
      createdAt: _nullableString(json['created_at']),
    );
  }

  factory InkPhoto.fromImageInfo(ImageInfo image, {String? deviceId}) {
    return InkPhoto(
      photoId: image.imageId,
      imageId: image.imageId,
      title: image.imageId,
      previewUrl: image.previewUrl,
      dataUrl: image.dataUrl,
      assignedDeviceId: deviceId,
      width: image.width,
      height: image.height,
      createdAt: image.createdAt,
    );
  }
}

class InkAlbum {
  const InkAlbum({
    required this.albumId,
    required this.title,
    this.subtitle,
    this.coverUrl,
    this.photoCount = 0,
    this.tags = const [],
    this.shared = false,
    this.photos = const [],
    this.createdAt,
    this.updatedAt,
  });

  final String albumId;
  final String title;
  final String? subtitle;
  final String? coverUrl;
  final int photoCount;
  final List<String> tags;
  final bool shared;
  final List<InkPhoto> photos;
  final String? createdAt;
  final String? updatedAt;

  factory InkAlbum.fromJson(Map<String, dynamic> json) {
    final rawPhotos = json['photos'];
    return InkAlbum(
      albumId: _string(json['album_id'] ?? json['id']),
      title: _string(json['title'] ?? json['name'], fallback: 'Untitled'),
      subtitle: _nullableString(json['subtitle'] ?? json['description']),
      coverUrl: _nullableString(json['cover_url'] ?? json['cover_preview_url']),
      photoCount: _int(
        json['photo_count'] ??
            json['count'] ??
            (rawPhotos is List ? rawPhotos.length : 0),
      ),
      tags: _stringList(json['tags']),
      shared: json['shared'] == true,
      photos: rawPhotos is List
          ? rawPhotos
                .whereType<Map>()
                .map(
                  (item) => InkPhoto.fromJson(
                    item.map((key, value) => MapEntry('$key', value)),
                  ),
                )
                .toList(growable: false)
          : const [],
      createdAt: _nullableString(json['created_at']),
      updatedAt: _nullableString(json['updated_at']),
    );
  }
}

class InkTimelineEvent {
  const InkTimelineEvent({
    required this.eventId,
    required this.type,
    required this.title,
    this.subtitle,
    this.photoId,
    this.albumId,
    this.deviceId,
    this.previewUrl,
    this.createdAt,
  });

  final String eventId;
  final String type;
  final String title;
  final String? subtitle;
  final String? photoId;
  final String? albumId;
  final String? deviceId;
  final String? previewUrl;
  final String? createdAt;

  factory InkTimelineEvent.fromJson(Map<String, dynamic> json) {
    return InkTimelineEvent(
      eventId: _string(json['event_id'] ?? json['id']),
      type: _string(json['type'], fallback: 'event'),
      title: _string(json['title'], fallback: 'InkSplash'),
      subtitle: _nullableString(json['subtitle'] ?? json['detail']),
      photoId: _nullableString(json['photo_id']),
      albumId: _nullableString(json['album_id']),
      deviceId: _nullableString(json['device_id']),
      previewUrl: _nullableString(json['preview_url']),
      createdAt: _nullableString(json['created_at']),
    );
  }
}

class InkNotification {
  const InkNotification({
    required this.notificationId,
    required this.title,
    this.body,
    this.type,
    this.read = false,
    this.createdAt,
  });

  final String notificationId;
  final String title;
  final String? body;
  final String? type;
  final bool read;
  final String? createdAt;

  factory InkNotification.fromJson(Map<String, dynamic> json) {
    return InkNotification(
      notificationId: _string(json['notification_id'] ?? json['id']),
      title: _string(json['title'], fallback: 'InkSplash'),
      body: _nullableString(json['body'] ?? json['message']),
      type: _nullableString(json['type']),
      read: json['read'] == true || json['read_at'] != null,
      createdAt: _nullableString(json['created_at']),
    );
  }
}

class StorageSummary {
  const StorageSummary({
    required this.usedBytes,
    required this.quotaBytes,
    this.photoCount = 0,
    this.albumCount = 0,
    this.deviceCount = 0,
    this.cleanupSuggestion,
  });

  final int usedBytes;
  final int quotaBytes;
  final int photoCount;
  final int albumCount;
  final int deviceCount;
  final String? cleanupSuggestion;

  double get usedRatio => quotaBytes <= 0 ? 0 : usedBytes / quotaBytes;

  factory StorageSummary.fromJson(Map<String, dynamic> json) {
    return StorageSummary(
      usedBytes: _int(json['used_bytes']),
      quotaBytes: _int(json['quota_bytes']),
      photoCount: _int(json['photo_count']),
      albumCount: _int(json['album_count']),
      deviceCount: _int(json['device_count']),
      cleanupSuggestion: _nullableString(json['cleanup_suggestion']),
    );
  }
}

class UserPreferences {
  const UserPreferences({
    this.deviceAlerts = true,
    this.sharingAlerts = true,
    this.uploadAlerts = true,
    this.profileVisibility = 'family',
    this.analyticsEnabled = false,
  });

  final bool deviceAlerts;
  final bool sharingAlerts;
  final bool uploadAlerts;
  final String profileVisibility;
  final bool analyticsEnabled;

  factory UserPreferences.fromJson(Map<String, dynamic> json) {
    return UserPreferences(
      deviceAlerts: json['device_alerts'] != false,
      sharingAlerts: json['sharing_alerts'] != false,
      uploadAlerts: json['upload_alerts'] != false,
      profileVisibility: _string(
        json['profile_visibility'],
        fallback: 'family',
      ),
      analyticsEnabled: json['analytics_enabled'] == true,
    );
  }

  Map<String, Object> toJson() {
    return {
      'device_alerts': deviceAlerts,
      'sharing_alerts': sharingAlerts,
      'upload_alerts': uploadAlerts,
      'profile_visibility': profileVisibility,
      'analytics_enabled': analyticsEnabled,
    };
  }
}

class UploadOptions {
  const UploadOptions({
    this.direction = 'auto',
    this.mode = 'scale',
    this.dither = true,
  });

  final String direction;
  final String mode;
  final bool dither;
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

String _string(Object? value, {String fallback = ''}) {
  if (value == null) {
    return fallback;
  }
  return '$value';
}

String? _nullableString(Object? value) {
  if (value == null) {
    return null;
  }
  final string = '$value';
  return string.isEmpty ? null : string;
}

int _int(Object? value, {int fallback = 0}) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse('$value') ?? fallback;
}

int? _nullableInt(Object? value) {
  if (value == null) {
    return null;
  }
  return _int(value);
}

List<List<int>> _palette(Object? value) {
  if (value is! List) {
    return const [];
  }
  return value
      .whereType<List>()
      .map((entry) => entry.map((item) => _int(item)).toList(growable: false))
      .toList(growable: false);
}

List<String> _stringList(Object? value) {
  if (value is! List) {
    return const [];
  }
  return value.map((item) => '$item').toList(growable: false);
}

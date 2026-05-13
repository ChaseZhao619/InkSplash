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
    required this.createdAt,
  });

  final String userId;
  final String email;
  final String? createdAt;

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      userId: _string(json['user_id'] ?? json['id']),
      email: _string(json['email']),
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
  });

  final String version;
  final String name;
  final String transport;
  final int security;
  final String proofOfPossession;
  final String deviceId;
  final String claimCode;

  String get devicePrefix {
    final underscore = name.indexOf('_');
    return underscore > 0 ? name.substring(0, underscore + 1) : name;
  }

  factory ProvisioningQrPayload.fromRaw(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('QR payload must be a JSON object');
    }
    final payload = ProvisioningQrPayload(
      version: _string(decoded['ver']),
      name: _string(decoded['name']),
      transport: _string(decoded['transport']),
      security: _int(decoded['security'], fallback: 1),
      proofOfPossession: _string(decoded['pop']),
      deviceId: _string(decoded['device_id']),
      claimCode: _string(decoded['claim_code']),
    );
    if (payload.version != 'v1') {
      throw const FormatException('Unsupported QR version');
    }
    if (payload.transport != 'ble') {
      throw const FormatException('Only BLE provisioning is supported in V1');
    }
    if (payload.security != 1) {
      throw const FormatException(
        'Only Security 1 provisioning is supported in V1',
      );
    }
    if (payload.name.isEmpty ||
        payload.deviceId.isEmpty ||
        payload.claimCode.isEmpty) {
      throw const FormatException('QR payload is missing required fields');
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
    this.currentImageId,
    this.currentVersion,
    this.lastSeenAt,
    this.lastStatus,
    this.lastError,
    this.batteryMv,
    this.rssi,
    this.claimedAt,
  });

  final String deviceId;
  final String? nickname;
  final String? currentImageId;
  final int? currentVersion;
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
      currentImageId: _nullableString(json['current_image_id']),
      currentVersion: _nullableInt(json['current_version']),
      lastSeenAt: _nullableString(json['last_seen_at']),
      lastStatus: _nullableString(json['last_status']),
      lastError: _nullableString(json['last_error']),
      batteryMv: _nullableInt(json['battery_mv']),
      rssi: _nullableInt(json['rssi']),
      claimedAt: _nullableString(json['claimed_at']),
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

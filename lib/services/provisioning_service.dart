import 'package:flutter/services.dart';

import '../models.dart';

class ProvisioningService {
  const ProvisioningService();

  static const MethodChannel _channel = MethodChannel(
    'com.inksplash.app/provisioning',
  );

  Future<bool> requestPermissions() async {
    final granted = await _channel.invokeMethod<bool>('requestPermissions');
    return granted ?? false;
  }

  Future<List<ProvisioningDevice>> searchBleDevices(String prefix) async {
    final raw = await _channel.invokeMethod<List<dynamic>>('searchBleDevices', {
      'prefix': prefix,
    });
    return (raw ?? const [])
        .whereType<Map>()
        .map(
          (item) => ProvisioningDevice.fromJson(
            item.map((key, value) => MapEntry('$key', value)),
          ),
        )
        .toList(growable: false);
  }

  Future<List<ProvisioningDevice>> searchSoftApDevices({
    required String prefix,
    required String name,
  }) async {
    final raw = await _channel.invokeMethod<List<dynamic>>(
      'searchSoftApDevices',
      {'prefix': prefix, 'name': name},
    );
    return (raw ?? const [])
        .whereType<Map>()
        .map(
          (item) => ProvisioningDevice.fromJson(
            item.map((key, value) => MapEntry('$key', value)),
          ),
        )
        .toList(growable: false);
  }

  Future<void> connectBleDevice({
    required String name,
    required String proofOfPossession,
    int security = 1,
  }) async {
    await _channel.invokeMethod<void>('connectBleDevice', {
      'name': name,
      'proofOfPossession': proofOfPossession,
      'security': security,
    });
  }

  Future<void> connectSoftApDevice({
    required String name,
    required String proofOfPossession,
    String password = '',
    int security = 1,
  }) async {
    await _channel.invokeMethod<void>('connectSoftApDevice', {
      'name': name,
      'proofOfPossession': proofOfPossession,
      'password': password,
      'security': security,
    });
  }

  Future<List<WifiNetwork>> scanWifiNetworks() async {
    final raw = await _channel.invokeMethod<List<dynamic>>('scanWifiNetworks');
    return (raw ?? const [])
        .whereType<Map>()
        .map(
          (item) => WifiNetwork.fromJson(
            item.map((key, value) => MapEntry('$key', value)),
          ),
        )
        .where((network) => network.ssid.isNotEmpty)
        .toList(growable: false);
  }

  Future<void> provisionWifi({
    required String ssid,
    required String password,
  }) async {
    await _channel.invokeMethod<void>('provisionWifi', {
      'ssid': ssid,
      'password': password,
    });
  }

  Future<void> disconnect() async {
    await _channel.invokeMethod<void>('disconnect');
  }
}

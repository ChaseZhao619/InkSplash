import 'dart:typed_data';

import 'package:flutter/material.dart' hide ImageInfo;
import 'package:image_picker/image_picker.dart';

import '../../models.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../services/device_service.dart';
import '../../services/image_service.dart';
import '../../services/provisioning_service.dart';
import '../../services/session_store.dart';
import '../localization/app_strings.dart';

class AppController extends ChangeNotifier {
  AppController({
    ProvisioningService provisioning = const ProvisioningService(),
    SessionStore sessionStore = const SessionStore(),
  }) : _provisioning = provisioning,
       _sessionStore = sessionStore;

  final baseUrlController = TextEditingController(
    text: 'http://47.113.120.232',
  );
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final deviceNicknameController = TextEditingController();
  final renameController = TextEditingController();
  final wifiPasswordController = TextEditingController();
  final verifyEmailTokenController = TextEditingController();
  final resetEmailController = TextEditingController();
  final resetTokenController = TextEditingController();
  final resetPasswordController = TextEditingController();
  final inviteEmailController = TextEditingController();
  final inviteTokenController = TextEditingController();

  final ProvisioningService _provisioning;
  final SessionStore _sessionStore;

  AuthSession? session;
  ProvisioningQrPayload? qrPayload;
  List<ProvisioningDevice> provisioningDevices = const [];
  List<WifiNetwork> wifiNetworks = const [];
  List<AppDevice> devices = const [];
  AppDevice? selectedDevice;
  WifiNetwork? selectedWifi;
  List<DeviceMember> members = const [];
  List<StatusEvent> statusEvents = const [];
  ImageInfo? latestImage;
  Uint8List? previewPng;
  String direction = 'auto';
  String mode = 'scale';
  String inviteRole = 'viewer';
  bool dither = true;
  bool busy = false;
  String? message;

  EpaperApiClient get _api => EpaperApiClient(baseUrl: baseUrlController.text);
  AuthService get _auth => AuthService(_api);
  DeviceBindingService get _deviceService => DeviceBindingService(_api);
  ImageService get _imageService => ImageService(_api);
  String? get bearerToken => session?.accessToken;

  Future<void> restoreSession(AppStrings s) async {
    final stored = await _sessionStore.load();
    if (stored == null) {
      return;
    }
    busy = true;
    notifyListeners();
    try {
      baseUrlController.text = stored.baseUrl;
      final user = await _auth.me(stored.accessToken);
      final loadedDevices = await _deviceService.listDevices(
        stored.accessToken,
      );
      session = AuthSession(
        accessToken: stored.accessToken,
        tokenType: 'bearer',
        user: user,
      );
      devices = loadedDevices;
      selectedDevice = loadedDevices.isEmpty ? null : loadedDevices.first;
      renameController.text = selectedDevice?.nickname ?? '';
    } catch (error) {
      await _sessionStore.clear();
      message = '${s.savedLoginExpired}: $error';
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> runAction(
    AppStrings s,
    String action,
    Future<void> Function() task,
  ) async {
    if (busy) {
      return;
    }
    busy = true;
    message = null;
    notifyListeners();
    try {
      await task();
      message = s.completed(action);
    } catch (error) {
      message = s.failed(action, error);
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> login(AppStrings s, {required bool register}) async {
    await runAction(s, register ? s.registerAction : s.loginAction, () async {
      final email = emailController.text.trim();
      final password = passwordController.text;
      if (email.length < 3) {
        throw ApiError(s.enterEmail);
      }
      if (password.length < 8) {
        throw ApiError(s.passwordTooShort);
      }
      final nextSession = register
          ? await _auth.register(email: email, password: password)
          : await _auth.login(email: email, password: password);
      final loadedDevices = await _deviceService.listDevices(
        nextSession.accessToken,
      );
      await _sessionStore.save(
        baseUrl: baseUrlController.text.trim(),
        accessToken: nextSession.accessToken,
      );
      session = nextSession;
      devices = loadedDevices;
      selectedDevice = loadedDevices.isEmpty ? null : loadedDevices.first;
      renameController.text = selectedDevice?.nickname ?? '';
    });
  }

  Future<void> logout(AppStrings s) async {
    await runAction(s, s.logoutAction, () async {
      await _sessionStore.clear();
      session = null;
      devices = const [];
      selectedDevice = null;
      members = const [];
      statusEvents = const [];
    });
  }

  Future<void> refreshDevices(AppStrings s) async {
    final token = requireLogin(s);
    await runAction(s, s.refreshDevicesAction, () async {
      final loadedDevices = await _deviceService.listDevices(token);
      devices = loadedDevices;
      if (loadedDevices.isEmpty) {
        selectedDevice = null;
        renameController.text = '';
      } else if (selectedDevice == null ||
          !loadedDevices.any(
            (device) => device.deviceId == selectedDevice!.deviceId,
          )) {
        selectedDevice = loadedDevices.first;
        renameController.text = selectedDevice?.nickname ?? '';
      }
    });
  }

  Future<void> requestEmailVerification(AppStrings s) async {
    final token = requireLogin(s);
    await runAction(s, s.requestVerificationAction, () async {
      await _auth.requestEmailVerification(token);
    });
  }

  Future<void> confirmEmailVerification(AppStrings s) async {
    await runAction(s, s.confirmEmailAction, () async {
      final user = await _auth.confirmEmailVerification(
        token: verifyEmailTokenController.text.trim(),
      );
      final current = session;
      if (current == null) {
        return;
      }
      session = AuthSession(
        accessToken: current.accessToken,
        tokenType: current.tokenType,
        user: user,
      );
    });
  }

  Future<void> requestPasswordReset(AppStrings s) async {
    await runAction(s, s.requestPasswordResetAction, () async {
      final email = resetEmailController.text.trim().isEmpty
          ? emailController.text.trim()
          : resetEmailController.text.trim();
      if (email.length < 3) {
        throw ApiError(s.enterEmail);
      }
      await _auth.requestPasswordReset(email: email);
    });
  }

  Future<void> confirmPasswordReset(AppStrings s) async {
    await runAction(s, s.resetPasswordAction, () async {
      final newPassword = resetPasswordController.text;
      if (newPassword.length < 8) {
        throw ApiError(s.passwordTooShort);
      }
      await _auth.confirmPasswordReset(
        token: resetTokenController.text.trim(),
        newPassword: newPassword,
      );
    });
  }

  Future<void> renameSelectedDevice(AppStrings s) async {
    final token = requireLogin(s);
    final device = requireSelectedDevice(s);
    await runAction(s, s.renameDeviceAction, () async {
      final updated = await _deviceService.updateDevice(
        bearerToken: token,
        deviceId: device.deviceId,
        nickname: renameController.text.trim().isEmpty
            ? null
            : renameController.text.trim(),
      );
      final loadedDevices = await _deviceService.listDevices(token);
      devices = loadedDevices;
      selectedDevice = updated;
    });
  }

  Future<void> unbindSelectedDevice(AppStrings s) async {
    final token = requireLogin(s);
    final device = requireSelectedDevice(s);
    await runAction(s, s.unbindDeviceAction, () async {
      await _deviceService.unbindDevice(
        bearerToken: token,
        deviceId: device.deviceId,
      );
      final loadedDevices = await _deviceService.listDevices(token);
      devices = loadedDevices;
      selectedDevice = loadedDevices.isEmpty ? null : loadedDevices.first;
      renameController.text = selectedDevice?.nickname ?? '';
      members = const [];
      statusEvents = const [];
    });
  }

  Future<void> refreshDeviceExtras(AppStrings s) async {
    final token = requireLogin(s);
    final device = requireSelectedDevice(s);
    await runAction(s, s.refreshDeviceDetailAction, () async {
      final results = await Future.wait([
        _deviceService.listMembers(
          bearerToken: token,
          deviceId: device.deviceId,
        ),
        _deviceService.listStatusEvents(
          bearerToken: token,
          deviceId: device.deviceId,
        ),
      ]);
      members = results[0] as List<DeviceMember>;
      statusEvents = results[1] as List<StatusEvent>;
    });
  }

  Future<void> createInvite(AppStrings s) async {
    final token = requireLogin(s);
    final device = requireSelectedDevice(s);
    await runAction(s, s.createInviteAction, () async {
      await _deviceService.createInvite(
        bearerToken: token,
        deviceId: device.deviceId,
        email: inviteEmailController.text.trim(),
        role: inviteRole,
      );
    });
  }

  Future<void> acceptInviteToken(AppStrings s) async {
    final token = requireLogin(s);
    await runAction(s, s.acceptInviteAction, () async {
      final device = await _deviceService.acceptInvite(
        bearerToken: token,
        token: inviteTokenController.text.trim(),
      );
      final loadedDevices = await _deviceService.listDevices(token);
      devices = loadedDevices;
      selectedDevice = loadedDevices.firstWhere(
        (item) => item.deviceId == device.deviceId,
        orElse: () => device,
      );
      renameController.text = selectedDevice?.nickname ?? '';
    });
  }

  void applyQrPayload(AppStrings s, String raw) {
    try {
      final payload = ProvisioningQrPayload.fromRaw(raw);
      qrPayload = payload;
      provisioningDevices = const [];
      wifiNetworks = const [];
      selectedWifi = null;
      message = null;
    } catch (error) {
      final detail = error is FormatException ? error.message : '$error';
      message = '${s.invalidQrPayload}: $detail';
    }
    notifyListeners();
  }

  Future<void> searchProvisioningDevice(AppStrings s) async {
    final payload = requireQr(s);
    await runAction(s, s.bleSearchAction, () async {
      await _provisioning.requestPermissions();
      provisioningDevices = await _provisioning.searchBleDevices(
        payload.devicePrefix,
      );
    });
  }

  Future<void> connectProvisioningDevice(
    AppStrings s,
    ProvisioningDevice device,
  ) async {
    final payload = requireQr(s);
    await runAction(s, s.bleConnectAction, () async {
      await _provisioning.connectBleDevice(
        name: device.name,
        proofOfPossession: payload.proofOfPossession,
        security: payload.security,
      );
      final networks = await _provisioning.scanWifiNetworks();
      wifiNetworks = networks;
      selectedWifi = networks.isEmpty ? null : networks.first;
    });
  }

  Future<void> provisionAndClaim(AppStrings s) async {
    final payload = requireQr(s);
    final token = requireLogin(s);
    final wifi = selectedWifi;
    if (wifi == null) {
      throw ApiError(s.selectWifiFirst);
    }
    await runAction(s, s.provisionClaimAction, () async {
      await _provisioning.provisionWifi(
        ssid: wifi.ssid,
        password: wifiPasswordController.text,
      );
      final claimed = await _deviceService.claimDevice(
        bearerToken: token,
        deviceId: payload.deviceId,
        claimCode: payload.claimCode,
        nickname: deviceNicknameController.text.trim().isEmpty
            ? null
            : deviceNicknameController.text.trim(),
      );
      final loadedDevices = await _deviceService.listDevices(token);
      devices = loadedDevices;
      selectedDevice = loadedDevices.firstWhere(
        (device) => device.deviceId == claimed.deviceId,
        orElse: () => claimed,
      );
    });
  }

  Future<void> uploadAndAssign(AppStrings s) async {
    await runAction(s, s.uploadAssignAction, () async {
      final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (picked == null) {
        return;
      }
      final token = requireLogin(s);
      final device = selectedDevice;
      if (device == null) {
        throw ApiError(s.selectBindDeviceFirst);
      }
      final image = await _imageService.uploadImage(
        bearerToken: token,
        filePath: picked.path,
        fileName: picked.name,
        options: UploadOptions(
          direction: direction,
          mode: mode,
          dither: dither,
        ),
      );
      await _deviceService.assignImage(
        bearerToken: token,
        deviceId: device.deviceId,
        imageId: image.imageId,
      );
      final preview = await _imageService.getPreviewPng(
        image,
        bearerToken: token,
      );
      final loadedDevices = await _deviceService.listDevices(token);
      latestImage = image;
      previewPng = preview;
      devices = loadedDevices;
      selectedDevice = loadedDevices.firstWhere(
        (item) => item.deviceId == device.deviceId,
        orElse: () => device,
      );
    });
  }

  void selectDevice(AppDevice device) {
    selectedDevice = device;
    renameController.text = device.nickname ?? '';
    members = const [];
    statusEvents = const [];
    notifyListeners();
  }

  void selectTargetDevice(String deviceId) {
    selectedDevice = devices.firstWhere(
      (device) => device.deviceId == deviceId,
    );
    notifyListeners();
  }

  void selectWifi(WifiNetwork? value) {
    selectedWifi = value;
    notifyListeners();
  }

  void setInviteRole(String value) {
    inviteRole = value;
    notifyListeners();
  }

  void setDirection(String value) {
    direction = value;
    notifyListeners();
  }

  void setMode(String value) {
    mode = value;
    notifyListeners();
  }

  void setDither(bool value) {
    dither = value;
    notifyListeners();
  }

  String requireLogin(AppStrings s) {
    final token = bearerToken;
    if (token == null || token.isEmpty) {
      throw ApiError(s.loginFirst);
    }
    return token;
  }

  ProvisioningQrPayload requireQr(AppStrings s) {
    final payload = qrPayload;
    if (payload == null) {
      throw ApiError(s.scanQrFirst);
    }
    return payload;
  }

  AppDevice requireSelectedDevice(AppStrings s) {
    final device = selectedDevice;
    if (device == null) {
      throw ApiError(s.selectBindDeviceFirst);
    }
    return device;
  }

  @override
  void dispose() {
    baseUrlController.dispose();
    emailController.dispose();
    passwordController.dispose();
    deviceNicknameController.dispose();
    renameController.dispose();
    wifiPasswordController.dispose();
    verifyEmailTokenController.dispose();
    resetEmailController.dispose();
    resetTokenController.dispose();
    resetPasswordController.dispose();
    inviteEmailController.dispose();
    inviteTokenController.dispose();
    super.dispose();
  }
}

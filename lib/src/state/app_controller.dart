import 'dart:typed_data';

import 'package:flutter/material.dart' hide ImageInfo;
import 'package:image_picker/image_picker.dart';

import '../../models.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../services/device_service.dart';
import '../../services/group_service.dart';
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
  final softApPasswordController = TextEditingController();
  final verifyEmailTokenController = TextEditingController();
  final resetEmailController = TextEditingController();
  final resetTokenController = TextEditingController();
  final resetPasswordController = TextEditingController();
  final inviteEmailController = TextEditingController();
  final inviteTokenController = TextEditingController();
  final groupNameController = TextEditingController();
  final groupInviteEmailController = TextEditingController();
  final groupInviteCodeController = TextEditingController();

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
  List<AccountGroup> groups = const [];
  AccountGroup? selectedGroup;
  List<AccountGroupMember> groupMembers = const [];
  List<AppDevice> groupDevices = const [];
  ImageInfo? latestImage;
  Uint8List? previewPng;
  String direction = 'auto';
  String mode = 'scale';
  String inviteRole = 'viewer';
  String groupKind = 'family';
  String groupInviteRole = 'member';
  String groupDeviceRole = 'admin';
  bool dither = true;
  bool busy = false;
  String? message;

  EpaperApiClient get _api => EpaperApiClient(baseUrl: baseUrlController.text);
  AuthService get _auth => AuthService(_api);
  DeviceBindingService get _deviceService => DeviceBindingService(_api);
  GroupService get _groupService => GroupService(_api);
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
      await _tryRefreshGroupsWithToken(stored.accessToken);
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
      await _tryRefreshGroupsWithToken(nextSession.accessToken);
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
      groups = const [];
      selectedGroup = null;
      groupMembers = const [];
      groupDevices = const [];
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
      final code = verifyEmailTokenController.text.trim();
      _requireSixCharacterCode(s, code);
      final user = await _auth.confirmEmailVerification(token: code);
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
      final code = resetTokenController.text.trim();
      _requireSixCharacterCode(s, code);
      final newPassword = resetPasswordController.text;
      if (newPassword.length < 8) {
        throw ApiError(s.passwordTooShort);
      }
      await _auth.confirmPasswordReset(token: code, newPassword: newPassword);
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
      final code = inviteTokenController.text.trim();
      _requireSixCharacterCode(s, code);
      final device = await _deviceService.acceptInvite(
        bearerToken: token,
        token: code,
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

  Future<void> refreshGroups(AppStrings s) async {
    final token = requireLogin(s);
    await runAction(s, s.refreshGroupsAction, () async {
      await _refreshGroupsWithToken(token);
    });
  }

  Future<void> createGroup(AppStrings s) async {
    final token = requireLogin(s);
    await runAction(s, s.createGroupAction, () async {
      final name = groupNameController.text.trim();
      if (name.isEmpty) {
        throw ApiError(s.enterGroupName);
      }
      final group = await _groupService.createGroup(
        bearerToken: token,
        name: name,
        kind: groupKind,
      );
      await _refreshGroupsWithToken(token, preferredGroupId: group.groupId);
      groupNameController.clear();
    });
  }

  Future<void> refreshGroupDetail(AppStrings s) async {
    final token = requireLogin(s);
    final group = requireSelectedGroup(s);
    await runAction(s, s.refreshGroupDetailAction, () async {
      await _refreshGroupDetailWithToken(token, group.groupId);
    });
  }

  Future<void> createGroupInvite(AppStrings s) async {
    final token = requireLogin(s);
    final group = requireSelectedGroup(s);
    await runAction(s, s.createGroupInviteAction, () async {
      await _groupService.createInvite(
        bearerToken: token,
        groupId: group.groupId,
        email: groupInviteEmailController.text.trim(),
        role: groupInviteRole,
      );
    });
  }

  Future<void> acceptGroupInvite(AppStrings s) async {
    final token = requireLogin(s);
    await runAction(s, s.acceptGroupInviteAction, () async {
      final code = groupInviteCodeController.text.trim();
      _requireSixCharacterCode(s, code);
      final group = await _groupService.acceptInvite(
        bearerToken: token,
        code: code,
      );
      await _refreshGroupsWithToken(token, preferredGroupId: group.groupId);
      groupInviteCodeController.clear();
    });
  }

  Future<void> shareSelectedDeviceToGroup(AppStrings s) async {
    final token = requireLogin(s);
    final group = requireSelectedGroup(s);
    final device = requireSelectedDevice(s);
    await runAction(s, s.shareDeviceToGroupAction, () async {
      await _groupService.shareDevice(
        bearerToken: token,
        groupId: group.groupId,
        deviceId: device.deviceId,
        role: groupDeviceRole,
      );
      await _refreshGroupDetailWithToken(token, group.groupId);
    });
  }

  void applyQrPayload(AppStrings s, String raw) {
    try {
      final payload = ProvisioningQrPayload.fromRaw(raw);
      qrPayload = payload;
      softApPasswordController.text = payload.softApPassword ?? '';
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
    await runAction(
      s,
      payload.isSoftAp ? s.softApSearchAction : s.bleSearchAction,
      () async {
        await _provisioning.requestPermissions();
        provisioningDevices = payload.isSoftAp
            ? await _provisioning.searchSoftApDevices(
                prefix: payload.devicePrefix,
                name: payload.name,
              )
            : await _provisioning.searchBleDevices(payload.devicePrefix);
      },
    );
  }

  Future<void> connectProvisioningDevice(
    AppStrings s,
    ProvisioningDevice device,
  ) async {
    final payload = requireQr(s);
    await runAction(
      s,
      payload.isSoftAp ? s.softApConnectAction : s.bleConnectAction,
      () async {
        if (payload.isSoftAp) {
          await _provisioning.connectSoftApDevice(
            name: device.name,
            proofOfPossession: payload.proofOfPossession,
            password: softApPasswordController.text,
            security: payload.security,
          );
        } else {
          await _provisioning.connectBleDevice(
            name: device.name,
            proofOfPossession: payload.proofOfPossession,
            security: payload.security,
          );
        }
        final networks = await _provisioning.scanWifiNetworks();
        wifiNetworks = networks;
        selectedWifi = networks.isEmpty ? null : networks.first;
      },
    );
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
      if (payload.isSoftAp) {
        await _releaseSoftApNetwork();
      }
      final claimed = await _claimDeviceWithNetworkRetry(
        s: s,
        token: token,
        payload: payload,
      );
      final loadedDevices = await _listDevicesWithNetworkRetry(token);
      devices = loadedDevices;
      selectedDevice = loadedDevices.firstWhere(
        (device) => device.deviceId == claimed.deviceId,
        orElse: () => claimed,
      );
    });
  }

  Future<void> _releaseSoftApNetwork() async {
    try {
      await _provisioning.disconnect();
    } catch (_) {
      // The ESP may reboot immediately after provisioning; the cloud claim can
      // continue as long as Android releases the SoftAP network binding.
    }
    await Future<void>.delayed(const Duration(seconds: 3));
  }

  Future<AppDevice> _claimDeviceWithNetworkRetry({
    required AppStrings s,
    required String token,
    required ProvisioningQrPayload payload,
  }) async {
    Future<AppDevice> claim() {
      return _deviceService
          .claimDevice(
            bearerToken: token,
            deviceId: payload.deviceId,
            claimCode: payload.claimCode,
            nickname: deviceNicknameController.text.trim().isEmpty
                ? null
                : deviceNicknameController.text.trim(),
          )
          .catchError((Object error) {
            if (error is ApiError &&
                error.statusCode == 401 &&
                error.message.toLowerCase().contains('claim')) {
              throw ApiError(
                s.invalidClaimCodeHelp,
                statusCode: error.statusCode,
              );
            }
            throw error;
          });
    }

    try {
      return await claim();
    } on ApiError {
      rethrow;
    } catch (_) {
      await Future<void>.delayed(const Duration(seconds: 3));
      return claim();
    }
  }

  Future<List<AppDevice>> _listDevicesWithNetworkRetry(String token) async {
    try {
      return await _deviceService.listDevices(token);
    } catch (_) {
      await Future<void>.delayed(const Duration(seconds: 2));
      return _deviceService.listDevices(token);
    }
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

  void setGroupKind(String value) {
    groupKind = value;
    notifyListeners();
  }

  void setGroupInviteRole(String value) {
    groupInviteRole = value;
    notifyListeners();
  }

  void setGroupDeviceRole(String value) {
    groupDeviceRole = value;
    notifyListeners();
  }

  void selectGroup(AccountGroup group) {
    selectedGroup = group;
    groupMembers = const [];
    groupDevices = const [];
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

  AccountGroup requireSelectedGroup(AppStrings s) {
    final group = selectedGroup;
    if (group == null) {
      throw ApiError(s.selectGroupFirst);
    }
    return group;
  }

  Future<void> _refreshGroupsWithToken(
    String token, {
    String? preferredGroupId,
  }) async {
    final loadedGroups = await _groupService.listGroups(token);
    groups = loadedGroups;
    if (loadedGroups.isEmpty) {
      selectedGroup = null;
      groupMembers = const [];
      groupDevices = const [];
      return;
    }
    final preferred = preferredGroupId ?? selectedGroup?.groupId;
    selectedGroup = loadedGroups.firstWhere(
      (group) => group.groupId == preferred,
      orElse: () => loadedGroups.first,
    );
  }

  Future<void> _tryRefreshGroupsWithToken(String token) async {
    try {
      await _refreshGroupsWithToken(token);
    } catch (_) {
      groups = const [];
      selectedGroup = null;
      groupMembers = const [];
      groupDevices = const [];
    }
  }

  Future<void> _refreshGroupDetailWithToken(
    String token,
    String groupId,
  ) async {
    final results = await Future.wait([
      _groupService.listMembers(bearerToken: token, groupId: groupId),
      _groupService.listDevices(bearerToken: token, groupId: groupId),
    ]);
    groupMembers = results[0] as List<AccountGroupMember>;
    groupDevices = results[1] as List<AppDevice>;
  }

  void _requireSixCharacterCode(AppStrings s, String code) {
    if (!RegExp(r'^[A-Za-z0-9]{6}$').hasMatch(code)) {
      throw ApiError(s.invalidSixCode);
    }
  }

  @override
  void dispose() {
    baseUrlController.dispose();
    emailController.dispose();
    passwordController.dispose();
    deviceNicknameController.dispose();
    renameController.dispose();
    wifiPasswordController.dispose();
    softApPasswordController.dispose();
    verifyEmailTokenController.dispose();
    resetEmailController.dispose();
    resetTokenController.dispose();
    resetPasswordController.dispose();
    inviteEmailController.dispose();
    inviteTokenController.dispose();
    groupNameController.dispose();
    groupInviteEmailController.dispose();
    groupInviteCodeController.dispose();
    super.dispose();
  }
}

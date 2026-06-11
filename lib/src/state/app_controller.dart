import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart' hide ImageInfo;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../../models.dart';
import '../../services/api_client.dart';
import '../../services/album_service.dart';
import '../../services/auth_service.dart';
import '../../services/device_service.dart';
import '../../services/group_service.dart';
import '../../services/image_service.dart';
import '../../services/notification_service.dart';
import '../../services/profile_service.dart';
import '../../services/provisioning_service.dart';
import '../../services/session_store.dart';
import '../../services/timeline_service.dart';
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
  final wifiNameController = TextEditingController();
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
  final albumNameController = TextEditingController();
  final albumSearchController = TextEditingController();
  final profileNameController = TextEditingController();
  final profileBioController = TextEditingController();

  final ProvisioningService _provisioning;
  final SessionStore _sessionStore;

  AuthSession? session;
  ProvisioningQrPayload? qrPayload;
  List<ProvisioningDevice> provisioningDevices = const [];
  List<WifiNetwork> wifiNetworks = const [];
  String provisioningTransport = 'ble';
  bool provisioningSearchAttempted = false;
  bool provisioningConnected = false;
  List<AppDevice> devices = const [];
  AppDevice? selectedDevice;
  WifiNetwork? selectedWifi;
  List<DeviceMember> members = const [];
  List<StatusEvent> statusEvents = const [];
  List<AccountGroup> groups = const [];
  AccountGroup? selectedGroup;
  List<AccountGroupMember> groupMembers = const [];
  List<AppDevice> groupDevices = const [];
  List<InkAlbum> albums = const [];
  List<InkPhoto> photos = const [];
  List<InkTimelineEvent> timelineEvents = const [];
  List<InkNotification> notifications = const [];
  StorageSummary? storageSummary;
  UserPreferences preferences = const UserPreferences();
  InkAlbum? selectedAlbum;
  ImageInfo? latestImage;
  Uint8List? previewPng;
  XFile? selectedImage;
  String direction = 'portrait';
  String mode = 'scale';
  int rotationDegrees = 0;
  String inviteRole = 'viewer';
  String groupKind = 'family';
  String groupInviteRole = 'member';
  String groupDeviceRole = 'admin';
  bool dither = true;
  bool busy = false;
  String? message;
  String? uiFeatureError;
  String timelineRange = 'all';

  static const _googleServerClientId =
      '21000885315-r2b3c1ea0jq6aiurvturrt4sg323pjic.apps.googleusercontent.com';
  static Future<void>? _googleInitialization;

  EpaperApiClient get _api => EpaperApiClient(baseUrl: baseUrlController.text);
  AuthService get _auth => AuthService(_api);
  DeviceBindingService get _deviceService => DeviceBindingService(_api);
  GroupService get _groupService => GroupService(_api);
  ImageService get _imageService => ImageService(_api);
  AlbumService get _albumService => AlbumService(_api);
  TimelineService get _timelineService => TimelineService(_api);
  NotificationService get _notificationService => NotificationService(_api);
  ProfileService get _profileService => ProfileService(_api);
  String? get bearerToken => session?.accessToken;
  User? get currentUser => session?.user;

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
      await _tryRefreshUiFeaturesWithToken(stored.accessToken);
      selectedDevice = loadedDevices.isEmpty ? null : loadedDevices.first;
      renameController.text = selectedDevice?.nickname ?? '';
      _syncProfileControllers(session?.user);
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
      await _tryRefreshUiFeaturesWithToken(nextSession.accessToken);
      selectedDevice = loadedDevices.isEmpty ? null : loadedDevices.first;
      renameController.text = selectedDevice?.nickname ?? '';
      _syncProfileControllers(session?.user);
    });
  }

  Future<void> loginWithApple(AppStrings s) async {
    await runAction(s, s.isZh ? 'Apple 登录' : 'Apple sign in', () async {
      final available = await SignInWithApple.isAvailable();
      if (!available) {
        throw ApiError(
          s.isZh
              ? '当前设备不支持 Apple 登录。'
              : 'Apple sign in is not available on this device.',
        );
      }
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );
      final identityToken = credential.identityToken;
      if (identityToken == null || identityToken.isEmpty) {
        throw ApiError(
          s.isZh ? 'Apple 未返回身份令牌。' : 'Apple did not return an identity token.',
        );
      }
      final fullName = [
        credential.givenName,
        credential.familyName,
      ].whereType<String>().where((part) => part.isNotEmpty).join(' ');
      await _finishOauthLogin(
        await _auth.loginWithApple(
          identityToken: identityToken,
          authorizationCode: credential.authorizationCode,
          email: credential.email,
          fullName: fullName.isEmpty ? null : fullName,
        ),
      );
    });
  }

  Future<void> loginWithGoogle(AppStrings s) async {
    await runAction(s, s.isZh ? 'Google 登录' : 'Google sign in', () async {
      final google = GoogleSignIn.instance;
      _googleInitialization ??= google.initialize(
        serverClientId: _googleServerClientId,
      );
      await _googleInitialization;
      if (!google.supportsAuthenticate()) {
        throw ApiError(
          s.isZh
              ? '当前平台不支持此 Google 登录方式。'
              : 'Google sign in is not supported on this platform.',
        );
      }
      final account = await google.authenticate();
      final identityToken = account.authentication.idToken;
      if (identityToken == null || identityToken.isEmpty) {
        throw ApiError(
          s.isZh
              ? 'Google 未返回身份令牌。'
              : 'Google did not return an identity token.',
        );
      }
      final serverAuth = await account.authorizationClient.authorizeServer([
        'email',
        'profile',
      ]);
      await _finishOauthLogin(
        await _auth.loginWithGoogle(
          identityToken: identityToken,
          authorizationCode: serverAuth?.serverAuthCode,
          email: account.email,
          displayName: account.displayName,
        ),
      );
    });
  }

  Future<void> _finishOauthLogin(AuthSession nextSession) async {
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
    await _tryRefreshUiFeaturesWithToken(nextSession.accessToken);
    selectedDevice = loadedDevices.isEmpty ? null : loadedDevices.first;
    renameController.text = selectedDevice?.nickname ?? '';
    _syncProfileControllers(session?.user);
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
      albums = const [];
      photos = const [];
      timelineEvents = const [];
      notifications = const [];
      storageSummary = null;
      selectedAlbum = null;
      uiFeatureError = null;
      profileNameController.clear();
      profileBioController.clear();
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
      await _tryRefreshUiFeaturesWithToken(token);
    });
  }

  Future<void> updateProfile(AppStrings s) async {
    final token = requireLogin(s);
    await runAction(s, s.isZh ? '更新个人资料' : 'Update profile', () async {
      final updated = await _profileService.updateProfile(
        bearerToken: token,
        displayName: profileNameController.text.trim().isEmpty
            ? null
            : profileNameController.text.trim(),
        bio: profileBioController.text.trim().isEmpty
            ? null
            : profileBioController.text.trim(),
      );
      _replaceSessionUser(updated);
      _syncProfileControllers(updated);
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
      provisioningDevices = const [];
      wifiNetworks = const [];
      selectedWifi = null;
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

  Future<void> deleteSelectedGroup(AppStrings s) async {
    final token = requireLogin(s);
    final group = requireSelectedGroup(s);
    await runAction(s, s.deleteGroupAction, () async {
      await _groupService.deleteGroup(
        bearerToken: token,
        groupId: group.groupId,
      );
      groupMembers = const [];
      groupDevices = const [];
      await _refreshGroupsWithToken(token);
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

  Future<void> removeSelectedDeviceFromGroup(
    AppStrings s,
    AppDevice device,
  ) async {
    final token = requireLogin(s);
    final group = requireSelectedGroup(s);
    await runAction(s, s.isZh ? '移除共享设备' : 'Remove shared device', () async {
      await _groupService.removeDevice(
        bearerToken: token,
        groupId: group.groupId,
        deviceId: device.deviceId,
      );
      await _refreshGroupDetailWithToken(token, group.groupId);
    });
  }

  void applyQrPayload(AppStrings s, String raw) {
    try {
      final payload = ProvisioningQrPayload.fromRaw(raw);
      qrPayload = payload;
      provisioningTransport = payload.isSoftAp ? 'softap' : 'ble';
      provisioningSearchAttempted = false;
      provisioningConnected = false;
      softApPasswordController.text = payload.softApPassword ?? '';
      provisioningDevices = payload.isSoftAp
          ? [_softApFallbackDevice(s, payload)]
          : const [];
      wifiNetworks = const [];
      selectedWifi = null;
      message = s.completed(s.scanDeviceQr);
    } catch (error) {
      final detail = error is FormatException ? error.message : '$error';
      message = '${s.invalidQrPayload}: $detail';
    }
    notifyListeners();
  }

  Future<void> searchProvisioningDevice(AppStrings s) async {
    final payload = requireQr(s);
    final useSoftAp = provisioningTransport == 'softap';
    await runAction(
      s,
      useSoftAp ? s.softApSearchAction : s.bleSearchAction,
      () async {
        final granted = await _provisioning.requestPermissions();
        if (!granted) {
          throw ApiError(s.provisioningPermissionDenied);
        }
        List<ProvisioningDevice> devices;
        try {
          final search = useSoftAp
              ? _provisioning.searchSoftApDevices(
                  prefix: payload.devicePrefix,
                  name: payload.name,
                )
              : _provisioning.searchBleDevices(payload.devicePrefix);
          devices = await search.timeout(
            const Duration(seconds: 18),
            onTimeout: () => throw TimeoutException(
              s.provisioningSearchTimeout,
              const Duration(seconds: 18),
            ),
          );
        } catch (_) {
          provisioningSearchAttempted = true;
          if (!useSoftAp) {
            rethrow;
          }
          devices = [_softApFallbackDevice(s, payload)];
        }
        provisioningSearchAttempted = true;
        provisioningDevices = useSoftAp
            ? _withSoftApFallback(s, payload, devices)
            : devices;
        if (devices.isEmpty) {
          if (useSoftAp) {
            provisioningDevices = [_softApFallbackDevice(s, payload)];
            return;
          }
          throw ApiError(s.noProvisioningDevicesFound);
        }
      },
    );
  }

  ProvisioningDevice _softApFallbackDevice(
    AppStrings s,
    ProvisioningQrPayload payload,
  ) {
    return ProvisioningDevice(
      name: payload.name,
      serviceUuid: s.softApManualFallback,
    );
  }

  List<ProvisioningDevice> _withSoftApFallback(
    AppStrings s,
    ProvisioningQrPayload payload,
    List<ProvisioningDevice> devices,
  ) {
    if (devices.any((device) => device.name == payload.name)) {
      return devices;
    }
    return [_softApFallbackDevice(s, payload), ...devices];
  }

  Future<void> connectProvisioningDevice(
    AppStrings s,
    ProvisioningDevice device,
  ) async {
    final payload = requireQr(s);
    final useSoftAp = provisioningTransport == 'softap';
    await runAction(
      s,
      useSoftAp ? s.softApConnectAction : s.bleConnectAction,
      () async {
        if (useSoftAp) {
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
        final networks = await _provisioning.scanWifiNetworks().catchError(
          (_) => <WifiNetwork>[],
        );
        wifiNetworks = networks;
        selectedWifi = networks.isEmpty ? null : networks.first;
        wifiNameController.text = selectedWifi?.ssid ?? '';
        provisioningConnected = true;
      },
    );
  }

  Future<void> connectScannedSoftApDevice(AppStrings s) async {
    final payload = requireQr(s);
    await connectProvisioningDevice(s, _softApFallbackDevice(s, payload));
  }

  Future<void> provisionAndClaim(AppStrings s) async {
    final payload = requireQr(s);
    final token = requireLogin(s);
    final ssid = wifiNameController.text.trim();
    if (ssid.isEmpty) {
      throw ApiError(s.selectWifiFirst);
    }
    await runAction(s, s.provisionClaimAction, () async {
      await _provisioning.provisionWifi(
        ssid: ssid,
        password: wifiPasswordController.text,
      );
      if (provisioningTransport == 'softap') {
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

  Future<void> chooseImage(AppStrings s) async {
    await runAction(s, s.chooseImageAction, () async {
      final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (picked == null) {
        return;
      }
      selectedImage = picked;
      latestImage = null;
      await _refreshSelectedImagePreview();
    });
  }

  Future<void> uploadAndAssign(AppStrings s) async {
    await runAction(s, s.uploadAssignAction, () async {
      final token = requireLogin(s);
      final device = selectedDevice;
      final picked = selectedImage;
      if (picked == null) {
        throw ApiError(s.selectImageFirst);
      }
      if (device == null && selectedAlbum == null) {
        throw ApiError(
          s.isZh ? '请选择目标相册或设备。' : 'Choose a target album or device.',
        );
      }
      final image = await _uploadSelectedImage(token, picked);
      await _addImageToSelectedAlbumIfNeeded(s, token, image);
      if (device != null) {
        await _deviceService.assignImage(
          bearerToken: token,
          deviceId: device.deviceId,
          imageId: image.imageId,
        );
      }
      final preview = await _imageService.getPreviewPng(
        image,
        bearerToken: token,
      );
      final loadedDevices = device == null
          ? devices
          : await _deviceService.listDevices(token);
      latestImage = image;
      photos = [
        InkPhoto.fromImageInfo(image, deviceId: device?.deviceId),
        ...photos,
      ];
      timelineEvents = [
        InkTimelineEvent(
          eventId: 'local-${image.imageId}',
          type: device == null ? 'photo_uploaded' : 'photo_assigned',
          title: device == null
              ? (s.isZh ? '照片已上传' : 'Photo uploaded')
              : (s.isZh ? '照片已下发' : 'Photo sent'),
          subtitle: device == null
              ? selectedAlbum?.title
              : _deviceTitle(device),
          photoId: image.imageId,
          albumId: selectedAlbum?.albumId,
          deviceId: device?.deviceId,
          previewUrl: image.previewUrl,
          createdAt: image.createdAt,
        ),
        ...timelineEvents,
      ];
      previewPng = preview;
      devices = loadedDevices;
      if (device != null) {
        selectedDevice = loadedDevices.firstWhere(
          (item) => item.deviceId == device.deviceId,
          orElse: () => device,
        );
      }
      await _tryRefreshUiFeaturesWithToken(token);
    });
  }

  Future<void> uploadSelectedImageForPreview(AppStrings s) async {
    await runAction(s, s.generatePreviewAction, () async {
      final token = requireLogin(s);
      final picked = selectedImage;
      if (picked == null) {
        throw ApiError(s.selectImageFirst);
      }
      final image = await _uploadSelectedImage(token, picked);
      await _addImageToSelectedAlbumIfNeeded(s, token, image);
      final preview = await _imageService.getPreviewPng(
        image,
        bearerToken: token,
      );
      latestImage = image;
      previewPng = preview;
      photos = [InkPhoto.fromImageInfo(image), ...photos];
      timelineEvents = [
        InkTimelineEvent(
          eventId: 'local-preview-${image.imageId}',
          type: 'photo_uploaded',
          title: s.isZh ? '预览已生成' : 'Preview ready',
          subtitle: selectedAlbum?.title,
          photoId: image.photoId ?? image.imageId,
          albumId: selectedAlbum?.albumId,
          previewUrl: image.previewUrl,
          createdAt: image.createdAt,
        ),
        ...timelineEvents,
      ];
      await _tryRefreshUiFeaturesWithToken(token);
    });
  }

  Future<void> assignLatestImageToSelectedDevice(AppStrings s) async {
    await runAction(s, s.confirmSendAction, () async {
      final token = requireLogin(s);
      final device = requireSelectedDevice(s);
      final image = latestImage;
      if (image == null) {
        throw ApiError(s.isZh ? '请先生成预览。' : 'Generate a preview first.');
      }
      await _deviceService.assignImage(
        bearerToken: token,
        deviceId: device.deviceId,
        imageId: image.imageId,
      );
      final loadedDevices = await _deviceService.listDevices(token);
      devices = loadedDevices;
      selectedDevice = loadedDevices.firstWhere(
        (item) => item.deviceId == device.deviceId,
        orElse: () => device,
      );
      photos = [
        InkPhoto.fromImageInfo(image, deviceId: device.deviceId),
        ...photos,
      ];
      timelineEvents = [
        InkTimelineEvent(
          eventId: 'local-assigned-${image.imageId}',
          type: 'photo_assigned',
          title: s.isZh ? '照片已下发' : 'Photo sent',
          subtitle: _deviceTitle(device),
          photoId: image.photoId ?? image.imageId,
          albumId: selectedAlbum?.albumId,
          deviceId: device.deviceId,
          previewUrl: image.previewUrl,
          createdAt: image.createdAt,
        ),
        ...timelineEvents,
      ];
      await _tryRefreshUiFeaturesWithToken(token);
    });
  }

  Future<void> refreshUiFeatures(AppStrings s) async {
    final token = requireLogin(s);
    await runAction(s, s.isZh ? '刷新内容' : 'Refresh content', () async {
      await _refreshUiFeaturesWithToken(token);
    });
  }

  Future<void> createAlbum(AppStrings s) async {
    final token = requireLogin(s);
    await runAction(s, s.isZh ? '创建相册' : 'Create album', () async {
      final title = albumNameController.text.trim();
      if (title.isEmpty) {
        throw ApiError(s.isZh ? '请输入相册名称。' : 'Enter an album name.');
      }
      final album = await _albumService.createAlbum(
        bearerToken: token,
        title: title,
      );
      albumNameController.clear();
      await _refreshAlbumsWithToken(token, preferredAlbumId: album.albumId);
    });
  }

  Future<void> renameSelectedAlbum(AppStrings s) async {
    final token = requireLogin(s);
    final album = selectedAlbum;
    if (album == null) {
      throw ApiError(s.isZh ? '请先选择相册。' : 'Select an album first.');
    }
    await runAction(s, s.isZh ? '重命名相册' : 'Rename album', () async {
      final title = albumNameController.text.trim();
      if (title.isEmpty) {
        throw ApiError(s.isZh ? '请输入相册名称。' : 'Enter an album name.');
      }
      final updated = await _albumService.updateAlbum(
        bearerToken: token,
        albumId: album.albumId,
        title: title,
        subtitle: album.subtitle,
      );
      selectedAlbum = updated;
      await _refreshAlbumsWithToken(token, preferredAlbumId: updated.albumId);
    });
  }

  Future<void> deleteSelectedAlbum(AppStrings s) async {
    final token = requireLogin(s);
    final album = selectedAlbum;
    if (album == null) {
      throw ApiError(s.isZh ? '请先选择相册。' : 'Select an album first.');
    }
    await runAction(s, s.isZh ? '删除相册' : 'Delete album', () async {
      await _albumService.deleteAlbum(
        bearerToken: token,
        albumId: album.albumId,
      );
      await _refreshAlbumsWithToken(token);
    });
  }

  Future<void> toggleFavoritePhoto(AppStrings s, InkPhoto photo) async {
    final token = requireLogin(s);
    await runAction(s, s.isZh ? '更新收藏' : 'Update favorite', () async {
      final updated = await _albumService.updatePhoto(
        bearerToken: token,
        photoId: photo.photoId,
        favorite: !photo.favorite,
      );
      photos = [
        for (final item in photos)
          item.photoId == updated.photoId ? updated : item,
      ];
    });
  }

  Future<void> addLatestPhotoToSelectedAlbum(AppStrings s) async {
    final token = requireLogin(s);
    final album = selectedAlbum;
    final image = latestImage;
    if (album == null) {
      throw ApiError(s.isZh ? '请先选择相册。' : 'Select an album first.');
    }
    if (image == null) {
      throw ApiError(s.isZh ? '请先上传照片。' : 'Upload a photo first.');
    }
    await runAction(s, s.isZh ? '加入相册' : 'Add to album', () async {
      await _addImageToAlbum(s, token, album, image);
      await _refreshAlbumsWithToken(token, preferredAlbumId: album.albumId);
      photos = await _albumService.listPhotos(token);
    });
  }

  Future<void> uploadToSelectedAlbum(AppStrings s) async {
    await runAction(s, s.isZh ? '上传到相册' : 'Upload to album', () async {
      final token = requireLogin(s);
      final album = selectedAlbum;
      if (album == null) {
        throw ApiError(s.isZh ? '请先选择相册。' : 'Select an album first.');
      }
      final picked = selectedImage;
      if (picked == null) {
        throw ApiError(s.selectImageFirst);
      }
      final image = await _uploadSelectedImage(token, picked);
      await _addImageToAlbum(s, token, album, image);
      final preview = await _imageService.getPreviewPng(
        image,
        bearerToken: token,
      );
      latestImage = image;
      previewPng = preview;
      photos = [InkPhoto.fromImageInfo(image), ...photos];
      timelineEvents = [
        InkTimelineEvent(
          eventId: 'local-${image.imageId}',
          type: 'photo_uploaded',
          title: s.isZh ? '照片已上传' : 'Photo uploaded',
          subtitle: album.title,
          photoId: image.photoId ?? image.imageId,
          albumId: album.albumId,
          previewUrl: image.previewUrl,
          createdAt: image.createdAt,
        ),
        ...timelineEvents,
      ];
      await _refreshAlbumsWithToken(token, preferredAlbumId: album.albumId);
      await _tryRefreshUiFeaturesWithToken(token);
    });
  }

  Future<void> createVirtualDevice(AppStrings s) async {
    final token = requireLogin(s);
    await runAction(s, s.isZh ? '创建测试设备' : 'Create test device', () async {
      final device = await _deviceService.createVirtualDevice(
        bearerToken: token,
        nickname: s.isZh ? '测试墨水屏' : 'Test Frame',
      );
      final loadedDevices = await _deviceService.listDevices(token);
      devices = loadedDevices;
      selectedDevice = loadedDevices.firstWhere(
        (item) => item.deviceId == device.deviceId,
        orElse: () => device,
      );
      renameController.text = selectedDevice?.nickname ?? '';
      await _tryRefreshUiFeaturesWithToken(token);
    });
  }

  Future<void> markNotificationRead(AppStrings s, InkNotification item) async {
    final token = requireLogin(s);
    await runAction(s, s.isZh ? '读取通知' : 'Read notification', () async {
      await _notificationService.markRead(
        bearerToken: token,
        notificationId: item.notificationId,
      );
      notifications = await _notificationService.listNotifications(token);
    });
  }

  Future<void> updatePreferences(AppStrings s, UserPreferences next) async {
    final token = requireLogin(s);
    await runAction(s, s.isZh ? '更新设置' : 'Update settings', () async {
      preferences = await _profileService.updatePreferences(
        bearerToken: token,
        preferences: next,
      );
    });
  }

  List<InkAlbum> get filteredAlbums {
    final query = albumSearchController.text.trim().toLowerCase();
    if (query.isEmpty) {
      return albums;
    }
    return albums
        .where(
          (album) =>
              album.title.toLowerCase().contains(query) ||
              album.tags.any((tag) => tag.toLowerCase().contains(query)),
        )
        .toList(growable: false);
  }

  void setAlbumSearch(String value) {
    albumSearchController.text = value;
    notifyListeners();
  }

  void selectAlbum(InkAlbum album) {
    selectedAlbum = album;
    albumNameController.text = album.title;
    notifyListeners();
  }

  void setTimelineRange(String value) {
    timelineRange = value;
    notifyListeners();
  }

  void selectDevice(AppDevice device) {
    selectedDevice = device;
    renameController.text = device.nickname ?? '';
    members = const [];
    statusEvents = const [];
    notifyListeners();
  }

  void selectProvisioningTransport(AppStrings s, String transport) {
    if (transport != 'ble' && transport != 'softap') {
      return;
    }
    provisioningTransport = transport;
    final payload = qrPayload;
    provisioningDevices = transport == 'softap' && payload != null
        ? [_softApFallbackDevice(s, payload)]
        : const [];
    wifiNetworks = const [];
    selectedWifi = null;
    provisioningSearchAttempted = false;
    provisioningConnected = false;
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
    wifiNameController.text = value?.ssid ?? '';
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

  Future<void> setRotationDegrees(int value) async {
    rotationDegrees = value;
    await _refreshSelectedImagePreview();
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

  Future<void> _tryRefreshUiFeaturesWithToken(String token) async {
    try {
      await _refreshUiFeaturesWithToken(token);
      uiFeatureError = null;
    } catch (error) {
      uiFeatureError = '$error';
      albums = const [];
      photos = const [];
      timelineEvents = const [];
      notifications = const [];
      storageSummary = null;
    }
  }

  Future<void> _refreshUiFeaturesWithToken(String token) async {
    await _refreshAlbumsWithToken(token);
    final results = await Future.wait<Object>([
      _profileService.getProfile(token),
      _albumService.listPhotos(token),
      _timelineService.listTimeline(
        bearerToken: token,
        range: timelineRange,
        albumId: selectedAlbum?.albumId,
        deviceId: selectedDevice?.deviceId,
      ),
      _notificationService.listNotifications(token),
      _profileService.getStorage(token),
      _profileService.getPreferences(token),
    ]);
    final user = results[0] as User;
    _replaceSessionUser(user);
    _syncProfileControllers(user);
    photos = results[1] as List<InkPhoto>;
    timelineEvents = results[2] as List<InkTimelineEvent>;
    notifications = results[3] as List<InkNotification>;
    storageSummary = results[4] as StorageSummary;
    preferences = results[5] as UserPreferences;
  }

  Future<void> _refreshAlbumsWithToken(
    String token, {
    String? preferredAlbumId,
  }) async {
    final loadedAlbums = await _albumService.listAlbums(token);
    albums = loadedAlbums;
    if (loadedAlbums.isEmpty) {
      selectedAlbum = null;
      return;
    }
    final preferred = preferredAlbumId ?? selectedAlbum?.albumId;
    selectedAlbum = loadedAlbums.firstWhere(
      (album) => album.albumId == preferred,
      orElse: () => loadedAlbums.first,
    );
    albumNameController.text = selectedAlbum?.title ?? '';
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

  Future<ImageInfo> _uploadSelectedImage(String token, XFile picked) async {
    final uploadFile = await _prepareUploadFile(picked, fullSize: true);
    return _imageService.uploadImage(
      bearerToken: token,
      filePath: uploadFile.path,
      fileName: uploadFile.fileName,
      options: UploadOptions(direction: direction, mode: mode, dither: dither),
    );
  }

  Future<void> _addImageToSelectedAlbumIfNeeded(
    AppStrings s,
    String token,
    ImageInfo image,
  ) async {
    final album = selectedAlbum;
    if (album == null) {
      return;
    }
    await _addImageToAlbum(s, token, album, image);
  }

  Future<void> _addImageToAlbum(
    AppStrings s,
    String token,
    InkAlbum album,
    ImageInfo image,
  ) async {
    final photoId = await _resolvePhotoIdForImage(token, image);
    try {
      await _albumService.addPhotoToAlbum(
        bearerToken: token,
        albumId: album.albumId,
        photoId: photoId,
      );
    } on ApiError catch (error) {
      final retriedPhotoId = await _resolvePhotoIdForImage(
        token,
        image,
        forceRefresh: true,
      );
      if (retriedPhotoId != photoId) {
        await _albumService.addPhotoToAlbum(
          bearerToken: token,
          albumId: album.albumId,
          photoId: retriedPhotoId,
        );
        return;
      }
      if (error.statusCode == 404 &&
          error.message.toLowerCase().contains('unknown photo')) {
        throw ApiError(
          s.isZh
              ? '上传成功，但服务端还没有返回可加入相册的 photo_id。请稍后刷新，或确认上传接口会创建照片库记录。'
              : 'Upload succeeded, but the server did not return a photo_id that can be added to albums. Refresh shortly or confirm uploads create photo library records.',
          statusCode: error.statusCode,
        );
      }
      rethrow;
    }
  }

  Future<String> _resolvePhotoIdForImage(
    String token,
    ImageInfo image, {
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && image.photoId?.isNotEmpty == true) {
      return image.photoId!;
    }
    if (forceRefresh) {
      await Future<void>.delayed(const Duration(milliseconds: 450));
    }
    final loadedPhotos = await _albumService.listPhotos(token);
    photos = loadedPhotos;
    for (final photo in loadedPhotos) {
      if (photo.imageId == image.imageId ||
          photo.photoId == image.imageId ||
          photo.previewUrl == image.previewUrl ||
          photo.dataUrl == image.dataUrl) {
        return photo.photoId;
      }
    }
    return image.photoId ?? image.imageId;
  }

  Future<void> _refreshSelectedImagePreview() async {
    final picked = selectedImage;
    if (picked == null) {
      return;
    }
    final uploadFile = await _prepareUploadFile(picked, fullSize: false);
    previewPng = await File(uploadFile.path).readAsBytes();
  }

  Future<_UploadFile> _prepareUploadFile(
    XFile picked, {
    required bool fullSize,
  }) async {
    final normalizedRotation = rotationDegrees % 360;
    if (normalizedRotation == 0 && fullSize) {
      return _UploadFile(path: picked.path, fileName: picked.name);
    }
    final bytes = await File(picked.path).readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      return _UploadFile(path: picked.path, fileName: picked.name);
    }
    var prepared = img.copyRotate(
      img.bakeOrientation(decoded),
      angle: normalizedRotation,
    );
    if (!fullSize) {
      prepared = img.copyResize(
        prepared,
        width: prepared.width >= prepared.height ? 800 : null,
        height: prepared.height > prepared.width ? 800 : null,
      );
    }
    final tempFile = File(
      '${Directory.systemTemp.path}/inksplash_${DateTime.now().microsecondsSinceEpoch}_$normalizedRotation.png',
    );
    await tempFile.writeAsBytes(img.encodePng(prepared), flush: true);
    return _UploadFile(
      path: tempFile.path,
      fileName: 'inksplash_${normalizedRotation}_${picked.name}.png',
    );
  }

  @override
  void dispose() {
    baseUrlController.dispose();
    emailController.dispose();
    passwordController.dispose();
    deviceNicknameController.dispose();
    renameController.dispose();
    wifiNameController.dispose();
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
    albumNameController.dispose();
    albumSearchController.dispose();
    profileNameController.dispose();
    profileBioController.dispose();
    super.dispose();
  }

  void _replaceSessionUser(User user) {
    final current = session;
    if (current == null) {
      return;
    }
    session = AuthSession(
      accessToken: current.accessToken,
      tokenType: current.tokenType,
      user: user,
    );
  }

  void _syncProfileControllers(User? user) {
    profileNameController.text = user?.displayName ?? '';
    profileBioController.text = user?.bio ?? '';
  }
}

String _deviceTitle(AppDevice device) {
  return device.nickname?.isNotEmpty == true
      ? device.nickname!
      : device.deviceId;
}

class _UploadFile {
  const _UploadFile({required this.path, required this.fileName});

  final String path;
  final String fileName;
}

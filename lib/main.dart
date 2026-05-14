import 'dart:typed_data';

import 'package:flutter/material.dart' hide ImageInfo;
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'models.dart';
import 'services/api_client.dart';
import 'services/auth_service.dart';
import 'services/device_service.dart';
import 'services/image_service.dart';
import 'services/provisioning_service.dart';
import 'services/session_store.dart';

void main() {
  runApp(const InkSplashApp());
}

class InkSplashApp extends StatelessWidget {
  const InkSplashApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'InkSplash',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff176b87)),
        useMaterial3: true,
      ),
      home: const AppShell(),
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final _baseUrlController = TextEditingController(
    text: 'http://47.113.120.232',
  );
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _deviceNicknameController = TextEditingController();
  final _renameController = TextEditingController();
  final _wifiPasswordController = TextEditingController();
  final _verifyEmailTokenController = TextEditingController();
  final _resetEmailController = TextEditingController();
  final _resetTokenController = TextEditingController();
  final _resetPasswordController = TextEditingController();
  final _inviteEmailController = TextEditingController();
  final _inviteTokenController = TextEditingController();

  final _provisioning = const ProvisioningService();
  final _sessionStore = const SessionStore();

  AuthSession? _session;
  ProvisioningQrPayload? _qrPayload;
  List<ProvisioningDevice> _provisioningDevices = const [];
  List<WifiNetwork> _wifiNetworks = const [];
  List<AppDevice> _devices = const [];
  AppDevice? _selectedDevice;
  WifiNetwork? _selectedWifi;
  List<DeviceMember> _members = const [];
  List<StatusEvent> _statusEvents = const [];
  ImageInfo? _latestImage;
  Uint8List? _previewPng;
  String _direction = 'auto';
  String _mode = 'scale';
  String _inviteRole = 'viewer';
  bool _dither = true;
  bool _busy = false;
  String? _message;

  EpaperApiClient get _api => EpaperApiClient(baseUrl: _baseUrlController.text);
  AuthService get _auth => AuthService(_api);
  DeviceBindingService get _deviceService => DeviceBindingService(_api);
  ImageService get _imageService => ImageService(_api);
  String? get _bearerToken => _session?.accessToken;

  @override
  void initState() {
    super.initState();
    _restoreSession();
  }

  @override
  void dispose() {
    _baseUrlController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _deviceNicknameController.dispose();
    _renameController.dispose();
    _wifiPasswordController.dispose();
    _verifyEmailTokenController.dispose();
    _resetEmailController.dispose();
    _resetTokenController.dispose();
    _resetPasswordController.dispose();
    _inviteEmailController.dispose();
    _inviteTokenController.dispose();
    super.dispose();
  }

  Future<void> _run(String action, Future<void> Function() task) async {
    if (_busy) {
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await task();
      setState(() => _message = '$action completed');
    } catch (error) {
      setState(() => _message = '$action failed: $error');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _login({required bool register}) async {
    await _run(register ? 'Register' : 'Login', () async {
      final email = _emailController.text.trim();
      final password = _passwordController.text;
      if (email.length < 3) {
        throw const ApiError('Please enter your email.');
      }
      if (password.length < 8) {
        throw const ApiError('Password must be at least 8 characters.');
      }
      final session = register
          ? await _auth.register(email: email, password: password)
          : await _auth.login(email: email, password: password);
      final devices = await _deviceService.listDevices(session.accessToken);
      await _sessionStore.save(
        baseUrl: _baseUrlController.text.trim(),
        accessToken: session.accessToken,
      );
      setState(() {
        _session = session;
        _devices = devices;
        _selectedDevice = devices.isEmpty ? null : devices.first;
        _renameController.text = _selectedDevice?.nickname ?? '';
      });
    });
  }

  Future<void> _restoreSession() async {
    final stored = await _sessionStore.load();
    if (stored == null) {
      return;
    }
    setState(() => _busy = true);
    try {
      _baseUrlController.text = stored.baseUrl;
      final user = await _auth.me(stored.accessToken);
      final devices = await _deviceService.listDevices(stored.accessToken);
      setState(() {
        _session = AuthSession(
          accessToken: stored.accessToken,
          tokenType: 'bearer',
          user: user,
        );
        _devices = devices;
        _selectedDevice = devices.isEmpty ? null : devices.first;
        _renameController.text = _selectedDevice?.nickname ?? '';
      });
    } catch (error) {
      await _sessionStore.clear();
      if (mounted) {
        setState(() => _message = 'Saved login expired: $error');
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _logout() async {
    await _run('Logout', () async {
      await _sessionStore.clear();
      setState(() {
        _session = null;
        _devices = const [];
        _selectedDevice = null;
        _members = const [];
        _statusEvents = const [];
      });
    });
  }

  Future<void> _refreshDevices() async {
    final token = _requireLogin();
    await _run('Refresh devices', () async {
      final devices = await _deviceService.listDevices(token);
      setState(() {
        _devices = devices;
        if (devices.isEmpty) {
          _selectedDevice = null;
          _renameController.text = '';
        } else if (_selectedDevice == null ||
            !devices.any(
              (device) => device.deviceId == _selectedDevice!.deviceId,
            )) {
          _selectedDevice = devices.first;
          _renameController.text = _selectedDevice?.nickname ?? '';
        }
      });
    });
  }

  Future<void> _requestEmailVerification() async {
    final token = _requireLogin();
    await _run('Request verification email', () async {
      await _auth.requestEmailVerification(token);
    });
  }

  Future<void> _confirmEmailVerification() async {
    await _run('Confirm email', () async {
      final user = await _auth.confirmEmailVerification(
        token: _verifyEmailTokenController.text.trim(),
      );
      final session = _session;
      if (session == null) {
        return;
      }
      setState(() {
        _session = AuthSession(
          accessToken: session.accessToken,
          tokenType: session.tokenType,
          user: user,
        );
      });
    });
  }

  Future<void> _requestPasswordReset() async {
    await _run('Request password reset', () async {
      final email = _resetEmailController.text.trim().isEmpty
          ? _emailController.text.trim()
          : _resetEmailController.text.trim();
      if (email.length < 3) {
        throw const ApiError('Please enter your email.');
      }
      await _auth.requestPasswordReset(email: email);
    });
  }

  Future<void> _confirmPasswordReset() async {
    await _run('Reset password', () async {
      final newPassword = _resetPasswordController.text;
      if (newPassword.length < 8) {
        throw const ApiError('Password must be at least 8 characters.');
      }
      await _auth.confirmPasswordReset(
        token: _resetTokenController.text.trim(),
        newPassword: newPassword,
      );
    });
  }

  Future<void> _renameSelectedDevice() async {
    final token = _requireLogin();
    final device = _requireSelectedDevice();
    await _run('Rename device', () async {
      final updated = await _deviceService.updateDevice(
        bearerToken: token,
        deviceId: device.deviceId,
        nickname: _renameController.text.trim().isEmpty
            ? null
            : _renameController.text.trim(),
      );
      final devices = await _deviceService.listDevices(token);
      setState(() {
        _devices = devices;
        _selectedDevice = updated;
      });
    });
  }

  Future<void> _unbindSelectedDevice() async {
    final token = _requireLogin();
    final device = _requireSelectedDevice();
    await _run('Unbind device', () async {
      await _deviceService.unbindDevice(
        bearerToken: token,
        deviceId: device.deviceId,
      );
      final devices = await _deviceService.listDevices(token);
      setState(() {
        _devices = devices;
        _selectedDevice = devices.isEmpty ? null : devices.first;
        _renameController.text = _selectedDevice?.nickname ?? '';
        _members = const [];
        _statusEvents = const [];
      });
    });
  }

  Future<void> _refreshDeviceExtras() async {
    final token = _requireLogin();
    final device = _requireSelectedDevice();
    await _run('Refresh device detail', () async {
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
      setState(() {
        _members = results[0] as List<DeviceMember>;
        _statusEvents = results[1] as List<StatusEvent>;
      });
    });
  }

  Future<void> _createInvite() async {
    final token = _requireLogin();
    final device = _requireSelectedDevice();
    await _run('Create invite', () async {
      await _deviceService.createInvite(
        bearerToken: token,
        deviceId: device.deviceId,
        email: _inviteEmailController.text.trim(),
        role: _inviteRole,
      );
    });
  }

  Future<void> _acceptInvite() async {
    final token = _requireLogin();
    await _run('Accept invite', () async {
      final device = await _deviceService.acceptInvite(
        bearerToken: token,
        token: _inviteTokenController.text.trim(),
      );
      final devices = await _deviceService.listDevices(token);
      setState(() {
        _devices = devices;
        _selectedDevice = devices.firstWhere(
          (item) => item.deviceId == device.deviceId,
          orElse: () => device,
        );
        _renameController.text = _selectedDevice?.nickname ?? '';
      });
    });
  }

  Future<void> _scanQr() async {
    final raw = await Navigator.of(
      context,
    ).push<String>(MaterialPageRoute(builder: (_) => const QrScannerPage()));
    if (raw == null || raw.isEmpty) {
      return;
    }
    try {
      final payload = ProvisioningQrPayload.fromRaw(raw);
      setState(() {
        _qrPayload = payload;
        _provisioningDevices = const [];
        _wifiNetworks = const [];
        _selectedWifi = null;
      });
    } catch (error) {
      final message = error is FormatException ? error.message : '$error';
      setState(() => _message = 'Invalid QR payload: $message');
    }
  }

  Future<void> _searchProvisioningDevice() async {
    final payload = _requireQr();
    await _run('BLE search', () async {
      await _provisioning.requestPermissions();
      final devices = await _provisioning.searchBleDevices(
        payload.devicePrefix,
      );
      setState(() => _provisioningDevices = devices);
    });
  }

  Future<void> _connectProvisioningDevice(ProvisioningDevice device) async {
    final payload = _requireQr();
    await _run('BLE connect', () async {
      await _provisioning.connectBleDevice(
        name: device.name,
        proofOfPossession: payload.proofOfPossession,
        security: payload.security,
      );
      final networks = await _provisioning.scanWifiNetworks();
      setState(() {
        _wifiNetworks = networks;
        _selectedWifi = networks.isEmpty ? null : networks.first;
      });
    });
  }

  Future<void> _provisionAndClaim() async {
    final payload = _requireQr();
    final token = _requireLogin();
    final wifi = _selectedWifi;
    if (wifi == null) {
      throw const ApiError('Select a Wi-Fi network first');
    }
    await _run('Provision and claim', () async {
      await _provisioning.provisionWifi(
        ssid: wifi.ssid,
        password: _wifiPasswordController.text,
      );
      final claimed = await _deviceService.claimDevice(
        bearerToken: token,
        deviceId: payload.deviceId,
        claimCode: payload.claimCode,
        nickname: _deviceNicknameController.text.trim().isEmpty
            ? null
            : _deviceNicknameController.text.trim(),
      );
      final devices = await _deviceService.listDevices(token);
      setState(() {
        _devices = devices;
        _selectedDevice = devices.firstWhere(
          (device) => device.deviceId == claimed.deviceId,
          orElse: () => claimed,
        );
      });
    });
  }

  Future<void> _uploadAndAssign() async {
    await _run('Upload and assign', () async {
      final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (picked == null) {
        return;
      }
      final token = _requireLogin();
      final device = _selectedDevice;
      if (device == null) {
        throw const ApiError('Select or bind a device first.');
      }
      final image = await _imageService.uploadImage(
        bearerToken: token,
        filePath: picked.path,
        fileName: picked.name,
        options: UploadOptions(
          direction: _direction,
          mode: _mode,
          dither: _dither,
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
      final devices = await _deviceService.listDevices(token);
      setState(() {
        _latestImage = image;
        _previewPng = preview;
        _devices = devices;
        _selectedDevice = devices.firstWhere(
          (item) => item.deviceId == device.deviceId,
          orElse: () => device,
        );
      });
    });
  }

  String _requireLogin() {
    final token = _bearerToken;
    if (token == null || token.isEmpty) {
      throw const ApiError('Login first');
    }
    return token;
  }

  ProvisioningQrPayload _requireQr() {
    final payload = _qrPayload;
    if (payload == null) {
      throw const ApiError('Scan the device QR code first');
    }
    return payload;
  }

  AppDevice _requireSelectedDevice() {
    final device = _selectedDevice;
    if (device == null) {
      throw const ApiError('Select or bind a device first.');
    }
    return device;
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('InkSplash'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.person), text: 'Account'),
              Tab(icon: Icon(Icons.devices), text: 'Devices'),
              Tab(icon: Icon(Icons.add_link), text: 'Bind'),
              Tab(icon: Icon(Icons.upload_file), text: 'Upload'),
            ],
          ),
        ),
        body: AbsorbPointer(
          absorbing: _busy,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _ConnectionPanel(controller: _baseUrlController, busy: _busy),
                const SizedBox(height: 12),
                if (_message != null) _MessageBanner(message: _message!),
                if (_busy) const LinearProgressIndicator(),
                Expanded(
                  child: TabBarView(
                    children: [
                      _accountTab(),
                      _devicesTab(),
                      _bindTab(),
                      _uploadTab(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _accountTab() {
    return ListView(
      children: [
        _Section(
          title: 'Cloud account',
          child: Column(
            children: [
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Password'),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: () => _login(register: false),
                    icon: const Icon(Icons.login),
                    label: const Text('Login'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _login(register: true),
                    icon: const Icon(Icons.person_add),
                    label: const Text('Register'),
                  ),
                  if (_session != null)
                    TextButton.icon(
                      onPressed: _logout,
                      icon: const Icon(Icons.logout),
                      label: const Text('Logout'),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _session == null
                      ? 'Not logged in'
                      : 'Logged in as ${_session!.user.email} (${_session!.user.emailVerified ? 'verified' : 'unverified'})',
                ),
              ),
              if (_session != null && !_session!.user.emailVerified) ...[
                const SizedBox(height: 16),
                const Divider(),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Email verification',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _requestEmailVerification,
                  icon: const Icon(Icons.mark_email_read_outlined),
                  label: const Text('Send verification email'),
                ),
                TextField(
                  controller: _verifyEmailTokenController,
                  decoration: const InputDecoration(
                    labelText: 'Verification token',
                  ),
                ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: _confirmEmailVerification,
                  icon: const Icon(Icons.verified_user_outlined),
                  label: const Text('Confirm verification'),
                ),
              ],
              const SizedBox(height: 16),
              const Divider(),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Password reset',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              TextField(
                controller: _resetEmailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Reset email',
                  helperText: 'Leave empty to use the email above.',
                ),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: _requestPasswordReset,
                    icon: const Icon(Icons.lock_reset),
                    label: const Text('Send reset email'),
                  ),
                ],
              ),
              TextField(
                controller: _resetTokenController,
                decoration: const InputDecoration(labelText: 'Reset token'),
              ),
              TextField(
                controller: _resetPasswordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'New password'),
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: _confirmPasswordReset,
                icon: const Icon(Icons.password),
                label: const Text('Reset password'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _devicesTab() {
    return ListView(
      children: [
        _Section(
          title: 'Bound devices',
          actions: [
            IconButton(
              onPressed: _refreshDevices,
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh devices',
            ),
          ],
          child: Column(
            children: [
              if (_devices.isEmpty)
                const ListTile(
                  leading: Icon(Icons.info_outline),
                  title: Text('No bound devices'),
                )
              else
                for (final device in _devices)
                  ListTile(
                    selected: device.deviceId == _selectedDevice?.deviceId,
                    leading: Icon(
                      device.deviceId == _selectedDevice?.deviceId
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                    ),
                    onTap: () => setState(() {
                      _selectedDevice = device;
                      _renameController.text = device.nickname ?? '';
                      _members = const [];
                      _statusEvents = const [];
                    }),
                    title: Text(
                      device.nickname?.isNotEmpty == true
                          ? device.nickname!
                          : device.deviceId,
                    ),
                    subtitle: Text(
                      [
                        if (device.role != null) 'role ${device.role}',
                        'version ${device.currentVersion ?? 0}',
                        if (device.lastStatus != null)
                          'status ${device.lastStatus}',
                        if (device.batteryMv != null) '${device.batteryMv} mV',
                        if (device.rssi != null) '${device.rssi} dBm',
                      ].join(' | '),
                    ),
                  ),
              if (_selectedDevice != null) ...[
                const Divider(),
                TextField(
                  controller: _renameController,
                  decoration: const InputDecoration(labelText: 'Nickname'),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      onPressed: _renameSelectedDevice,
                      icon: const Icon(Icons.edit),
                      label: const Text('Rename'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _refreshDeviceExtras,
                      icon: const Icon(Icons.info_outline),
                      label: const Text('Load members/status'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _unbindSelectedDevice,
                      icon: const Icon(Icons.link_off),
                      label: const Text('Unbind/leave'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Family sharing',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                TextField(
                  controller: _inviteEmailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Invite email'),
                ),
                DropdownButtonFormField<String>(
                  initialValue: _inviteRole,
                  items: const [
                    DropdownMenuItem(value: 'viewer', child: Text('Viewer')),
                    DropdownMenuItem(value: 'admin', child: Text('Admin')),
                  ],
                  onChanged: (value) =>
                      setState(() => _inviteRole = value ?? 'viewer'),
                  decoration: const InputDecoration(labelText: 'Invite role'),
                ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: _createInvite,
                  icon: const Icon(Icons.person_add_alt_1),
                  label: const Text('Invite member'),
                ),
                TextField(
                  controller: _inviteTokenController,
                  decoration: const InputDecoration(labelText: 'Invite token'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _acceptInvite,
                  icon: const Icon(Icons.group_add),
                  label: const Text('Accept invite'),
                ),
                for (final member in _members)
                  ListTile(
                    leading: const Icon(Icons.person_outline),
                    title: Text(member.email),
                    subtitle: Text('${member.role} | ${member.userId}'),
                  ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Recent status',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                if (_statusEvents.isEmpty)
                  const ListTile(
                    leading: Icon(Icons.history),
                    title: Text('No status events loaded'),
                  )
                else
                  for (final event in _statusEvents)
                    ListTile(
                      leading: const Icon(Icons.history),
                      title: Text(event.status),
                      subtitle: Text(
                        [
                          if (event.version != null) 'v${event.version}',
                          if (event.error != null) event.error!,
                          if (event.batteryMv != null) '${event.batteryMv} mV',
                          if (event.rssi != null) '${event.rssi} dBm',
                          if (event.createdAt != null) event.createdAt!,
                        ].join(' | '),
                      ),
                    ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _bindTab() {
    final payload = _qrPayload;
    return ListView(
      children: [
        _Section(
          title: 'Provision and bind',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FilledButton.icon(
                onPressed: _scanQr,
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text('Scan device QR'),
              ),
              if (payload != null) ...[
                const SizedBox(height: 12),
                _KeyValue(label: 'BLE name', value: payload.name),
                _KeyValue(label: 'Device ID', value: payload.deviceId),
                TextField(
                  controller: _deviceNicknameController,
                  decoration: const InputDecoration(labelText: 'Nickname'),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _searchProvisioningDevice,
                  icon: const Icon(Icons.bluetooth_searching),
                  label: const Text('Search BLE device'),
                ),
              ],
              for (final device in _provisioningDevices)
                ListTile(
                  leading: const Icon(Icons.bluetooth),
                  title: Text(device.name),
                  subtitle: Text(device.serviceUuid ?? 'No service UUID'),
                  trailing: IconButton(
                    icon: const Icon(Icons.link),
                    tooltip: 'Connect',
                    onPressed: () => _connectProvisioningDevice(device),
                  ),
                ),
              if (_wifiNetworks.isNotEmpty) ...[
                const Divider(),
                DropdownButtonFormField<WifiNetwork>(
                  initialValue: _selectedWifi,
                  items: [
                    for (final network in _wifiNetworks)
                      DropdownMenuItem(
                        value: network,
                        child: Text(
                          '${network.ssid}${network.rssi == null ? '' : ' (${network.rssi} dBm)'}',
                        ),
                      ),
                  ],
                  onChanged: (value) => setState(() => _selectedWifi = value),
                  decoration: const InputDecoration(labelText: 'Wi-Fi network'),
                ),
                TextField(
                  controller: _wifiPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Wi-Fi password',
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _provisionAndClaim,
                  icon: const Icon(Icons.done),
                  label: const Text('Provision Wi-Fi and bind account'),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _uploadTab() {
    final image = _latestImage;
    final selectedDeviceId =
        _devices.any((device) => device.deviceId == _selectedDevice?.deviceId)
        ? _selectedDevice!.deviceId
        : null;
    return ListView(
      children: [
        _Section(
          title: 'Upload and send',
          actions: [
            IconButton(
              onPressed: _refreshDevices,
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh devices',
            ),
          ],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Target device',
                  helperText: _devices.isEmpty
                      ? 'No bound devices. Bind a device first, then refresh.'
                      : null,
                  border: const OutlineInputBorder(),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: selectedDeviceId,
                    hint: Text(
                      _devices.isEmpty
                          ? 'No device available'
                          : 'Select target device',
                    ),
                    items: [
                      for (final device in _devices)
                        DropdownMenuItem(
                          value: device.deviceId,
                          child: Text(
                            device.nickname?.isNotEmpty == true
                                ? '${device.nickname} (${device.deviceId})'
                                : device.deviceId,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: _devices.isEmpty
                        ? null
                        : (deviceId) {
                            if (deviceId == null) {
                              return;
                            }
                            setState(
                              () => _selectedDevice = _devices.firstWhere(
                                (device) => device.deviceId == deviceId,
                              ),
                            );
                          },
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'auto', label: Text('Auto')),
                  ButtonSegment(value: 'landscape', label: Text('Landscape')),
                  ButtonSegment(value: 'portrait', label: Text('Portrait')),
                ],
                selected: {_direction},
                onSelectionChanged: (values) =>
                    setState(() => _direction = values.first),
              ),
              const SizedBox(height: 12),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'scale', label: Text('Scale')),
                  ButtonSegment(value: 'cut', label: Text('Cut')),
                ],
                selected: {_mode},
                onSelectionChanged: (values) =>
                    setState(() => _mode = values.first),
              ),
              SwitchListTile(
                value: _dither,
                onChanged: (value) => setState(() => _dither = value),
                title: const Text('Dither'),
              ),
              FilledButton.icon(
                onPressed: _uploadAndAssign,
                icon: const Icon(Icons.upload_file),
                label: const Text('Choose image, upload, and assign'),
              ),
              if (image != null) ...[
                const SizedBox(height: 16),
                _KeyValue(label: 'Image ID', value: image.imageId),
                _KeyValue(
                  label: 'Size',
                  value: '${image.width} x ${image.height}',
                ),
                _KeyValue(label: 'Data', value: '${image.dataSize} bytes'),
                _KeyValue(label: 'Format', value: image.format),
                _KeyValue(label: 'SHA-256', value: image.sha256),
              ],
              if (_previewPng != null) ...[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.memory(_previewPng!, fit: BoxFit.contain),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class QrScannerPage extends StatefulWidget {
  const QrScannerPage({super.key});

  @override
  State<QrScannerPage> createState() => _QrScannerPageState();
}

class _QrScannerPageState extends State<QrScannerPage> {
  final MobileScannerController _controller = MobileScannerController();
  bool _handled = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan device QR')),
      body: MobileScanner(
        controller: _controller,
        onDetect: (capture) {
          if (_handled) {
            return;
          }
          final raw = capture.barcodes.firstOrNull?.rawValue;
          if (raw != null && raw.isNotEmpty) {
            _handled = true;
            _controller.stop();
            Navigator.of(context).maybePop(raw);
          }
        },
      ),
    );
  }
}

class _ConnectionPanel extends StatelessWidget {
  const _ConnectionPanel({required this.controller, required this.busy});

  final TextEditingController controller;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: !busy,
      decoration: const InputDecoration(
        labelText: 'Server base URL',
        prefixIcon: Icon(Icons.cloud_outlined),
        border: OutlineInputBorder(),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.child,
    this.actions = const [],
  });

  final String title;
  final Widget child;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                ...actions,
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _MessageBanner extends StatelessWidget {
  const _MessageBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        child: Padding(padding: const EdgeInsets.all(12), child: Text(message)),
      ),
    );
  }
}

class _KeyValue extends StatelessWidget {
  const _KeyValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: SelectableText(value)),
        ],
      ),
    );
  }
}

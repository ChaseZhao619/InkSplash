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
  final _wifiPasswordController = TextEditingController();

  final _provisioning = const ProvisioningService();

  AuthSession? _session;
  ProvisioningQrPayload? _qrPayload;
  List<ProvisioningDevice> _provisioningDevices = const [];
  List<WifiNetwork> _wifiNetworks = const [];
  List<AppDevice> _devices = const [];
  AppDevice? _selectedDevice;
  WifiNetwork? _selectedWifi;
  ImageInfo? _latestImage;
  Uint8List? _previewPng;
  String _direction = 'auto';
  String _mode = 'scale';
  bool _dither = true;
  bool _busy = false;
  String? _message;

  EpaperApiClient get _api => EpaperApiClient(baseUrl: _baseUrlController.text);
  AuthService get _auth => AuthService(_api);
  DeviceBindingService get _deviceService => DeviceBindingService(_api);
  ImageService get _imageService => ImageService(_api);
  String? get _bearerToken => _session?.accessToken;

  @override
  void dispose() {
    _baseUrlController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _deviceNicknameController.dispose();
    _wifiPasswordController.dispose();
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
      setState(() {
        _session = session;
        _devices = devices;
        _selectedDevice = devices.isEmpty ? null : devices.first;
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
        } else if (_selectedDevice == null ||
            !devices.any(
              (device) => device.deviceId == _selectedDevice!.deviceId,
            )) {
          _selectedDevice = devices.first;
        }
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
                ],
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _session == null
                      ? 'Not logged in'
                      : 'Logged in as ${_session!.user.email}',
                ),
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
                    onTap: () => setState(() => _selectedDevice = device),
                    title: Text(
                      device.nickname?.isNotEmpty == true
                          ? device.nickname!
                          : device.deviceId,
                    ),
                    subtitle: Text(
                      [
                        'version ${device.currentVersion ?? 0}',
                        if (device.lastStatus != null)
                          'status ${device.lastStatus}',
                        if (device.batteryMv != null) '${device.batteryMv} mV',
                        if (device.rssi != null) '${device.rssi} dBm',
                      ].join(' | '),
                    ),
                  ),
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
    return ListView(
      children: [
        _Section(
          title: 'Upload and send',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<String>(
                initialValue: _selectedDevice?.deviceId,
                items: [
                  for (final device in _devices)
                    DropdownMenuItem(
                      value: device.deviceId,
                      child: Text(
                        device.nickname?.isNotEmpty == true
                            ? device.nickname!
                            : device.deviceId,
                      ),
                    ),
                ],
                onChanged: (deviceId) => setState(
                  () => _selectedDevice = _devices.firstWhere(
                    (device) => device.deviceId == deviceId,
                  ),
                ),
                decoration: const InputDecoration(labelText: 'Target device'),
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

import 'package:flutter/material.dart' hide ImageInfo;
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../models.dart';
import '../localization/app_strings.dart';
import '../settings/language_preference.dart';
import '../state/app_controller.dart';

class AppShell extends StatefulWidget {
  const AppShell({
    required this.language,
    required this.onLanguageChanged,
    super.key,
  });

  final LanguagePreference language;
  final ValueChanged<LanguagePreference> onLanguageChanged;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late final AppController _controller;
  int _index = 0;
  bool _restored = false;

  @override
  void initState() {
    super.initState();
    _controller = AppController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_restored) {
      _restored = true;
      _controller.restoreSession(AppStrings.of(context));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        if (_controller.session == null) {
          return Scaffold(
            body: SafeArea(
              child: Column(
                children: [
                  if (_controller.message != null)
                    _MessageBanner(message: _controller.message!),
                  if (_controller.busy) const LinearProgressIndicator(),
                  Expanded(
                    child: _AuthPage(
                      controller: _controller,
                      language: widget.language,
                      onLanguageChanged: widget.onLanguageChanged,
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        final pages = [
          _HomePage(controller: _controller),
          _DevicesPage(controller: _controller),
          _AddDevicePage(controller: _controller),
          _SettingsPage(
            controller: _controller,
            language: widget.language,
            onLanguageChanged: widget.onLanguageChanged,
          ),
        ];
        return Scaffold(
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.appName,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                Text(
                  s.galleryTone,
                  style: Theme.of(context).textTheme.bodySmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          body: AbsorbPointer(
            absorbing: _controller.busy,
            child: SafeArea(
              child: Column(
                children: [
                  if (_controller.message != null)
                    _MessageBanner(message: _controller.message!),
                  if (_controller.busy) const LinearProgressIndicator(),
                  Expanded(child: pages[_index]),
                ],
              ),
            ),
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: (value) => setState(() => _index = value),
            destinations: [
              NavigationDestination(
                icon: const Icon(Icons.dashboard_outlined),
                selectedIcon: const Icon(Icons.dashboard),
                label: s.home,
              ),
              NavigationDestination(
                icon: const Icon(Icons.devices_outlined),
                selectedIcon: const Icon(Icons.devices),
                label: s.devices,
              ),
              NavigationDestination(
                icon: const Icon(Icons.add_link_outlined),
                selectedIcon: const Icon(Icons.add_link),
                label: s.addDevice,
              ),
              NavigationDestination(
                icon: const Icon(Icons.tune_outlined),
                selectedIcon: const Icon(Icons.tune),
                label: s.settings,
              ),
            ],
          ),
        );
      },
    );
  }
}

enum _AuthMode { login, register, reset }

class _AuthPage extends StatefulWidget {
  const _AuthPage({
    required this.controller,
    required this.language,
    required this.onLanguageChanged,
  });

  final AppController controller;
  final LanguagePreference language;
  final ValueChanged<LanguagePreference> onLanguageChanged;

  @override
  State<_AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<_AuthPage> {
  _AuthMode _mode = _AuthMode.login;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final controller = widget.controller;
    final isRegister = _mode == _AuthMode.register;
    final isReset = _mode == _AuthMode.reset;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 42, 24, 24),
          shrinkWrap: true,
          children: [
            Text(
              s.appName,
              style: Theme.of(
                context,
              ).textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(
              isRegister
                  ? s.createAccount
                  : isReset
                  ? s.forgotPassword
                  : s.welcomeBack,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(s.signInSubtitle),
            const SizedBox(height: 26),
            if (!isReset) ...[
              TextField(
                controller: controller.emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(labelText: s.email),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller.passwordController,
                obscureText: true,
                decoration: InputDecoration(labelText: s.password),
              ),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: () => controller.login(s, register: isRegister),
                child: Text(isRegister ? s.createAccount : s.login),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => setState(
                  () =>
                      _mode = isRegister ? _AuthMode.login : _AuthMode.register,
                ),
                child: Text(isRegister ? s.haveAccount : s.noAccount),
              ),
              TextButton(
                onPressed: () => setState(() => _mode = _AuthMode.reset),
                child: Text(s.forgotPassword),
              ),
            ] else ...[
              TextField(
                controller: controller.resetEmailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: s.resetEmail,
                  helperText: s.resetEmailHelp,
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => controller.requestPasswordReset(s),
                icon: const Icon(Icons.mark_email_read_outlined),
                label: Text(s.sendCode),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller.resetTokenController,
                textCapitalization: TextCapitalization.characters,
                inputFormatters: _codeFormatters,
                decoration: InputDecoration(
                  labelText: s.resetToken,
                  helperText: s.codeHelp,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller.resetPasswordController,
                obscureText: true,
                decoration: InputDecoration(labelText: s.newPassword),
              ),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: () => controller.confirmPasswordReset(s),
                child: Text(s.resetPassword),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => setState(() => _mode = _AuthMode.login),
                child: Text(s.backToLogin),
              ),
            ],
            const SizedBox(height: 18),
            SegmentedButton<LanguagePreference>(
              segments: [
                ButtonSegment(
                  value: LanguagePreference.system,
                  label: Text(s.followSystem),
                  icon: const Icon(Icons.phone_iphone),
                ),
                ButtonSegment(
                  value: LanguagePreference.zh,
                  label: Text(s.simplifiedChinese),
                ),
                ButtonSegment(
                  value: LanguagePreference.en,
                  label: Text(s.english),
                ),
              ],
              selected: {widget.language},
              onSelectionChanged: (value) =>
                  widget.onLanguageChanged(value.first),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomePage extends StatelessWidget {
  const _HomePage({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final device = controller.selectedDevice;
    final selectedDeviceId =
        controller.devices.any((item) => item.deviceId == device?.deviceId)
        ? device!.deviceId
        : null;

    return _PageScaffold(
      children: [
        _HeroPanel(
          title: s.currentCanvas,
          subtitle: device == null
              ? s.selectBindDeviceFirst
              : _deviceTitle(device),
          preview: controller.previewPng,
          emptyText: s.noPreview,
        ),
        _Panel(
          title: s.targetDevice,
          action: IconButton(
            onPressed: () => controller.refreshDevices(s),
            icon: const Icon(Icons.refresh),
            tooltip: s.refreshDevices,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              InputDecorator(
                decoration: InputDecoration(
                  labelText: s.targetDevice,
                  helperText: controller.devices.isEmpty
                      ? s.bindFirstThenRefresh
                      : null,
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: selectedDeviceId,
                    hint: Text(
                      controller.devices.isEmpty
                          ? s.noDeviceAvailable
                          : s.selectTargetDevice,
                    ),
                    items: [
                      for (final item in controller.devices)
                        DropdownMenuItem(
                          value: item.deviceId,
                          child: Text(
                            _deviceTitle(item),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: controller.devices.isEmpty
                        ? null
                        : (value) {
                            if (value != null) {
                              controller.selectTargetDevice(value);
                            }
                          },
                  ),
                ),
              ),
              const SizedBox(height: 14),
              _ImageOptions(controller: controller),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: () => controller.uploadAndAssign(s),
                icon: const Icon(Icons.upload_file),
                label: Text(s.chooseUploadAssign),
              ),
            ],
          ),
        ),
        if (controller.latestImage != null)
          _ImageMetaPanel(image: controller.latestImage!),
        _SharingEntryPanel(controller: controller),
        _Panel(
          title: s.deviceOverview,
          child: device == null
              ? _EmptyState(icon: Icons.devices_other, text: s.noBoundDevices)
              : Column(
                  children: [
                    _KeyValue(label: s.deviceId, value: device.deviceId),
                    if (device.role != null)
                      _KeyValue(label: s.role, value: device.role!),
                    _KeyValue(
                      label: s.version,
                      value: '${device.currentVersion ?? 0}',
                    ),
                    if (device.lastStatus != null)
                      _KeyValue(label: s.status, value: device.lastStatus!),
                    if (device.batteryMv != null)
                      _KeyValue(
                        label: 'Battery',
                        value: '${device.batteryMv} mV',
                      ),
                    if (device.rssi != null)
                      _KeyValue(label: 'RSSI', value: '${device.rssi} dBm'),
                  ],
                ),
        ),
      ],
    );
  }
}

class _DevicesPage extends StatelessWidget {
  const _DevicesPage({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final selected = controller.selectedDevice;

    return _PageScaffold(
      children: [
        _Panel(
          title: s.devices,
          action: IconButton(
            onPressed: () => controller.refreshDevices(s),
            icon: const Icon(Icons.refresh),
            tooltip: s.refreshDevices,
          ),
          child: controller.devices.isEmpty
              ? _EmptyState(icon: Icons.devices_other, text: s.noBoundDevices)
              : Column(
                  children: [
                    for (final device in controller.devices)
                      _DeviceTile(
                        device: device,
                        selected: device.deviceId == selected?.deviceId,
                        onTap: () => controller.selectDevice(device),
                      ),
                  ],
                ),
        ),
        if (selected != null)
          _Panel(
            title: _deviceTitle(selected),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: controller.renameController,
                  decoration: InputDecoration(labelText: s.nickname),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      onPressed: () => controller.renameSelectedDevice(s),
                      icon: const Icon(Icons.edit_outlined),
                      label: Text(s.rename),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => controller.refreshDeviceExtras(s),
                      icon: const Icon(Icons.info_outline),
                      label: Text(s.loadMembersStatus),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => controller.unbindSelectedDevice(s),
                      icon: const Icon(Icons.link_off),
                      label: Text(s.unbindLeave),
                    ),
                  ],
                ),
              ],
            ),
          ),
        _SharingEntryPanel(controller: controller),
        if (selected != null)
          _Panel(
            title: s.recentStatus,
            child: controller.statusEvents.isEmpty
                ? _EmptyState(icon: Icons.history, text: s.noStatusEvents)
                : Column(
                    children: [
                      for (final event in controller.statusEvents)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.history),
                          title: Text(event.status),
                          subtitle: Text(
                            [
                              if (event.version != null) 'v${event.version}',
                              if (event.error != null) event.error!,
                              if (event.batteryMv != null)
                                '${event.batteryMv} mV',
                              if (event.rssi != null) '${event.rssi} dBm',
                              if (event.createdAt != null) event.createdAt!,
                            ].join(' | '),
                          ),
                        ),
                    ],
                  ),
          ),
      ],
    );
  }
}

class _SharingEntryPanel extends StatelessWidget {
  const _SharingEntryPanel({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    return _Panel(
      title: s.groups,
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.group_outlined),
        title: Text(s.manageSharing),
        subtitle: Text(s.shareMembers),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => _SharingPage(controller: controller),
          ),
        ),
      ),
    );
  }
}

class _SharingPage extends StatelessWidget {
  const _SharingPage({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final device = controller.selectedDevice;
    final group = controller.selectedGroup;

    return Scaffold(
      appBar: AppBar(title: Text(s.shareMembers)),
      body: _PageScaffold(
        children: [
          _Panel(
            title: s.groups,
            action: IconButton(
              onPressed: () => controller.refreshGroups(s),
              icon: const Icon(Icons.refresh),
              tooltip: s.refreshDevices,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: controller.groupNameController,
                  decoration: InputDecoration(labelText: s.groupName),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: controller.groupKind,
                  items: [
                    DropdownMenuItem(
                      value: 'family',
                      child: Text(s.familyGroup),
                    ),
                    DropdownMenuItem(
                      value: 'friends',
                      child: Text(s.friendsGroup),
                    ),
                  ],
                  onChanged: (value) =>
                      controller.setGroupKind(value ?? 'family'),
                  decoration: InputDecoration(labelText: s.groupKind),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () => controller.createGroup(s),
                  icon: const Icon(Icons.group_add_outlined),
                  label: Text(s.createGroup),
                ),
                const SizedBox(height: 16),
                if (controller.groups.isEmpty)
                  _EmptyState(icon: Icons.group_outlined, text: s.noGroups)
                else
                  DropdownButtonFormField<String>(
                    initialValue: group?.groupId,
                    items: [
                      for (final item in controller.groups)
                        DropdownMenuItem(
                          value: item.groupId,
                          child: Text(
                            '${item.name} (${item.kind})',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (value) {
                      if (value == null) {
                        return;
                      }
                      controller.selectGroup(
                        controller.groups.firstWhere(
                          (item) => item.groupId == value,
                        ),
                      );
                    },
                    decoration: InputDecoration(labelText: s.selectGroup),
                  ),
              ],
            ),
          ),
          _Panel(
            title: s.inviteMember,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: controller.groupInviteEmailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(labelText: s.groupInviteEmail),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: controller.groupInviteRole,
                  items: [
                    DropdownMenuItem(value: 'member', child: Text(s.viewer)),
                    DropdownMenuItem(value: 'admin', child: Text(s.admin)),
                  ],
                  onChanged: (value) =>
                      controller.setGroupInviteRole(value ?? 'member'),
                  decoration: InputDecoration(labelText: s.inviteRole),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: group == null
                      ? null
                      : () => controller.createGroupInvite(s),
                  icon: const Icon(Icons.person_add_alt_1),
                  label: Text(s.inviteToGroup),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: controller.groupInviteCodeController,
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: _codeFormatters,
                  decoration: InputDecoration(
                    labelText: s.groupInviteCode,
                    helperText: s.codeHelp,
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => controller.acceptGroupInvite(s),
                  icon: const Icon(Icons.group_add_outlined),
                  label: Text(s.acceptGroupInvite),
                ),
              ],
            ),
          ),
          _Panel(
            title: s.members,
            action: IconButton(
              onPressed: group == null
                  ? null
                  : () => controller.refreshGroupDetail(s),
              icon: const Icon(Icons.refresh),
            ),
            child: controller.groupMembers.isEmpty
                ? _EmptyState(
                    icon: Icons.group_outlined,
                    text: s.noMembersLoaded,
                  )
                : Column(
                    children: [
                      for (final member in controller.groupMembers)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.person_outline),
                          title: Text(member.email),
                          subtitle: Text('${member.role} | ${member.userId}'),
                        ),
                    ],
                  ),
          ),
          _Panel(
            title: s.sharedDevices,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: controller.groupDeviceRole,
                  items: [
                    DropdownMenuItem(value: 'viewer', child: Text(s.viewer)),
                    DropdownMenuItem(value: 'admin', child: Text(s.admin)),
                  ],
                  onChanged: (value) =>
                      controller.setGroupDeviceRole(value ?? 'admin'),
                  decoration: InputDecoration(labelText: s.inviteRole),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: group == null || device == null
                      ? null
                      : () => controller.shareSelectedDeviceToGroup(s),
                  icon: const Icon(Icons.devices_other_outlined),
                  label: Text(s.shareCurrentDevice),
                ),
                const SizedBox(height: 12),
                if (controller.groupDevices.isEmpty)
                  _EmptyState(icon: Icons.devices_other, text: s.noGroupDevices)
                else
                  for (final item in controller.groupDevices)
                    _DeviceTile(
                      device: item,
                      selected: item.deviceId == device?.deviceId,
                      onTap: () => controller.selectDevice(item),
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AddDevicePage extends StatelessWidget {
  const _AddDevicePage({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final payload = controller.qrPayload;

    return _PageScaffold(
      children: [
        _Panel(
          title: s.provisionBind,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FilledButton.icon(
                onPressed: () async {
                  final raw = await Navigator.of(context).push<String>(
                    MaterialPageRoute(builder: (_) => const QrScannerPage()),
                  );
                  if (raw != null && raw.isNotEmpty && context.mounted) {
                    controller.applyQrPayload(s, raw);
                  }
                },
                icon: const Icon(Icons.qr_code_scanner),
                label: Text(s.scanDeviceQr),
              ),
              if (payload != null) ...[
                const SizedBox(height: 16),
                _StepHeader(index: 1, text: s.scanDeviceQr),
                _KeyValue(
                  label: payload.isSoftAp ? s.softApName : s.bleName,
                  value: payload.name,
                ),
                _KeyValue(label: s.deviceId, value: payload.deviceId),
                _KeyValue(label: s.transport, value: payload.transport),
                const SizedBox(height: 12),
                TextField(
                  controller: controller.deviceNicknameController,
                  decoration: InputDecoration(labelText: s.nickname),
                ),
                const SizedBox(height: 16),
                _StepHeader(
                  index: 2,
                  text: payload.isSoftAp
                      ? s.searchSoftApDevice
                      : s.searchBleDevice,
                ),
                if (payload.isSoftAp) ...[
                  Text(s.softApHint),
                  const SizedBox(height: 10),
                  TextField(
                    controller: controller.softApPasswordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: s.softApPassword,
                      helperText: s.softApPasswordHelp,
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                OutlinedButton.icon(
                  onPressed: () => controller.searchProvisioningDevice(s),
                  icon: Icon(
                    payload.isSoftAp
                        ? Icons.wifi_tethering
                        : Icons.bluetooth_searching,
                  ),
                  label: Text(
                    payload.isSoftAp ? s.searchSoftApDevice : s.searchBleDevice,
                  ),
                ),
              ],
              for (final device in controller.provisioningDevices)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    payload?.isSoftAp == true ? Icons.wifi : Icons.bluetooth,
                  ),
                  title: Text(device.name),
                  subtitle: Text(device.serviceUuid ?? s.noServiceUuid),
                  trailing: IconButton(
                    icon: const Icon(Icons.link),
                    tooltip: s.connect,
                    onPressed: () =>
                        controller.connectProvisioningDevice(s, device),
                  ),
                ),
              if (controller.wifiNetworks.isNotEmpty) ...[
                const SizedBox(height: 16),
                _StepHeader(index: 3, text: s.wifiNetwork),
                DropdownButtonFormField<WifiNetwork>(
                  initialValue: controller.selectedWifi,
                  items: [
                    for (final network in controller.wifiNetworks)
                      DropdownMenuItem(
                        value: network,
                        child: Text(
                          '${network.ssid}${network.rssi == null ? '' : ' (${network.rssi} dBm)'}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: controller.selectWifi,
                  decoration: InputDecoration(labelText: s.wifiNetwork),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: controller.wifiPasswordController,
                  obscureText: true,
                  decoration: InputDecoration(labelText: s.wifiPassword),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () => controller.provisionAndClaim(s),
                  icon: const Icon(Icons.done),
                  label: Text(s.provisionWifiBind),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _SettingsPage extends StatelessWidget {
  const _SettingsPage({
    required this.controller,
    required this.language,
    required this.onLanguageChanged,
  });

  final AppController controller;
  final LanguagePreference language;
  final ValueChanged<LanguagePreference> onLanguageChanged;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final session = controller.session;

    return _PageScaffold(
      children: [
        _Panel(
          title: s.cloudAccount,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                session == null
                    ? s.notLoggedIn
                    : s.loggedInAs(
                        session.user.email,
                        session.user.emailVerified,
                      ),
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.lock_reset),
                title: Text(s.passwordReset),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => _PasswordResetPage(controller: controller),
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: () => controller.logout(s),
                icon: const Icon(Icons.logout),
                label: Text(s.logout),
              ),
            ],
          ),
        ),
        if (session != null && !session.user.emailVerified)
          _Panel(
            title: s.emailVerification,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                OutlinedButton.icon(
                  onPressed: () => controller.requestEmailVerification(s),
                  icon: const Icon(Icons.mark_email_read_outlined),
                  label: Text(s.sendVerificationEmail),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: controller.verifyEmailTokenController,
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: _codeFormatters,
                  decoration: InputDecoration(
                    labelText: s.verificationToken,
                    helperText: s.codeHelp,
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () => controller.confirmEmailVerification(s),
                  icon: const Icon(Icons.verified_user_outlined),
                  label: Text(s.confirmVerification),
                ),
              ],
            ),
          ),
        _Panel(
          title: s.language,
          child: SegmentedButton<LanguagePreference>(
            segments: [
              ButtonSegment(
                value: LanguagePreference.system,
                label: Text(s.followSystem),
                icon: const Icon(Icons.phone_iphone),
              ),
              ButtonSegment(
                value: LanguagePreference.zh,
                label: Text(s.simplifiedChinese),
              ),
              ButtonSegment(
                value: LanguagePreference.en,
                label: Text(s.english),
              ),
            ],
            selected: {language},
            onSelectionChanged: (value) => onLanguageChanged(value.first),
          ),
        ),
        _Panel(
          title: s.advanced,
          child: TextField(
            controller: controller.baseUrlController,
            enabled: !controller.busy,
            decoration: InputDecoration(
              labelText: s.serverBaseUrl,
              prefixIcon: const Icon(Icons.cloud_outlined),
            ),
          ),
        ),
      ],
    );
  }
}

class _PasswordResetPage extends StatelessWidget {
  const _PasswordResetPage({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(s.passwordReset)),
      body: _PageScaffold(
        children: [
          _Panel(
            title: s.passwordReset,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: controller.resetEmailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: s.resetEmail,
                    helperText: s.resetEmailHelp,
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () => controller.requestPasswordReset(s),
                  icon: const Icon(Icons.lock_reset),
                  label: Text(s.sendCode),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: controller.resetTokenController,
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: _codeFormatters,
                  decoration: InputDecoration(
                    labelText: s.resetToken,
                    helperText: s.codeHelp,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: controller.resetPasswordController,
                  obscureText: true,
                  decoration: InputDecoration(labelText: s.newPassword),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () => controller.confirmPasswordReset(s),
                  icon: const Icon(Icons.password),
                  label: Text(s.resetPassword),
                ),
              ],
            ),
          ),
        ],
      ),
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
    final s = AppStrings.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(s.scanDeviceQr)),
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

class _PageScaffold extends StatelessWidget {
  const _PageScaffold({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
      itemCount: children.length,
      separatorBuilder: (_, _) => const SizedBox(height: 14),
      itemBuilder: (context, index) => children[index],
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.child, this.action});

  final String title;
  final Widget child;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Card(
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
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                ?action,
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

class _HeroPanel extends StatelessWidget {
  const _HeroPanel({
    required this.title,
    required this.subtitle,
    required this.preview,
    required this.emptyText,
  });

  final String title;
  final String subtitle;
  final List<int>? preview;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.onSurface.withValues(alpha: 0.08)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(subtitle, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 16),
          AspectRatio(
            aspectRatio: 4 / 3,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xffefede6),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: colors.onSurface.withValues(alpha: 0.10),
                ),
              ),
              child: preview == null
                  ? Center(
                      child: Text(
                        emptyText,
                        style: TextStyle(
                          color: colors.onSurface.withValues(alpha: 0.58),
                        ),
                      ),
                    )
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.memory(
                        Uint8List.fromList(preview!),
                        fit: BoxFit.contain,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ImageOptions extends StatelessWidget {
  const _ImageOptions({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          s.imageOptions,
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        Text(s.direction),
        const SizedBox(height: 6),
        SegmentedButton<String>(
          segments: [
            ButtonSegment(value: 'auto', label: Text(s.auto)),
            ButtonSegment(value: 'landscape', label: Text(s.landscape)),
            ButtonSegment(value: 'portrait', label: Text(s.portrait)),
          ],
          selected: {controller.direction},
          onSelectionChanged: (values) => controller.setDirection(values.first),
        ),
        const SizedBox(height: 10),
        Text(s.fitMode),
        const SizedBox(height: 6),
        SegmentedButton<String>(
          segments: [
            ButtonSegment(value: 'scale', label: Text(s.scale)),
            ButtonSegment(value: 'cut', label: Text(s.cut)),
          ],
          selected: {controller.mode},
          onSelectionChanged: (values) => controller.setMode(values.first),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: controller.dither,
          onChanged: controller.setDither,
          title: Text(s.dither),
        ),
      ],
    );
  }
}

class _ImageMetaPanel extends StatelessWidget {
  const _ImageMetaPanel({required this.image});

  final ImageInfo image;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    return _Panel(
      title: s.latestImage,
      child: Column(
        children: [
          _KeyValue(label: s.imageId, value: image.imageId),
          _KeyValue(label: s.size, value: '${image.width} x ${image.height}'),
          _KeyValue(label: s.data, value: '${image.dataSize} bytes'),
          _KeyValue(label: s.format, value: image.format),
          _KeyValue(label: s.sha256, value: image.sha256),
        ],
      ),
    );
  }
}

class _DeviceTile extends StatelessWidget {
  const _DeviceTile({
    required this.device,
    required this.selected,
    required this.onTap,
  });

  final AppDevice device;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      selected: selected,
      leading: Icon(
        selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
      ),
      onTap: onTap,
      title: Text(_deviceTitle(device), overflow: TextOverflow.ellipsis),
      subtitle: Text(
        [
          if (device.role != null) '${s.role} ${device.role}',
          '${s.version} ${device.currentVersion ?? 0}',
          if (device.lastStatus != null) '${s.status} ${device.lastStatus}',
          if (device.batteryMv != null) '${device.batteryMv} mV',
          if (device.rssi != null) '${device.rssi} dBm',
        ].join(' | '),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _StepHeader extends StatelessWidget {
  const _StepHeader({required this.index, required this.text});

  final int index;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          CircleAvatar(
            radius: 13,
            backgroundColor: colors.primary,
            foregroundColor: colors.onPrimary,
            child: Text('$index', style: const TextStyle(fontSize: 12)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBanner extends StatelessWidget {
  const _MessageBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Material(
        color: colors.secondaryContainer.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(8),
        child: Padding(padding: const EdgeInsets.all(12), child: Text(message)),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Center(
        child: Column(
          children: [
            Icon(icon, color: colors.onSurface.withValues(alpha: 0.46)),
            const SizedBox(height: 8),
            Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.onSurface.withValues(alpha: 0.62)),
            ),
          ],
        ),
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
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(child: SelectableText(value)),
        ],
      ),
    );
  }
}

String _deviceTitle(AppDevice device) {
  return device.nickname?.isNotEmpty == true
      ? device.nickname!
      : device.deviceId;
}

final _codeFormatters = [
  FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9]')),
  LengthLimitingTextInputFormatter(6),
  TextInputFormatter.withFunction(
    (oldValue, newValue) =>
        newValue.copyWith(text: newValue.text.toUpperCase()),
  ),
];

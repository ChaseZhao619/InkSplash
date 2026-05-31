import 'package:flutter/material.dart' hide ImageInfo;
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../models.dart';
import '../localization/app_strings.dart';
import '../settings/language_preference.dart';
import '../state/app_controller.dart';
import '../theme/ink_theme.dart';

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
            backgroundColor: InkTheme.paperWhite,
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
          _AlbumsPage(controller: _controller),
          _TimelinePage(controller: _controller),
          _SendPage(controller: _controller),
          _MePage(
            controller: _controller,
            language: widget.language,
            onLanguageChanged: widget.onLanguageChanged,
          ),
        ];
        return Scaffold(
          backgroundColor: InkTheme.paperWhite,
          appBar: AppBar(
            toolbarHeight: 74,
            title: Row(
              children: [
                Image.asset(
                  'UI/logo.png',
                  width: 34,
                  height: 34,
                  fit: BoxFit.contain,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.appName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0,
                        ),
                      ),
                      Text(
                        s.galleryTone,
                        style: Theme.of(context).textTheme.bodySmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
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
                icon: const Icon(Icons.home_outlined),
                selectedIcon: const Icon(Icons.home),
                label: s.home,
              ),
              NavigationDestination(
                icon: const Icon(Icons.photo_library_outlined),
                selectedIcon: const Icon(Icons.photo_library),
                label: s.albums,
              ),
              NavigationDestination(
                icon: const Icon(Icons.schedule_outlined),
                selectedIcon: const Icon(Icons.schedule),
                label: s.timeline,
              ),
              NavigationDestination(
                icon: const Icon(Icons.send_outlined),
                selectedIcon: const Icon(Icons.send),
                label: s.send,
              ),
              NavigationDestination(
                icon: const Icon(Icons.person_outline),
                selectedIcon: const Icon(Icons.person),
                label: s.me,
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
    final compact = MediaQuery.sizeOf(context).height < 720;

    return _PaperSurface(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              24,
              compact ? 10 : 22,
              24,
              compact ? 16 : 28,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _AuthBrandHero(
                  title: isRegister
                      ? s.createAccount
                      : isReset
                      ? s.forgotPassword
                      : (s.isZh ? '开始使用 InkSplash' : 'Get started'),
                  subtitle: isReset
                      ? s.resetEmailHelp
                      : (s.isZh
                            ? '纸感电子墨水相册，把家人的珍贵时刻温柔保存。'
                            : 'A calm color e-ink album for the memories you keep close.'),
                ),
                SizedBox(height: compact ? 10 : 18),
                InkCard(
                  padding: EdgeInsets.all(compact ? 16 : 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        isRegister
                            ? s.createAccount
                            : isReset
                            ? s.passwordReset
                            : s.welcomeBack,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 6),
                      Text(s.signInSubtitle),
                      if (!isReset && !isRegister) ...[
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            Expanded(
                              child: InkButton.secondary(
                                onPressed: () {},
                                icon: Icons.apple,
                                label: 'Apple',
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: InkButton.secondary(
                                onPressed: () {},
                                icon: Icons.g_mobiledata,
                                label: 'Google',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        _DividerLabel(text: s.isZh ? '或' : 'or'),
                      ],
                      if (!isReset) ...[
                        const SizedBox(height: 18),
                        InkTextField(
                          controller: controller.emailController,
                          keyboardType: TextInputType.emailAddress,
                          labelText: s.email,
                          prefixIcon: Icons.mail_outline,
                        ),
                        const SizedBox(height: 12),
                        InkTextField(
                          controller: controller.passwordController,
                          obscureText: true,
                          labelText: s.password,
                          prefixIcon: Icons.lock_outline,
                        ),
                        const SizedBox(height: 16),
                        InkButton.primary(
                          onPressed: () =>
                              controller.login(s, register: isRegister),
                          icon: isRegister
                              ? Icons.person_add_alt_outlined
                              : Icons.login,
                          label: isRegister ? s.createAccount : s.login,
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () => setState(
                            () => _mode = isRegister
                                ? _AuthMode.login
                                : _AuthMode.register,
                          ),
                          child: Text(isRegister ? s.haveAccount : s.noAccount),
                        ),
                        TextButton(
                          onPressed: () =>
                              setState(() => _mode = _AuthMode.reset),
                          child: Text(s.forgotPassword),
                        ),
                      ] else ...[
                        const SizedBox(height: 18),
                        InkTextField(
                          controller: controller.resetEmailController,
                          keyboardType: TextInputType.emailAddress,
                          labelText: s.resetEmail,
                          helperText: s.resetEmailHelp,
                          prefixIcon: Icons.mail_outline,
                        ),
                        const SizedBox(height: 12),
                        InkButton.secondary(
                          onPressed: () => controller.requestPasswordReset(s),
                          icon: Icons.mark_email_read_outlined,
                          label: s.sendCode,
                        ),
                        const SizedBox(height: 12),
                        InkTextField(
                          controller: controller.resetTokenController,
                          textCapitalization: TextCapitalization.characters,
                          inputFormatters: _codeFormatters,
                          labelText: s.resetToken,
                          helperText: s.codeHelp,
                          prefixIcon: Icons.pin_outlined,
                        ),
                        const SizedBox(height: 12),
                        InkTextField(
                          controller: controller.resetPasswordController,
                          obscureText: true,
                          labelText: s.newPassword,
                          prefixIcon: Icons.lock_reset,
                        ),
                        const SizedBox(height: 16),
                        InkButton.primary(
                          onPressed: () => controller.confirmPasswordReset(s),
                          icon: Icons.password,
                          label: s.resetPassword,
                        ),
                        const SizedBox(height: 10),
                        TextButton(
                          onPressed: () =>
                              setState(() => _mode = _AuthMode.login),
                          child: Text(s.backToLogin),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
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
    final greeting = s.isZh ? '早上好，Emily' : 'Good morning, Emily';
    return _PageScaffold(
      children: [
        _HeaderBlock(
          icon: Icons.wb_sunny_outlined,
          title: greeting,
          subtitle: s.isZh
              ? '珍藏每一刻，记录爱与生活。'
              : 'Cherish each moment, record love and life.',
        ),
        _Panel(
          title: s.isZh ? '我的相册' : 'My Albums',
          action: TextButton(
            onPressed: () {},
            child: Text(s.isZh ? '查看全部' : 'View all'),
          ),
          child: SizedBox(
            height: 152,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemBuilder: (context, index) =>
                  _AlbumCoverCard(album: _demoAlbums[index], compact: true),
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemCount: _demoAlbums.length,
            ),
          ),
        ),
        _Panel(
          title: s.familySharing,
          action: TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => _BusyRoute(
                  controller: controller,
                  child: _SharingPage(controller: controller),
                ),
              ),
            ),
            child: Text(s.manageSharing),
          ),
          child: _MemberAvatarRow(),
        ),
        _DeviceSyncCard(controller: controller),
        _Panel(
          title: s.isZh ? '最近更新' : 'Recent Updates',
          child: Column(
            children: [
              for (final item in _demoUpdates)
                _UpdateTile(
                  title: item.titleZh,
                  subtitle: item.subtitleZh,
                  image: item.asset,
                  dotColor: item.color,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AlbumsPage extends StatelessWidget {
  const _AlbumsPage({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    return _PageScaffold(
      children: [
        _HeaderBlock(
          icon: Icons.photo_library_outlined,
          title: s.isZh ? '我的相册' : 'My Albums',
          subtitle: s.isZh
              ? '浏览、筛选和珍藏每一段回忆。'
              : 'Browse, filter, and keep every memory.',
        ),
        _FilterChips(
          labels: [
            s.isZh ? '全部' : 'All',
            s.isZh ? '旅行' : 'Travel',
            s.isZh ? '家人' : 'Family',
            s.isZh ? '成长' : 'Growth',
            s.isZh ? '节日' : 'Holiday',
          ],
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.82,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: _demoAlbums.length,
          itemBuilder: (context, index) => _AlbumCoverCard(
            album: _demoAlbums[index],
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => _AlbumDetailPage(album: _demoAlbums[index]),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TimelinePage extends StatelessWidget {
  const _TimelinePage({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    return _PageScaffold(
      children: [
        _HeaderBlock(
          icon: Icons.schedule_outlined,
          title: s.timeline,
          subtitle: s.isZh
              ? '按月份整理生活流动的瞬间。'
              : 'Moments arranged by month and feeling.',
        ),
        _FilterChips(labels: const ['2024', '3月', '4月', '5月', '6月']),
        for (final group in _demoTimeline)
          _Panel(
            title: group.title,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  group.subtitle,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 10),
                _PhotoStrip(assets: group.assets),
              ],
            ),
          ),
      ],
    );
  }
}

class _SendPage extends StatelessWidget {
  const _SendPage({required this.controller});

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
          title: s.isZh ? '编辑照片' : 'Edit Photo',
          subtitle: device == null
              ? s.selectBindDeviceFirst
              : _deviceTitle(device),
          preview: controller.previewPng,
          emptyText: s.noPreview,
        ),
        _Panel(
          title: s.isZh ? '01 选择设备' : '01 Select Device',
          action: IconButton(
            onPressed: () => controller.refreshDevices(s),
            icon: const Icon(Icons.refresh),
            tooltip: s.refreshDevices,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<String>(
                initialValue: selectedDeviceId,
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
                        if (value != null) controller.selectTargetDevice(value);
                      },
                decoration: InputDecoration(
                  labelText: s.targetDevice,
                  helperText: controller.devices.isEmpty
                      ? s.bindFirstThenRefresh
                      : null,
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => _AddDevicePage(controller: controller),
                  ),
                ),
                icon: const Icon(Icons.add_link_outlined),
                label: Text(s.addDevice),
              ),
            ],
          ),
        ),
        _Panel(
          title: s.isZh ? '02 编辑与适配' : '02 Edit & Fit',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ImageOptions(controller: controller),
              const SizedBox(height: 12),
              _FilterChips(
                labels: [
                  s.isZh ? '柔和' : 'Soft',
                  s.isZh ? '自然' : 'Natural',
                  s.isZh ? '清晰' : 'Clear',
                  s.isZh ? '怀旧' : 'Nostalgic',
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: InkButton.secondary(
                      onPressed: () => controller.chooseImage(s),
                      icon: Icons.add_photo_alternate_outlined,
                      label: s.chooseImage,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: InkButton.primary(
                      onPressed: controller.selectedImage == null
                          ? null
                          : () => controller.uploadAndAssign(s),
                      icon: Icons.send_outlined,
                      label: s.sendToFrame,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (controller.latestImage != null)
          _ImageMetaPanel(image: controller.latestImage!),
        _SendProgressPanel(controller: controller),
      ],
    );
  }
}

class _MePage extends StatelessWidget {
  const _MePage({
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
    final email = controller.session?.user.email ?? 'emily@inksplash.com';
    return _PageScaffold(
      children: [
        _ProfileHeader(email: email),
        _SettingsList(
          controller: controller,
          language: language,
          onLanguageChanged: onLanguageChanged,
        ),
        OutlinedButton.icon(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => _DevicesPage(controller: controller),
            ),
          ),
          icon: const Icon(Icons.devices_outlined),
          label: Text(s.devices),
        ),
        OutlinedButton.icon(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => _SettingsPage(
                controller: controller,
                language: language,
                onLanguageChanged: onLanguageChanged,
              ),
            ),
          ),
          icon: const Icon(Icons.tune_outlined),
          label: Text(s.advanced),
        ),
        TextButton.icon(
          onPressed: () => controller.logout(s),
          icon: const Icon(Icons.logout),
          label: Text(s.logout),
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
                InkTextField(
                  controller: controller.renameController,
                  labelText: s.nickname,
                  prefixIcon: Icons.edit_outlined,
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
                        InkIconTile(
                          icon: Icons.history,
                          title: event.status,
                          subtitle: [
                            if (event.version != null) 'v${event.version}',
                            if (event.error != null) event.error!,
                            if (event.batteryMv != null)
                              '${event.batteryMv} mV',
                            if (event.rssi != null) '${event.rssi} dBm',
                            if (event.createdAt != null) event.createdAt!,
                          ].join(' | '),
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
      child: InkIconTile(
        icon: Icons.group_outlined,
        title: s.manageSharing,
        subtitle: s.shareMembers,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => _BusyRoute(
              controller: controller,
              child: _SharingPage(controller: controller),
            ),
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
                InkTextField(
                  controller: controller.groupNameController,
                  labelText: s.groupName,
                  prefixIcon: Icons.group_outlined,
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
                InkTextField(
                  controller: controller.groupInviteEmailController,
                  keyboardType: TextInputType.emailAddress,
                  labelText: s.groupInviteEmail,
                  prefixIcon: Icons.mail_outline,
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
                InkTextField(
                  controller: controller.groupInviteCodeController,
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: _codeFormatters,
                  labelText: s.groupInviteCode,
                  helperText: s.codeHelp,
                  prefixIcon: Icons.pin_outlined,
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
                        InkIconTile(
                          icon: Icons.person_outline,
                          title: member.email,
                          subtitle: '${member.role} | ${member.userId}',
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
                InkTextField(
                  controller: controller.deviceNicknameController,
                  labelText: s.nickname,
                  prefixIcon: Icons.edit_outlined,
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
                  InkTextField(
                    controller: controller.softApPasswordController,
                    obscureText: true,
                    labelText: s.softApPassword,
                    helperText: s.softApPasswordHelp,
                    prefixIcon: Icons.wifi_password_outlined,
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
                InkIconTile(
                  icon: payload?.isSoftAp == true
                      ? Icons.wifi
                      : Icons.bluetooth,
                  title: device.name,
                  subtitle: device.serviceUuid ?? s.noServiceUuid,
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
                InkTextField(
                  controller: controller.wifiPasswordController,
                  obscureText: true,
                  labelText: s.wifiPassword,
                  prefixIcon: Icons.lock_outline,
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
              InkIconTile(
                icon: Icons.lock_reset,
                title: s.passwordReset,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => _BusyRoute(
                      controller: controller,
                      child: _PasswordResetPage(controller: controller),
                    ),
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
                InkTextField(
                  controller: controller.verifyEmailTokenController,
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: _codeFormatters,
                  labelText: s.verificationToken,
                  helperText: s.codeHelp,
                  prefixIcon: Icons.pin_outlined,
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
          child: InkTextField(
            controller: controller.baseUrlController,
            enabled: !controller.busy,
            labelText: s.serverBaseUrl,
            prefixIcon: Icons.cloud_outlined,
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
                InkTextField(
                  controller: controller.resetEmailController,
                  keyboardType: TextInputType.emailAddress,
                  labelText: s.resetEmail,
                  helperText: s.resetEmailHelp,
                  prefixIcon: Icons.mail_outline,
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () => controller.requestPasswordReset(s),
                  icon: const Icon(Icons.lock_reset),
                  label: Text(s.sendCode),
                ),
                const SizedBox(height: 10),
                InkTextField(
                  controller: controller.resetTokenController,
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: _codeFormatters,
                  labelText: s.resetToken,
                  helperText: s.codeHelp,
                  prefixIcon: Icons.pin_outlined,
                ),
                const SizedBox(height: 10),
                InkTextField(
                  controller: controller.resetPasswordController,
                  obscureText: true,
                  labelText: s.newPassword,
                  prefixIcon: Icons.lock_reset,
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

class _PaperSurface extends StatelessWidget {
  const _PaperSurface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(color: InkTheme.paperWhite),
      child: CustomPaint(painter: _PaperTexturePainter(), child: child),
    );
  }
}

class _PaperTexturePainter extends CustomPainter {
  const _PaperTexturePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final warmWash = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xfffffdf8), Color(0xfff7f3eb)],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, warmWash);

    final fiber = Paint()
      ..color = InkTheme.inkBlack.withValues(alpha: 0.018)
      ..strokeWidth = 0.6;
    for (double y = 18; y < size.height; y += 31) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y + 5), fiber);
    }
    final speck = Paint()..color = InkTheme.eInkYellow.withValues(alpha: 0.03);
    for (double x = 12; x < size.width; x += 37) {
      for (double y = 10; y < size.height; y += 43) {
        canvas.drawCircle(Offset(x, y), 0.7, speck);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class InkPageScaffold extends StatelessWidget {
  const InkPageScaffold({required this.children, this.padding, super.key});

  final List<Widget> children;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return _PaperSurface(
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView.separated(
            padding: padding ?? const EdgeInsets.fromLTRB(18, 12, 18, 28),
            itemCount: children.length,
            separatorBuilder: (_, _) => const SizedBox(height: 16),
            itemBuilder: (context, index) => children[index],
          ),
        ),
      ),
    );
  }
}

class _PageScaffold extends StatelessWidget {
  const _PageScaffold({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return InkPageScaffold(children: children);
  }
}

class _BusyRoute extends StatelessWidget {
  const _BusyRoute({required this.controller, required this.child});

  final AppController controller;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Stack(
          children: [
            AbsorbPointer(absorbing: controller.busy, child: child),
            if (controller.busy)
              const Positioned(
                left: 0,
                top: 0,
                right: 0,
                child: LinearProgressIndicator(),
              ),
            if (controller.message != null)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: SafeArea(
                  child: _MessageBanner(message: controller.message!),
                ),
              ),
          ],
        );
      },
    );
  }
}

class InkCard extends StatelessWidget {
  const InkCard({
    required this.child,
    this.title,
    this.action,
    this.padding = const EdgeInsets.all(18),
    super.key,
  });

  final String? title;
  final Widget child;
  final Widget? action;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final border = InkTheme.inkBlack.withValues(alpha: 0.065);
    return Container(
      decoration: BoxDecoration(
        color: InkTheme.paperSurface.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: InkTheme.inkBlack.withValues(alpha: 0.045),
            blurRadius: 26,
            offset: const Offset(0, 14),
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.72),
            blurRadius: 1,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (title != null || action != null) ...[
              Row(
                children: [
                  if (title != null)
                    Expanded(
                      child: Text(
                        title!,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    )
                  else
                    const Spacer(),
                  ?action,
                ],
              ),
              const SizedBox(height: 14),
            ],
            child,
          ],
        ),
      ),
    );
  }
}

class InkButton extends StatelessWidget {
  const InkButton.primary({
    required this.onPressed,
    required this.label,
    this.icon,
    super.key,
  }) : primary = true;

  const InkButton.secondary({
    required this.onPressed,
    required this.label,
    this.icon,
    super.key,
  }) : primary = false;

  final VoidCallback? onPressed;
  final String label;
  final IconData? icon;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final child = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[Icon(icon, size: 19), const SizedBox(width: 8)],
        Flexible(
          child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ],
    );

    if (!primary) {
      return OutlinedButton(onPressed: onPressed, child: child);
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: onPressed == null
            ? null
            : const LinearGradient(
                colors: [Color(0xff376ff0), InkTheme.eInkBlue],
              ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: onPressed == null
            ? const []
            : [
                BoxShadow(
                  color: InkTheme.eInkBlue.withValues(alpha: 0.22),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
      ),
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
        ),
        child: child,
      ),
    );
  }
}

class InkTextField extends StatelessWidget {
  const InkTextField({
    required this.controller,
    required this.labelText,
    this.helperText,
    this.prefixIcon,
    this.keyboardType,
    this.obscureText = false,
    this.enabled,
    this.textCapitalization = TextCapitalization.none,
    this.inputFormatters,
    super.key,
  });

  final TextEditingController controller;
  final String labelText;
  final String? helperText;
  final IconData? prefixIcon;
  final TextInputType? keyboardType;
  final bool obscureText;
  final bool? enabled;
  final TextCapitalization textCapitalization;
  final List<TextInputFormatter>? inputFormatters;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      enabled: enabled,
      textCapitalization: textCapitalization,
      inputFormatters: inputFormatters,
      decoration: InputDecoration(
        labelText: labelText,
        helperText: helperText,
        prefixIcon: prefixIcon == null ? null : Icon(prefixIcon),
      ),
    );
  }
}

class InkIconTile extends StatelessWidget {
  const InkIconTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.dotColor,
    super.key,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? dotColor;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      minLeadingWidth: 36,
      leading: _LineIcon(icon: icon, dotColor: dotColor),
      title: Text(title, overflow: TextOverflow.ellipsis),
      subtitle: subtitle == null
          ? null
          : Text(subtitle!, maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing:
          trailing ?? (onTap == null ? null : const Icon(Icons.chevron_right)),
      onTap: onTap,
    );
  }
}

class _LineIcon extends StatelessWidget {
  const _LineIcon({required this.icon, this.dotColor});

  final IconData icon;
  final Color? dotColor;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: InkTheme.paperWhite,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: InkTheme.inkBlack.withValues(alpha: 0.07),
            ),
          ),
          child: Icon(icon, size: 20),
        ),
        if (dotColor != null)
          Positioned(
            right: -1,
            top: -1,
            child: CircleAvatar(radius: 4, backgroundColor: dotColor),
          ),
      ],
    );
  }
}

class InkStatusPill extends StatelessWidget {
  const InkStatusPill({required this.text, required this.color, super.key});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.20)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _DividerLabel extends StatelessWidget {
  const _DividerLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(text, style: Theme.of(context).textTheme.bodySmall),
        ),
        const Expanded(child: Divider()),
      ],
    );
  }
}

class _AuthBrandHero extends StatelessWidget {
  const _AuthBrandHero({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final compact = MediaQuery.sizeOf(context).height < 720;
    final heroHeight = compact ? 128.0 : 260.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Image.asset('UI/logo.png', width: 58, height: 58),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.appName,
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                  Text(
                    'Color E-Ink Photo Album',
                    style: Theme.of(
                      context,
                    ).textTheme.titleMedium?.copyWith(color: InkTheme.eInkBlue),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (compact) ...[
          Text(title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 6),
          Text(subtitle),
        ] else
          ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: Stack(
              alignment: Alignment.bottomLeft,
              children: [
                Image.asset(
                  'assets/demo/album_cover.png',
                  height: heroHeight,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
                Container(
                  height: heroHeight,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        InkTheme.paperWhite.withValues(alpha: 0.96),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Text(subtitle),
                      const SizedBox(height: 18),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: const [
                          InkStatusPill(
                            text: 'Paper-like calm',
                            color: InkTheme.eInkBlue,
                          ),
                          InkStatusPill(
                            text: 'Family sharing',
                            color: InkTheme.eInkRed,
                          ),
                          InkStatusPill(
                            text: 'Six-color e-ink',
                            color: InkTheme.eInkYellow,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
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
    return InkCard(title: title, action: action, child: child);
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
    return InkCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 5),
                    Text(subtitle, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              const InkStatusPill(text: '6-color', color: InkTheme.eInkBlue),
            ],
          ),
          const SizedBox(height: 16),
          AspectRatio(
            aspectRatio: 480 / 800,
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xffefede6),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: colors.onSurface.withValues(alpha: 0.10),
                ),
                boxShadow: [
                  BoxShadow(
                    color: InkTheme.inkBlack.withValues(alpha: 0.07),
                    blurRadius: 22,
                    offset: const Offset(0, 10),
                  ),
                ],
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
                      borderRadius: BorderRadius.circular(23),
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
        Text(s.rotation),
        const SizedBox(height: 6),
        SegmentedButton<int>(
          segments: [
            ButtonSegment(value: 0, label: Text(s.rotate0)),
            ButtonSegment(value: 90, label: Text(s.rotate90)),
            ButtonSegment(value: 180, label: Text(s.rotate180)),
            ButtonSegment(value: 270, label: Text(s.rotate270)),
          ],
          selected: {controller.rotationDegrees},
          onSelectionChanged: (values) =>
              controller.setRotationDegrees(values.first),
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
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: InkTheme.paperWhite,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: InkTheme.inkBlack.withValues(alpha: 0.07),
            ),
          ),
          child: Row(
            children: [
              const _LineIcon(icon: Icons.grain_outlined),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  s.dither,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              Switch(value: controller.dither, onChanged: controller.setDither),
            ],
          ),
        ),
      ],
    );
  }
}

class _HeaderBlock extends StatelessWidget {
  const _HeaderBlock({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 12, 2, 4),
      child: Row(
        children: [
          _LineIcon(icon: icon, dotColor: InkTheme.eInkYellow),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 2),
                Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          IconButton(
            onPressed: () {},
            icon: Icon(Icons.notifications_none, color: colors.onSurface),
          ),
        ],
      ),
    );
  }
}

class _AlbumCoverCard extends StatelessWidget {
  const _AlbumCoverCard({
    required this.album,
    this.compact = false,
    this.onTap,
  });

  final _DemoAlbum album;
  final bool compact;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: compact ? 118 : null,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Image.asset(
                  album.asset,
                  fit: BoxFit.cover,
                  width: double.infinity,
                ),
              ),
            ),
            const SizedBox(height: 9),
            Text(
              album.titleZh,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            Text(
              '${album.count} 张照片',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _MemberAvatarRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final members = [
      ['Emily', '你', 'assets/demo/avatar_emily.png'],
      ['爸爸', '在线', 'assets/demo/avatar_dad.png'],
      ['妈妈', '在线', 'assets/demo/avatar_mom.png'],
      ['奶奶', '离线', 'assets/demo/avatar_grandma.png'],
    ];
    return Row(
      children: [
        for (final member in members)
          Expanded(
            child: Column(
              children: [
                CircleAvatar(
                  backgroundImage: AssetImage(member[2]),
                  radius: 24,
                ),
                const SizedBox(height: 6),
                Text(
                  member[0],
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(member[1], style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        OutlinedButton(onPressed: () {}, child: const Icon(Icons.add)),
      ],
    );
  }
}

class _DeviceSyncCard extends StatelessWidget {
  const _DeviceSyncCard({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final device = controller.selectedDevice;
    return _Panel(
      title: s.isZh ? '设备同步' : 'Device Sync',
      action: IconButton(
        onPressed: () => controller.refreshDevices(s),
        icon: const Icon(Icons.refresh),
      ),
      child: InkIconTile(
        icon: Icons.tablet_mac_outlined,
        title: device == null ? 'InkPad Color 6' : _deviceTitle(device),
        subtitle: device == null
            ? '已连接 · 电量 78%'
            : '${device.lastStatus ?? 'online'} · v${device.currentVersion ?? 0}',
        dotColor: InkTheme.eInkBlue,
        trailing: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Container(
            color: InkTheme.paperWhite,
            padding: const EdgeInsets.all(4),
            child: Image.asset(
              'assets/demo/frame_preview.png',
              width: 34,
              height: 46,
              fit: BoxFit.cover,
            ),
          ),
        ),
      ),
    );
  }
}

class _UpdateTile extends StatelessWidget {
  const _UpdateTile({
    required this.title,
    required this.subtitle,
    required this.image,
    required this.dotColor,
  });

  final String title;
  final String subtitle;
  final String image;
  final Color dotColor;

  @override
  Widget build(BuildContext context) {
    return InkIconTile(
      icon: Icons.image_outlined,
      title: title,
      subtitle: subtitle,
      dotColor: dotColor,
      trailing: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.asset(image, width: 50, height: 50, fit: BoxFit.cover),
      ),
    );
  }
}

class _FilterChips extends StatelessWidget {
  const _FilterChips({required this.labels});

  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: labels.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) => ChoiceChip(
          selected: index == 0,
          showCheckmark: false,
          label: Text(labels[index]),
          side: BorderSide(color: colors.onSurface.withValues(alpha: 0.08)),
          selectedColor: colors.primary,
          backgroundColor: colors.surface,
          labelStyle: TextStyle(
            color: index == 0 ? Colors.white : colors.onSurface,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _PhotoStrip extends StatelessWidget {
  const _PhotoStrip({required this.assets});

  final List<String> assets;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 118,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: assets.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) => ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Image.asset(
            assets[index],
            width: 112,
            height: 112,
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }
}

class _AlbumDetailPage extends StatelessWidget {
  const _AlbumDetailPage({required this.album});

  final _DemoAlbum album;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(album.titleZh)),
      body: _PageScaffold(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Image.asset(
              album.asset,
              height: 220,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          Text(
            album.titleZh,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          Text('${album.count} 张照片 · 6 个地点'),
          _MemberAvatarRow(),
          _FilterChips(
            labels: [
              s.isZh ? '照片' : 'Photos',
              s.timeline,
              s.isZh ? '地点' : 'Places',
            ],
          ),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 7,
              crossAxisSpacing: 7,
            ),
            itemCount: _demoPhotos.length,
            itemBuilder: (context, index) => ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.asset(_demoPhotos[index], fit: BoxFit.cover),
            ),
          ),
        ],
      ),
    );
  }
}

class _SendProgressPanel extends StatelessWidget {
  const _SendProgressPanel({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final active = controller.latestImage != null;
    return _Panel(
      title: s.isZh ? '03 发送与同步' : '03 Send & Sync',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LinearProgressIndicator(value: active ? 1 : 0.68),
          const SizedBox(height: 12),
          _ProgressStep(done: true, title: s.isZh ? '连接设备' : 'Connect Device'),
          _ProgressStep(done: true, title: s.isZh ? '准备照片' : 'Prepare Photo'),
          _ProgressStep(done: active, title: s.isZh ? '传输数据' : 'Transfer Data'),
          _ProgressStep(done: active, title: s.isZh ? '更新相框' : 'Update Frame'),
        ],
      ),
    );
  }
}

class _ProgressStep extends StatelessWidget {
  const _ProgressStep({required this.done, required this.title});

  final bool done;
  final String title;

  @override
  Widget build(BuildContext context) {
    return InkIconTile(
      icon: done ? Icons.check_circle_outline : Icons.radio_button_unchecked,
      title: title,
      dotColor: done ? InkTheme.eInkBlue : null,
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.email});

  final String email;

  @override
  Widget build(BuildContext context) {
    return InkCard(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: InkTheme.eInkBlue.withValues(alpha: 0.22),
              ),
            ),
            child: const CircleAvatar(
              backgroundImage: AssetImage('assets/demo/avatar_emily.png'),
              radius: 30,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Emily',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                ),
                const SizedBox(height: 3),
                Text(email, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          const Icon(Icons.chevron_right),
        ],
      ),
    );
  }
}

class _SettingsList extends StatelessWidget {
  const _SettingsList({
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
    final rows = [
      [
        Icons.security_outlined,
        s.isZh ? '账号与安全' : 'Account & security',
        s.isZh ? '修改密码 / 登录状态' : 'Password and sessions',
        null,
      ],
      [
        Icons.notifications_none,
        s.isZh ? '通知设置' : 'Notifications',
        s.isZh ? '消息提醒 / 同步通知' : 'Alerts and sync',
        InkTheme.eInkRed,
      ],
      [
        Icons.cloud_queue_outlined,
        s.isZh ? '存储与空间' : 'Storage',
        '2.3 GB / 10 GB',
        null,
      ],
      [
        Icons.devices_outlined,
        s.isZh ? '设备管理' : 'Device management',
        s.isZh
            ? '已连接 ${controller.devices.length} 台设备'
            : '${controller.devices.length} devices connected',
        InkTheme.eInkBlue,
      ],
      [
        Icons.lock_outline,
        s.isZh ? '隐私设置' : 'Privacy',
        s.isZh ? '权限管理 / 可见性' : 'Permissions and visibility',
        null,
      ],
      [
        Icons.help_outline,
        s.isZh ? '帮助与反馈' : 'Help & feedback',
        s.isZh ? '常见问题与反馈' : 'FAQ and feedback',
        null,
      ],
      [
        Icons.info_outline,
        s.isZh ? '关于 InkSplash' : 'About InkSplash',
        'v1.0.10',
        InkTheme.eInkYellow,
      ],
    ];
    return _Panel(
      title: s.settings,
      child: Column(
        children: [
          SegmentedButton<LanguagePreference>(
            segments: [
              ButtonSegment(
                value: LanguagePreference.system,
                label: Text(s.followSystem),
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
          const SizedBox(height: 12),
          for (final row in rows)
            InkIconTile(
              icon: row[0] as IconData,
              title: row[1] as String,
              subtitle: row[2] as String,
              dotColor: row[3] as Color?,
              onTap: () {},
            ),
        ],
      ),
    );
  }
}

class _DemoAlbum {
  const _DemoAlbum(this.titleZh, this.asset, this.count);

  final String titleZh;
  final String asset;
  final int count;
}

class _DemoUpdate {
  const _DemoUpdate(this.titleZh, this.subtitleZh, this.asset, this.color);

  final String titleZh;
  final String subtitleZh;
  final String asset;
  final Color color;
}

class _TimelineGroup {
  const _TimelineGroup(this.title, this.subtitle, this.assets);

  final String title;
  final String subtitle;
  final List<String> assets;
}

const _demoAlbums = [
  _DemoAlbum('旅行足迹', 'assets/demo/mountain_lake.png', 142),
  _DemoAlbum('家人时光', 'assets/demo/family_reading.png', 328),
  _DemoAlbum('成长记忆', 'assets/demo/child_reading.png', 215),
  _DemoAlbum('节日纪念', 'assets/demo/red_blossom.png', 96),
  _DemoAlbum('日常点滴', 'assets/demo/daily_scene.png', 176),
  _DemoAlbum('宠物时光', 'assets/demo/travel_town.png', 64),
];

const _demoPhotos = [
  'assets/demo/mountain_lake.png',
  'assets/demo/red_blossom.png',
  'assets/demo/child_reading.png',
  'assets/demo/family_reading.png',
  'assets/demo/travel_town.png',
  'assets/demo/daily_scene.png',
  'assets/demo/frame_preview.png',
  'assets/demo/album_cover.png',
  'assets/demo/mountain_lake.png',
];

const _demoUpdates = [
  _DemoUpdate(
    '黄山之旅',
    '新添加 12 张照片',
    'assets/demo/mountain_lake.png',
    Color(0xff2d5bff),
  ),
  _DemoUpdate(
    '全家福 · 春节聚会',
    '新添加 23 张照片',
    'assets/demo/family_reading.png',
    Color(0xffd46a6a),
  ),
  _DemoUpdate(
    '小豆豆的画作',
    '新添加 8 张照片',
    'assets/demo/child_reading.png',
    Color(0xffe5c35a),
  ),
];

const _demoTimeline = [
  _TimelineGroup('5月 · 黄山之旅', '142 张照片', [
    'assets/demo/mountain_lake.png',
    'assets/demo/red_blossom.png',
    'assets/demo/travel_town.png',
  ]),
  _TimelineGroup('4月 · 家人时光', '328 张照片', [
    'assets/demo/family_reading.png',
    'assets/demo/child_reading.png',
    'assets/demo/daily_scene.png',
  ]),
  _TimelineGroup('3月 · 春日日记', '215 张照片', [
    'assets/demo/red_blossom.png',
    'assets/demo/mountain_lake.png',
    'assets/demo/album_cover.png',
  ]),
];

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
    return InkIconTile(
      icon: selected
          ? Icons.radio_button_checked
          : Icons.radio_button_unchecked,
      title: _deviceTitle(device),
      subtitle: [
        if (device.role != null) '${s.role} ${device.role}',
        '${s.version} ${device.currentVersion ?? 0}',
        if (device.lastStatus != null) '${s.status} ${device.lastStatus}',
        if (device.batteryMv != null) '${device.batteryMv} mV',
        if (device.rssi != null) '${device.rssi} dBm',
      ].join(' | '),
      dotColor: selected ? InkTheme.eInkBlue : null,
      trailing: Icon(
        selected ? Icons.check_circle : Icons.chevron_right,
        color: selected ? InkTheme.eInkBlue : null,
      ),
      onTap: onTap,
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
        borderRadius: BorderRadius.circular(16),
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

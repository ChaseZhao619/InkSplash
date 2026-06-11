import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart' hide ImageInfo;
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../models.dart';
import '../localization/app_strings.dart';
import '../settings/language_preference.dart';
import '../state/app_controller.dart';
import '../theme/ink_theme.dart';
import 'time_format.dart';

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
  String? _lastMessage;

  @override
  void initState() {
    super.initState();
    _controller = AppController();
    _controller.addListener(_showControllerMessage);
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
    _controller.removeListener(_showControllerMessage);
    _controller.dispose();
    super.dispose();
  }

  void _showControllerMessage() {
    final message = _controller.message;
    if (message == null || message.isEmpty) {
      _lastMessage = null;
      return;
    }
    if (message == _lastMessage) {
      return;
    }
    _lastMessage = message;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final colors = Theme.of(context).colorScheme;
      final failed = message.contains('失败') || message.contains('failed');
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.fromLTRB(18, 0, 18, 20),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            backgroundColor: failed ? colors.errorContainer : colors.primary,
            content: Text(
              message,
              style: TextStyle(
                color: failed ? colors.onErrorContainer : colors.onPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        );
    });
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
          _HomePage(
            controller: _controller,
            onOpenAlbums: () => setState(() => _index = 1),
          ),
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
          extendBody: true,
          appBar: AppBar(
            backgroundColor: InkTheme.paperWhite.withValues(alpha: 0.74),
            toolbarHeight: 74,
            flexibleSpace: const _GlassWash(radius: 0),
            title: Row(
              children: [
                Image.asset(
                  'UI/image.png',
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
                  if (_controller.busy) const LinearProgressIndicator(),
                  Expanded(child: pages[_index]),
                ],
              ),
            ),
          ),
          bottomNavigationBar: SafeArea(
            minimum: const EdgeInsets.fromLTRB(14, 0, 14, 10),
            child: _GlassShell(
              radius: 28,
              opacity: 0.56,
              borderOpacity: 0.16,
              child: NavigationBar(
                backgroundColor: Colors.transparent,
                selectedIndex: _index,
                onDestinationSelected: (value) =>
                    setState(() => _index = value),
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
            ),
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
                      if (!isReset && !isRegister && !compact) ...[
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            Expanded(
                              child: InkButton.secondary(
                                onPressed: () => controller.loginWithApple(s),
                                icon: Icons.apple,
                                label: 'Apple',
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: InkButton.secondary(
                                onPressed: () => controller.loginWithGoogle(s),
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
  const _HomePage({required this.controller, required this.onOpenAlbums});

  final AppController controller;
  final VoidCallback onOpenAlbums;

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
            onPressed: onOpenAlbums,
            child: Text(s.isZh ? '查看全部' : 'View all'),
          ),
          child: controller.albums.isEmpty
              ? _FeatureEmptyState(
                  icon: Icons.photo_library_outlined,
                  title: s.isZh ? '等待云端相册' : 'Waiting for cloud albums',
                  detail: controller.uiFeatureError,
                )
              : SizedBox(
                  height: 152,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemBuilder: (context, index) => _InkAlbumCard(
                      album: controller.albums[index],
                      compact: true,
                      onTap: () {
                        controller.selectAlbum(controller.albums[index]);
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => _AlbumDetailPage(
                              controller: controller,
                              album: controller.albums[index],
                            ),
                          ),
                        );
                      },
                    ),
                    separatorBuilder: (_, _) => const SizedBox(width: 10),
                    itemCount: controller.albums.length,
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
          child: _MemberAvatarRow(controller: controller),
        ),
        _DeviceSyncCard(controller: controller),
        _Panel(
          title: s.isZh ? '最近更新' : 'Recent Updates',
          child: Column(
            children: [
              if (controller.timelineEvents.isEmpty)
                _FeatureEmptyState(
                  icon: Icons.update_outlined,
                  title: s.isZh ? '暂无云端更新' : 'No cloud updates yet',
                  detail: controller.uiFeatureError,
                )
              else
                for (final item in controller.timelineEvents.take(3))
                  _UpdateTile.fromTimeline(item: item),
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
    final albums = controller.filteredAlbums;
    return _PageScaffold(
      children: [
        _HeaderBlock(
          icon: Icons.photo_library_outlined,
          title: s.isZh ? '我的相册' : 'My Albums',
          subtitle: s.isZh
              ? '浏览、筛选和珍藏每一段回忆。'
              : 'Browse, filter, and keep every memory.',
        ),
        _Panel(
          title: s.isZh ? '相册管理' : 'Album management',
          action: IconButton(
            onPressed: () => controller.refreshUiFeatures(s),
            icon: const Icon(Icons.refresh),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              InkTextField(
                controller: controller.albumSearchController,
                labelText: s.isZh ? '搜索相册' : 'Search albums',
                prefixIcon: Icons.search,
              ),
              const SizedBox(height: 10),
              InkTextField(
                controller: controller.albumNameController,
                labelText: s.isZh ? '相册名称' : 'Album name',
                prefixIcon: Icons.photo_album_outlined,
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: () => controller.createAlbum(s),
                    icon: const Icon(Icons.add),
                    label: Text(s.isZh ? '创建相册' : 'Create album'),
                  ),
                  OutlinedButton.icon(
                    onPressed: controller.selectedAlbum == null
                        ? null
                        : () => controller.renameSelectedAlbum(s),
                    icon: const Icon(Icons.edit_outlined),
                    label: Text(s.rename),
                  ),
                  OutlinedButton.icon(
                    onPressed: controller.selectedAlbum == null
                        ? null
                        : () => controller.deleteSelectedAlbum(s),
                    icon: const Icon(Icons.delete_outline),
                    label: Text(s.isZh ? '删除' : 'Delete'),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (albums.isEmpty)
          _Panel(
            title: s.albums,
            child: _FeatureEmptyState(
              icon: Icons.photo_library_outlined,
              title: s.isZh ? '还没有云端相册' : 'No cloud albums yet',
              detail: controller.uiFeatureError,
            ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.82,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: albums.length,
            itemBuilder: (context, index) => _InkAlbumCard(
              album: albums[index],
              selected:
                  albums[index].albumId == controller.selectedAlbum?.albumId,
              onTap: () {
                controller.selectAlbum(albums[index]);
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => _AlbumDetailPage(
                      controller: controller,
                      album: albums[index],
                    ),
                  ),
                );
              },
            ),
          ),
        if (controller.photos.isNotEmpty)
          _Panel(
            title: s.isZh ? '照片库' : 'Photo library',
            child: _PhotoGrid(
              photos: controller.photos,
              onFavorite: (photo) => controller.toggleFavoritePhoto(s, photo),
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
        _Panel(
          title: s.isZh ? '时间筛选' : 'Timeline filters',
          action: IconButton(
            onPressed: () => controller.refreshUiFeatures(s),
            icon: const Icon(Icons.refresh),
          ),
          child: SegmentedButton<String>(
            segments: [
              ButtonSegment(value: 'all', label: Text(s.isZh ? '全部' : 'All')),
              ButtonSegment(
                value: 'month',
                label: Text(s.isZh ? '本月' : 'Month'),
              ),
              ButtonSegment(value: 'year', label: Text(s.isZh ? '今年' : 'Year')),
            ],
            selected: {controller.timelineRange},
            onSelectionChanged: (values) {
              controller.setTimelineRange(values.first);
              controller.refreshUiFeatures(s);
            },
          ),
        ),
        if (controller.timelineEvents.isEmpty)
          _Panel(
            title: s.timeline,
            child: _FeatureEmptyState(
              icon: Icons.schedule_outlined,
              title: s.isZh ? '暂无时间线事件' : 'No timeline events yet',
              detail: controller.uiFeatureError,
            ),
          )
        else
          for (final event in controller.timelineEvents)
            _Panel(
              title: formatLocalTime(event.createdAt).isEmpty
                  ? event.type
                  : formatLocalTime(event.createdAt),
              child: _TimelineEventTile(event: event),
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
              ? (s.isZh ? '可仅上传到相册' : 'Album upload available')
              : _deviceTitle(device),
          preview: controller.previewPng,
          emptyText: s.noPreview,
        ),
        _Panel(
          title: s.isZh ? '01 目标相册' : '01 Target Album',
          action: IconButton(
            onPressed: () => controller.refreshUiFeatures(s),
            icon: const Icon(Icons.refresh),
          ),
          child: _AlbumTargetSelector(controller: controller),
        ),
        _Panel(
          title: s.isZh ? '02 选择设备（可选）' : '02 Select Device (optional)',
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
          title: s.isZh ? '03 编辑与适配' : '03 Edit & Fit',
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
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  SizedBox(
                    width: 180,
                    child: InkButton.secondary(
                      onPressed: () => controller.chooseImage(s),
                      icon: Icons.add_photo_alternate_outlined,
                      label: s.chooseImage,
                    ),
                  ),
                  SizedBox(
                    width: 190,
                    child: InkButton.primary(
                      onPressed: controller.selectedImage == null
                          ? null
                          : () => controller.uploadSelectedImageForPreview(s),
                      icon: Icons.tune_outlined,
                      label: device == null
                          ? (s.isZh ? '上传并预览' : 'Upload preview')
                          : (s.isZh ? '生成预览' : 'Generate preview'),
                    ),
                  ),
                  if (device != null)
                    SizedBox(
                      width: 190,
                      child: InkButton.primary(
                        onPressed: controller.latestImage == null
                            ? null
                            : () => controller
                                  .assignLatestImageToSelectedDevice(s),
                        icon: Icons.send_outlined,
                        label: s.isZh ? '确认下发' : 'Confirm send',
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                s.isZh
                    ? '先生成六色墨水屏预览，确认画面没问题后再下发到设备。'
                    : 'Generate the six-color e-ink preview first, then confirm before sending to the frame.',
                style: Theme.of(context).textTheme.bodySmall,
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
    final user = controller.currentUser;
    return _PageScaffold(
      children: [
        _ProfileHeader(
          user: user,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => _ProfileEditPage(controller: controller),
            ),
          ),
        ),
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

class _AlbumTargetSelector extends StatelessWidget {
  const _AlbumTargetSelector({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    if (controller.albums.isEmpty) {
      return _FeatureEmptyState(
        icon: Icons.photo_album_outlined,
        title: s.isZh ? '暂无相册可选' : 'No albums available',
        detail: controller.uiFeatureError,
      );
    }
    return DropdownButtonFormField<String>(
      initialValue: controller.selectedAlbum?.albumId,
      items: [
        for (final album in controller.albums)
          DropdownMenuItem(
            value: album.albumId,
            child: Text(album.title, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: (value) {
        if (value == null) {
          return;
        }
        controller.selectAlbum(
          controller.albums.firstWhere((album) => album.albumId == value),
        );
      },
      decoration: InputDecoration(
        labelText: s.albums,
        helperText: s.isZh
            ? '没有设备时也可以仅上传到相册。'
            : 'You can upload to an album without a device.',
      ),
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
        _Panel(
          title: s.isZh ? '测试工具' : 'Testing tools',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                s.isZh
                    ? '创建一台云端虚拟六色墨水屏，用于测试上传、下发、时间线和状态流程。'
                    : 'Create a cloud virtual six-color e-ink frame for upload, assign, timeline, and status testing.',
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => controller.createVirtualDevice(s),
                icon: const Icon(Icons.science_outlined),
                label: Text(s.isZh ? '绑定虚拟测试设备' : 'Bind virtual test device'),
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
                      onPressed: () async {
                        final confirmed = await _confirmDestructiveAction(
                          context,
                          title: s.isZh
                              ? '解绑 / 删除设备'
                              : 'Unbind / delete device',
                          message: s.isZh
                              ? '设备将从当前账号移除。虚拟测试设备也会从云端测试列表删除。'
                              : 'This removes the device from your account. Virtual test devices are also deleted from the cloud test list.',
                          confirmLabel: s.isZh ? '解绑设备' : 'Unbind device',
                        );
                        if (confirmed && context.mounted) {
                          controller.unbindSelectedDevice(s);
                        }
                      },
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
                          subtitle: joinDetails([
                            if (event.version != null) 'v${event.version}',
                            if (event.error != null) event.error!,
                            if (event.batteryMv != null)
                              '${event.batteryMv} mV',
                            if (event.rssi != null) '${event.rssi} dBm',
                            formatLocalTime(event.createdAt),
                          ], separator: ' | '),
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

Future<bool> _confirmDestructiveAction(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
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
                if (controller.groups.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: _EmptyState(
                      icon: Icons.group_outlined,
                      text: s.noGroups,
                    ),
                  ),
              ],
            ),
          ),
          _Panel(
            title: s.inviteMember,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (controller.groups.isEmpty)
                  _EmptyState(icon: Icons.group_outlined, text: s.noGroups)
                else ...[
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
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: group == null
                        ? null
                        : () async {
                            final confirmed = await _confirmDestructiveAction(
                              context,
                              title: s.isZh ? '删除组' : 'Delete group',
                              message: s.isZh
                                  ? '删除后成员邀请和共享设备关系会从该组移除。'
                                  : 'Members, invites, and shared device links in this group will be removed.',
                              confirmLabel: s.isZh ? '删除组' : 'Delete group',
                            );
                            if (confirmed && context.mounted) {
                              controller.deleteSelectedGroup(s);
                            }
                          },
                    icon: const Icon(Icons.delete_outline),
                    label: Text(s.isZh ? '删除当前组' : 'Delete selected group'),
                  ),
                  const SizedBox(height: 14),
                ],
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
                      trailing: IconButton(
                        onPressed: group == null
                            ? null
                            : () async {
                                final confirmed = await _confirmDestructiveAction(
                                  context,
                                  title: s.isZh
                                      ? '移除共享设备'
                                      : 'Remove shared device',
                                  message: s.isZh
                                      ? '这只会从当前组移除共享关系，不会删除设备本身。'
                                      : 'This only removes the shared link from this group. The device itself is not deleted.',
                                  confirmLabel: s.isZh ? '移除' : 'Remove',
                                );
                                if (confirmed && context.mounted) {
                                  controller.removeSelectedDeviceFromGroup(
                                    s,
                                    item,
                                  );
                                }
                              },
                        icon: const Icon(Icons.link_off),
                      ),
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
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final s = AppStrings.of(context);
        final payload = controller.qrPayload;
        final media = MediaQuery.of(context);
        final useSoftAp = controller.provisioningTransport == 'softap';

        return MediaQuery(
          data: media.copyWith(
            textScaler: media.textScaler.clamp(maxScaleFactor: 1.15),
          ),
          child: ColoredBox(
            color: InkTheme.paperWhite,
            child: SafeArea(
              top: false,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 110),
                children: [
                  _ProvisionPanel(
                    title: s.provisionBind,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        FilledButton.icon(
                          onPressed: () async {
                            final raw = await Navigator.of(context)
                                .push<String>(
                                  MaterialPageRoute(
                                    builder: (_) => const QrScannerPage(),
                                  ),
                                );
                            if (raw != null &&
                                raw.isNotEmpty &&
                                context.mounted) {
                              controller.applyQrPayload(s, raw);
                            }
                          },
                          icon: const Icon(Icons.qr_code_scanner),
                          label: Text(s.scanDeviceQr),
                        ),
                        if (payload == null) ...[
                          const SizedBox(height: 18),
                          _EmptyState(
                            icon: Icons.qr_code_2_outlined,
                            text: s.isZh
                                ? '扫描设备二维码后，这里会显示设备信息和搜索入口。'
                                : 'After scanning the device QR code, device details and search actions will appear here.',
                          ),
                        ] else ...[
                          const SizedBox(height: 16),
                          _StepHeader(index: 1, text: s.scanDeviceQr),
                          _KeyValue(
                            label: useSoftAp ? s.softApName : s.bleName,
                            value: payload.name,
                          ),
                          _KeyValue(label: s.deviceId, value: payload.deviceId),
                          _KeyValue(
                            label: s.transport,
                            value: payload.transport,
                          ),
                          const SizedBox(height: 10),
                          SegmentedButton<String>(
                            segments: [
                              ButtonSegment(
                                value: 'ble',
                                icon: const Icon(Icons.bluetooth),
                                label: Text(s.isZh ? 'BLE' : 'BLE'),
                              ),
                              ButtonSegment(
                                value: 'softap',
                                icon: const Icon(Icons.wifi_tethering),
                                label: Text(s.isZh ? 'SoftAP' : 'SoftAP'),
                              ),
                            ],
                            selected: {controller.provisioningTransport},
                            onSelectionChanged: (selection) =>
                                controller.selectProvisioningTransport(
                                  s,
                                  selection.first,
                                ),
                          ),
                          const SizedBox(height: 12),
                          InkTextField(
                            controller: controller.deviceNicknameController,
                            labelText: s.nickname,
                            prefixIcon: Icons.edit_outlined,
                          ),
                          const SizedBox(height: 16),
                          _StepHeader(
                            index: 2,
                            text: useSoftAp
                                ? s.searchSoftApDevice
                                : s.searchBleDevice,
                          ),
                          if (useSoftAp) ...[
                            Text(
                              s.softApHint,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const SizedBox(height: 10),
                            InkTextField(
                              controller: controller.softApPasswordController,
                              obscureText: true,
                              labelText: s.softApPassword,
                              helperText: s.softApPasswordHelp,
                              prefixIcon: Icons.wifi_password_outlined,
                            ),
                            const SizedBox(height: 10),
                            FilledButton.icon(
                              onPressed: () =>
                                  controller.connectScannedSoftApDevice(s),
                              icon: const Icon(Icons.link),
                              label: Text(
                                s.isZh
                                    ? '连接 ${payload.name}'
                                    : 'Connect ${payload.name}',
                              ),
                            ),
                            const SizedBox(height: 10),
                          ],
                          OutlinedButton.icon(
                            onPressed: () =>
                                controller.searchProvisioningDevice(s),
                            icon: Icon(
                              useSoftAp
                                  ? Icons.wifi_tethering
                                  : Icons.bluetooth_searching,
                            ),
                            label: Text(
                              useSoftAp
                                  ? s.searchSoftApDevice
                                  : s.searchBleDevice,
                            ),
                          ),
                          if (controller.busy) ...[
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    s.searchingDevices,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                        for (final device
                            in controller.provisioningDevices) ...[
                          const SizedBox(height: 8),
                          InkIconTile(
                            icon: useSoftAp ? Icons.wifi : Icons.bluetooth,
                            title: device.name,
                            subtitle: device.serviceUuid ?? s.noServiceUuid,
                            onTap: () =>
                                controller.connectProvisioningDevice(s, device),
                            trailing: FilledButton.icon(
                              icon: const Icon(Icons.link, size: 18),
                              label: Text(s.connect),
                              onPressed: () => controller
                                  .connectProvisioningDevice(s, device),
                            ),
                          ),
                        ],
                        if (!controller.busy &&
                            controller.provisioningSearchAttempted &&
                            controller.provisioningDevices.isEmpty) ...[
                          const SizedBox(height: 10),
                          _EmptyState(
                            icon: useSoftAp
                                ? Icons.wifi_off_outlined
                                : Icons.bluetooth_disabled_outlined,
                            text: useSoftAp
                                ? s.softApManualFallback
                                : s.noProvisioningDevicesFound,
                          ),
                        ],
                        if (controller.provisioningConnected) ...[
                          const SizedBox(height: 16),
                          _StepHeader(index: 3, text: s.wifiNetwork),
                          if (controller.wifiNetworks.isNotEmpty) ...[
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
                              decoration: InputDecoration(
                                labelText: s.wifiNetwork,
                              ),
                            ),
                            const SizedBox(height: 10),
                          ],
                          InkTextField(
                            controller: controller.wifiNameController,
                            labelText: s.isZh
                                ? 'Wi-Fi 名称（SSID）'
                                : 'Wi-Fi name (SSID)',
                            prefixIcon: Icons.wifi_outlined,
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
                        if (payload != null) ...[
                          const SizedBox(height: 16),
                          _ProvisioningDiagnostics(
                            controller: controller,
                            payload: payload,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
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
        _HeaderBlock(
          icon: Icons.security_outlined,
          title: s.isZh ? '账号与安全' : 'Account & security',
          subtitle: s.isZh
              ? '管理账号状态、验证、密码与连接。'
              : 'Manage account status, verification, password, and connection.',
        ),
        _Panel(
          title: s.isZh ? '账号状态' : 'Account status',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              InkIconTile(
                icon: Icons.person_outline,
                title: session?.user.preferredName ?? s.notLoggedIn,
                subtitle: session == null
                    ? s.notLoggedIn
                    : s.loggedInAs(
                        session.user.email,
                        session.user.emailVerified,
                      ),
                dotColor: session?.user.emailVerified == true
                    ? InkTheme.eInkBlue
                    : InkTheme.eInkYellow,
              ),
              if (session?.user.updatedAt != null)
                _KeyValue(
                  label: s.isZh ? '资料更新' : 'Profile updated',
                  value: formatLocalTime(session!.user.updatedAt),
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
                Text(
                  s.isZh
                      ? '验证邮箱后可以使用设备绑定、上传和共享等写操作。'
                      : 'Verify your email to use device binding, uploads, and sharing writes.',
                ),
                const SizedBox(height: 12),
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
          title: s.isZh ? '密码安全' : 'Password security',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              InkIconTile(
                icon: Icons.lock_reset,
                title: s.passwordReset,
                subtitle: s.isZh ? '通过邮件验证码重设密码' : 'Reset with an email code',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => _BusyRoute(
                      controller: controller,
                      child: _PasswordResetPage(controller: controller),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        _Panel(
          title: s.isZh ? '登录方式' : 'Sign-in methods',
          child: Column(
            children: [
              InkIconTile(
                icon: Icons.mail_outline,
                title: s.isZh ? '邮箱密码' : 'Email and password',
                subtitle: session?.user.email ?? s.notLoggedIn,
                dotColor: InkTheme.eInkBlue,
              ),
              InkIconTile(
                icon: Icons.apple,
                title: 'Apple',
                subtitle: s.isZh
                    ? '通过 Apple 凭证登录'
                    : 'Sign in with Apple token exchange',
              ),
              InkIconTile(
                icon: Icons.g_mobiledata,
                title: 'Google',
                subtitle: s.isZh
                    ? '通过 Google 凭证登录'
                    : 'Sign in with Google token exchange',
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
          title: s.isZh ? '服务器连接' : 'Server connection',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              InkTextField(
                controller: controller.baseUrlController,
                enabled: !controller.busy,
                labelText: s.serverBaseUrl,
                prefixIcon: Icons.cloud_outlined,
              ),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: () => controller.logout(s),
                icon: const Icon(Icons.logout),
                label: Text(s.logout),
              ),
            ],
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

class _ProfileEditPage extends StatelessWidget {
  const _ProfileEditPage({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final user = controller.currentUser;
    return Scaffold(
      appBar: AppBar(title: Text(s.isZh ? '编辑个人资料' : 'Edit profile')),
      body: _PageScaffold(
        children: [
          _Panel(
            title: s.isZh ? '个人信息' : 'Profile',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                InkIconTile(
                  icon: Icons.alternate_email,
                  title: user?.email ?? s.notLoggedIn,
                  subtitle: user?.emailVerified == true
                      ? (s.isZh ? '邮箱已验证' : 'Email verified')
                      : (s.isZh ? '邮箱未验证' : 'Email unverified'),
                  dotColor: user?.emailVerified == true
                      ? InkTheme.eInkBlue
                      : InkTheme.eInkYellow,
                ),
                const SizedBox(height: 12),
                InkTextField(
                  controller: controller.profileNameController,
                  labelText: s.isZh ? '显示名称' : 'Display name',
                  prefixIcon: Icons.badge_outlined,
                ),
                const SizedBox(height: 12),
                InkTextField(
                  controller: controller.profileBioController,
                  labelText: s.isZh ? '简介' : 'Bio',
                  prefixIcon: Icons.notes_outlined,
                ),
                if (user?.updatedAt != null) ...[
                  const SizedBox(height: 10),
                  _KeyValue(
                    label: s.isZh ? '上次更新' : 'Last updated',
                    value: formatLocalTime(user!.updatedAt),
                  ),
                ],
                const SizedBox(height: 16),
                InkButton.primary(
                  onPressed: () => controller.updateProfile(s),
                  icon: Icons.save_outlined,
                  label: s.isZh ? '保存资料' : 'Save profile',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationsPage extends StatelessWidget {
  const _NotificationsPage({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(s.isZh ? '通知' : 'Notifications')),
      body: _PageScaffold(
        children: [
          _Panel(
            title: s.isZh ? '云端通知' : 'Cloud notifications',
            action: IconButton(
              onPressed: () => controller.refreshUiFeatures(s),
              icon: const Icon(Icons.refresh),
            ),
            child: controller.notifications.isEmpty
                ? _FeatureEmptyState(
                    icon: Icons.notifications_none,
                    title: s.isZh ? '暂无通知' : 'No notifications yet',
                    detail: controller.uiFeatureError,
                  )
                : Column(
                    children: [
                      for (final item in controller.notifications)
                        InkIconTile(
                          icon: item.read
                              ? Icons.notifications_none
                              : Icons.notifications_active_outlined,
                          title: item.title,
                          subtitle: joinDetails([
                            if (item.body != null) item.body!,
                            formatLocalTime(item.createdAt),
                          ]),
                          dotColor: item.read ? null : InkTheme.eInkRed,
                          onTap: () => controller.markNotificationRead(s, item),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _StoragePage extends StatelessWidget {
  const _StoragePage({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final storage = controller.storageSummary;
    return Scaffold(
      appBar: AppBar(title: Text(s.isZh ? '存储与空间' : 'Storage')),
      body: _PageScaffold(
        children: [
          _Panel(
            title: s.isZh ? '云端空间' : 'Cloud storage',
            action: IconButton(
              onPressed: () => controller.refreshUiFeatures(s),
              icon: const Icon(Icons.refresh),
            ),
            child: storage == null
                ? _FeatureEmptyState(
                    icon: Icons.cloud_queue_outlined,
                    title: s.isZh ? '暂无存储统计' : 'No storage summary yet',
                    detail: controller.uiFeatureError,
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      LinearProgressIndicator(
                        value: storage.usedRatio.clamp(0, 1).toDouble(),
                      ),
                      const SizedBox(height: 12),
                      _KeyValue(
                        label: s.isZh ? '已使用' : 'Used',
                        value: _storageLabel(storage),
                      ),
                      _KeyValue(
                        label: s.isZh ? '照片' : 'Photos',
                        value: '${storage.photoCount}',
                      ),
                      _KeyValue(
                        label: s.albums,
                        value: '${storage.albumCount}',
                      ),
                      _KeyValue(
                        label: s.devices,
                        value: '${storage.deviceCount}',
                      ),
                      if (storage.cleanupSuggestion != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(storage.cleanupSuggestion!),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _PreferencesPage extends StatelessWidget {
  const _PreferencesPage({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final prefs = controller.preferences;
    return Scaffold(
      appBar: AppBar(title: Text(s.isZh ? '隐私与偏好' : 'Privacy & preferences')),
      body: _PageScaffold(
        children: [
          _Panel(
            title: s.isZh ? '通知与可见性' : 'Alerts and visibility',
            child: Column(
              children: [
                SwitchListTile(
                  value: prefs.deviceAlerts,
                  onChanged: (value) => controller.updatePreferences(
                    s,
                    UserPreferences(
                      deviceAlerts: value,
                      sharingAlerts: prefs.sharingAlerts,
                      uploadAlerts: prefs.uploadAlerts,
                      profileVisibility: prefs.profileVisibility,
                      analyticsEnabled: prefs.analyticsEnabled,
                    ),
                  ),
                  title: Text(s.isZh ? '设备提醒' : 'Device alerts'),
                ),
                SwitchListTile(
                  value: prefs.sharingAlerts,
                  onChanged: (value) => controller.updatePreferences(
                    s,
                    UserPreferences(
                      deviceAlerts: prefs.deviceAlerts,
                      sharingAlerts: value,
                      uploadAlerts: prefs.uploadAlerts,
                      profileVisibility: prefs.profileVisibility,
                      analyticsEnabled: prefs.analyticsEnabled,
                    ),
                  ),
                  title: Text(s.isZh ? '共享提醒' : 'Sharing alerts'),
                ),
                SwitchListTile(
                  value: prefs.uploadAlerts,
                  onChanged: (value) => controller.updatePreferences(
                    s,
                    UserPreferences(
                      deviceAlerts: prefs.deviceAlerts,
                      sharingAlerts: prefs.sharingAlerts,
                      uploadAlerts: value,
                      profileVisibility: prefs.profileVisibility,
                      analyticsEnabled: prefs.analyticsEnabled,
                    ),
                  ),
                  title: Text(s.isZh ? '上传提醒' : 'Upload alerts'),
                ),
                SwitchListTile(
                  value: prefs.analyticsEnabled,
                  onChanged: (value) => controller.updatePreferences(
                    s,
                    UserPreferences(
                      deviceAlerts: prefs.deviceAlerts,
                      sharingAlerts: prefs.sharingAlerts,
                      uploadAlerts: prefs.uploadAlerts,
                      profileVisibility: prefs.profileVisibility,
                      analyticsEnabled: value,
                    ),
                  ),
                  title: Text(s.isZh ? '体验分析' : 'Experience analytics'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

enum _InfoPageKind { help, about }

class _InfoPage extends StatelessWidget {
  const _InfoPage({required this.kind});

  final _InfoPageKind kind;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final about = kind == _InfoPageKind.about;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          about
              ? (s.isZh ? '关于 InkSplash' : 'About InkSplash')
              : (s.isZh ? '帮助与反馈' : 'Help & feedback'),
        ),
      ),
      body: _PageScaffold(
        children: [
          _Panel(
            title: about
                ? (s.isZh ? 'InkSplash' : 'InkSplash')
                : (s.isZh ? '支持' : 'Support'),
            child: Text(
              about
                  ? (s.isZh
                        ? 'InkSplash 是为六色电子墨水屏设计的家庭相册 App。当前版本 v1.0.28。'
                        : 'InkSplash is a family album app for six-color e-ink frames. Current version v1.0.28.')
                  : (s.isZh
                        ? '如需反馈，请在 GitHub 项目中提交 issue，并附上设备型号、系统版本和问题截图。'
                        : 'For feedback, open a GitHub issue with your device model, OS version, and screenshots.'),
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
          String? raw;
          for (final barcode in capture.barcodes) {
            final value = barcode.rawValue?.trim();
            if (value != null && value.isNotEmpty) {
              raw = value;
              break;
            }
          }
          if (raw != null) {
            _handled = true;
            unawaited(_controller.stop());
            Navigator.of(context).pop(raw);
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
            padding: padding ?? const EdgeInsets.fromLTRB(18, 12, 18, 110),
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
          ],
        );
      },
    );
  }
}

class _GlassWash extends StatelessWidget {
  const _GlassWash({this.radius = 24});

  final double radius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xbffffdf9), Color(0x8cffffff), Color(0x66f1efe8)],
            ),
          ),
          child: SizedBox.expand(),
        ),
      ),
    );
  }
}

class _GlassShell extends StatelessWidget {
  const _GlassShell({
    required this.child,
    this.radius = 24,
    this.opacity = 0.64,
    this.borderOpacity = 0.12,
  });

  final Widget child;
  final double radius;
  final double opacity;
  final double borderOpacity;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          decoration: BoxDecoration(
            color: InkTheme.paperSurface.withValues(alpha: opacity),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.72),
              width: 0.8,
            ),
            boxShadow: [
              BoxShadow(
                color: InkTheme.inkBlack.withValues(alpha: 0.07),
                blurRadius: 28,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          foregroundDecoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: InkTheme.inkBlack.withValues(alpha: borderOpacity),
              width: 0.7,
            ),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.28),
                Colors.white.withValues(alpha: 0.06),
                InkTheme.eInkBlue.withValues(alpha: 0.035),
              ],
            ),
          ),
          child: child,
        ),
      ),
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
    return _GlassShell(
      radius: 22,
      opacity: 0.72,
      borderOpacity: 0.08,
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

    return _GlassShell(
      radius: 16,
      opacity: onPressed == null ? 0.34 : 0.18,
      borderOpacity: 0.10,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: onPressed == null
              ? null
              : const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xff6f9df2),
                    Color(0xff4c7bd9),
                    Color(0xff2858c8),
                  ],
                ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: onPressed == null
              ? const []
              : [
                  BoxShadow(
                    color: InkTheme.eInkBlue.withValues(alpha: 0.24),
                    blurRadius: 20,
                    offset: const Offset(0, 9),
                  ),
                ],
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.white.withValues(alpha: onPressed == null ? 0.04 : 0.26),
                Colors.transparent,
              ],
            ),
          ),
          child: FilledButton(
            onPressed: onPressed,
            style: FilledButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
            ),
            child: child,
          ),
        ),
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
            Image.asset('UI/image.png', width: 58, height: 58),
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
                  child: _GlassShell(
                    radius: 24,
                    opacity: 0.50,
                    borderOpacity: 0.09,
                    child: Padding(
                      padding: const EdgeInsets.all(18),
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

class _ProvisionPanel extends StatelessWidget {
  const _ProvisionPanel({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: InkTheme.paperSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: InkTheme.inkBlack.withValues(alpha: 0.08)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 14),
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

class _MemberAvatarRow extends StatelessWidget {
  const _MemberAvatarRow({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final members = controller.groupMembers.isEmpty
        ? [
            [controller.session?.user.email ?? 'Me', s.isZh ? '你' : 'You'],
          ]
        : [
            for (final member in controller.groupMembers)
              [member.email, member.role],
          ];
    final avatars = [
      'assets/demo/avatar_emily.png',
      'assets/demo/avatar_dad.png',
      'assets/demo/avatar_mom.png',
      'assets/demo/avatar_grandma.png',
    ];
    return Row(
      children: [
        for (var index = 0; index < members.length.clamp(0, 4); index++)
          Expanded(
            child: Column(
              children: [
                CircleAvatar(
                  backgroundImage: AssetImage(avatars[index % avatars.length]),
                  radius: 24,
                ),
                const SizedBox(height: 6),
                Text(
                  members[index][0],
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  members[index][1],
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        OutlinedButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => _BusyRoute(
                controller: controller,
                child: _SharingPage(controller: controller),
              ),
            ),
          ),
          child: const Icon(Icons.add),
        ),
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
        title: device == null
            ? (s.isZh ? '尚未选择设备' : 'No device selected')
            : _deviceTitle(device),
        subtitle: device == null
            ? s.bindFirstThenRefresh
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
  _UpdateTile.fromTimeline({required InkTimelineEvent item})
    : title = item.title,
      subtitle = joinDetails([
        if (item.subtitle != null) item.subtitle!,
        if (item.deviceId != null) item.deviceId!,
        formatLocalTime(item.createdAt),
      ]),
      image = null,
      previewUrl = item.previewUrl,
      dotColor = _timelineColor(item.type);

  final String title;
  final String subtitle;
  final String? image;
  final String? previewUrl;
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
        child: _RemoteOrAssetThumb(
          url: previewUrl,
          asset: image ?? 'assets/demo/frame_preview.png',
          width: 50,
          height: 50,
        ),
      ),
    );
  }
}

Color _timelineColor(String type) {
  return switch (type) {
    'photo_assigned' || 'device_displayed' => InkTheme.eInkBlue,
    'group_invite' || 'member_joined' => InkTheme.eInkRed,
    _ => InkTheme.eInkYellow,
  };
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

class _FeatureEmptyState extends StatelessWidget {
  const _FeatureEmptyState({
    required this.icon,
    required this.title,
    this.detail,
  });

  final IconData icon;
  final String title;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    return _EmptyState(
      icon: icon,
      text: [
        title,
        if (detail != null && detail!.isNotEmpty)
          s.contentTemporarilyUnavailable,
      ].join('\n'),
    );
  }
}

class _RemoteOrAssetThumb extends StatelessWidget {
  const _RemoteOrAssetThumb({
    required this.asset,
    this.url,
    this.width,
    this.height,
  });

  final String? url;
  final String asset;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final remote = url;
    if (remote != null && remote.isNotEmpty) {
      return Image.network(
        remote,
        width: width,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) =>
            Image.asset(asset, width: width, height: height, fit: BoxFit.cover),
      );
    }
    return Image.asset(asset, width: width, height: height, fit: BoxFit.cover);
  }
}

class _InkAlbumCard extends StatelessWidget {
  const _InkAlbumCard({
    required this.album,
    this.compact = false,
    this.selected = false,
    this.onTap,
  });

  final InkAlbum album;
  final bool compact;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: compact ? 118 : null,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: selected
                ? Border.all(color: InkTheme.eInkBlue, width: 1.4)
                : null,
          ),
          child: Padding(
            padding: EdgeInsets.all(selected ? 4 : 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: _RemoteOrAssetThumb(
                      url: album.coverUrl,
                      asset: 'assets/demo/album_cover.png',
                      width: double.infinity,
                    ),
                  ),
                ),
                const SizedBox(height: 9),
                Text(
                  album.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(
                  '${album.photoCount} ${AppStrings.of(context).isZh ? '张照片' : 'photos'}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PhotoGrid extends StatelessWidget {
  const _PhotoGrid({required this.photos, required this.onFavorite});

  final List<InkPhoto> photos;
  final ValueChanged<InkPhoto> onFavorite;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 7,
        crossAxisSpacing: 7,
      ),
      itemCount: photos.length,
      itemBuilder: (context, index) {
        final photo = photos[index];
        return Stack(
          fit: StackFit.expand,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: _RemoteOrAssetThumb(
                url: photo.previewUrl,
                asset: 'assets/demo/frame_preview.png',
              ),
            ),
            Positioned(
              right: 2,
              top: 2,
              child: IconButton.filledTonal(
                onPressed: () => onFavorite(photo),
                icon: Icon(
                  photo.favorite ? Icons.favorite : Icons.favorite_border,
                  size: 18,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _TimelineEventTile extends StatelessWidget {
  const _TimelineEventTile({required this.event});

  final InkTimelineEvent event;

  @override
  Widget build(BuildContext context) {
    return InkIconTile(
      icon: switch (event.type) {
        'photo_assigned' => Icons.send_outlined,
        'device_displayed' => Icons.tablet_mac_outlined,
        'group_invite' => Icons.group_add_outlined,
        'member_joined' => Icons.person_add_alt_1,
        _ => Icons.image_outlined,
      },
      title: event.title,
      subtitle: joinDetails([
        if (event.subtitle != null) event.subtitle!,
        if (event.deviceId != null) event.deviceId!,
        if (event.albumId != null) event.albumId!,
      ]),
      dotColor: _timelineColor(event.type),
      trailing: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: _RemoteOrAssetThumb(
          url: event.previewUrl,
          asset: 'assets/demo/frame_preview.png',
          width: 50,
          height: 50,
        ),
      ),
    );
  }
}

class _AlbumDetailPage extends StatelessWidget {
  const _AlbumDetailPage({required this.controller, required this.album});

  final AppController controller;
  final InkAlbum album;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final photos = album.photos.isEmpty
        ? controller.photos
              .where((photo) => photo.albumIds.contains(album.albumId))
              .toList(growable: false)
        : album.photos;
    return Scaffold(
      appBar: AppBar(title: Text(album.title)),
      body: _PageScaffold(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: _RemoteOrAssetThumb(
              url: album.coverUrl,
              asset: 'assets/demo/album_cover.png',
              height: 220,
              width: double.infinity,
            ),
          ),
          Text(
            album.title,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          Text(
            '${album.photoCount} ${s.isZh ? '张照片' : 'photos'}'
            '${album.shared ? ' · ${s.familySharing}' : ''}',
          ),
          _Panel(
            title: s.isZh ? '添加照片' : 'Add photos',
            child: Row(
              children: [
                Expanded(
                  child: InkButton.secondary(
                    onPressed: () {
                      controller.selectAlbum(album);
                      controller.chooseImage(s);
                    },
                    icon: Icons.add_photo_alternate_outlined,
                    label: s.chooseImage,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: InkButton.primary(
                    onPressed: controller.selectedImage == null
                        ? null
                        : () {
                            controller.selectAlbum(album);
                            controller.uploadToSelectedAlbum(s);
                          },
                    icon: Icons.cloud_upload_outlined,
                    label: s.isZh ? '上传到相册' : 'Upload',
                  ),
                ),
              ],
            ),
          ),
          _MemberAvatarRow(controller: controller),
          _FilterChips(
            labels: [
              s.isZh ? '照片' : 'Photos',
              s.timeline,
              s.isZh ? '地点' : 'Places',
            ],
          ),
          if (photos.isEmpty)
            _FeatureEmptyState(
              icon: Icons.image_outlined,
              title: s.isZh ? '这个相册还没有照片' : 'No photos in this album yet',
            )
          else
            _PhotoGrid(
              photos: photos,
              onFavorite: (photo) => controller.toggleFavoritePhoto(s, photo),
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
  const _ProfileHeader({required this.user, required this.onTap});

  final User? user;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final email = user?.email ?? 'account@inksplash.app';
    final name = user?.preferredName ?? 'InkSplash';
    final bio = user?.bio;
    return InkCard(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
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
              child: CircleAvatar(
                backgroundImage: user?.avatarUrl?.isNotEmpty == true
                    ? NetworkImage(user!.avatarUrl!)
                    : const AssetImage('assets/demo/avatar_emily.png')
                          as ImageProvider,
                radius: 30,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(email, overflow: TextOverflow.ellipsis),
                  if (bio != null && bio.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      bio,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
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
    final storage = controller.storageSummary;
    final rows = [
      _SettingsRow(
        Icons.security_outlined,
        s.isZh ? '账号与安全' : 'Account & security',
        s.isZh ? '修改密码 / 登录状态' : 'Password and sessions',
        () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => _SettingsPage(
              controller: controller,
              language: language,
              onLanguageChanged: onLanguageChanged,
            ),
          ),
        ),
      ),
      _SettingsRow(
        Icons.notifications_none,
        s.isZh ? '通知设置' : 'Notifications',
        s.isZh
            ? '${controller.notifications.where((item) => !item.read).length} 条未读'
            : '${controller.notifications.where((item) => !item.read).length} unread',
        () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => _NotificationsPage(controller: controller),
          ),
        ),
        dotColor: InkTheme.eInkRed,
      ),
      _SettingsRow(
        Icons.cloud_queue_outlined,
        s.isZh ? '存储与空间' : 'Storage',
        storage == null
            ? (s.isZh ? '等待云端统计' : 'Waiting for cloud usage')
            : _storageLabel(storage),
        () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => _StoragePage(controller: controller),
          ),
        ),
      ),
      _SettingsRow(
        Icons.devices_outlined,
        s.isZh ? '设备管理' : 'Device management',
        s.isZh
            ? '已连接 ${controller.devices.length} 台设备'
            : '${controller.devices.length} devices connected',
        () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => _DevicesPage(controller: controller),
          ),
        ),
        dotColor: InkTheme.eInkBlue,
      ),
      _SettingsRow(
        Icons.lock_outline,
        s.isZh ? '隐私设置' : 'Privacy',
        controller.preferences.profileVisibility,
        () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => _PreferencesPage(controller: controller),
          ),
        ),
      ),
      _SettingsRow(
        Icons.help_outline,
        s.isZh ? '帮助与反馈' : 'Help & feedback',
        s.isZh ? '常见问题与反馈' : 'FAQ and feedback',
        () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const _InfoPage(kind: _InfoPageKind.help),
          ),
        ),
      ),
      _SettingsRow(
        Icons.info_outline,
        s.isZh ? '关于 InkSplash' : 'About InkSplash',
        'v1.0.28',
        () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const _InfoPage(kind: _InfoPageKind.about),
          ),
        ),
        dotColor: InkTheme.eInkYellow,
      ),
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
              icon: row.icon,
              title: row.title,
              subtitle: row.subtitle,
              dotColor: row.dotColor,
              onTap: row.onTap,
            ),
        ],
      ),
    );
  }
}

class _SettingsRow {
  const _SettingsRow(
    this.icon,
    this.title,
    this.subtitle,
    this.onTap, {
    this.dotColor,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color? dotColor;
}

String _storageLabel(StorageSummary storage) {
  final usedGb = storage.usedBytes / (1024 * 1024 * 1024);
  final quotaGb = storage.quotaBytes / (1024 * 1024 * 1024);
  return '${usedGb.toStringAsFixed(1)} GB / ${quotaGb.toStringAsFixed(0)} GB';
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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkIconTile(
            icon: Icons.check_circle_outline,
            title: s.previewReady,
            subtitle:
                '${image.width} x ${image.height} · ${image.format.toUpperCase()}',
            dotColor: InkTheme.eInkBlue,
          ),
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
    this.trailing,
  });

  final AppDevice device;
  final bool selected;
  final VoidCallback onTap;
  final Widget? trailing;

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
      trailing:
          trailing ??
          Icon(
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
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
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
              style: TextStyle(
                color: colors.onSurface.withValues(alpha: 0.62),
                fontSize: 14,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProvisioningDiagnostics extends StatelessWidget {
  const _ProvisioningDiagnostics({
    required this.controller,
    required this.payload,
  });

  final AppController controller;
  final ProvisioningQrPayload payload;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final items = <(String, String)>[
      (s.isZh ? '当前传输' : 'Transport', controller.provisioningTransport),
      (s.isZh ? '二维码名称' : 'QR name', payload.name),
      (s.deviceId, payload.deviceId),
      ('Security', '${payload.security}'),
      (
        'PoP',
        payload.proofOfPossession.isEmpty
            ? (s.isZh ? '空' : 'empty')
            : (s.isZh ? '已提供' : 'present'),
      ),
      (
        s.isZh ? '权限' : 'Permissions',
        controller.provisioningPermissionGranted == null
            ? (s.isZh ? '未请求' : 'not requested')
            : controller.provisioningPermissionGranted == true
            ? (s.isZh ? '已允许' : 'granted')
            : (s.isZh ? '已拒绝' : 'denied'),
      ),
      (
        s.isZh ? '最后步骤' : 'Last step',
        controller.provisioningLastStep.isEmpty
            ? (s.isZh ? '无' : 'none')
            : controller.provisioningLastStep,
      ),
      (
        s.isZh ? '最后错误' : 'Last error',
        controller.provisioningLastError ?? (s.isZh ? '无' : 'none'),
      ),
      (
        s.isZh ? '发现设备数' : 'Devices found',
        '${controller.provisioningScannedDeviceCount}',
      ),
      (
        s.isZh ? '设备扫描到的 Wi-Fi 数' : 'Wi-Fi networks found',
        '${controller.provisioningScannedWifiCount}',
      ),
      (
        s.isZh ? '手动 Wi-Fi 名称' : 'Manual Wi-Fi SSID',
        controller.wifiNameController.text.trim().isEmpty
            ? (s.isZh ? '空' : 'empty')
            : controller.wifiNameController.text.trim(),
      ),
    ];

    return DecoratedBox(
      decoration: BoxDecoration(
        color: InkTheme.paperWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: InkTheme.inkBlack.withValues(alpha: 0.08)),
      ),
      child: ExpansionTile(
        initiallyExpanded: controller.provisioningDiagnosticsExpanded,
        onExpansionChanged: controller.setProvisioningDiagnosticsExpanded,
        tilePadding: const EdgeInsets.symmetric(horizontal: 12),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        title: Text(
          s.isZh ? '诊断信息' : 'Diagnostics',
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        children: [
          for (final item in items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 132,
                    child: Text(
                      item.$1,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item.$2,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
        ],
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
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 112,
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colors.onSurface.withValues(alpha: 0.72),
                decoration: TextDecoration.none,
              ),
            ),
          ),
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

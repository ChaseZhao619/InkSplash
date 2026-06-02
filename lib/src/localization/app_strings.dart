import 'package:flutter/widgets.dart';

class AppStrings {
  const AppStrings(this.locale);

  final Locale locale;

  static const supportedLocales = [Locale('en'), Locale('zh')];

  static AppStrings of(BuildContext context) {
    return Localizations.of<AppStrings>(context, AppStrings)!;
  }

  bool get isZh => locale.languageCode == 'zh';

  String get appName => 'InkSplash';
  String get home => isZh ? '首页' : 'Home';
  String get albums => isZh ? '相册' : 'Albums';
  String get timeline => isZh ? '时间线' : 'Timeline';
  String get send => isZh ? '发送' : 'Send';
  String get me => isZh ? '我的' : 'Me';
  String get devices => isZh ? '设备' : 'Devices';
  String get addDevice => isZh ? '添加' : 'Add';
  String get settings => isZh ? '设置' : 'Settings';
  String get account => isZh ? '账号' : 'Account';
  String get upload => isZh ? '上传' : 'Upload';
  String get galleryTone =>
      isZh ? '珍藏记忆，墨见永恒。' : 'Cherish memories, ink meets eternity.';
  String get welcomeBack => isZh ? '欢迎回来' : 'Welcome back';
  String get signInSubtitle =>
      isZh ? '登录后管理你的墨水屏和共享设备。' : 'Sign in to manage your e-paper displays.';
  String get createAccount => isZh ? '创建账号' : 'Create account';
  String get forgotPassword => isZh ? '忘记密码' : 'Forgot password';
  String get backToLogin => isZh ? '返回登录' : 'Back to login';
  String get haveAccount =>
      isZh ? '已有账号？去登录' : 'Already have an account? Sign in';
  String get noAccount => isZh ? '没有账号？去注册' : 'No account? Create one';
  String get sendCode => isZh ? '发送验证码' : 'Send code';
  String get sixDigitCode => isZh ? '6 位验证码' : '6-character code';
  String get codeHelp => isZh
      ? '请输入邮件中的 6 位数字或字母。'
      : 'Enter the 6 letters or digits from your email.';
  String get invalidSixCode =>
      isZh ? '验证码必须是 6 位数字或字母。' : 'Code must be 6 letters or digits.';
  String get currentCanvas => isZh ? '当前画布' : 'Current canvas';
  String get noPreview => isZh ? '还没有图片预览' : 'No image preview yet';
  String get chooseImage => isZh ? '选择图片' : 'Choose image';
  String get sendToFrame => isZh ? '下发到相框' : 'Send to frame';
  String get chooseUploadAssign => sendToFrame;
  String get targetDevice => isZh ? '目标设备' : 'Target device';
  String get selectTargetDevice => isZh ? '选择目标设备' : 'Select target device';
  String get noDeviceAvailable => isZh ? '暂无可用设备' : 'No device available';
  String get bindFirstThenRefresh =>
      isZh ? '请先绑定设备，然后刷新。' : 'Bind a device first, then refresh.';
  String get deviceOverview => isZh ? '设备概览' : 'Device overview';
  String get noBoundDevices => isZh ? '还没有绑定设备' : 'No bound devices';
  String get refreshDevices => isZh ? '刷新设备' : 'Refresh devices';
  String get nickname => isZh ? '昵称' : 'Nickname';
  String get rename => isZh ? '重命名' : 'Rename';
  String get loadMembersStatus => isZh ? '加载成员与状态' : 'Load members/status';
  String get unbindLeave => isZh ? '解绑 / 退出' : 'Unbind / leave';
  String get familySharing => isZh ? '家庭共享' : 'Family sharing';
  String get shareMembers => isZh ? '共享与成员' : 'Sharing & members';
  String get manageSharing => isZh ? '管理共享' : 'Manage sharing';
  String get members => isZh ? '成员' : 'Members';
  String get noMembersLoaded => isZh ? '还没有加载成员' : 'No members loaded';
  String get groups => isZh ? '家庭 / 好友组' : 'Family / friend groups';
  String get groupName => isZh ? '组名称' : 'Group name';
  String get groupKind => isZh ? '组类型' : 'Group type';
  String get familyGroup => isZh ? '家庭组' : 'Family';
  String get friendsGroup => isZh ? '好友组' : 'Friends';
  String get createGroup => isZh ? '创建组' : 'Create group';
  String get selectGroup => isZh ? '选择组' : 'Select group';
  String get noGroups => isZh ? '还没有家庭组或好友组' : 'No family or friend groups yet';
  String get selectGroupFirst =>
      isZh ? '请先选择家庭组或好友组。' : 'Select a family or friend group first.';
  String get enterGroupName => isZh ? '请输入组名称。' : 'Enter a group name.';
  String get groupInviteEmail => isZh ? '成员邮箱' : 'Member email';
  String get groupInviteCode => isZh ? '组邀请码' : 'Group invite code';
  String get inviteToGroup => isZh ? '邀请到组' : 'Invite to group';
  String get acceptGroupInvite => isZh ? '接受组邀请' : 'Accept group invite';
  String get sharedDevices => isZh ? '共享设备' : 'Shared devices';
  String get shareCurrentDevice =>
      isZh ? '共享当前设备到组' : 'Share current device to group';
  String get noGroupDevices => isZh ? '还没有共享设备' : 'No shared devices';
  String get inviteEmail => isZh ? '邀请邮箱' : 'Invite email';
  String get inviteRole => isZh ? '邀请角色' : 'Invite role';
  String get viewer => isZh ? '查看者' : 'Viewer';
  String get admin => isZh ? '管理员' : 'Admin';
  String get inviteMember => isZh ? '邀请成员' : 'Invite member';
  String get inviteToken => isZh ? '邀请码' : 'Invite token';
  String get acceptInvite => isZh ? '接受邀请' : 'Accept invite';
  String get recentStatus => isZh ? '最近状态' : 'Recent status';
  String get noStatusEvents => isZh ? '暂无状态记录' : 'No status events loaded';
  String get provisionBind => isZh ? '配网与绑定' : 'Provision and bind';
  String get scanDeviceQr => isZh ? '扫描设备二维码' : 'Scan device QR';
  String get bleName => isZh ? 'BLE 名称' : 'BLE name';
  String get softApName => isZh ? 'SoftAP 名称' : 'SoftAP name';
  String get deviceId => isZh ? '设备 ID' : 'Device ID';
  String get transport => isZh ? '传输方式' : 'Transport';
  String get searchBleDevice => isZh ? '搜索 BLE 设备' : 'Search BLE device';
  String get searchSoftApDevice =>
      isZh ? '搜索 SoftAP 设备' : 'Search SoftAP device';
  String get connectSoftApDevice =>
      isZh ? '连接 SoftAP 设备' : 'Connect SoftAP device';
  String get softApHint => isZh
      ? '如果设备热点没有密码，请先到系统 Wi-Fi 设置手动连接该热点，再返回 App 继续。若设备热点有密码，请在下方输入。'
      : 'If the device hotspot has no password, connect to it in system Wi-Fi settings first, then return here. If it has a password, enter it below.';
  String get softApPassword =>
      isZh ? 'SoftAP 热点密码（可选）' : 'SoftAP password (optional)';
  String get softApPasswordHelp => isZh
      ? '留空表示手机已经手动连接到设备热点。'
      : 'Leave empty when the phone is already connected to the device hotspot.';
  String get noServiceUuid => isZh ? '无 Service UUID' : 'No service UUID';
  String get connect => isZh ? '连接' : 'Connect';
  String get wifiNetwork => isZh ? 'Wi-Fi 网络' : 'Wi-Fi network';
  String get wifiPassword => isZh ? 'Wi-Fi 密码' : 'Wi-Fi password';
  String get provisionWifiBind =>
      isZh ? '配网并绑定账号' : 'Provision Wi-Fi and bind account';
  String get cloudAccount => isZh ? '云端账号' : 'Cloud account';
  String get email => isZh ? '邮箱' : 'Email';
  String get password => isZh ? '密码' : 'Password';
  String get login => isZh ? '登录' : 'Login';
  String get register => isZh ? '注册' : 'Register';
  String get logout => isZh ? '退出登录' : 'Logout';
  String get notLoggedIn => isZh ? '未登录' : 'Not logged in';
  String loggedInAs(String email, bool verified) {
    final state = verified
        ? (isZh ? '已验证' : 'verified')
        : (isZh ? '未验证' : 'unverified');
    return isZh ? '已登录：$email（$state）' : 'Logged in as $email ($state)';
  }

  String get emailVerification => isZh ? '邮箱验证' : 'Email verification';
  String get sendVerificationEmail =>
      isZh ? '发送验证邮件' : 'Send verification email';
  String get verificationToken => isZh ? '邮箱验证码' : 'Email code';
  String get confirmVerification => isZh ? '确认验证' : 'Confirm verification';
  String get passwordReset => isZh ? '重置密码' : 'Password reset';
  String get resetEmail => isZh ? '重置邮箱' : 'Reset email';
  String get resetEmailHelp =>
      isZh ? '留空则使用上方邮箱。' : 'Leave empty to use the email above.';
  String get sendResetEmail => isZh ? '发送重置邮件' : 'Send reset email';
  String get resetToken => isZh ? '重置验证码' : 'Reset code';
  String get newPassword => isZh ? '新密码' : 'New password';
  String get resetPassword => isZh ? '重置密码' : 'Reset password';
  String get language => isZh ? '语言' : 'Language';
  String get followSystem => isZh ? '跟随系统' : 'Follow system';
  String get simplifiedChinese => '中文';
  String get english => 'English';
  String get advanced => isZh ? '高级设置' : 'Advanced';
  String get serverBaseUrl => isZh ? '服务器地址' : 'Server base URL';
  String get imageOptions => isZh ? '图片参数' : 'Image options';
  String get direction => isZh ? '方向' : 'Direction';
  String get auto => isZh ? '自动' : 'Auto';
  String get landscape => isZh ? '横向' : 'Landscape';
  String get portrait => isZh ? '竖向' : 'Portrait';
  String get rotation => isZh ? '旋转' : 'Rotation';
  String get rotate0 => '0°';
  String get rotate90 => '90°';
  String get rotate180 => '180°';
  String get rotate270 => '270°';
  String get fitMode => isZh ? '适配方式' : 'Fit mode';
  String get scale => isZh ? '缩放' : 'Scale';
  String get cut => isZh ? '裁切' : 'Cut';
  String get dither => isZh ? '抖动' : 'Dither';
  String get latestImage => isZh ? '最新图片' : 'Latest image';
  String get imageId => isZh ? '图片 ID' : 'Image ID';
  String get size => isZh ? '尺寸' : 'Size';
  String get data => isZh ? '数据' : 'Data';
  String get format => isZh ? '格式' : 'Format';
  String get sha256 => 'SHA-256';
  String get role => isZh ? '角色' : 'role';
  String get version => isZh ? '版本' : 'version';
  String get status => isZh ? '状态' : 'status';
  String get selectWifiFirst =>
      isZh ? '请先选择 Wi-Fi 网络' : 'Select a Wi-Fi network first';
  String get enterEmail => isZh ? '请输入邮箱。' : 'Please enter your email.';
  String get passwordTooShort =>
      isZh ? '密码至少需要 8 位。' : 'Password must be at least 8 characters.';
  String get loginFirst => isZh ? '请先登录' : 'Login first';
  String get scanQrFirst =>
      isZh ? '请先扫描设备二维码' : 'Scan the device QR code first';
  String get selectBindDeviceFirst =>
      isZh ? '请先选择或绑定设备。' : 'Select or bind a device first.';
  String get selectImageFirst =>
      isZh ? '请先选择图片并确认预览。' : 'Choose an image and review the preview first.';
  String get invalidQrPayload => isZh ? '二维码无效' : 'Invalid QR payload';
  String get invalidClaimCodeHelp => isZh
      ? '设备绑定码无效或设备已被绑定。请确认二维码里的 device_id 和 claim_code 来自同一台设备，且服务端使用了正确的 DEVICE_CLAIM_HMAC_SECRET。'
      : 'Device claim code is invalid or the device is already bound. Confirm the QR device_id and claim_code come from the same device and the server uses the correct DEVICE_CLAIM_HMAC_SECRET.';
  String get provisioningPermissionDenied => isZh
      ? '请允许蓝牙、定位或附近设备权限后再搜索设备。'
      : 'Allow Bluetooth, location, or nearby device permissions before searching.';
  String get noProvisioningDevicesFound => isZh
      ? '附近没有找到待配网设备。请确认设备已开机并处于配网模式。'
      : 'No provisioning device found nearby. Make sure the device is powered on and in provisioning mode.';
  String get provisioningSearchTimeout => isZh
      ? '搜索设备超时。请靠近设备后重试。'
      : 'Device search timed out. Move closer to the device and try again.';
  String get searchingDevices =>
      isZh ? '正在搜索附近设备...' : 'Searching nearby devices...';
  String get contentTemporarilyUnavailable => isZh
      ? '内容暂时无法加载，请稍后刷新。'
      : 'Content is temporarily unavailable. Refresh again later.';
  String get previewReady =>
      isZh ? '预览已生成，可以确认后下发。' : 'Preview ready. Review it before sending.';
  String completed(String action) => isZh ? '$action 已完成' : '$action completed';
  String failed(String action, Object error) {
    final detail = _friendlyError(error);
    return isZh ? '$action 失败：$detail' : '$action failed: $detail';
  }

  String _friendlyError(Object error) {
    final raw = '$error';
    final normalized = raw.toLowerCase();
    if (normalized.contains('timeoutexception') ||
        normalized.contains('future not completed') ||
        normalized.contains('timed out')) {
      return isZh ? '网络连接超时，请稍后重试。' : 'Network timed out. Try again later.';
    }
    if (normalized.contains('clientexception') ||
        normalized.contains('connection abort') ||
        normalized.contains('connection reset') ||
        normalized.contains('broken pipe')) {
      return isZh
          ? '网络连接中断，请检查网络后重试。'
          : 'Network connection was interrupted. Check your connection and try again.';
    }
    if (normalized.contains('http 401') ||
        normalized.contains('unauthorized') ||
        normalized.contains('invalid oauth')) {
      return isZh
          ? '登录凭证无效，请重新登录。'
          : 'Sign-in credential is invalid. Sign in again.';
    }
    return raw
        .replaceFirst(RegExp(r'^[A-Za-z]+Exception:\s*'), '')
        .replaceFirst(RegExp(r'^ApiError:\s*'), '');
  }

  String get loginAction => isZh ? '登录' : 'Login';
  String get registerAction => isZh ? '注册' : 'Register';
  String get logoutAction => isZh ? '退出登录' : 'Logout';
  String get refreshDevicesAction => isZh ? '刷新设备' : 'Refresh devices';
  String get requestVerificationAction =>
      isZh ? '发送验证邮件' : 'Request verification email';
  String get confirmEmailAction => isZh ? '确认邮箱' : 'Confirm email';
  String get requestPasswordResetAction =>
      isZh ? '发送重置邮件' : 'Request password reset';
  String get resetPasswordAction => isZh ? '重置密码' : 'Reset password';
  String get renameDeviceAction => isZh ? '重命名设备' : 'Rename device';
  String get unbindDeviceAction => isZh ? '解绑设备' : 'Unbind device';
  String get refreshDeviceDetailAction =>
      isZh ? '刷新设备详情' : 'Refresh device detail';
  String get createInviteAction => isZh ? '创建邀请' : 'Create invite';
  String get acceptInviteAction => isZh ? '接受邀请' : 'Accept invite';
  String get refreshGroupsAction => isZh ? '刷新组' : 'Refresh groups';
  String get createGroupAction => isZh ? '创建组' : 'Create group';
  String get refreshGroupDetailAction =>
      isZh ? '刷新组详情' : 'Refresh group detail';
  String get createGroupInviteAction => isZh ? '邀请组成员' : 'Invite group member';
  String get acceptGroupInviteAction => isZh ? '接受组邀请' : 'Accept group invite';
  String get shareDeviceToGroupAction =>
      isZh ? '共享设备到组' : 'Share device to group';
  String get bleSearchAction => isZh ? '搜索 BLE' : 'BLE search';
  String get bleConnectAction => isZh ? '连接 BLE' : 'BLE connect';
  String get softApSearchAction => isZh ? '搜索 SoftAP' : 'SoftAP search';
  String get softApConnectAction => isZh ? '连接 SoftAP' : 'SoftAP connect';
  String get provisionClaimAction => isZh ? '配网绑定' : 'Provision and claim';
  String get chooseImageAction => isZh ? '选择图片' : 'Choose image';
  String get uploadAssignAction => isZh ? '上传下发' : 'Upload and assign';
  String get generatePreviewAction => isZh ? '生成预览' : 'Generate preview';
  String get confirmSendAction => isZh ? '确认下发' : 'Confirm send';
  String get deleteGroupAction => isZh ? '删除组' : 'Delete group';
  String get savedLoginExpired => isZh ? '已保存登录已过期' : 'Saved login expired';
}

class AppStringsDelegate extends LocalizationsDelegate<AppStrings> {
  const AppStringsDelegate();

  @override
  bool isSupported(Locale locale) => ['en', 'zh'].contains(locale.languageCode);

  @override
  Future<AppStrings> load(Locale locale) async {
    final languageCode = locale.languageCode == 'zh' ? 'zh' : 'en';
    return AppStrings(Locale(languageCode));
  }

  @override
  bool shouldReload(AppStringsDelegate old) => false;
}

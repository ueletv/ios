import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:videoweb_flutter/utils/app_toast.dart';

import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:videoweb_flutter/api/api_parse.dart';
import 'package:videoweb_flutter/api/api_result.dart';
import 'package:videoweb_flutter/api/api_service.dart';
import 'package:videoweb_flutter/api/models/user.dart';
import 'package:videoweb_flutter/pages/login/login_page.dart';
import 'package:videoweb_flutter/pages/profile/favorite_page.dart';
import 'package:videoweb_flutter/pages/profile/watch_history_page.dart';
import 'package:videoweb_flutter/pages/profile/level_page.dart';
import 'package:videoweb_flutter/pages/profile/customer_service_page.dart';
import 'package:videoweb_flutter/pages/profile/promote_page.dart';
import 'package:videoweb_flutter/pages/profile/settings_page.dart';
import 'package:videoweb_flutter/pages/profile/guest_account_setup_page.dart';
import 'package:videoweb_flutter/utils/guest_account_helper.dart';
import 'package:videoweb_flutter/pages/profile/recharge_page.dart';
import 'package:videoweb_flutter/pages/profile/vip_page.dart';
import 'package:videoweb_flutter/services/app_config_cache.dart';
import 'package:videoweb_flutter/services/app_prefs.dart';
import 'package:videoweb_flutter/services/main_tab_controller.dart';
import 'package:videoweb_flutter/services/guest_auth_helper.dart';
import 'package:videoweb_flutter/services/theme_controller.dart';
import 'package:videoweb_flutter/utils/image_url.dart';
import 'package:videoweb_flutter/widgets/user_avatar.dart';
import 'package:videoweb_flutter/theme/app_theme.dart';
import 'package:videoweb_flutter/pages/profile/widgets/profile_promo_backgrounds.dart';
import 'package:videoweb_flutter/pages/profile/widgets/profile_header_background.dart';

/// 个人中心（对应原生 ProfileFragment.kt + fragment_profile.xml）
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> with AutomaticKeepAliveClientMixin {
  final ApiService _api = ApiService();
  UserInfo? _userInfo;
  int _followCount = 0;
  int _favoriteCount = 0;
  bool _isLoading = false;
  bool _autoRegisterTried = false;
  AppPrefs? _prefs;
  bool? _lastLoggedIn;
  String? _lastToken;
  String? _userGuide;

  @override
  bool get wantKeepAlive => true;

  bool get _hasUserGuide => _userGuide != null && _userGuide!.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _loadUserGuide();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _prefs = context.read<AppPrefs>();
      _lastLoggedIn = _prefs!.isLoggedIn;
      _lastToken = _prefs!.token;
      _prefs!.addListener(_onAuthChanged);
    });
    _applyProfileUi();
  }

  @override
  void dispose() {
    _prefs?.removeListener(_onAuthChanged);
    super.dispose();
  }

  void _onAuthChanged() {
    if (!mounted) return;
    final prefs = _prefs ?? context.read<AppPrefs>();
    final loggedIn = prefs.isLoggedIn;
    final token = prefs.token;
    if (_lastLoggedIn == loggedIn && _lastToken == token) return;
    _lastLoggedIn = loggedIn;
    _lastToken = token;
    if (loggedIn) {
      _applyProfileUi(force: true);
    } else {
      setState(() {
        _userInfo = null;
        _followCount = 0;
        _favoriteCount = 0;
      });
    }
  }

  Future<void> _openLogin() async {
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const LoginPage()),
    );
    if (mounted && ok == true) _applyProfileUi(force: true);
  }

  Future<void> _openGuestAccountSetup() async {
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => GuestAccountSetupPage(user: _userInfo)),
    );
    if (mounted && ok == true) _applyProfileUi(force: true);
  }

  Future<void> _loadUserGuide() async {
    final data = await AppConfigCache.fetch();
    final guide = data?['user_guide']?.toString().trim();
    if (!mounted) return;
    setState(() => _userGuide = (guide != null && guide.isNotEmpty) ? guide : null);
  }

  void _showUserGuideDialog(AppColors c) {
    final text = _userGuide?.trim();
    if (text == null || text.isEmpty) return;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.notifications_none_rounded, color: c.accent, size: 22),
            const SizedBox(width: 8),
            Text('用户说明', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: c.textPrimary)),
          ],
        ),
        content: SingleChildScrollView(
          child: Text(text, style: TextStyle(fontSize: 14, height: 1.55, color: c.textSecondary)),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  Widget _buildUserGuideBell(AppColors c) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _showUserGuideDialog(c),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(Icons.notifications_none_rounded, size: 22, color: c.accent),
        ),
      ),
    );
  }

  Future<void> _applyProfileUi({bool force = false}) async {
    if (_isLoading && !force) return;
    await _loadUserGuide();
    final prefs = context.read<AppPrefs>();
    if (!prefs.isLoggedIn) {
      setState(() {
        _userInfo = null;
        _followCount = 0;
        _favoriteCount = 0;
      });
      _tryAutoRegisterOnce();
      return;
    }
    prefs.recordDailyLogin();
    setState(() => _isLoading = true);
    try {
      await _loadUserInfo();
      await _loadCounts();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadUserInfo() async {
    final prefs = context.read<AppPrefs>();
    await ImageUrl.refreshFromConfig(prefs);
    final res = await _api.getUserInfo();
    if (ApiResult.isSuccess(res)) {
      final data = res.data['data'] as Map<String, dynamic>?;
      if (data != null && mounted) {
        final user = UserInfo.fromJson(data);
        prefs.cachedLevelIcon = user.resolvedLevelIcon;
        final username = user.username?.trim();
        if (username != null && username.isNotEmpty) {
          prefs.username = username;
        }
        if (GuestAccountHelper.hasBoundPhone(user)) {
          prefs.phone = user.phone;
        }
        setState(() => _userInfo = user);
      }
    }
  }

  Future<void> _loadCounts() async {
    try {
      final favRes = await _api.getFavoriteList(page: 1, pageSize: 1);
      if (ApiResult.isSuccess(favRes)) {
        final pagination = favRes.data['pagination'];
        if (pagination is Map) {
          _favoriteCount = ApiParse.asInt(pagination['total']) ?? 0;
        }
      }
    } catch (_) {}
    try {
      final followRes = await _api.getStreamerList(type: 'follow', page: 1, pageSize: 1);
      if (ApiResult.isSuccess(followRes)) {
        final pagination = followRes.data['pagination'];
        if (pagination is Map) {
          _followCount = ApiParse.asInt(pagination['total']) ?? 0;
        }
      }
    } catch (_) {}
    if (mounted) setState(() {});
  }

  Future<void> _tryAutoRegisterOnce() async {
    if (_autoRegisterTried) return;
    final prefs = context.read<AppPrefs>();
    if (prefs.isLoggedIn || prefs.autoGuestLoginPaused) return;
    _autoRegisterTried = true;
    final ok = await GuestAuthHelper.ensureToken(prefs);
    if (mounted && ok) _applyProfileUi();
  }

  void _needLoginThen(VoidCallback action) {
    final prefs = context.read<AppPrefs>();
    if (!prefs.isLoggedIn) {
      _showToast('请先登录');
      _openLogin();
      return;
    }
    action();
  }

  void _navigateToPage(Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page)).then((_) => _applyProfileUi());
  }

  void _copyAccount(String account) {
    if (account.isEmpty) return;
    Clipboard.setData(ClipboardData(text: account));
    _showToast('账号已复制');
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    // 设置里切换主题后即时刷新（IndexedStack 子页）
    context.watch<ThemeController>();
    final c = context.appColors;
    final prefs = context.watch<AppPrefs>();
    final hasToken = prefs.isLoggedIn;
    final showProfile = hasToken && _userInfo != null;

    return ColoredBox(
      color: c.pageBg,
      child: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: c.accent,
          onRefresh: _applyProfileUi,
          child: ListView(
            primary: false,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              _buildHeaderCard(c, hasToken, showProfile),
              if (showProfile && GuestAccountHelper.isGuestAccount(_userInfo)) ...[
                const SizedBox(height: 8),
                _buildGuestUpgradeBanner(c),
              ],
              if (showProfile) ...[
                const SizedBox(height: 8),
                _buildStatsRow(c),
              ],
              const SizedBox(height: 4),
              _buildVipRechargeRow(),
              const SizedBox(height: 8),
              _buildInviteBanner(),
              const SizedBox(height: 8),
              _buildFunctionGrid(c, showProfile),
              if (!hasToken) ...[
                const SizedBox(height: 16),
                Center(
                  child: GestureDetector(
                    onTap: _openLogin,
                    child: Text(
                      '点击登录 / 注册',
                      style: TextStyle(color: c.accent, fontSize: 13),
                    ),
                  ),
                ),
              ],
              if (_isLoading && hasToken && !showProfile)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: c.accent)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGuestUpgradeBanner(AppColors c) {
    final isLight = c.pageBg.computeLuminance() > 0.5;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isLight
                ? [c.accent.withOpacity(0.12), c.accent.withOpacity(0.05)]
                : [c.accent.withOpacity(0.22), c.accent.withOpacity(0.08)],
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: c.accent.withOpacity(isLight ? 0.28 : 0.35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.shield_outlined, size: 18, color: c.accent),
                const SizedBox(width: 6),
                Text(
                  '游客账号',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: c.textPrimary),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '设置密码后可用「账号+密码」登录；绑定手机号后还可使用「手机号+密码」登录并换机恢复。',
              style: TextStyle(fontSize: 12, height: 1.45, color: c.textSecondary),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _openGuestAccountSetup,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 42),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('完善账号', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard(AppColors c, bool hasToken, bool showProfile) {
    final user = _userInfo;
    final name = showProfile ? GuestAccountHelper.accountDisplayLabel(user!) : (hasToken ? '加载中...' : '登录');
    final accountCopyLine = showProfile ? GuestAccountHelper.accountCopyLine(user) : '';
    final loginAccount = showProfile ? GuestAccountHelper.loginAccount(user) : '';
    final isVip = user?.isActiveVip == true;
    final levelIcon = user?.resolvedLevelIcon;
    final levelNum = user?.resolvedLevel ?? 0;
    final showLevel = showProfile && (levelNum > 0 || user?.levelInfo != null || (user?.exp ?? 0) > 0);
    final hasLevelIcon = showLevel && levelIcon != null && levelIcon.isNotEmpty;
    final isLight = c.pageBg.computeLuminance() > 0.5;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
      child: Material(
        color: Colors.transparent,
        elevation: isLight ? 2 : 4,
        shadowColor: Colors.black.withOpacity(isLight ? 0.08 : 0.28),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: hasToken ? null : _openLogin,
          child: ProfileHeaderBackground(
            colors: c,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _buildProfileAvatar(c, user, showProfile, hasToken),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: c.textPrimary),
                              ),
                            ),
                            if (hasToken && _hasUserGuide) _buildUserGuideBell(c),
                          ],
                        ),
                        if (showProfile) ...[
                          const SizedBox(height: 5),
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  accountCopyLine,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 12, color: c.textSecondary),
                                ),
                              ),
                              if (loginAccount.isNotEmpty) ...[
                              const SizedBox(width: 6),
                              GestureDetector(
                                onTap: () => _copyAccount(loginAccount),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: c.accentContainer,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '复制',
                                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: c.accent),
                                  ),
                                ),
                              ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 7),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: c.surface,
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(color: c.cardStroke, width: 0.5),
                                ),
                                child: Text(
                                  isVip ? 'VIP会员' : (GuestAccountHelper.isGuestAccount(user) ? '游客' : '正式用户'),
                                  style: TextStyle(fontSize: 10, color: c.textPrimary),
                                ),
                              ),
                              if (isVip) ...[
                                const SizedBox(width: 6),
                                const ProfileVipBadge(),
                              ],
                              if (hasLevelIcon) ...[
                                const SizedBox(width: 4),
                                CachedNetworkImage(
                                  imageUrl: ImageUrl.getLevelIconUrl(levelIcon),
                                  width: 32,
                                  height: 18,
                                  fit: BoxFit.contain,
                                  placeholder: (_, __) => ColoredBox(color: c.chipBg, child: const SizedBox(width: 32, height: 18)),
                                  errorWidget: (_, __, ___) => ProfileLevelBadge(level: '$levelNum'),
                                ),
                              ] else if (showLevel) ...[
                                const SizedBox(width: 4),
                                ProfileLevelBadge(level: '${levelNum > 0 ? levelNum : 1}'),
                              ],
                            ],
                          ),
                          const SizedBox(height: 7),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: c.profileLoginChipBg,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '您已累计登录${math.max(context.read<AppPrefs>().loginDayCount, 1)}天',
                              style: TextStyle(fontSize: 11, color: c.textSecondary),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileAvatar(AppColors c, UserInfo? user, bool showProfile, bool hasToken) {
    if (hasToken && !showProfile) {
      return SizedBox(
        width: 64,
        height: 64,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: c.accent)),
      );
    }
    return UserAvatar(
      rawAvatar: showProfile ? user?.avatar : null,
      size: 64,
      useServerDefault: showProfile,
    );
  }

  Widget _buildStatsRow(AppColors c) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Container(
        decoration: BoxDecoration(
          color: c.profileStatRowBg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: () => _needLoginThen(() => context.read<MainTabController>().switchToLiveFollow()),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('$_followCount', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: c.textPrimary)),
                      const SizedBox(width: 5),
                      Text('关注', style: TextStyle(fontSize: 12, color: c.textSecondary)),
                    ],
                  ),
                ),
              ),
            ),
            Container(width: 1, height: 18, color: c.profileStatDivider),
            Expanded(
              child: InkWell(
                onTap: () => _needLoginThen(() => _navigateToPage(const FavoritePage())),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('$_favoriteCount', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: c.textPrimary)),
                      const SizedBox(width: 5),
                      Text('收藏', style: TextStyle(fontSize: 12, color: c.textSecondary)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVipRechargeRow() {
    final isVip = _userInfo?.isActiveVip == true;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          Expanded(
            child: _PromoNativeCard(
              height: 114,
              overlay: ProfilePromoBackgrounds.vipCardOverlay,
              title: 'VIP 会员',
              subtitle: isVip ? 'VIP 权益已生效' : '您当前未开通 VIP',
              action: '立即开通',
              onTap: () => _needLoginThen(() => _navigateToPage(const VipPage())),
            ),
          ),
          const SizedBox(width: 5),
          Expanded(
            child: _PromoNativeCard(
              height: 114,
              overlay: ProfilePromoBackgrounds.rechargeCardOverlay,
              title: '直播充值',
              subtitle: '直播钱包钻石充值',
              action: '立即充值',
              onTap: () => _needLoginThen(() => _navigateToPage(const RechargePage())),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInviteBanner() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Material(
        color: Colors.transparent,
        elevation: 2,
        shadowColor: Colors.black26,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () => _needLoginThen(() => _navigateToPage(const PromotePage())),
          borderRadius: BorderRadius.circular(16),
          child: ProfilePromoBackgrounds.inviteBannerOverlay(
            child: SizedBox(
              height: 68,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                const Text('分享', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                Container(
                  width: 1,
                  height: 34,
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  color: Colors.white38,
                ),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '邀请好友下载 APP',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '注册即可免费看片',
                        style: TextStyle(color: Colors.white.withOpacity(0.92), fontSize: 13),
                      ),
                    ],
                  ),
                ),
                const Text('›', style: TextStyle(color: Colors.white, fontSize: 24)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFunctionGrid(AppColors c, bool showProfile) {
    final cells = [
      _GridCellData(Icons.history, '观看历史', () => _needLoginThen(() => _navigateToPage(const WatchHistoryPage()))),
      _GridCellData(Icons.favorite_border, '我的收藏', () => _needLoginThen(() => _navigateToPage(const FavoritePage()))),
      _GridCellData(Icons.download_outlined, '缓存列表', () => _showToast('缓存功能开发中')),
      _GridCellData(Icons.star_border, '我的等级', () => _needLoginThen(() => _navigateToPage(const LevelPage()))),
      _GridCellData(Icons.headset_mic_outlined, '联系我们', () => _needLoginThen(() => _navigateToPage(const CustomerServicePage()))),
      _GridCellData(Icons.settings, '设置', () {
        if (!showProfile) {
          _openLogin();
        } else {
          _navigateToPage(const SettingsPage());
        }
      }),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Container(
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: c.cardStroke, width: 0.5),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(child: _gridCell(c, cells[0])),
                _gridDivider(c),
                Expanded(child: _gridCell(c, cells[1])),
                _gridDivider(c),
                Expanded(child: _gridCell(c, cells[2])),
              ],
            ),
            Divider(height: 1, color: c.divider),
            Row(
              children: [
                Expanded(child: _gridCell(c, cells[3])),
                _gridDivider(c),
                Expanded(child: _gridCell(c, cells[4])),
                _gridDivider(c),
                Expanded(child: _gridCell(c, cells[5])),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _gridDivider(AppColors c) => Container(width: 0.5, height: 72, color: c.divider);

  Widget _gridCell(AppColors c, _GridCellData cell) {
    return InkWell(
      onTap: cell.onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(cell.icon, size: 26, color: c.textSecondary),
            const SizedBox(height: 8),
            Text(cell.label, style: TextStyle(fontSize: 12, color: c.textPrimary)),
          ],
        ),
      ),
    );
  }

  void _showToast(String msg) {
    if (!mounted) return;
    AppToast.show(msg, context: context);
  }
}

class _GridCellData {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  _GridCellData(this.icon, this.label, this.onTap);
}

class _PromoNativeCard extends StatelessWidget {
  final double height;
  final Widget Function({required Widget child}) overlay;
  final String title;
  final String subtitle;
  final String action;
  final VoidCallback onTap;

  const _PromoNativeCard({
    required this.height,
    required this.overlay,
    required this.title,
    required this.subtitle,
    required this.action,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      elevation: 2,
      shadowColor: Colors.black26,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          height: height,
          child: overlay(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: const TextStyle(color: Color(0xE6FFFFFF), fontSize: 11)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: ProfilePromoBackgrounds.promoActionBtn(),
                    child: Text(action, style: const TextStyle(color: Colors.white, fontSize: 11)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:videoweb_flutter/utils/app_toast.dart';

import 'package:provider/provider.dart';
import 'package:videoweb_flutter/api/api_result.dart';
import 'package:videoweb_flutter/api/api_service.dart';
import 'package:videoweb_flutter/api/models/user.dart';
import 'package:videoweb_flutter/pages/profile/bind_phone_page.dart';
import 'package:videoweb_flutter/pages/profile/change_password_page.dart';
import 'package:videoweb_flutter/pages/profile/guest_account_setup_page.dart';
import 'package:videoweb_flutter/services/app_prefs.dart';
import 'package:videoweb_flutter/utils/guest_account_helper.dart';
import 'package:videoweb_flutter/services/theme_controller.dart';
import 'package:videoweb_flutter/theme/app_theme.dart';

/// 设置页（对应原生 ProfileSettingsActivity.kt）
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final ApiService _api = ApiService();
  UserInfo? _userInfo;
  bool _userInfoLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    if (!context.read<AppPrefs>().isLoggedIn) {
      if (mounted) setState(() => _userInfoLoaded = true);
      return;
    }
    try {
      final res = await _api.getUserInfo();
      if (!mounted) return;
      if (!ApiResult.isSuccess(res)) {
        setState(() => _userInfoLoaded = true);
        return;
      }
      final data = res.data['data'] as Map<String, dynamic>?;
      if (data == null) {
        setState(() => _userInfoLoaded = true);
        return;
      }
      setState(() {
        _userInfo = UserInfo.fromJson(data);
        _userInfoLoaded = true;
      });
    } catch (_) {
      if (mounted) setState(() => _userInfoLoaded = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final themeCtrl = context.watch<ThemeController>();

    return Scaffold(
      backgroundColor: colors.pageBg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
          children: [
            Row(
              children: [
                IconButton.filledTonal(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
                const SizedBox(width: 12),
                Text(
                  '设置',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: colors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildSectionCard(
              colors: colors,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '主题模式',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    themeCtrl.themeHint,
                    style: TextStyle(fontSize: 12, color: colors.textHint),
                  ),
                  const SizedBox(height: 12),
                  _ThemeSegmentRow(
                    current: themeCtrl.themeMode,
                    onChanged: (mode) {
                      if (mode == themeCtrl.themeMode) return;
                      themeCtrl.setThemeMode(mode);
                      AppToast.show('正在切换主题…', context: context);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Consumer<AppPrefs>(
              builder: (context, prefs, _) {
                if (!prefs.isLoggedIn) return const SizedBox.shrink();
                if (!_userInfoLoaded) {
                  return _buildSectionCard(
                    colors: colors,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 28),
                      child: Center(
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: colors.accent,
                          ),
                        ),
                      ),
                    ),
                  );
                }
                final isGuest = GuestAccountHelper.isGuestAccount(_userInfo);
                final canBindPhone = !GuestAccountHelper.hasBoundPhone(_userInfo);
                return _buildSectionCard(
                  colors: colors,
                  child: Column(
                    children: [
                      if (isGuest) ...[
                        _buildSettingItem(
                          colors: colors,
                          icon: Icons.person_outline,
                          title: '完善账号',
                          subtitle: '设置密码 / 绑定手机号（手机可选）',
                          onTap: () async {
                            final ok = await Navigator.of(context).push<bool>(
                              MaterialPageRoute(builder: (_) => GuestAccountSetupPage(user: _userInfo)),
                            );
                            if (mounted && ok == true) _loadUserInfo();
                          },
                        ),
                        Divider(height: 1, indent: 68, color: colors.divider),
                      ] else ...[
                        _buildSettingItem(
                          colors: colors,
                          icon: Icons.lock_outline,
                          title: '修改密码',
                          subtitle: '修改登录密码',
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const ChangePasswordPage()),
                          ),
                        ),
                        if (canBindPhone) ...[
                          Divider(height: 1, indent: 68, color: colors.divider),
                          _buildSettingItem(
                            colors: colors,
                            icon: Icons.phone_android_outlined,
                            title: '绑定手机号',
                            subtitle: '绑定后可使用手机号登录',
                            onTap: () async {
                              final ok = await Navigator.of(context).push<bool>(
                                MaterialPageRoute(builder: (_) => const BindPhonePage(bindOnly: true)),
                              );
                              if (mounted && ok == true) _loadUserInfo();
                            },
                          ),
                        ],
                        Divider(height: 1, indent: 68, color: colors.divider),
                      ],
                      _buildSettingItem(
                        colors: colors,
                        icon: Icons.delete_outline,
                        title: '清除缓存',
                        subtitle: '清除本地缓存数据',
                        onTap: _showClearCacheDialog,
                      ),
                      Divider(height: 1, indent: 68, color: colors.divider),
                      _buildSettingItem(
                        colors: colors,
                        icon: Icons.info_outline,
                        title: '关于',
                        subtitle: '版本信息',
                        onTap: _showAboutDialog,
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            Consumer<AppPrefs>(
              builder: (context, prefs, _) {
                if (!prefs.isLoggedIn) return const SizedBox.shrink();
                return SizedBox(
                  height: 52,
                  child: FilledButton(
                    onPressed: () => _showLogoutDialog(prefs),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text('退出登录', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingItem({
    required AppColors colors,
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: colors.chipBg,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(icon, color: colors.accent),
      ),
      title: Text(title, style: TextStyle(fontWeight: FontWeight.w700, color: colors.textPrimary)),
      subtitle: subtitle != null ? Text(subtitle, style: TextStyle(color: colors.textSecondary)) : null,
      trailing: Icon(Icons.chevron_right_rounded, color: colors.textHint),
      onTap: onTap,
    );
  }

  Widget _buildSectionCard({required AppColors colors, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.cardStroke),
      ),
      child: child,
    );
  }

  void _showClearCacheDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('清除缓存'),
        content: const Text('确定要清除本地缓存数据吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('取消')),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              AppToast.show('缓存已清除', context: context);
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog(AppPrefs prefs) {
    final isGuest = GuestAccountHelper.isGuestAccount(_userInfo);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('退出登录'),
        content: Text(
          isGuest
              ? '退出后本机仍保留游客账号，再次点「游客登录」可恢复（按本机设备识别，同 WiFi 不会串号）。'
              : '退出后本机仍保留账号信息，下次可自动登录。若要换账号，请点「切换账号」。',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('取消')),
          TextButton(
            onPressed: () {
              prefs.resetForAccountSwitch();
              Navigator.of(ctx).pop();
              Navigator.of(context).pop();
              AppToast.show('已切换账号，下次游客登录将创建新账号', context: context);
            },
            child: const Text('切换账号'),
          ),
          FilledButton.tonal(
            onPressed: () {
              prefs.logoutKeepingAccount();
              Navigator.of(ctx).pop();
              Navigator.of(context).pop();
            },
            style: FilledButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('退出'),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog() {
    showAboutDialog(
      context: context,
      applicationName: '视频直播',
      applicationVersion: '1.0.0',
      children: const [
        Text('视频直播平台，提供丰富的直播和视频内容。'),
        SizedBox(height: 16),
        Text('有问题请联系客服'),
      ],
    );
  }
}

class _ThemeSegmentRow extends StatelessWidget {
  final String current;
  final ValueChanged<String> onChanged;

  const _ThemeSegmentRow({required this.current, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final items = [
      (AppPrefs.themeLight, '浅色'),
      (AppPrefs.themeDark, '深色'),
      (AppPrefs.themeSystem, '跟随系统'),
    ];

    return Container(
      height: 40,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: colors.chipBg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: items.map((item) {
          final selected = current == item.$1;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(item.$1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected ? colors.cardBg : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: selected
                      ? [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 4, offset: const Offset(0, 1))]
                      : null,
                ),
                child: Text(
                  item.$2,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? colors.textPrimary : colors.textSecondary,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

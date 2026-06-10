import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:videoweb_flutter/api/api_result.dart';
import 'package:videoweb_flutter/api/api_service.dart';
import 'package:videoweb_flutter/api/models/user.dart';
import 'package:videoweb_flutter/pages/profile/widgets/profile_subpage_scaffold.dart';
import 'package:videoweb_flutter/services/app_prefs.dart';
import 'package:videoweb_flutter/services/theme_controller.dart';
import 'package:videoweb_flutter/theme/app_theme.dart';
import 'package:videoweb_flutter/utils/image_url.dart';

/// 等级详情页（对应原生 LevelActivity.kt）
class LevelPage extends StatefulWidget {
  const LevelPage({super.key});

  @override
  State<LevelPage> createState() => _LevelPageState();
}

class _LevelPageState extends State<LevelPage> {
  final ApiService _api = ApiService();
  UserInfo? _userInfo;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    final prefs = context.read<AppPrefs>();
    if (!prefs.isLoggedIn) return;
    setState(() => _isLoading = true);
    try {
      await ImageUrl.refreshFromConfig(prefs);
      final res = await _api.getUserInfo();
      if (ApiResult.isSuccess(res)) {
        final data = res.data['data'] as Map<String, dynamic>?;
        if (data != null) {
          final user = UserInfo.fromJson(data);
          prefs.cachedLevelIcon = user.resolvedLevelIcon;
          setState(() => _userInfo = user);
        }
      }
    } catch (_) {}
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    context.watch<ThemeController>();
    final colors = context.appColors;
    return ProfileSubpageScaffold(
      title: '我的等级',
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: colors.accent))
          : _userInfo == null
              ? ProfileEmptyState(icon: Icons.person_outline, message: '请先登录')
              : _buildContent(colors),
    );
  }

  Widget _buildContent(AppColors colors) {
    final user = _userInfo!;
    final info = user.effectiveLevelInfo;
    if (info == null && user.resolvedLevel <= 0 && (user.exp ?? 0) <= 0) {
      return ProfileEmptyState(icon: Icons.star_border, message: '暂无等级数据，送礼物或互动可获得经验');
    }
    final level = info?.level ?? user.resolvedLevel;
    final levelName = (info?.levelName.isNotEmpty == true && info!.levelName != '等级')
        ? info.levelName
        : 'Lv.${level > 0 ? level : 1}';
    final exp = info?.exp ?? user.exp ?? 0;
    final expNeeded = info?.expNeeded ?? user.expNeeded ?? 0;
    final nextLevelExp = info?.nextLevelExp ?? user.nextLevelExp ?? 0;
    final nextLevel = info?.nextLevel ?? user.nextLevel ?? 0;
    final isMax = info?.isMaxLevel ?? user.resolvedIsMaxLevel;
    final progress = (info?.expProgress ?? user.resolvedExpProgress).clamp(0.0, 100.0) / 100;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ProfileThemedCard(
            padding: const EdgeInsets.all(20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _buildLevelIcon(user),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(levelName, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: colors.textPrimary)),
                          const SizedBox(width: 8),
                          Text('Lv.$level', style: TextStyle(fontSize: 14, color: colors.textSecondary)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text('当前经验值：$exp', style: TextStyle(fontSize: 13, color: colors.textSecondary)),
                      if (!isMax) ...[
                        const SizedBox(height: 2),
                        Text('下一级所需：$nextLevelExp 经验', style: TextStyle(fontSize: 13, color: colors.textSecondary)),
                        const SizedBox(height: 2),
                        Text('还需经验值：$expNeeded 经验', style: TextStyle(fontSize: 13, color: colors.textSecondary)),
                      ],
                      if (isMax)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text('已达最高等级', style: TextStyle(color: colors.accent, fontSize: 14, fontWeight: FontWeight.w700)),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (!isMax) ...[
            const SizedBox(height: 14),
            ProfileThemedCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('升级进度', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: colors.textPrimary)),
                      Text('${(progress * 100).round()}%', style: TextStyle(color: colors.accent, fontWeight: FontWeight.w700)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: progress.clamp(0.0, 1.0),
                      backgroundColor: colors.chipBg,
                      valueColor: AlwaysStoppedAnimation(colors.accent),
                      minHeight: 10,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '当前等级：Lv.$level → 下一级：Lv.$nextLevel ($nextLevelExp 经验)',
                    style: TextStyle(color: colors.textSecondary, fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLevelIcon(UserInfo user) {
    final icon = user.resolvedLevelIcon;
    if (icon != null && icon.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: CachedNetworkImage(
          imageUrl: ImageUrl.getLevelIconUrl(icon),
          width: 56,
          height: 56,
          fit: BoxFit.contain,
          placeholder: (_, __) => Container(width: 56, height: 56, color: Colors.black12),
          errorWidget: (_, __, ___) => _fallbackIcon(),
        ),
      );
    }
    return _fallbackIcon();
  }

  Widget _fallbackIcon() {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(8)),
      child: Icon(Icons.star_rounded, size: 32, color: Colors.amber.shade600),
    );
  }
}

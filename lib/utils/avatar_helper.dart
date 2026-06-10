import 'package:videoweb_flutter/services/app_prefs.dart';
import 'package:videoweb_flutter/utils/image_url.dart';

/// 用户头像解析（对应原生 AvatarLoader.kt + ImageUrl.resolveAvatarUrl）
class AvatarHelper {
  AvatarHelper._();

  /// 原生 ic_avatar_placeholder.png
  static const assetPath = 'assets/images/profile/default_avatar.png';

  /// 原生 assets/default_avatar.svg（后台未配置时的兜底）
  static const svgAssetPath = 'assets/images/profile/default_avatar.svg';

  static bool isGenericDefaultAvatar(String? path) {
    if (path == null || path.trim().isEmpty) return false;
    final p = path.trim().toLowerCase().split('?').first;
    return p.endsWith('.svg') ||
        p.contains('default-avatar') ||
        p.contains('default_avatar') ||
        p.contains('placeholder') ||
        p.endsWith('/default.png');
  }

  static bool isUnsupportedAvatarUrl(String? url) {
    if (url == null || url.trim().isEmpty) return true;
    final path = url.split('?').first.trim().toLowerCase();
    return path.endsWith('.svg');
  }

  /// 解析可加载的网络头像；无有效头像时返回空字符串（应显示本地默认图）
  static String resolveUrl(String? raw, AppPrefs prefs) {
    if (isGenericDefaultAvatar(raw)) return '';
    final fromUser = ImageUrl.getImageUrl(raw);
    if (fromUser.isEmpty || isUnsupportedAvatarUrl(fromUser)) return '';
    final serverDefault = ImageUrl.getImageUrl(prefs.defaultAvatarUrl);
    if (serverDefault.isNotEmpty && fromUser == serverDefault) return '';
    return fromUser;
  }

  /// 用户头像：优先用户字段，否则后台 default_avatar（对齐原生 resolveAvatarUrl）
  static String resolveAvatarUrl(String? raw, AppPrefs prefs) {
    final fromUser = ImageUrl.getImageUrl(raw);
    if (fromUser.isNotEmpty && !isUnsupportedAvatarUrl(fromUser)) return fromUser;
    final fallback = ImageUrl.getImageUrl(prefs.defaultAvatarUrl);
    if (fallback.isNotEmpty && !isUnsupportedAvatarUrl(fallback)) return fallback;
    return '';
  }
}

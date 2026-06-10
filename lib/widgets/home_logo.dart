import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:videoweb_flutter/services/app_config_cache.dart';
import 'package:videoweb_flutter/utils/image_url.dart';

/// 后台配置的站点 Logo（首页 / 登录页共用）
class HomeLogo extends StatelessWidget {
  final String? logoUrl;
  final double maxHeight;
  final double maxWidth;
  final BorderRadius borderRadius;

  const HomeLogo({
    super.key,
    this.logoUrl,
    this.maxHeight = 40,
    this.maxWidth = 120,
    this.borderRadius = const BorderRadius.all(Radius.circular(6)),
  });

  static String? logoFromConfig(Map<String, dynamic>? config) {
    if (config == null) return null;
    for (final key in const [
      'site_logo',
      'home_logo',
      'app_logo',
      'logo',
      'web_logo',
      'mobile_logo',
    ]) {
      final value = config[key];
      if (value is String && value.trim().isNotEmpty) return value.trim();
    }
    return null;
  }

  static Future<String?> fetchLogoUrl() async {
    final config = await AppConfigCache.fetch();
    return logoFromConfig(config);
  }

  @override
  Widget build(BuildContext context) {
    final url = logoUrl;
    if (url == null || url.isEmpty) return const SizedBox.shrink();
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight, maxWidth: maxWidth),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: CachedNetworkImage(
          imageUrl: ImageUrl.getImageUrl(url),
          fit: BoxFit.contain,
          placeholder: (_, __) => SizedBox(width: maxHeight, height: maxHeight),
          errorWidget: (_, __, ___) => const SizedBox.shrink(),
        ),
      ),
    );
  }
}

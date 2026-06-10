import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:videoweb_flutter/services/app_prefs.dart';
import 'package:videoweb_flutter/utils/avatar_helper.dart';

/// 圆形用户头像（本地默认图对齐原生 ic_avatar_placeholder）
class UserAvatar extends StatelessWidget {
  final String? rawAvatar;
  final double size;
  final bool useServerDefault;
  final BoxFit fit;

  const UserAvatar({
    super.key,
    this.rawAvatar,
    this.size = 40,
    this.useServerDefault = false,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    final prefs = context.read<AppPrefs>();
    final url = useServerDefault
        ? AvatarHelper.resolveAvatarUrl(rawAvatar, prefs)
        : AvatarHelper.resolveUrl(rawAvatar, prefs);

    Widget image;
    if (url.isEmpty) {
      image = Image.asset(
        AvatarHelper.assetPath,
        width: size,
        height: size,
        fit: fit,
      );
    } else {
      image = CachedNetworkImage(
        imageUrl: url,
        width: size,
        height: size,
        fit: fit,
        placeholder: (_, __) => Image.asset(
          AvatarHelper.assetPath,
          width: size,
          height: size,
          fit: fit,
        ),
        errorWidget: (_, __, ___) => Image.asset(
          AvatarHelper.assetPath,
          width: size,
          height: size,
          fit: fit,
        ),
      );
    }

    return ClipOval(
      child: SizedBox(width: size, height: size, child: image),
    );
  }
}

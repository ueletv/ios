import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// 抖音短视频互动图标（SVG 来自原生 ic_hot_*.xml）
abstract final class HotDouyinIcons {
  static const likeActive = Color(0xFFFE2C55);
  static const favoriteActive = Color(0xFFFACE15);

  static const _like = 'assets/images/hot/ic_hot_like.svg';
  static const _comment = 'assets/images/hot/ic_hot_comment.svg';
  static const _star = 'assets/images/hot/ic_hot_star.svg';
  static const _share = 'assets/images/hot/ic_hot_share.svg';
  static const _play = 'assets/images/hot/ic_hot_play.svg';

  static Widget like({required bool active, double size = 36}) {
    return _tintedSvg(
      _like,
      size: size,
      color: active ? likeActive : Colors.white,
    );
  }

  static Widget comment({double size = 36}) {
    return SvgPicture.asset(_comment, width: size, height: size);
  }

  static Widget favorite({required bool active, double size = 36}) {
    return _tintedSvg(
      _star,
      size: size,
      color: active ? favoriteActive : Colors.white,
    );
  }

  static Widget share({double size = 36}) {
    return _tintedSvg(_share, size: size, color: Colors.white);
  }

  static Widget play({double size = 48, Color color = Colors.white}) {
    return _tintedSvg(_play, size: size, color: color);
  }

  static Widget _tintedSvg(
    String asset, {
    required double size,
    required Color color,
  }) {
    return SvgPicture.asset(
      asset,
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:videoweb_flutter/utils/image_url.dart';

/// Banner UI 工具（对应 BannerUi.kt）
class BannerUi {
  /// 构建 Banner 图片 widget
  static Widget buildBannerImage(String? imageUrl, {double height = 180}) {
    final url = ImageUrl.getImageUrl(imageUrl);
    if (url.isEmpty) {
      return Container(
        height: height,
        color: Colors.grey[200],
        child: const Center(child: Icon(Icons.image, color: Colors.grey)),
      );
    }
    return CachedNetworkImage(
      imageUrl: url,
      height: height,
      width: double.infinity,
      fit: BoxFit.cover,
      placeholder: (_, __) => Container(
        height: height,
        color: Colors.grey[200],
      ),
      errorWidget: (_, __, ___) => Container(
        height: height,
        color: Colors.grey[300],
        child: const Icon(Icons.broken_image, color: Colors.grey),
      ),
    );
  }

  /// 创建 Banner 指示器圆点
  static Widget buildIndicator(int currentIndex, int itemCount, {Color activeColor = Colors.purple}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(itemCount, (index) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 2),
          width: currentIndex == index ? 8 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: currentIndex == index ? activeColor : Colors.white38,
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }
}

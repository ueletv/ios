import 'package:videoweb_flutter/api/models/gift.dart';

/// 礼物 SVGA 工具（对应 GiftSvgaUtil.kt）
class GiftSvgaUtil {
  static bool isSvgaUrl(String? url) {
    if (url == null || url.trim().isEmpty) return false;
    final path = url.split('?').first.toLowerCase();
    return path.endsWith('.svga');
  }

  static String resolveAnimationUrl(Map<String, dynamic> msg) {
    final image = (msg['gift_image'] ?? '').toString().trim();
    if (isSvgaUrl(image)) return image;
    final icon = (msg['gift_icon'] ?? '').toString().trim();
    if (isSvgaUrl(icon)) return icon;
    return image.isEmpty ? icon : image;
  }

  static String resolveGiftPanelPreview(Gift gift) {
    final image = gift.image?.trim() ?? '';
    final icon = gift.icon?.trim() ?? '';
    if (isSvgaUrl(image)) return icon;
    return image.isEmpty ? icon : image;
  }

  /// 聊天/飘条用小图：SVGA 用 gift_preview，普通礼物用 preview/icon/image
  static String resolveChatPreviewIcon(Map<String, dynamic> msg) {
    final image = (msg['gift_image'] ?? '').toString().trim();
    final preview = (msg['gift_preview'] ?? '').toString().trim();
    if (isSvgaUrl(image)) return preview;
    final icon = (msg['gift_icon'] ?? '').toString().trim();
    return preview.isNotEmpty ? preview : (image.isNotEmpty ? icon : image);
  }

  static String resolveSendAnimationUrl(Gift gift) {
    final image = gift.image?.trim() ?? '';
    final icon = gift.icon?.trim() ?? '';
    if (isSvgaUrl(image)) return image;
    if (isSvgaUrl(icon)) return icon;
    return image.isEmpty ? icon : image;
  }
}

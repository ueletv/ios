import 'package:videoweb_flutter/api/api_client.dart';

/// 视频互动工具（对应 VideoInteractHelper.kt）
class VideoInteractHelper {
  static bool isTruthy(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is num) return value.toInt() != 0;
    if (value is String) {
      return value == '1' || value.toLowerCase() == 'true';
    }
    return false;
  }

  static String formatCount(int? count) {
    final n = count ?? 0;
    if (n >= 10000) {
      final w = (n / 10000 * 10).round() / 10;
      return '${w.toStringAsFixed(w == w.roundToDouble() ? 0 : 1)}w';
    }
    if (n >= 1000) {
      final k = (n / 1000 * 10).round() / 10;
      return '${k.toStringAsFixed(k == k.roundToDouble() ? 0 : 1)}k';
    }
    return n.toString();
  }

  static bool? jsonBool(Map<String, dynamic>? obj, List<String> keys) {
    if (obj == null) return null;
    for (final key in keys) {
      if (!obj.containsKey(key)) continue;
      final value = obj[key];
      if (value == null) continue;
      if (value is bool) return value;
      if (value is num) return value.toInt() != 0;
      if (value is String) return isTruthy(value);
    }
    return null;
  }

  static int? jsonInt(Map<String, dynamic>? obj, List<String> keys) {
    if (obj == null) return null;
    for (final key in keys) {
      if (!obj.containsKey(key)) continue;
      final value = obj[key];
      if (value == null) continue;
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value);
    }
    return null;
  }

  static bool? stateFromMessage(String? message) {
    if (message == null || message.isEmpty) return null;
    if (message.contains('取消') && message.contains('点赞')) return false;
    if (message.contains('点赞成功')) return true;
    if (message.contains('收藏成功') && !message.contains('取消')) return true;
    if (message.contains('取消') && message.contains('收藏')) return false;
    return null;
  }

  static Map<String, dynamic>? parseToggleData(dynamic data) {
    if (data == null) return null;
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return null;
  }

  /// 短视频分享链接（对齐原生 buildHotShareUrl）
  static String buildHotShareUrl(String videoId) {
    final origin = ApiClient.baseUrl
        .trim()
        .replaceAll(RegExp(r'/+$'), '')
        .replaceAll(RegExp(r'/index\.php/?$'), '');
    return '$origin/home/video/$videoId?from=hot';
  }
}

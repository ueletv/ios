import 'package:videoweb_flutter/api/models/video.dart';

/// 视频 URL 解析工具（对应 VideoUrl.kt）
class VideoUrl {
  /// 获取全部可尝试的播放地址（对应 getAllPlayUrls）
  static List<String> getAllPlayUrls(Video? video) {
    if (video == null) return [];
    final urls = <String>[];
    final primary = video.resolvedPlayUrl;
    if (primary != null && primary.isNotEmpty) urls.add(primary);
    final vod = video.vodPlayUrl;
    if (vod is List) {
      for (final item in vod) {
        if (item is Map) {
          final u = item['url']?.toString() ?? '';
          if (u.isNotEmpty && !urls.contains(u)) urls.add(u);
        } else if (item is String && item.isNotEmpty && !urls.contains(item)) {
          urls.add(item);
        }
      }
    } else if (vod is String && vod.isNotEmpty && !urls.contains(vod)) {
      urls.add(vod);
    }
    return urls;
  }

  static bool isPlayable(Video? video) => getAllPlayUrls(video).isNotEmpty;
  /// 从视频对象获取播放地址
  /// 优先取直接 url，其次从 vod_play_url 数组取第一个
  static String getPlayUrl(Map<String, dynamic> video) {
    // 直接 url 字段
    final url = video['url'] as String?;
    if (url != null && url.isNotEmpty) return url;

    // vod_play_url 可能是字符串或数组
    final vodPlayUrl = video['vod_play_url'];
    if (vodPlayUrl is List && vodPlayUrl.isNotEmpty) {
      final first = vodPlayUrl[0];
      if (first is Map) {
        final u = first['url'] as String?;
        if (u != null && u.isNotEmpty) return u;
      }
      if (first is String) return first;
    }
    if (vodPlayUrl is String && vodPlayUrl.isNotEmpty) {
      return vodPlayUrl;
    }

    return '';
  }

  /// 判断是否为直播流地址（m3u8 / flv 等）
  static bool isLiveStream(String url) {
    final lower = url.toLowerCase();
    return lower.endsWith('.m3u8') ||
        lower.endsWith('.flv') ||
        lower.endsWith('.rtmp') ||
        lower.contains('live') ||
        lower.contains('stream');
  }
}

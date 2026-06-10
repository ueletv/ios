import 'package:videoweb_flutter/api/models/video.dart';

/// 视频日期格式化（对应原生 VideoDateUtils.kt / Vue VideoCard.getVideoDate）
class VideoDateUtils {
  /// 返回 yyyy-MM-dd，无日期时返回空字符串
  static String formatVideoDate(Video? video) {
    if (video == null) return '';
    final raw = (video.createdAt?.trim().isNotEmpty == true
            ? video.createdAt!.trim()
            : video.updatedAt?.trim() ?? '')
        .trim();
    if (raw.isEmpty) return '';

    if (RegExp(r'^\d+$').hasMatch(raw)) {
      final ts = int.tryParse(raw);
      if (ts == null) return '';
      final millis = ts < 1000000000000 ? ts * 1000 : ts;
      final dt = DateTime.fromMillisecondsSinceEpoch(millis);
      return _formatDate(dt);
    }

    final dateMatch = RegExp(r'^(\d{4}-\d{2}-\d{2})').firstMatch(raw);
    if (dateMatch != null) return dateMatch.group(1)!;

    final parsed = DateTime.tryParse(raw);
    if (parsed != null) return _formatDate(parsed.toLocal());

    return '';
  }

  static String _formatDate(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}

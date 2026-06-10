/// 评论时间工具（对应 CommentTimeUtil.kt）
class CommentTimeUtil {
  /// 格式化评论时间
  /// 规则：
  /// - 1分钟内：刚刚
  /// - 1小时内：X分钟前
  /// - 24小时内：X小时前
  /// - 7天内：X天前
  /// - 超过7天：显示日期
  static String format(String? createdAt) {
    if (createdAt == null || createdAt.isEmpty) return '';

    final date = _parseDateTime(createdAt);
    if (date == null) return createdAt;

    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.isNegative) return '刚刚';

    if (diff.inSeconds < 60) return '刚刚';
    if (diff.inMinutes < 60) return '${diff.inMinutes}分钟前';
    if (diff.inHours < 24) return '${diff.inHours}小时前';
    if (diff.inDays < 7) return '${diff.inDays}天前';

    // 超过7天显示日期
    return '${date.month}-${date.day}';
  }

  /// 完整日期格式
  static String fullDate(String? createdAt) {
    if (createdAt == null || createdAt.isEmpty) return '';
    final date = _parseDateTime(createdAt);
    if (date == null) return createdAt;
    return '${date.year}-${_pad(date.month)}-${_pad(date.day)} ${_pad(date.hour)}:${_pad(date.minute)}';
  }

  static DateTime? _parseDateTime(String str) {
    try {
      return DateTime.tryParse(str);
    } catch (_) {
      return null;
    }
  }

  static String _pad(int n) => n.toString().padLeft(2, '0');
}

/// 评论计数工具（对应 CommentCountHelper.kt）
class CommentCountHelper {
  /// 格式化评论数
  static String format(int? count) {
    if (count == null || count <= 0) return '';
    if (count < 10000) return count.toString();
    return '${(count / 10000).toStringAsFixed(1)}w';
  }
}

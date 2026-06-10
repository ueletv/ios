/// 直播间 Socket 消息解析（对应 LiveSocket.kt）
class LiveMessageParser {
  static String _userLevelIcon(Map<String, dynamic> obj) {
    final primary = _str(obj['user_level_icon']);
    if (primary.isNotEmpty) return primary;
    return _str(obj['level_icon']);
  }

  static Map<String, dynamic> parseMessage(Map<String, dynamic> obj) {
    final username = _str(obj['username'], '用户');
    final content = _str(obj['content']);
    final isBarrage = _int(obj['is_barrage']) == 1;
    final giftName = _str(obj['gift_name']).isEmpty ? null : _str(obj['gift_name']);
    final isGift = _int(obj['is_gift']) == 1 || obj['is_gift'] == true || content.contains('送出了');
    final giftImage = _str(obj['gift_image']).trim();
    final giftPreview = _str(obj['gift_preview']).trim().isEmpty
        ? _str(obj['gift_icon']).trim()
        : _str(obj['gift_preview']).trim();
    final giftIconChat = giftImage.toLowerCase().endsWith('.svga')
        ? giftPreview
        : (giftPreview.isEmpty ? giftImage : giftPreview);
    final isOfficial = obj['is_official'] == true || obj['isOfficial'] == true;
    final isSystem = content.contains('进入了直播间') ||
        content.contains('关注了') ||
        content.contains('升级到') ||
        obj['level_up'] == true;

    String displayText;
    if (isGift && giftName != null) {
      displayText = '$username 送出 $giftName';
    } else if (isGift) {
      displayText = username.isNotEmpty ? '$username: $content' : content;
    } else if (content.contains('我进入了直播间')) {
      displayText = '我进入了直播间';
    } else if (content.contains('进入了直播间')) {
      displayText = '$username 进入了直播间';
    } else if (content.contains('关注了')) {
      displayText = content;
    } else if (isSystem) {
      displayText = content;
    } else if (username.isNotEmpty) {
      displayText = '$username: $content';
    } else {
      displayText = content;
    }

    return {
      'id': obj['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      'username': username,
      'content': content,
      'display_text': displayText,
      'is_barrage': isBarrage,
      'is_gift': isGift,
      'is_system_message': isSystem,
      'is_official': isOfficial,
      'user_id': _long(obj['user_id'] ?? obj['userId']),
      'user_level_icon': _userLevelIcon(obj),
      'gift_name': giftName ?? '',
      'gift_count': _int(obj['gift_count'], fallback: 1),
      'gift_icon': giftIconChat,
      'gift_image': giftImage,
      'gift_preview': giftPreview,
      'display_duration': _int(obj['display_duration'], fallback: 4).clamp(1, 30),
      'opencode': _str(obj['opencode']),
      'biaoshi': _str(obj['biaoshi']),
      'is_lottery_bet': false,
      'is_lottery_win': false,
    };
  }

  static Map<String, dynamic> parseJoinMessage(Map<String, dynamic> data, {required bool isSelf}) {
    final username = _str(data['username'], '游客');
    final content = isSelf ? '我进入了直播间' : '$username 进入了直播间';
    final displayText = isSelf ? '$username: 我进入了直播间' : '$username: 进入了直播间';
    return {
      'id': 'join_${DateTime.now().millisecondsSinceEpoch}_${username.hashCode}',
      'username': username,
      'content': content,
      'display_text': displayText,
      'is_barrage': false,
      'is_gift': false,
      'is_system_message': true,
      'is_official': false,
      'user_id': _long(data['user_id'] ?? data['userId']),
      'user_level_icon': _userLevelIcon(data),
    };
  }

  static Map<String, dynamic> parseFollowMessage(Map<String, dynamic> data, {required bool isSelf}) {
    final username = _str(data['username'], '游客');
    final content = _str(data['content']).isEmpty
        ? (isSelf ? '我关注了' : '$username 关注了')
        : _str(data['content']);
    return {
      'id': data['id'] ?? 'follow_${DateTime.now().millisecondsSinceEpoch}',
      'username': username,
      'content': content,
      'display_text': content,
      'is_barrage': false,
      'is_gift': false,
      'is_system_message': true,
      'user_id': _long(data['user_id'] ?? data['userId']),
      'user_level_icon': _userLevelIcon(data),
    };
  }

  static Map<String, dynamic> parseGiftEvent(Map<String, dynamic> obj) {
    final username = _str(obj['username'], '用户');
    final giftName = _str(obj['gift_name'], '礼物');
    final count = _int(obj['count'], fallback: 1).clamp(1, 9999);
    final giftImage = _str(obj['gift_image']).trim();
    final giftPreview = _str(obj['gift_preview']).trim();
    final giftIconRaw = _str(obj['gift_icon']).trim();
    final animUrl = giftImage.isEmpty ? giftIconRaw : giftImage;
    final preview = giftPreview.isEmpty
        ? (animUrl.toLowerCase().endsWith('.svga') ? '' : giftIconRaw)
        : giftPreview;
    final giftIconChat = animUrl.toLowerCase().endsWith('.svga')
        ? preview
        : (preview.isEmpty ? animUrl : preview).isEmpty
            ? giftIconRaw
            : (preview.isEmpty ? animUrl : preview);

    return {
      'id': 'gift_${DateTime.now().millisecondsSinceEpoch}',
      'username': username,
      'content': '送出了 $giftName x$count',
      'display_text': '$username 送出 $giftName',
      'is_barrage': false,
      'is_gift': true,
      'is_system_message': false,
      'user_id': _long(obj['user_id'] ?? obj['userId']),
      'user_level_icon': _userLevelIcon(obj),
      'gift_name': giftName,
      'gift_count': count,
      'gift_icon': giftIconChat,
      'gift_image': animUrl,
      'gift_preview': preview,
      'display_duration': _int(obj['display_duration'], fallback: 4).clamp(1, 30),
    };
  }

  static Map<String, dynamic> parseLotteryMessage(Map<String, dynamic> obj, {required bool isWin}) {
    final base = parseMessage(obj);
    base['is_lottery_bet'] = !isWin;
    base['is_lottery_win'] = isWin;
    if (isWin) {
      base['win_amount'] = obj['win_amount'];
      base['lottery_name'] = obj['lottery_name'];
    } else {
      base['bet_amount'] = obj['bet_amount'];
      base['lottery_name'] = obj['lottery_name'];
    }
    return base;
  }

  static String _str(dynamic v, [String fallback = '']) {
    if (v == null) return fallback;
    final s = v.toString().trim();
    return s.isEmpty ? fallback : s;
  }

  static int _int(dynamic v, {int fallback = 0}) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? fallback;
  }

  static int? _long(dynamic v) {
    if (v == null) return null;
    if (v is int) return v >= 0 ? v : null;
    if (v is num) {
      final n = v.toInt();
      return n >= 0 ? n : null;
    }
    return int.tryParse(v.toString());
  }
}

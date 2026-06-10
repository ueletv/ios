import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:videoweb_flutter/pages/live/live_room_colors.dart';
import 'package:videoweb_flutter/utils/image_url.dart';

/// 直播间消息气泡（对应 item_barrage.xml + BarrageAdapter.kt，背景随文字宽度收缩）
class LiveMessageBubble extends StatelessWidget {
  final Map<String, dynamic> msg;
  final int? currentUserId;
  final double maxWidth;

  const LiveMessageBubble({
    super.key,
    required this.msg,
    this.currentUserId,
    required this.maxWidth,
  });

  bool _bool(dynamic v) => v == true || v == 1;

  String _str(dynamic v) => v?.toString() ?? '';

  double _amount(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse(_str(v)) ?? 0;
  }

  bool get _isGift =>
      _bool(msg['is_gift']) || msg['type'] == 'gift' || _bool(msg['isGift']);

  bool get _isOfficial => _bool(msg['is_official']) || _bool(msg['isOfficial']);

  bool get _isSystem =>
      _bool(msg['is_system_message']) || _bool(msg['isSystemMessage']);

  bool get _isBarrage => _bool(msg['is_barrage']) || _bool(msg['isBarrage']);

  bool get _isLotteryWin =>
      _bool(msg['is_lottery_win']) || _bool(msg['isLotteryWin']);

  bool get _isLotteryBet =>
      _bool(msg['is_lottery_bet']) || _bool(msg['isLotteryBet']);

  int? get _msgUserId {
    final v = msg['user_id'] ?? msg['userId'];
    if (v is int) return v;
    return int.tryParse(_str(v));
  }

  String get _userLevelIcon => _str(msg['user_level_icon'] ?? msg['level_icon']).trim();

  bool get _showLevelIcon => _userLevelIcon.isNotEmpty && !_isOfficial;

  bool get _isCurrentUser =>
      currentUserId != null && _msgUserId != null && currentUserId == _msgUserId;

  String get _username => _str(msg['username'] ?? msg['nickname']).trim();

  String get _content => _str(msg['content']);

  String get _displayText =>
      _str(msg['display_text'] ?? msg['displayText']).trim().isNotEmpty
          ? _str(msg['display_text'] ?? msg['displayText']).trim()
          : _content;

  bool _isEnterRoom() {
    final blob = '$_displayText\n$_content';
    return blob.contains('进入了直播间') || blob.contains('进入直播间');
  }

  @override
  Widget build(BuildContext context) {
    final bg = _isBarrage ? LiveRoomColors.msgBgBarrage : LiveRoomColors.msgBgDefault;

    // 对齐原生 wrap_content + Vue align-self:flex-start：短消息背景随内容，长消息才换行撑满 maxWidth
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Align(
        alignment: Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_showLevelIcon) ...[
                    Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: _buildLevelIcon(),
                    ),
                    const SizedBox(width: 4),
                  ],
                  Flexible(
                    fit: FlexFit.loose,
                    child: _isGift ? _buildGiftRow() : _buildTextRow(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLevelIcon() {
    final url = ImageUrl.getLevelIconUrl(_userLevelIcon);
    if (url.isEmpty) return const SizedBox(width: 18, height: 18);
    return CachedNetworkImage(
      imageUrl: url,
      width: 18,
      height: 18,
      fit: BoxFit.contain,
      placeholder: (_, __) => const SizedBox(width: 18, height: 18),
      errorWidget: (_, __, ___) => const SizedBox(width: 18, height: 18),
    );
  }

  Widget _buildTextRow() {
    return Text.rich(
      TextSpan(children: _buildSpans()),
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(fontSize: 13, height: 1.35, letterSpacing: 0.2),
    );
  }

  Widget _buildGiftRow() {
    final name = _username.isEmpty ? '用户' : _username;
    final giftName = _str(msg['gift_name'] ?? msg['giftName']).trim();
    final giftLabel = giftName.isEmpty ? '礼物' : giftName;
    final count = (_amount(msg['gift_count'] ?? msg['giftCount']).toInt()).clamp(1, 9999);
    final icon = _str(msg['gift_icon'] ?? msg['giftIcon'] ?? msg['gift_image'] ?? msg['giftImage']);

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Flexible(
          fit: FlexFit.loose,
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(text: name, style: const TextStyle(color: LiveRoomColors.usernameSystem, fontSize: 13)),
                const TextSpan(text: ' 送出 ', style: TextStyle(color: LiveRoomColors.giftAction, fontSize: 13)),
                TextSpan(text: giftLabel, style: const TextStyle(color: LiveRoomColors.giftAction, fontSize: 13)),
              ],
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (icon.isNotEmpty) ...[
          const SizedBox(width: 4),
          if (icon.startsWith('http') || icon.startsWith('/'))
            CachedNetworkImage(
              imageUrl: ImageUrl.getImageUrl(icon),
              width: 24,
              height: 24,
              fit: BoxFit.contain,
              errorWidget: (_, __, ___) => const Text('🎁', style: TextStyle(fontSize: 20)),
            )
          else
            Text(icon.length <= 4 ? icon : '🎁', style: const TextStyle(fontSize: 20)),
        ],
        const SizedBox(width: 4),
        Text(
          'x$count',
          style: const TextStyle(
            color: LiveRoomColors.giftCount,
            fontSize: 13,
            fontStyle: FontStyle.italic,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  List<InlineSpan> _buildSpans() {
    if (_isOfficial) {
      return [_span(_content.isNotEmpty ? _content : _displayText, LiveRoomColors.official)];
    }
    if (_isEnterRoom()) {
      return _usernameContentSpans(_displayText);
    }
    if (_isLotteryWin) {
      final youOrName = _isCurrentUser ? '你' : (_username.isEmpty ? '用户' : _username);
      final lottery = _str(msg['lottery_name'] ?? msg['lotteryName']).ifEmpty('彩票');
      final amount = _amount(msg['win_amount'] ?? msg['winAmount']).toStringAsFixed(2);
      return [
        _span('恭喜 ', LiveRoomColors.contentWhite),
        _span(youOrName, _isCurrentUser ? LiveRoomColors.winBetMeRed : LiveRoomColors.usernameSystem),
        _span(' 在 ', LiveRoomColors.contentWhite),
        _span(lottery, LiveRoomColors.amountGold),
        _span(' 中了 ', LiveRoomColors.contentWhite),
        _span(amount, LiveRoomColors.amountGold),
        _span(' 元', LiveRoomColors.contentWhite),
      ];
    }
    if (_isLotteryBet) {
      final meOrName = _isCurrentUser ? '我' : (_username.isEmpty ? '用户' : _username);
      final lottery = _str(msg['lottery_name'] ?? msg['lotteryName']).ifEmpty('彩票');
      final amount = _amount(msg['bet_amount'] ?? msg['betAmount']).toStringAsFixed(2);
      return [
        _span(meOrName, _isCurrentUser ? LiveRoomColors.winBetMeRed : LiveRoomColors.usernameSystem),
        _span(' 在 ', LiveRoomColors.contentWhite),
        _span(lottery, LiveRoomColors.amountGold),
        _span(' 中，已成功下注了 ', LiveRoomColors.contentWhite),
        _span(amount, LiveRoomColors.amountGold),
        _span(' 元', LiveRoomColors.contentWhite),
      ];
    }
    if (_displayText.contains('升级到') || _content.contains('升级到') || msg['level_up'] == true) {
      return [_span(_displayText.isNotEmpty ? _displayText : _content, LiveRoomColors.levelUpBlue)];
    }
    if (_isSystem) {
      return [_span(_displayText, LiveRoomColors.usernameSystem)];
    }
    return _usernameContentSpans(_displayText);
  }

  List<InlineSpan> _usernameContentSpans(String text) {
    final colon = text.indexOf(':');
    final colonCn = text.indexOf('：');
    final idx = colon > 0 ? colon : (colonCn > 0 ? colonCn : -1);
    if (idx > 0) {
      return [
        _span(text.substring(0, idx), LiveRoomColors.usernameSystem),
        _span(text.substring(idx), LiveRoomColors.contentWhite),
      ];
    }
    if (_username.isNotEmpty && text.startsWith(_username)) {
      return [
        _span(_username, LiveRoomColors.usernameSystem),
        _span(text.substring(_username.length), LiveRoomColors.contentWhite),
      ];
    }
    return [_span(text, LiveRoomColors.contentWhite)];
  }

  TextSpan _span(String text, Color color) =>
      TextSpan(text: text, style: TextStyle(color: color, fontSize: 13, height: 1.35));
}

extension _IfEmpty on String {
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
}

import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:videoweb_flutter/pages/live/gift_svga_util.dart';
import 'package:videoweb_flutter/pages/live/live_room_colors.dart';
import 'package:videoweb_flutter/utils/avatar_helper.dart';
import 'package:videoweb_flutter/utils/image_url.dart';

/// 礼物飘条（对应 LiveGiftBannerController.kt）：弹幕列表上方，同用户同礼物连送 x1→x2→x3
class LiveGiftBannerOverlay extends StatefulWidget {
  final int? currentUserId;

  const LiveGiftBannerOverlay({super.key, this.currentUserId});

  @override
  LiveGiftBannerOverlayState createState() => LiveGiftBannerOverlayState();
}

class LiveGiftBannerOverlayState extends State<LiveGiftBannerOverlay> {
  static const _maxSlots = 2;

  final List<_GiftBannerSlot> _slots = [];

  void show(Map<String, dynamic> msg) {
    if (!mounted) return;

    final userId = _long(msg['user_id'] ?? msg['userId']);
    final username = (msg['username'] ?? msg['nickname'] ?? '').toString().trim();
    final giftName = (msg['gift_name'] ?? msg['giftName'] ?? '').toString().trim();
    final label = giftName.isEmpty ? '礼物' : giftName;
    final addCount = _int(msg['gift_count'] ?? msg['giftCount'] ?? msg['count'], fallback: 1).clamp(1, 9999);
    final durationSec = _int(msg['display_duration'] ?? msg['displayDuration'], fallback: 4).clamp(1, 30);

    final existing = _findSlot(userId, username, label);
    if (existing != null) {
      existing.displayCount += addCount;
      existing.hideTimer?.cancel();
      existing.hideTimer = _scheduleHide(existing, durationSec);
      setState(() {});
      return;
    }

    while (_slots.length >= _maxSlots) {
      _removeSlot(_slots.first);
    }

    final slot = _GiftBannerSlot(
      msg: Map<String, dynamic>.from(msg),
      userId: userId,
      username: username,
      giftName: label,
      displayCount: addCount,
      slideIn: true,
    );
    slot.hideTimer = _scheduleHide(slot, durationSec);
    setState(() => _slots.add(slot));
  }

  void hideAll() {
    for (final slot in List<_GiftBannerSlot>.from(_slots)) {
      _removeSlot(slot);
    }
    if (mounted) setState(() {});
  }

  _GiftBannerSlot? _findSlot(int? userId, String username, String giftName) {
    for (final slot in _slots) {
      if (!_sameGift(slot, userId, username, giftName)) continue;
      return slot;
    }
    return null;
  }

  bool _sameGift(_GiftBannerSlot slot, int? userId, String username, String giftName) {
    if (slot.giftName.toLowerCase() != giftName.toLowerCase()) return false;
    if (slot.userId != null && userId != null) return slot.userId == userId;
    final a = slot.username.isEmpty ? (slot.userId?.toString() ?? '') : slot.username;
    final b = username.isEmpty ? (userId?.toString() ?? '') : username;
    return a.isNotEmpty && a == b;
  }

  Timer _scheduleHide(_GiftBannerSlot slot, int durationSec) {
    return Timer(Duration(seconds: durationSec), () {
      if (!mounted) return;
      setState(() => slot.fading = true);
      Timer(const Duration(milliseconds: 220), () {
        if (!mounted) return;
        _removeSlot(slot);
        setState(() {});
      });
    });
  }

  void _removeSlot(_GiftBannerSlot slot) {
    slot.hideTimer?.cancel();
    _slots.remove(slot);
  }

  @override
  void dispose() {
    for (final slot in _slots) {
      slot.hideTimer?.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_slots.isEmpty) return const SizedBox.shrink();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: _slots.map(_buildSlot).toList(),
    );
  }

  Widget _buildSlot(_GiftBannerSlot slot) {
    final isMe = widget.currentUserId != null &&
        slot.userId != null &&
        widget.currentUserId == slot.userId;
    final nickname = isMe ? '我' : (slot.username.isEmpty ? '用户' : slot.username);
    final icon = GiftSvgaUtil.resolveChatPreviewIcon(slot.msg);

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: _GiftBannerSlide(
        active: slot.slideIn,
        fading: slot.fading,
        child: Container(
          constraints: const BoxConstraints(minWidth: 200),
          height: 50,
          padding: const EdgeInsets.fromLTRB(6, 0, 8, 0),
          decoration: BoxDecoration(
            color: const Color(0x99000000),
            borderRadius: BorderRadius.circular(25),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipOval(
                child: Image.asset(
                  AvatarHelper.assetPath,
                  width: 36,
                  height: 36,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nickname,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: LiveRoomColors.contentWhite, fontSize: 13),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '送 ${slot.giftName}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: LiveRoomColors.giftAction, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              _buildGiftIcon(icon),
              const SizedBox(width: 4),
              _GiftCountText(count: slot.displayCount),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGiftIcon(String icon) {
    final isUrl = icon.startsWith('http') || icon.startsWith('/');
    if (isUrl) {
      return CachedNetworkImage(
        imageUrl: ImageUrl.getImageUrl(icon),
        width: 40,
        height: 40,
        fit: BoxFit.contain,
        errorWidget: (_, __, ___) => const Text('🎁', style: TextStyle(fontSize: 28)),
      );
    }
    if (icon.isNotEmpty) {
      return SizedBox(
        width: 40,
        height: 40,
        child: Center(child: Text(icon, style: const TextStyle(fontSize: 28))),
      );
    }
    return const SizedBox(width: 40, height: 40, child: Center(child: Text('🎁', style: TextStyle(fontSize: 28))));
  }

  int _int(dynamic v, {int fallback = 0}) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? fallback;
  }

  int? _long(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }
}

class _GiftBannerSlot {
  final Map<String, dynamic> msg;
  final int? userId;
  final String username;
  final String giftName;
  int displayCount;
  bool slideIn;
  bool fading;
  Timer? hideTimer;

  _GiftBannerSlot({
    required this.msg,
    required this.userId,
    required this.username,
    required this.giftName,
    required this.displayCount,
    this.slideIn = false,
    this.fading = false,
  });
}

class _GiftBannerSlide extends StatefulWidget {
  final bool active;
  final bool fading;
  final Widget child;

  const _GiftBannerSlide({
    required this.active,
    required this.fading,
    required this.child,
  });

  @override
  State<_GiftBannerSlide> createState() => _GiftBannerSlideState();
}

class _GiftBannerSlideState extends State<_GiftBannerSlide> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _slide;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 280));
    _slide = Tween<double>(begin: -120, end: 0).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _fade = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    if (widget.active) _ctrl.forward();
    else _ctrl.value = 1;
  }

  @override
  void didUpdateWidget(_GiftBannerSlide oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.fading && !oldWidget.fading) {
      _ctrl.animateTo(0, duration: const Duration(milliseconds: 200));
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(_slide.value, 0),
          child: Opacity(opacity: _fade.value, child: child),
        );
      },
      child: widget.child,
    );
  }
}

class _GiftCountText extends StatefulWidget {
  final int count;

  const _GiftCountText({required this.count});

  @override
  State<_GiftCountText> createState() => _GiftCountTextState();
}

class _GiftCountTextState extends State<_GiftCountText> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  int _lastCount = 0;

  @override
  void initState() {
    super.initState();
    _lastCount = widget.count;
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 160));
  }

  @override
  void didUpdateWidget(_GiftCountText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.count != oldWidget.count) {
      _lastCount = widget.count;
      _ctrl
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: TweenSequence<double>([
        TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.25), weight: 50),
        TweenSequenceItem(tween: Tween(begin: 1.25, end: 1.0), weight: 50),
      ]).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut)),
      child: Text(
        'x${widget.count}',
        style: const TextStyle(
          color: LiveRoomColors.giftCount,
          fontSize: 18,
          fontStyle: FontStyle.italic,
          fontWeight: FontWeight.bold,
          shadows: [Shadow(color: Color(0x80FFB800), blurRadius: 4)],
        ),
      ),
    );
  }
}

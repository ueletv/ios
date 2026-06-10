import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:videoweb_flutter/api/api_result.dart';
import 'package:videoweb_flutter/api/api_service.dart';
import 'package:videoweb_flutter/api/models/gift.dart';
import 'package:videoweb_flutter/api/models/user.dart';
import 'package:videoweb_flutter/pages/live/gift_svga_util.dart';
import 'package:videoweb_flutter/pages/live/live_room_colors.dart';
import 'package:videoweb_flutter/pages/profile/recharge_page.dart';
import 'package:videoweb_flutter/services/app_prefs.dart';
import 'package:videoweb_flutter/services/gift_list_cache.dart';
import 'package:videoweb_flutter/services/guest_auth_helper.dart';
import 'package:videoweb_flutter/utils/app_toast.dart';
import 'package:videoweb_flutter/utils/image_url.dart';
import 'package:videoweb_flutter/utils/user_balance_helper.dart';

/// 礼物面板（对应 activity_live_room.xml gift_panel + GiftAdapter.kt）
class GiftPanel extends StatefulWidget {
  final String streamerId;
  final void Function(Gift gift, Map<String, dynamic> localMsg)? onGiftSent;
  final VoidCallback? onClose;

  const GiftPanel({
    super.key,
    required this.streamerId,
    this.onGiftSent,
    this.onClose,
  });

  @override
  State<GiftPanel> createState() => _GiftPanelState();
}

class _GiftPanelState extends State<GiftPanel> {
  final ApiService _api = ApiService();
  List<Gift> _gifts = [];
  Gift? _selectedGift;
  bool _loading = true;
  double _userCoin = 0;
  UserLevelInfo? _levelInfo;

  @override
  void initState() {
    super.initState();
    final cachedGifts = GiftListCache.cachedGifts;
    if (cachedGifts != null && cachedGifts.isNotEmpty) {
      _gifts = List<Gift>.from(cachedGifts);
      _loading = false;
    }
    final cachedCoin = GiftListCache.cachedCoin;
    if (cachedCoin != null) {
      _userCoin = cachedCoin;
      _levelInfo = GiftListCache.cachedLevel;
    }
    _loadGifts(silent: _gifts.isNotEmpty);
    _loadUserInfo(silent: cachedCoin != null);
  }

  Future<void> _loadGifts({bool silent = false}) async {
    if (!silent && _gifts.isEmpty && mounted) {
      setState(() => _loading = true);
    }
    try {
      final list = await GiftListCache.prefetch();
      if (!mounted) return;
      setState(() {
        if (list.isNotEmpty) {
          _gifts = List<Gift>.from(list);
        }
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadUserInfo({bool silent = false}) async {
    try {
      await GiftListCache.refreshUserBalance();
      if (!mounted) return;
      final coin = GiftListCache.cachedCoin;
      if (coin != null) {
        setState(() {
          _userCoin = coin;
          _levelInfo = GiftListCache.cachedLevel;
        });
      }
    } catch (_) {}
  }

  void _toast(String msg) {
    if (!mounted) return;
    AppToast.show(msg, context: context);
  }

  Future<void> _openRecharge() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const RechargePage()),
    );
    if (mounted) _loadUserInfo();
  }

  Future<void> _showInsufficientBalanceDialog({required int need}) async {
    if (!mounted) return;
    final current = UserBalanceHelper.formatLiveCoinInteger(_userCoin);
    final goRecharge = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E2230),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('余额不足', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        content: Text(
          '余额 $current 钻，送礼物需 $need 钻。\n是否前往直播充值？',
          style: TextStyle(color: Colors.white.withOpacity(0.78), height: 1.45, fontSize: 14),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('取消', style: TextStyle(color: Colors.white.withOpacity(0.55))),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF7C4DFF),
              foregroundColor: Colors.white,
            ),
            child: const Text('去充值'),
          ),
        ],
      ),
    );
    if (goRecharge == true && mounted) {
      await _openRecharge();
    }
  }

  bool _isInsufficientBalanceMessage(String? msg) {
    if (msg == null || msg.isEmpty) return false;
    return msg.contains('余额不足') || msg.contains('直播币不足');
  }

  Future<void> _sendGift(Gift gift) async {
    final gid = gift.id is int ? gift.id as int : int.tryParse(gift.id.toString());
    if (gid == null) {
      _toast('礼物参数错误');
      return;
    }

    final giftPrice = (gift.price ?? 0).toDouble();
    final giftPriceInt = giftPrice.toInt();
    if (_userCoin + 0.0001 < giftPrice) {
      await _showInsufficientBalanceDialog(need: giftPriceInt);
      return;
    }

    final sId = int.tryParse(widget.streamerId);
    if (sId == null) {
      _toast('主播ID格式错误');
      return;
    }

    final prefs = context.read<AppPrefs>();
    final res = await GuestAuthHelper.callWithAuthRetry(prefs, () {
      return _api.sendGift({
        'streamer_id': sId,
        'gift_id': gid,
        'count': 1,
      });
    });

    if (res != null && ApiResult.isSuccess(res)) {
      final animUrl = (gift.image?.trim().isNotEmpty == true) ? gift.image!.trim() : (gift.icon ?? '');
      final previewUrl = GiftSvgaUtil.resolveGiftPanelPreview(gift);
      final duration = (gift.displayDuration ?? 4).clamp(1, 30);
      final giftIconChat = GiftSvgaUtil.isSvgaUrl(animUrl)
          ? previewUrl
          : (previewUrl.isNotEmpty ? previewUrl : (gift.icon ?? ''));
      final localMsg = <String, dynamic>{
        'id': 'gift_${DateTime.now().millisecondsSinceEpoch}',
        'username': '我',
        'content': '送出了 ${gift.name} x1',
        'display_text': '我 送出 ${gift.name}',
        'is_barrage': false,
        'is_gift': true,
        'is_system_message': false,
        'gift_name': gift.name ?? '',
        'gift_count': 1,
        'gift_icon': giftIconChat,
        'gift_image': animUrl,
        'gift_preview': previewUrl,
        'display_duration': duration,
      };
      widget.onGiftSent?.call(gift, localMsg);
      _loadUserInfo();
    } else {
      final err = ApiResult.getErrorMessage(res!) ?? '送礼失败';
      if (_isInsufficientBalanceMessage(err)) {
        await _showInsufficientBalanceDialog(need: giftPriceInt);
      } else {
        _toast(err);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: LiveRoomColors.giftPanelBg,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildTopBar(),
            SizedBox(
              height: 272,
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: Colors.white54))
                  : _gifts.isEmpty
                      ? const Center(child: Text('暂无可用礼物', style: TextStyle(color: Colors.white54)))
                      : GridView.builder(
                          padding: const EdgeInsets.fromLTRB(8, 4, 8, 16),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 4,
                            mainAxisSpacing: 8,
                            crossAxisSpacing: 8,
                            childAspectRatio: 0.72,
                          ),
                          itemCount: _gifts.length,
                          itemBuilder: (context, index) => _buildGiftCell(_gifts[index]),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    final level = _levelInfo;
    final progress = (level?.expProgress ?? 0).clamp(0, 100).toInt();
    final upgradeText = level == null
        ? ''
        : level.isMaxLevel
            ? '已满级'
            : '距离升级: ${level.expNeeded}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Row(
        children: [
          const Text(
            '礼物',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const Spacer(),
          if (level != null)
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: SizedBox(
                width: 100,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (level.levelIcon?.isNotEmpty == true)
                          CachedNetworkImage(
                            imageUrl: ImageUrl.getLevelIconUrl(level.levelIcon!),
                            width: 24,
                            height: 24,
                            fit: BoxFit.contain,
                            errorWidget: (_, __, ___) => const Icon(Icons.shield_outlined, color: Colors.white54, size: 20),
                          )
                        else
                          const Icon(Icons.shield_outlined, color: Colors.white54, size: 20),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            upgradeText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Color(0x99FFFFFF), fontSize: 9),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: level.isMaxLevel ? 1 : progress / 100,
                        minHeight: 4,
                        backgroundColor: Colors.white.withOpacity(0.15),
                        valueColor: const AlwaysStoppedAnimation(Color(0xFFFF6B9D)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          _buildBalanceChip(),
        ],
      ),
    );
  }

  Widget _buildBalanceChip() {
    final balanceText = UserBalanceHelper.formatLiveCoinInteger(_userCoin);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _openRecharge,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.4),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 6, 8, 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$balanceText 钻',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Icon(Icons.chevron_right_rounded, size: 18, color: Colors.white.withOpacity(0.55)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGiftCell(Gift gift) {
    final selected = _selectedGift?.id == gift.id;
    final preview = GiftSvgaUtil.resolveGiftPanelPreview(gift);
    final isImageUrl = preview.isNotEmpty &&
        !GiftSvgaUtil.isSvgaUrl(preview) &&
        (preview.startsWith('http') || preview.startsWith('/'));

    return GestureDetector(
      onTap: () => setState(() => _selectedGift = gift),
      child: Container(
        decoration: BoxDecoration(
          color: selected ? Colors.white.withOpacity(0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: selected ? Border.all(color: LiveRoomColors.giftCount.withOpacity(0.8), width: 1.5) : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isImageUrl)
              CachedNetworkImage(
                imageUrl: ImageUrl.getImageUrl(preview),
                width: 56,
                height: 56,
                fit: BoxFit.contain,
              )
            else if (preview.isNotEmpty && !preview.startsWith('http') && !preview.startsWith('/'))
              Text(preview, style: const TextStyle(fontSize: 36))
            else
              const Icon(Icons.card_giftcard, color: Colors.white54, size: 44),
            const SizedBox(height: 4),
            Text(
              gift.name ?? '',
              style: const TextStyle(color: Colors.white, fontSize: 11),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
            if (!selected) ...[
              const SizedBox(height: 2),
              Text(
                '${gift.price ?? 0} 钻',
                style: const TextStyle(color: Color(0x80FFFFFF), fontSize: 10),
              ),
            ],
            if (selected) ...[
              const SizedBox(height: 6),
              GestureDetector(
                onTap: () => _sendGift(gift),
                child: Container(
                  width: double.infinity,
                  height: 28,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFFFF6B9D), Color(0xFFFF4081)]),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Text(
                    '赠送',
                    style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

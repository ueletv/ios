import 'package:videoweb_flutter/api/api_result.dart';
import 'package:videoweb_flutter/api/api_service.dart';
import 'package:videoweb_flutter/api/models/gift.dart';
import 'package:videoweb_flutter/api/models/user.dart';
import 'package:videoweb_flutter/utils/user_balance_helper.dart';

/// 直播间礼物列表缓存（对齐原生：进房后可立即打开礼物面板，不必每次转圈）
class GiftListCache {
  GiftListCache._();

  static List<Gift>? _gifts;
  static Future<void>? _inflight;
  static double? _cachedCoin;
  static UserLevelInfo? _cachedLevel;

  static List<Gift>? get cachedGifts => _gifts;
  static double? get cachedCoin => _cachedCoin;
  static UserLevelInfo? get cachedLevel => _cachedLevel;

  static Future<List<Gift>> prefetch({bool force = false}) async {
    if (!force && _gifts != null && _gifts!.isNotEmpty) return _gifts!;
    if (_inflight != null) {
      await _inflight!;
      return _gifts ?? [];
    }
    _inflight = _load();
    try {
      await _inflight!;
    } finally {
      _inflight = null;
    }
    return _gifts ?? [];
  }

  static Future<void> _load() async {
    try {
      final res = await ApiService().getGiftList();
      if (!ApiResult.isSuccess(res)) return;
      final data = res.data['data'];
      if (data is! List) return;
      final list = data.map((e) => Gift.fromJson(e as Map<String, dynamic>)).toList();
      if (list.isNotEmpty) {
        _gifts = list;
      }
    } catch (_) {}
  }

  static Future<void> refreshUserBalance() async {
    try {
      final res = await ApiService().getUserInfo();
      if (!ApiResult.isSuccess(res)) return;
      final data = res.data['data'];
      if (data is! Map) return;
      final map = Map<String, dynamic>.from(data);
      _cachedCoin = UserBalanceHelper.liveCoinValue(map);
      _cachedLevel = UserInfo.fromJson(map).effectiveLevelInfo;
    } catch (_) {}
  }

  static void applyUserBalance(double coin, UserLevelInfo? level) {
    _cachedCoin = coin;
    _cachedLevel = level;
  }

  static void clear() {
    _gifts = null;
    _cachedCoin = null;
    _cachedLevel = null;
    _inflight = null;
  }
}

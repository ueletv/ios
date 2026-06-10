import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:videoweb_flutter/api/api_result.dart';
import 'package:videoweb_flutter/api/api_service.dart';
import 'package:videoweb_flutter/api/models/user.dart';

enum TrialContentType { video, live }

/// 视频 / 直播试看剩余时长（分开计费），仅在观看时扣减。
class GlobalTrialService extends ChangeNotifier {
  final ApiService _api = ApiService();

  int videoTrialRemaining = 0;
  int liveTrialRemaining = 0;
  bool isActiveVip = false;
  Timer? _consumeTimer;
  VoidCallback? _onExhausted;
  TrialContentType? _activeType;

  /// 兼容旧代码：指视频试看剩余
  int get trialRemaining => videoTrialRemaining;

  void syncUser(UserInfo? user) {
    isActiveVip = user?.isActiveVip ?? false;
    final videoRem = user?.videoTrialRemainingSeconds ?? user?.trialRemainingSeconds;
    if (videoRem != null) {
      videoTrialRemaining = videoRem;
    }
    final liveRem = user?.liveTrialRemainingSeconds;
    if (liveRem != null) {
      liveTrialRemaining = liveRem;
    }
    notifyListeners();
  }

  int remainingFor(TrialContentType type) {
    return type == TrialContentType.live ? liveTrialRemaining : videoTrialRemaining;
  }

  void updateRemaining(int seconds, {TrialContentType type = TrialContentType.video}) {
    final v = seconds < 0 ? 0 : seconds;
    if (type == TrialContentType.live) {
      liveTrialRemaining = v;
    } else {
      videoTrialRemaining = v;
    }
    notifyListeners();
  }

  void _applyConsumeResponse(Map data, TrialContentType type) {
    final rem = data['trial_remaining_seconds'];
    if (rem is num) {
      updateRemaining(rem.toInt(), type: type);
      return;
    }
    final videoRem = data['video_trial_remaining_seconds'];
    final liveRem = data['live_trial_remaining_seconds'];
    if (videoRem is num) {
      videoTrialRemaining = videoRem.toInt().clamp(0, 1 << 30);
    }
    if (liveRem is num) {
      liveTrialRemaining = liveRem.toInt().clamp(0, 1 << 30);
    }
    notifyListeners();
  }

  Future<void> refreshFromServer() async {
    try {
      final res = await _api.getUserInfo();
      if (!ApiResult.isSuccess(res)) return;
      final data = res.data['data'];
      if (data is Map) {
        syncUser(UserInfo.fromJson(Map<String, dynamic>.from(data)));
      }
    } catch (_) {}
  }

  bool canWatch({
    required bool vipRequired,
    TrialContentType type = TrialContentType.video,
  }) {
    if (!vipRequired) return true;
    if (isActiveVip) return true;
    return remainingFor(type) > 0;
  }

  void startWatching({
    TrialContentType type = TrialContentType.video,
    VoidCallback? onExhausted,
  }) {
    if (isActiveVip || remainingFor(type) <= 0) return;
    stopWatching();
    _activeType = type;
    _onExhausted = onExhausted;
    _consumeTimer = Timer.periodic(const Duration(seconds: 1), (_) => _tickConsume());
  }

  void stopWatching() {
    _consumeTimer?.cancel();
    _consumeTimer = null;
    _onExhausted = null;
    _activeType = null;
  }

  Future<void> _tickConsume() async {
    final type = _activeType ?? TrialContentType.video;
    if (isActiveVip) {
      stopWatching();
      return;
    }
    if (remainingFor(type) <= 0) {
      final cb = _onExhausted;
      stopWatching();
      cb?.call();
      return;
    }

    final apiType = type == TrialContentType.live ? 'live' : 'video';
    try {
      final res = await _api.consumeTrialSeconds(1, type: apiType);
      if (ApiResult.isSuccess(res)) {
        final data = res.data['data'];
        if (data is Map) {
          _applyConsumeResponse(Map<String, dynamic>.from(data), type);
        } else {
          updateRemaining(remainingFor(type) - 1, type: type);
        }
      } else {
        updateRemaining(remainingFor(type) - 1, type: type);
      }
    } catch (_) {
      updateRemaining(remainingFor(type) - 1, type: type);
    }

    if (remainingFor(type) <= 0) {
      final cb = _onExhausted;
      stopWatching();
      cb?.call();
    }
  }

  @override
  void dispose() {
    stopWatching();
    super.dispose();
  }
}

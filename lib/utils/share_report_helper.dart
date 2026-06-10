import 'package:videoweb_flutter/api/api_result.dart';
import 'package:videoweb_flutter/api/api_service.dart';
import 'package:videoweb_flutter/api/models/video_id_body.dart';
import 'package:videoweb_flutter/services/app_prefs.dart';
import 'package:videoweb_flutter/services/guest_auth_helper.dart';

/// 视频分享统计上报（同一视频当日仅上报一次，避免重复点击刷接口）
class ShareReportHelper {
  ShareReportHelper._();

  static final Set<String> _sessionReported = {};
  static final Set<String> _inflight = {};

  static bool alreadyReported(AppPrefs prefs, String videoId) {
    final id = videoId.trim();
    if (id.isEmpty) return true;
    return _sessionReported.contains(id) || prefs.hasShareReportedToday(id);
  }

  /// 若尚未上报则调用分享接口；返回是否本次成功上报
  static Future<bool> reportIfNeeded({
    required AppPrefs prefs,
    required ApiService api,
    required int videoId,
  }) async {
    final key = videoId.toString();
    if (videoId <= 0 || alreadyReported(prefs, key)) return false;
    if (_inflight.contains(key)) return false;

    _inflight.add(key);
    try {
      final res = await GuestAuthHelper.callWithAuthRetry(prefs, () {
        return api.shareVideo(VideoIdBody(videoId: videoId));
      });
      if (res != null && ApiResult.isSuccess(res)) {
        _sessionReported.add(key);
        prefs.markShareReportedToday(key);
        return true;
      }
    } catch (_) {}
    finally {
      _inflight.remove(key);
    }
    return false;
  }
}

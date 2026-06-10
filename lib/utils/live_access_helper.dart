import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:videoweb_flutter/services/app_config_cache.dart';
import 'package:videoweb_flutter/services/global_trial_service.dart';
import 'package:videoweb_flutter/utils/vip_access_helper.dart';

/// 进入直播间前的 VIP / 试看校验（在大厅拦截，避免先进房再弹窗）
class LiveAccessHelper {
  LiveAccessHelper._();

  static bool _isLiveVipRequired(Map<String, dynamic>? config) {
    return config?['live_room_vip_required']?.toString() != '0';
  }

  /// 是否允许进入直播间；不允许时在大厅直接弹 VIP 提示
  static Future<bool> ensureCanEnterLive(BuildContext context) async {
    final trial = context.read<GlobalTrialService>();
    await trial.refreshFromServer();
    if (!context.mounted) return false;

    var config = AppConfigCache.cached;
    if (config != null && !_isLiveVipRequired(config)) return true;
    if (config != null && trial.canWatch(vipRequired: true, type: TrialContentType.live)) {
      return true;
    }

    config = await AppConfigCache.fetch();
    if (!context.mounted) return false;
    if (!_isLiveVipRequired(config)) return true;
    if (trial.canWatch(vipRequired: true, type: TrialContentType.live)) return true;

    final openedVip = await VipAccessHelper.showVipRequiredDialog(
      context,
      title: '直播试看已结束',
      message: '直播试看时长已用完，开通 VIP 可继续观看精彩直播',
      cancelLabel: '知道了',
    );
    if (!context.mounted) return false;
    if (openedVip) {
      await trial.refreshFromServer();
      if (!context.mounted) return false;
      if (trial.canWatch(vipRequired: true, type: TrialContentType.live)) return true;
    }
    return false;
  }

  static Future<void> openLiveRoomIfAllowed(
    BuildContext context,
    VoidCallback openRoom,
  ) async {
    if (await ensureCanEnterLive(context) && context.mounted) {
      openRoom();
    }
  }
}

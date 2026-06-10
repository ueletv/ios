import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:videoweb_flutter/api/models/user.dart';
import 'package:videoweb_flutter/pages/profile/vip_page.dart';
import 'package:videoweb_flutter/pages/profile/widgets/purchase_theme.dart';
import 'package:videoweb_flutter/services/global_trial_service.dart';

class VipAccessHelper {
  VipAccessHelper._();

  static bool isActiveVip(UserInfo? user) {
    if (user == null) return false;
    if ((user.vipLevel ?? 0) != 1) return false;
    final expire = user.vipExpireTime?.trim();
    if (expire == null || expire.isEmpty) return true;
    try {
      return DateTime.parse(expire.replaceFirst(' ', 'T')).isAfter(DateTime.now());
    } catch (_) {
      return true;
    }
  }

  /// 返回 true=已前往 VIP 页，false=用户取消
  static Future<bool> showVipRequiredDialog(
    BuildContext context, {
    String title = '需要 VIP 会员',
    String message = '观看视频和直播需开通 VIP 会员，是否前往开通？',
    String cancelLabel = '稍后再说',
  }) async {
    final goVip = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.55),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 48),
        child: VipRequiredDialog(
          title: title,
          message: message,
          cancelLabel: cancelLabel,
        ),
      ),
    );
    if (goVip == true && context.mounted) {
      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const VipPage()));
      if (context.mounted) {
        await context.read<GlobalTrialService>().refreshFromServer();
      }
      return true;
    }
    return false;
  }

  static Future<void> openVipPage(BuildContext context) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const VipPage()));
    if (context.mounted) {
      await context.read<GlobalTrialService>().refreshFromServer();
    }
  }
}

/// 直播间 VIP 引导（屏幕居中、紧凑卡片）
class VipRequiredDialog extends StatelessWidget {
  final String title;
  final String message;
  final String cancelLabel;

  const VipRequiredDialog({
    super.key,
    required this.title,
    required this.message,
    this.cancelLabel = '稍后再说',
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xF0161823),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.45), blurRadius: 20, offset: const Offset(0, 8)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
              decoration: const BoxDecoration(gradient: PurchaseGradients.vipHero),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.22),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.workspace_premium_rounded, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.76),
                      fontSize: 13,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context, false),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white.withOpacity(0.72),
                            side: BorderSide(color: Colors.white.withOpacity(0.18)),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            minimumSize: const Size(0, 38),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text(cancelLabel, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [Color(0xFFFFB74D), Color(0xFFFF8F00)]),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () => Navigator.pop(context, true),
                              child: const SizedBox(
                                height: 38,
                                child: Center(
                                  child: Text(
                                    '开通 VIP',
                                    style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 播放器上的 VIP 遮罩（视频 / 短视频，简洁居中样式）
class VipPlayerOverlay extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback onOpenVip;

  const VipPlayerOverlay({
    super.key,
    required this.title,
    required this.message,
    required this.onOpenVip,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.72),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.workspace_premium_rounded, color: Colors.amber.shade400, size: 52),
                const SizedBox(height: 14),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white.withOpacity(0.82), fontSize: 14, height: 1.45),
                ),
                const SizedBox(height: 22),
                FilledButton(
                  onPressed: onOpenVip,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(160, 44),
                    backgroundColor: Colors.amber.shade700,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('开通 VIP', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

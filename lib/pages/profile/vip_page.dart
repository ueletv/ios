import 'package:flutter/material.dart';
import 'package:videoweb_flutter/utils/app_toast.dart';

import 'package:provider/provider.dart';
import 'package:videoweb_flutter/api/api_result.dart';
import 'package:videoweb_flutter/api/api_service.dart';
import 'package:videoweb_flutter/api/models/user.dart';
import 'package:videoweb_flutter/api/models/vip_info.dart';
import 'package:videoweb_flutter/pages/profile/widgets/profile_subpage_scaffold.dart';
import 'package:videoweb_flutter/pages/profile/widgets/purchase_widgets.dart';
import 'package:videoweb_flutter/services/global_trial_service.dart';
import 'package:videoweb_flutter/services/theme_controller.dart';
import 'package:videoweb_flutter/theme/app_theme.dart';

/// VIP 套餐购买页（对应原生 VipActivity.kt）
class VipPage extends StatefulWidget {
  const VipPage({super.key});

  @override
  State<VipPage> createState() => _VipPageState();
}

class _VipPageState extends State<VipPage> {
  final ApiService _api = ApiService();
  List<VipInfo> _plans = [];
  String _heroTitle = '开通VIP，免费观看所有付费视频';
  String _heroDesc = 'VIP：未开通';
  bool _isLoading = false;
  bool _isPurchasing = false;
  String? _emptyMessage;

  @override
  void initState() {
    super.initState();
    _loadUserVipStatus();
    _loadPlans();
  }

  Future<void> _loadUserVipStatus() async {
    try {
      final res = await _api.getUserInfo();
      if (!ApiResult.isSuccess(res)) return;
      final data = res.data['data'];
      if (data is! Map) return;
      final user = UserInfo.fromJson(Map<String, dynamic>.from(data));
      context.read<GlobalTrialService>().syncUser(user);
      final isVip = _isActiveVip(user);
      if (!mounted) return;
      setState(() {
        if (isVip) {
          _heroTitle = 'VIP状态';
          _heroDesc = '过期时间：${_formatVipExpire(user.vipExpireTime)}';
        } else {
          _heroTitle = '开通VIP，免费观看所有付费视频';
          _heroDesc = 'VIP：未开通';
        }
      });
    } catch (_) {}
  }

  bool _isActiveVip(UserInfo user) => user.isActiveVip;

  String _formatVipExpire(String? s) {
    if (s == null || s.isEmpty) return '未知';
    try {
      final dt = DateTime.parse(s.replaceFirst(' ', 'T'));
      if (dt.isBefore(DateTime.now())) return '已过期';
    } catch (_) {}
    return s;
  }

  Future<void> _loadPlans() async {
    setState(() {
      _isLoading = true;
      _emptyMessage = null;
    });
    try {
      final res = await _api.getVipPrice(all: 1);
      if (ApiResult.isSuccess(res)) {
        final data = res.data['data'];
        final plans = VipInfoParser.parseList(data);
        plans.sort((a, b) => (a.sort ?? 0).compareTo(b.sort ?? 0));
        setState(() {
          _plans = plans;
          _emptyMessage = plans.isEmpty ? (res.data['message']?.toString() ?? '暂无套餐') : null;
        });
      } else {
        setState(() {
          _plans = [];
          _emptyMessage = ApiResult.getErrorMessage(res) ?? '暂无套餐';
        });
      }
    } catch (_) {
      setState(() {
        _plans = [];
        _emptyMessage = '加载失败，请稍后重试';
      });
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _confirmPurchase(VipInfo plan) async {
    final timeText = plan.timeText.isEmpty ? '—' : plan.timeText;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('开通VIP'),
        content: Text('确定要开通${plan.name ?? 'VIP'}（$timeText）吗？价格为${plan.priceDisplay}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('确定')),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _isPurchasing = true);
    try {
      final res = await _api.purchaseVip({'vip_type': plan.type});
      if (ApiResult.isSuccess(res)) {
        _showToast('购买成功');
        await context.read<GlobalTrialService>().refreshFromServer();
        await _loadUserVipStatus();
      } else {
        _showToast(ApiResult.getErrorMessage(res) ?? '购买失败');
      }
    } catch (_) {
      _showToast('购买失败');
    }
    if (mounted) setState(() => _isPurchasing = false);
  }

  void _showToast(String msg) {
    if (!mounted) return;
    AppToast.show(msg, context: context);
  }

  @override
  Widget build(BuildContext context) {
    context.watch<ThemeController>();
    final colors = context.appColors;
    return ProfileSubpageScaffold(
      title: 'VIP 会员',
      body: Stack(
        children: [
          if (_isPurchasing)
            const Positioned.fill(
              child: ColoredBox(
                color: Color(0x33000000),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
          _isLoading && _plans.isEmpty
              ? Center(child: CircularProgressIndicator(color: colors.accent))
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  children: [
                    PurchaseWidgets.vipHero(title: _heroTitle, desc: _heroDesc),
                    const SizedBox(height: 20),
                    PurchaseWidgets.sectionTitle('选择套餐', colors: colors),
                    const SizedBox(height: 12),
                    if (_plans.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 32),
                        child: Center(
                          child: Text(
                            _emptyMessage ?? '暂无套餐，请稍后再试',
                            style: TextStyle(color: colors.textHint, fontSize: 14),
                          ),
                        ),
                      )
                    else
                      ..._plans.map(
                        (plan) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: PurchaseWidgets.vipPlanCard(
                            plan: plan,
                            recommend: plan.type == 2,
                            colors: colors,
                            onTap: () => _confirmPurchase(plan),
                          ),
                        ),
                      ),
                    PurchaseWidgets.vipBenefitsCard(colors),
                  ],
                ),
        ],
      ),
    );
  }
}

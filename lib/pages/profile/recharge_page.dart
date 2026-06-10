import 'package:flutter/material.dart';
import 'package:videoweb_flutter/utils/app_toast.dart';

import 'package:provider/provider.dart';
import 'package:videoweb_flutter/api/api_result.dart';
import 'package:videoweb_flutter/api/api_service.dart';
import 'package:videoweb_flutter/api/models/recharge.dart';
import 'package:videoweb_flutter/pages/profile/widgets/profile_subpage_scaffold.dart';
import 'package:videoweb_flutter/pages/profile/widgets/purchase_widgets.dart';
import 'package:videoweb_flutter/services/theme_controller.dart';
import 'package:videoweb_flutter/theme/app_theme.dart';
import 'package:videoweb_flutter/utils/user_balance_helper.dart';

/// 直播充值页（对应原生 RechargeActivity.kt walletType=live）
class RechargePage extends StatefulWidget {
  const RechargePage({super.key});

  @override
  State<RechargePage> createState() => _RechargePageState();
}

class _RechargePageState extends State<RechargePage> {
  final ApiService _api = ApiService();
  static const _walletType = 'live';

  List<RechargeRule> _rules = [];
  RechargeRule? _selectedRule;
  String _balance = '0';
  bool _loadingRules = false;
  bool _loadingBalance = false;
  bool _isCreating = false;
  String? _emptyMessage;

  @override
  void initState() {
    super.initState();
    _loadBalance();
    _loadRules();
  }

  RechargeRule? get _selected => _selectedRule;

  Future<void> _loadBalance({bool refresh = false}) async {
    setState(() => _loadingBalance = refresh);
    try {
      final res = await _api.getUserInfo();
      if (ApiResult.isSuccess(res)) {
        final data = res.data['data'];
        if (data is Map && mounted) {
          setState(() {
            _balance = UserBalanceHelper.formatLiveCoinInteger(
              UserBalanceHelper.liveCoinValue(Map<String, dynamic>.from(data)),
            );
          });
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _loadingBalance = false);
  }

  Future<void> _loadRules() async {
    setState(() {
      _loadingRules = true;
      _emptyMessage = null;
    });
    try {
      final res = await _api.getRechargeRules(walletType: _walletType);
      if (ApiResult.isSuccess(res)) {
        final data = res.data['data'];
        if (data is List) {
          final rules = data.map((e) => RechargeRule.fromJson(e as Map<String, dynamic>)).toList();
          setState(() {
            _rules = rules;
            if (rules.isNotEmpty) {
              if (_selectedRule == null || !rules.any((r) => r.id == _selectedRule!.id)) {
                _selectedRule = rules.first;
              }
            } else {
              _selectedRule = null;
              _emptyMessage = '暂无充值方案';
            }
          });
        }
      } else {
        setState(() {
          _rules = [];
          _selectedRule = null;
          _emptyMessage = ApiResult.getErrorMessage(res) ?? '加载失败';
        });
      }
    } catch (_) {
      setState(() {
        _rules = [];
        _selectedRule = null;
        _emptyMessage = '加载失败，请稍后重试';
      });
    }
    if (mounted) setState(() => _loadingRules = false);
  }

  Future<void> _createOrder() async {
    final rule = _selectedRule;
    if (rule == null) {
      _showToast('请选择充值金额');
      return;
    }

    final bonus = rule.bonusCoins > 0 ? '（含赠送${rule.bonusCoins}钻石）' : '';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认充值'),
        content: Text('充值金额：¥${rule.amount}\n获得钻石：${rule.totalCoins}钻石$bonus'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('确定')),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _isCreating = true);
    try {
      final createRes = await _api.createRechargeOrder({
        'rule_id': rule.id,
        'amount': rule.amount,
        'wallet_type': _walletType,
      });
      if (!ApiResult.isSuccess(createRes)) {
        _showToast(ApiResult.getErrorMessage(createRes) ?? '创建订单失败');
        return;
      }
      final data = createRes.data['data'];
      final orderNo = data is Map ? data['order_no']?.toString() ?? '' : '';
      if (orderNo.isEmpty) {
        _showToast('创建订单失败');
        return;
      }
      final confirmRes = await _api.confirmRecharge({
        'order_no': orderNo,
        'payment_method': 'manual',
      });
      if (ApiResult.isSuccess(confirmRes)) {
        _showToast('充值成功');
        await _loadBalance(refresh: true);
        if (mounted) Navigator.of(context).pop();
      } else {
        _showToast(ApiResult.getErrorMessage(confirmRes) ?? '充值失败');
      }
    } catch (_) {
      _showToast('充值失败');
    }
    if (mounted) setState(() => _isCreating = false);
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
      title: '直播充值',
      body: Column(
        children: [
          Expanded(
            child: _loadingRules && _rules.isEmpty
                ? Center(child: CircularProgressIndicator(color: colors.accent))
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
                    children: [
                      PurchaseWidgets.rechargeHero(
                        balance: _balance,
                        refreshing: _loadingBalance,
                        onRefresh: () => _loadBalance(refresh: true),
                      ),
                      const SizedBox(height: 20),
                      PurchaseWidgets.sectionTitle(
                        '选择充值金额',
                        subtitle: '点击档位即可选中，钻石可用于直播间打赏消费',
                        colors: colors,
                      ),
                      const SizedBox(height: 12),
                      if (_rules.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 32),
                          child: Center(
                            child: Text(
                              _emptyMessage ?? '暂无充值方案',
                              style: TextStyle(color: colors.textHint, fontSize: 14),
                            ),
                          ),
                        )
                      else
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 10,
                            crossAxisSpacing: 10,
                            childAspectRatio: 1.15,
                          ),
                          itemCount: _rules.length,
                          itemBuilder: (context, index) {
                            final rule = _rules[index];
                            return PurchaseWidgets.rechargeRuleCard(
                              rule: rule,
                              selected: _selectedRule?.id == rule.id,
                              recommend: index == 0,
                              colors: colors,
                              onTap: () => setState(() => _selectedRule = rule),
                            );
                          },
                        ),
                      PurchaseWidgets.rechargeTipsCard(colors),
                    ],
                  ),
          ),
          PurchaseWidgets.rechargeBottomBar(
            rule: _selected,
            loading: _isCreating,
            onSubmit: _createOrder,
            colors: colors,
          ),
        ],
      ),
    );
  }
}

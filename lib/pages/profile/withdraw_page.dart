import 'package:flutter/material.dart';
import 'package:videoweb_flutter/utils/app_toast.dart';

import 'package:provider/provider.dart';
import 'package:videoweb_flutter/api/api_result.dart';
import 'package:videoweb_flutter/api/api_service.dart';
import 'package:videoweb_flutter/api/models/withdraw.dart';
import 'package:videoweb_flutter/pages/profile/widgets/profile_subpage_scaffold.dart';
import 'package:videoweb_flutter/services/theme_controller.dart';
import 'package:videoweb_flutter/theme/app_theme.dart';

/// 提现页（对应原生 WithdrawActivity.kt）
class WithdrawPage extends StatefulWidget {
  const WithdrawPage({super.key});

  @override
  State<WithdrawPage> createState() => _WithdrawPageState();
}

class _WithdrawPageState extends State<WithdrawPage> {
  final ApiService _api = ApiService();
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _accountCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();

  WithdrawConfig? _config;
  String? _selectedType;
  bool _isLoading = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    setState(() => _isLoading = true);
    try {
      final res = await _api.getWithdrawConfig();
      if (ApiResult.isSuccess(res)) {
        final data = res.data['data'];
        if (data is Map<String, dynamic>) {
          final config = WithdrawConfig.fromJson(data);
          setState(() {
            _config = config;
            if (config.types != null && config.types!.isNotEmpty) {
              final first = config.types!.entries.firstWhere(
                (e) => e.value.enabled == 1,
                orElse: () => config.types!.entries.first,
              );
              _selectedType = first.key;
            }
          });
        }
      }
    } catch (_) {}
    setState(() => _isLoading = false);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_config == null || !_config!.enabled) {
      _showToast('提现功能未开放');
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      final amount = int.tryParse(_amountCtrl.text) ?? 0;
      final actualAmount =
          (amount * (1 - _config!.feeRate)).round();
      final res = await _api.createWithdrawOrder({
        'amount': amount,
        'actual_amount': actualAmount,
        'type': _selectedType ?? 'alipay',
        'account': _accountCtrl.text,
        'name': _nameCtrl.text,
      });
      if (ApiResult.isSuccess(res)) {
        _showToast('提现申请已提交');
        if (mounted) Navigator.of(context).pop();
      } else {
        _showToast(ApiResult.getErrorMessage(res) ?? '提现失败');
      }
    } catch (e) {
      _showToast('网络错误');
    }
    setState(() => _isSubmitting = false);
  }

  void _showToast(String msg) {
    if (!mounted) return;
    AppToast.show(msg, context: context);
  }

  Widget _buildFeePreview(AppColors colors) {
    if (_config == null || _amountCtrl.text.isEmpty) {
      return const SizedBox.shrink();
    }
    final amount = int.tryParse(_amountCtrl.text) ?? 0;
    final fee = (amount * _config!.feeRate).round();
    final actual = ((amount - fee) * _config!.coinsRate).toStringAsFixed(2);
    return ProfileThemedCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('手续费: $fee 金币', style: TextStyle(color: colors.textSecondary, fontSize: 13)),
          const SizedBox(height: 4),
          Text('预计到账: ¥$actual', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: colors.textPrimary)),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _accountCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    context.watch<ThemeController>();
    final colors = context.appColors;
    InputDecoration fieldDecoration(String label, {String? hint}) => InputDecoration(
          labelText: label,
          hintText: hint,
          filled: true,
          fillColor: colors.chipBg,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        );

    return ProfileSubpageScaffold(
      title: '提现',
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: colors.accent))
          : _config == null || !_config!.enabled
              ? const ProfileEmptyState(icon: Icons.info_outline, message: '提现功能暂未开放')
              : SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ProfileThemedCard(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('提现说明', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: colors.textPrimary)),
                              const SizedBox(height: 6),
                              Text(
                                '最低提现: ${_config!.minAmount} 金币\n最高提现: ${_config!.maxAmount} 金币\n手续费: ${(_config!.feeRate * 100).toStringAsFixed(0)}%\n汇率: ${_config!.coinsRate} 金币 = 1 元',
                                style: TextStyle(color: colors.textSecondary, fontSize: 13, height: 1.5),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        if (_config!.types != null && _config!.types!.isNotEmpty) ...[
                          Text('提现方式', style: TextStyle(fontWeight: FontWeight.w900, color: colors.textPrimary)),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            value: _selectedType,
                            dropdownColor: colors.cardBg,
                            decoration: fieldDecoration(''),
                            items: _config!.types!.entries.where((e) => e.value.enabled == 1).map((e) => DropdownMenuItem(value: e.key, child: Text(e.value.name, style: TextStyle(color: colors.textPrimary)))).toList(),
                            onChanged: (v) => setState(() => _selectedType = v),
                          ),
                          const SizedBox(height: 14),
                        ],
                        TextFormField(
                          controller: _amountCtrl,
                          keyboardType: TextInputType.number,
                          onChanged: (_) => setState(() {}),
                          decoration: fieldDecoration('提现金额（金币）', hint: '请输入金币数量'),
                          validator: (v) {
                            if (v == null || v.isEmpty) return '请输入提现金额';
                            final amount = int.tryParse(v);
                            if (amount == null) return '请输入有效数字';
                            if (amount < _config!.minAmount) return '最低提现 ${_config!.minAmount} 金币';
                            if (amount > _config!.maxAmount) return '最高提现 ${_config!.maxAmount} 金币';
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _accountCtrl,
                          decoration: fieldDecoration('收款账号', hint: '请输入支付宝/微信账号'),
                          validator: (v) => (v == null || v.isEmpty) ? '请输入收款账号' : null,
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _nameCtrl,
                          decoration: fieldDecoration('真实姓名', hint: '请输入收款人姓名'),
                          validator: (v) => (v == null || v.isEmpty) ? '请输入真实姓名' : null,
                        ),
                        const SizedBox(height: 14),
                        _buildFeePreview(colors),
                        if (_amountCtrl.text.isNotEmpty) const SizedBox(height: 14),
                        SizedBox(
                          height: 52,
                          child: FilledButton(
                            onPressed: _isSubmitting ? null : _submit,
                            style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                            child: _isSubmitting
                                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Text('提交提现', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:videoweb_flutter/api/api_result.dart';
import 'package:videoweb_flutter/api/api_service.dart';
import 'package:videoweb_flutter/pages/profile/widgets/profile_subpage_scaffold.dart';
import 'package:videoweb_flutter/services/app_prefs.dart';
import 'package:videoweb_flutter/services/theme_controller.dart';
import 'package:videoweb_flutter/theme/app_theme.dart';
import 'package:videoweb_flutter/utils/app_toast.dart';

/// 绑定手机号
/// [bindOnly] 为 true 时仅绑定手机（用户已设置过登录密码）
class BindPhonePage extends StatefulWidget {
  final bool bindOnly;

  const BindPhonePage({super.key, this.bindOnly = false});

  @override
  State<BindPhonePage> createState() => _BindPhonePageState();
}

class _BindPhonePageState extends State<BindPhonePage> {
  final ApiService _api = ApiService();
  final _formKey = GlobalKey<FormState>();
  final _phoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  bool get _bindOnly => widget.bindOnly;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);
    try {
      final phone = _phoneCtrl.text.trim();
      final prefs = context.read<AppPrefs>();
      final body = <String, dynamic>{
        'phone': phone,
        'device_id': prefs.deviceId,
      };
      if (!_bindOnly) {
        body['password'] = _passwordCtrl.text;
      }
      final res = await _api.bindPhone(body);
      if (!mounted) return;
      if (ApiResult.isSuccess(res)) {
        final prefs = context.read<AppPrefs>();
        prefs.phone = phone;
        if (!_bindOnly) {
          prefs.password = _passwordCtrl.text;
        }
        AppToast.show(
          _bindOnly ? '绑定成功，下次可用手机号+密码登录' : '绑定成功，下次可用手机号登录',
          context: context,
        );
        Navigator.of(context).pop(true);
      } else {
        AppToast.show(ApiResult.getErrorMessage(res) ?? '绑定失败', context: context);
      }
    } catch (_) {
      if (mounted) AppToast.show('网络错误', context: context);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    context.watch<ThemeController>();
    final colors = context.appColors;
    return ProfileSubpageScaffold(
      title: '绑定手机号',
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ProfileThemedCard(
                padding: const EdgeInsets.all(16),
                child: Text(
                  _bindOnly
                      ? '您已设置登录密码，绑定手机号后可用「手机号 + 密码」或「账号 + 密码」登录。'
                      : '绑定后可用手机号 + 密码在任意设备登录，收藏与余额也会跟着账号走。',
                  style: TextStyle(fontSize: 13, height: 1.45, color: colors.textSecondary),
                ),
              ),
              const SizedBox(height: 12),
              ProfileThemedCard(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _phoneCtrl,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(11),
                      ],
                      decoration: _fieldDecoration(colors, label: '手机号', hint: '请输入11位手机号'),
                      validator: (v) {
                        final p = v?.trim() ?? '';
                        if (p.isEmpty) return '请输入手机号';
                        if (!RegExp(r'^1[3-9]\d{9}$').hasMatch(p)) return '请输入正确的手机号';
                        return null;
                      },
                    ),
                    if (!_bindOnly) ...[
                      const SizedBox(height: 14),
                      _passwordField(
                        colors,
                        controller: _passwordCtrl,
                        label: '设置登录密码',
                        hint: '至少6位，绑定后用于登录',
                        obscure: _obscurePassword,
                        onToggle: () => setState(() => _obscurePassword = !_obscurePassword),
                        validator: (v) {
                          if (v == null || v.isEmpty) return '请设置登录密码';
                          if (v.length < 6) return '密码至少6位';
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      _passwordField(
                        colors,
                        controller: _confirmCtrl,
                        label: '确认密码',
                        hint: '请再次输入密码',
                        obscure: _obscureConfirm,
                        onToggle: () => setState(() => _obscureConfirm = !_obscureConfirm),
                        validator: (v) {
                          if (v == null || v.isEmpty) return '请确认密码';
                          if (v != _passwordCtrl.text) return '两次密码不一致';
                          return null;
                        },
                      ),
                    ],
                    const SizedBox(height: 20),
                    SizedBox(
                      height: 52,
                      child: FilledButton(
                        onPressed: _isLoading ? null : _submit,
                        style: FilledButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('确认绑定', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _fieldDecoration(AppColors colors, {required String label, required String hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: colors.chipBg,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  Widget _passwordField(
    AppColors colors, {
    required TextEditingController controller,
    required String label,
    required String hint,
    required bool obscure,
    required VoidCallback onToggle,
    required String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      validator: validator,
      decoration: _fieldDecoration(colors, label: label, hint: hint).copyWith(
        suffixIcon: IconButton(
          icon: Icon(obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined),
          onPressed: onToggle,
        ),
      ),
    );
  }
}

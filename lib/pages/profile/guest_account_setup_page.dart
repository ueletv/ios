import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:videoweb_flutter/api/api_result.dart';
import 'package:videoweb_flutter/api/api_service.dart';
import 'package:videoweb_flutter/api/models/user.dart';
import 'package:videoweb_flutter/pages/profile/widgets/profile_subpage_scaffold.dart';
import 'package:videoweb_flutter/services/app_prefs.dart';
import 'package:videoweb_flutter/services/theme_controller.dart';
import 'package:videoweb_flutter/theme/app_theme.dart';
import 'package:videoweb_flutter/utils/app_toast.dart';
import 'package:videoweb_flutter/utils/guest_account_helper.dart';

/// 游客完善账号：设置密码（必选）+ 绑定手机号（选填）
class GuestAccountSetupPage extends StatefulWidget {
  final UserInfo? user;

  const GuestAccountSetupPage({super.key, this.user});

  @override
  State<GuestAccountSetupPage> createState() => _GuestAccountSetupPageState();
}

class _GuestAccountSetupPageState extends State<GuestAccountSetupPage> {
  final ApiService _api = ApiService();
  final _formKey = GlobalKey<FormState>();
  final _phoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  String get _accountId => GuestAccountHelper.loginAccount(widget.user);

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);
    try {
      final prefs = context.read<AppPrefs>();
      final phone = _phoneCtrl.text.trim();
      final password = _passwordCtrl.text;
      if (phone.isEmpty && (prefs.password ?? '').isEmpty) {
        AppToast.show('本机未保存原密码，请重新游客登录后再试', context: context);
        return;
      }
      final deviceId = prefs.deviceId;
      final res = phone.isNotEmpty
          ? await _api.bindPhone({
              'phone': phone,
              'password': password,
              'device_id': deviceId,
            })
          : await _api.changePassword({
              'old_password': prefs.password ?? '',
              'new_password': password,
              'device_id': deviceId,
            });
      if (!mounted) return;
      if (ApiResult.isSuccess(res)) {
        prefs.password = password;
        if (phone.isNotEmpty) prefs.phone = phone;
        AppToast.show(
          phone.isNotEmpty ? '绑定成功，可用账号或手机号登录' : '密码设置成功，请用账号+密码登录',
          context: context,
        );
        Navigator.of(context).pop(true);
      } else {
        AppToast.show(ApiResult.getErrorMessage(res) ?? '保存失败', context: context);
      }
    } catch (_) {
      if (mounted) AppToast.show('网络错误', context: context);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _copyAccount() {
    final id = _accountId;
    if (id.isEmpty) return;
    Clipboard.setData(ClipboardData(text: id));
    AppToast.show('账号已复制', context: context);
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
    final accountLine = GuestAccountHelper.accountCopyLine(widget.user);

    return ProfileSubpageScaffold(
      title: '完善账号',
      body: SingleChildScrollView(
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
                    Text(
                      '您的登录账号',
                      style: TextStyle(fontSize: 12, color: colors.textHint),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            accountLine.isNotEmpty ? accountLine : '--',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: colors.textPrimary,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        if (_accountId.isNotEmpty)
                          TextButton.icon(
                            onPressed: _copyAccount,
                            icon: Icon(Icons.copy_rounded, size: 16, color: colors.accent),
                            label: Text('复制', style: TextStyle(color: colors.accent, fontWeight: FontWeight.w700)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '设置密码后，下次可用「账号 + 密码」登录；绑定手机号后，还可使用「手机号 + 密码」登录并换机恢复账号。',
                      style: TextStyle(fontSize: 12, height: 1.5, color: colors.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              ProfileThemedCard(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _sectionTitle(colors, Icons.lock_outline, '设置登录密码'),
                    const SizedBox(height: 12),
                    _passwordField(
                      colors,
                      controller: _passwordCtrl,
                      label: '登录密码',
                      hint: '至少6位',
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
                    const SizedBox(height: 22),
                    _sectionTitle(colors, Icons.phone_android_outlined, '绑定手机号'),
                    const SizedBox(height: 4),
                    Text(
                      '选填，不绑定也可仅使用账号登录',
                      style: TextStyle(fontSize: 12, color: colors.textHint),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _phoneCtrl,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(11),
                      ],
                      decoration: _fieldDecoration(colors, label: '手机号', hint: '可不填'),
                      validator: (v) {
                        final p = v?.trim() ?? '';
                        if (p.isEmpty) return null;
                        if (!RegExp(r'^1[3-9]\d{9}$').hasMatch(p)) return '请输入正确的手机号';
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
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
                            : const Text('保存', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
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

  Widget _sectionTitle(AppColors colors, IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 18, color: colors.accent),
        const SizedBox(width: 6),
        Text(text, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: colors.textPrimary)),
      ],
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

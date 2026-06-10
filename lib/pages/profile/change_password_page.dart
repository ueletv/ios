import 'package:flutter/material.dart';
import 'package:videoweb_flutter/utils/app_toast.dart';

import 'package:provider/provider.dart';
import 'package:videoweb_flutter/api/api_result.dart';
import 'package:videoweb_flutter/api/api_service.dart';
import 'package:videoweb_flutter/pages/profile/widgets/profile_subpage_scaffold.dart';
import 'package:videoweb_flutter/services/app_prefs.dart';
import 'package:videoweb_flutter/services/theme_controller.dart';
import 'package:videoweb_flutter/theme/app_theme.dart';

/// 修改密码页（对应原生 ProfileChangePasswordActivity.kt）
/// [guestMode] 为 true 时用于游客「设置密码」，自动使用本机保存的原密码
class ChangePasswordPage extends StatefulWidget {
  final bool guestMode;

  const ChangePasswordPage({super.key, this.guestMode = false});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final ApiService _api = ApiService();
  final _formKey = GlobalKey<FormState>();
  final _oldPwdCtrl = TextEditingController();
  final _newPwdCtrl = TextEditingController();
  final _confirmPwdCtrl = TextEditingController();
  bool _isLoading = false;
  bool _obscureOld = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);
    try {
      final prefs = context.read<AppPrefs>();
      final oldPassword = widget.guestMode ? (prefs.password ?? '') : _oldPwdCtrl.text;
      if (oldPassword.isEmpty) {
        _showToast(widget.guestMode ? '本机未保存原密码，请先绑定手机号' : '请输入原密码');
        return;
      }
      final res = await _api.changePassword({
        'old_password': oldPassword,
        'new_password': _newPwdCtrl.text,
        'device_id': prefs.deviceId,
      });
      if (ApiResult.isSuccess(res)) {
        prefs.password = _newPwdCtrl.text;
        _showToast(widget.guestMode ? '密码设置成功' : '密码修改成功');
        if (mounted) Navigator.of(context).pop(true);
      } else {
        _showToast(ApiResult.getErrorMessage(res) ?? '修改失败');
      }
    } catch (e) {
      _showToast('网络错误');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showToast(String msg) {
    if (!mounted) return;
    AppToast.show(msg, context: context);
  }

  @override
  void dispose() {
    _oldPwdCtrl.dispose();
    _newPwdCtrl.dispose();
    _confirmPwdCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    context.watch<ThemeController>();
    final colors = context.appColors;
    final guestMode = widget.guestMode;
    return ProfileSubpageScaffold(
      title: guestMode ? '设置登录密码' : '修改密码',
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (guestMode) ...[
                ProfileThemedCard(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    '设置后请用「账号 + 新密码」登录（账号在个人中心可复制）。换机登录请先绑定手机号。',
                    style: TextStyle(fontSize: 13, height: 1.45, color: colors.textSecondary),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              ProfileThemedCard(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                if (!guestMode) ...[
                  _buildPasswordField(colors, controller: _oldPwdCtrl, label: '原密码', hint: '请输入原密码', obscure: _obscureOld, onToggle: () => setState(() => _obscureOld = !_obscureOld), validator: (v) => (v == null || v.isEmpty) ? '请输入原密码' : null),
                  const SizedBox(height: 14),
                ],
                _buildPasswordField(colors, controller: _newPwdCtrl, label: '新密码', hint: '请输入新密码', obscure: _obscureNew, onToggle: () => setState(() => _obscureNew = !_obscureNew), validator: (v) {
                  if (v == null || v.isEmpty) return '请输入新密码';
                  if (v.length < 6) return '密码至少6位';
                  return null;
                }),
                const SizedBox(height: 14),
                _buildPasswordField(colors, controller: _confirmPwdCtrl, label: '确认新密码', hint: '请再次输入新密码', obscure: _obscureConfirm, onToggle: () => setState(() => _obscureConfirm = !_obscureConfirm), validator: (v) {
                  if (v == null || v.isEmpty) return '请确认新密码';
                  if (v != _newPwdCtrl.text) return '两次密码不一致';
                  return null;
                }),
                const SizedBox(height: 20),
                SizedBox(
                  height: 52,
                  child: FilledButton(
                    onPressed: _isLoading ? null : _submit,
                    style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                    child: _isLoading
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text(guestMode ? '确认设置' : '确认修改', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
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

  Widget _buildPasswordField(
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
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: colors.chipBg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        suffixIcon: IconButton(
          icon: Icon(obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined),
          onPressed: onToggle,
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:videoweb_flutter/utils/app_toast.dart';

import 'package:provider/provider.dart';
import 'package:videoweb_flutter/api/api_result.dart';
import 'package:videoweb_flutter/api/api_service.dart';
import 'package:videoweb_flutter/api/models/user.dart';
import 'package:videoweb_flutter/pages/profile/widgets/profile_subpage_scaffold.dart';
import 'package:videoweb_flutter/services/theme_controller.dart';
import 'package:videoweb_flutter/theme/app_theme.dart';
import 'package:videoweb_flutter/widgets/user_avatar.dart';

/// 编辑个人资料页（对应原生 ProfileEditActivity.kt）
class ProfileEditPage extends StatefulWidget {
  const ProfileEditPage({super.key});

  @override
  State<ProfileEditPage> createState() => _ProfileEditPageState();
}

class _ProfileEditPageState extends State<ProfileEditPage> {
  final ApiService _api = ApiService();
  final TextEditingController _nicknameCtrl = TextEditingController();
  UserInfo? _userInfo;
  bool _isLoading = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    setState(() => _isLoading = true);
    try {
      final res = await _api.getUserInfo();
      if (ApiResult.isSuccess(res)) {
        final data = res.data['data'] as Map<String, dynamic>?;
        if (data != null) {
          final user = UserInfo.fromJson(data);
          setState(() {
            _userInfo = user;
            _nicknameCtrl.text = user.nickname ?? user.username ?? '';
          });
        }
      }
    } catch (_) {}
    setState(() => _isLoading = false);
  }

  Future<void> _save() async {
    final nickname = _nicknameCtrl.text.trim();
    if (nickname.isEmpty) {
      _showToast('昵称不能为空');
      return;
    }
    setState(() => _isSaving = true);
    try {
      final res = await _api.updateUserInfo({'nickname': nickname});
      if (ApiResult.isSuccess(res)) {
        _showToast('保存成功');
        if (mounted) Navigator.of(context).pop();
      } else {
        _showToast(ApiResult.getErrorMessage(res) ?? '保存失败');
      }
    } catch (e) {
      _showToast('网络错误');
    }
    setState(() => _isSaving = false);
  }

  void _showToast(String msg) {
    if (!mounted) return;
    AppToast.show(msg, context: context);
  }

  @override
  void dispose() {
    _nicknameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    context.watch<ThemeController>();
    final colors = context.appColors;
    return ProfileSubpageScaffold(
      title: '编辑资料',
      actions: [
        FilledButton(
          onPressed: _isSaving ? null : _save,
          style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
          child: _isSaving
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('保存', style: TextStyle(fontWeight: FontWeight.w700)),
        ),
      ],
      body: _isLoading ? Center(child: CircularProgressIndicator(color: colors.accent)) : _buildForm(colors),
    );
  }

  Widget _buildForm(AppColors colors) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        ProfileThemedCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            children: [
              GestureDetector(
                onTap: () => _showToast('头像修改功能待实现'),
                child: Stack(
                  children: [
                    UserAvatar(
                      rawAvatar: _userInfo?.avatar,
                      size: 96,
                      useServerDefault: true,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(color: colors.accent, shape: BoxShape.circle),
                        child: const Icon(Icons.camera_alt_rounded, size: 16, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Text('点击更换头像', style: TextStyle(color: colors.textSecondary, fontSize: 13)),
              const SizedBox(height: 18),
              _buildFieldLabel(colors, '昵称'),
              const SizedBox(height: 8),
              TextField(
                controller: _nicknameCtrl,
                style: TextStyle(color: colors.textPrimary),
                decoration: InputDecoration(
                  hintText: '请输入昵称',
                  filled: true,
                  fillColor: colors.chipBg,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  counterText: '',
                ),
                maxLength: 20,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildInfoCard(colors, title: '账户信息', children: [
          _buildReadOnlyField(colors, '用户名', _userInfo?.username ?? '-'),
          _buildReadOnlyField(colors, '手机号', _userInfo?.phone ?? '-'),
          _buildReadOnlyField(colors, '邮箱', _userInfo?.email ?? '-'),
        ]),
      ],
    );
  }

  Widget _buildFieldLabel(AppColors colors, String text) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(text, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: colors.textPrimary)),
    );
  }

  Widget _buildInfoCard(AppColors colors, {required String title, required List<Widget> children}) {
    return ProfileThemedCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: colors.textPrimary)),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildReadOnlyField(AppColors colors, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(width: 80, child: Text(label, style: TextStyle(color: colors.textSecondary))),
          Expanded(child: Text(value, textAlign: TextAlign.right, style: TextStyle(color: colors.textPrimary))),
        ],
      ),
    );
  }
}

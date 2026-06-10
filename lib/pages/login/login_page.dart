import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:videoweb_flutter/api/api_result.dart';
import 'package:videoweb_flutter/api/api_service.dart';
import 'package:videoweb_flutter/api/models/user.dart';
import 'package:videoweb_flutter/services/app_prefs.dart';
import 'package:videoweb_flutter/services/app_config_cache.dart';
import 'package:videoweb_flutter/services/guest_auth_helper.dart';
import 'package:videoweb_flutter/services/theme_controller.dart';
import 'package:videoweb_flutter/widgets/home_logo.dart';
import 'package:videoweb_flutter/theme/app_theme.dart';

/// 登录页（对应原生 LoginActivity.kt：手机号 + 密码）
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginModeTab extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  final AppColors colors;

  const _LoginModeTab({
    required this.label,
    required this.active,
    required this.onTap,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final isLight = colors.pageBg.computeLuminance() > 0.5;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: active ? colors.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          boxShadow: active && isLight
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
          border: active && !isLight ? Border.all(color: colors.cardStroke, width: 0.5) : null,
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: active ? colors.accent : colors.textSecondary,
            fontWeight: active ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _LoginPageState extends State<LoginPage> {
  final ApiService _api = ApiService();

  /// false=账号登录（数字账号/用户名） true=手机号登录
  bool _isPhoneLogin = false;

  final TextEditingController _accountCtrl = TextEditingController();
  final TextEditingController _phoneCtrl = TextEditingController();
  final TextEditingController _passwordCtrl = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMsg;
  String? _siteLogoUrl;

  @override
  void initState() {
    super.initState();
    _siteLogoUrl = HomeLogo.logoFromConfig(AppConfigCache.cached);
    _loadSiteLogo();
    _accountCtrl.addListener(_onFormChanged);
    _phoneCtrl.addListener(_onFormChanged);
    _passwordCtrl.addListener(_onFormChanged);
    final prefs = context.read<AppPrefs>();
    final savedPhone = prefs.phone;
    final savedUsername = prefs.username;
    if (savedPhone != null && RegExp(r'^1[3-9]\d{9}$').hasMatch(savedPhone)) {
      _phoneCtrl.text = savedPhone;
    }
    if (savedUsername != null && savedUsername.isNotEmpty) {
      _accountCtrl.text = savedUsername;
    } else if (savedPhone != null &&
        savedPhone.isNotEmpty &&
        !RegExp(r'^1[3-9]\d{9}$').hasMatch(savedPhone)) {
      _accountCtrl.text = savedPhone;
    }
    final lastMode = prefs.lastLoginMode;
    if (lastMode == AppPrefs.loginModeAccount) {
      _isPhoneLogin = false;
    } else if (lastMode == AppPrefs.loginModePhone &&
        savedPhone != null &&
        RegExp(r'^1[3-9]\d{9}$').hasMatch(savedPhone)) {
      _isPhoneLogin = true;
    } else {
      _isPhoneLogin = savedUsername == null || savedUsername.isEmpty;
    }
  }

  Future<void> _loadSiteLogo() async {
    final logo = await HomeLogo.fetchLogoUrl();
    if (mounted && logo != null && logo.isNotEmpty) {
      setState(() => _siteLogoUrl = logo);
    }
  }

  Widget _buildLoginLogo(AppColors c) {
    final url = _siteLogoUrl;
    if (url != null && url.isNotEmpty) {
      return HomeLogo(
        logoUrl: url,
        maxHeight: 72,
        maxWidth: 160,
        borderRadius: BorderRadius.circular(12),
      );
    }
    return Container(
      width: 78,
      height: 78,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [c.accent, c.accent.withOpacity(0.68)],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: const Icon(Icons.play_circle_fill_rounded, size: 44, color: Colors.white),
    );
  }

  void _onFormChanged() {
    if (mounted) setState(() {});
  }

  /// 收起键盘后再读取输入，避免部分输入法未提交导致密码为空
  Future<({String account, String phone, String password})> _readFormFields() async {
    FocusScope.of(context).unfocus();
    await Future<void>.delayed(const Duration(milliseconds: 32));
    return (
      account: _accountCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      password: _passwordCtrl.text.trim(),
    );
  }

  @override
  void dispose() {
    _accountCtrl.removeListener(_onFormChanged);
    _phoneCtrl.removeListener(_onFormChanged);
    _passwordCtrl.removeListener(_onFormChanged);
    _accountCtrl.dispose();
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    setState(() {
      _isLoading = true;
      _errorMsg = null;
    });

    try {
      final prefs = context.read<AppPrefs>();
      final fields = await _readFormFields();
      final password = fields.password;
      if (password.isEmpty) {
        setState(() {
          _isLoading = false;
          _errorMsg = '请输入密码';
        });
        return;
      }

      if (_isPhoneLogin) {
        final phone = fields.phone;
        if (!RegExp(r'^1[3-9]\d{9}$').hasMatch(phone)) {
          setState(() {
            _isLoading = false;
            _errorMsg = '请输入正确的11位手机号';
          });
          return;
        }
        final res = await _api.loginByPhone({
          'phone': phone,
          'password': password,
          'device_id': prefs.deviceId,
        });
        if (!mounted) return;
        if (ApiResult.isSuccess(res)) {
          _saveLogin(prefs, res, phone: phone, password: password);
          Navigator.of(context).pop(true);
        } else {
          setState(() => _errorMsg = ApiResult.getErrorMessage(res) ?? '登录失败');
        }
      } else {
        final username = fields.account;
        if (username.isEmpty) {
          setState(() {
            _isLoading = false;
            _errorMsg = '请输入账号';
          });
          return;
        }
        final res = await _api.login({
          'username': username,
          'password': password,
          'device_id': prefs.deviceId,
        });
        if (!mounted) return;
        if (ApiResult.isSuccess(res)) {
          _saveLogin(prefs, res, username: username, password: password);
          Navigator.of(context).pop(true);
        } else {
          setState(() => _errorMsg = ApiResult.getErrorMessage(res) ?? '登录失败');
        }
      }
    } catch (e) {
      if (mounted) setState(() => _errorMsg = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _saveLogin(
    AppPrefs prefs,
    dynamic res, {
    String? phone,
    String? username,
    String? password,
  }) {
    final data = res.data['data'];
    if (data is! Map) return;
    final loginResp = LoginResponse.fromJson(Map<String, dynamic>.from(data));
    prefs.autoGuestLoginPaused = false;
    prefs.token = loginResp.token;
    if (phone != null && phone.isNotEmpty) {
      prefs.phone = phone;
      prefs.lastLoginMode = AppPrefs.loginModePhone;
    }
    if (username != null && username.isNotEmpty) {
      prefs.username = username;
      if (phone == null || phone.isEmpty) {
        prefs.lastLoginMode = AppPrefs.loginModeAccount;
      }
    } else if (loginResp.user.username?.isNotEmpty == true) {
      prefs.username = loginResp.user.username;
      if (phone == null || phone.isEmpty) {
        prefs.lastLoginMode = AppPrefs.loginModeAccount;
      }
    }
    if (password != null && password.isNotEmpty) {
      prefs.password = password;
    }
  }

  Future<void> _autoRegister() async {
    setState(() {
      _isLoading = true;
      _errorMsg = null;
    });

    final prefs = context.read<AppPrefs>();
    final fields = await _readFormFields();
    final password = fields.password;
    final phone = fields.phone;
    final account = fields.account;

    bool ok;
    if (_isPhoneLogin) {
      if (phone.isEmpty) {
        setState(() {
          _isLoading = false;
          _errorMsg = '请输入手机号';
        });
        return;
      }
      if (password.isEmpty) {
        setState(() {
          _isLoading = false;
          _errorMsg = '注册请设置登录密码';
        });
        return;
      }
      ok = await GuestAuthHelper.registerWithPhone(prefs, phone: phone, password: password);
    } else if (account.isNotEmpty && password.isNotEmpty) {
      ok = await GuestAuthHelper.registerWithUsername(
        prefs,
        username: account,
        password: password,
      );
    } else if (!_isPhoneLogin && password.isEmpty) {
      // 密码为空即游客恢复（忽略输入框预填账号）
      ok = await GuestAuthHelper.guestLogin(prefs);
    } else {
      setState(() {
        _isLoading = false;
        _errorMsg = account.isEmpty ? '注册请填写账号' : '注册请设置登录密码';
      });
      return;
    }

    if (!mounted) return;
    setState(() => _isLoading = false);
    if (ok) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() => _errorMsg = GuestAuthHelper.lastError ?? '注册失败');
  }

  String get _secondaryActionLabel {
    if (_isPhoneLogin) return '新用户？手机号注册';
    final password = _passwordCtrl.text.trim();
    if (password.isNotEmpty) return '没有账号？立即注册';
    return '游客登录';
  }

  bool get _canGuestLogin {
    if (_isPhoneLogin) return false;
    return _passwordCtrl.text.trim().isEmpty;
  }

  @override
  Widget build(BuildContext context) {
    context.watch<ThemeController>();
    final c = context.appColors;
    final isLight = c.pageBg.computeLuminance() > 0.5;

    return Scaffold(
      backgroundColor: c.pageBg,
      body: HomePageBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close_rounded, color: c.textSecondary),
                    label: Text('关闭', style: TextStyle(color: c.textSecondary)),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: c.cardBg,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: c.cardStroke, width: 0.5),
                    boxShadow: isLight
                        ? [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 24,
                              offset: const Offset(0, 12),
                            ),
                          ]
                        : null,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(child: _buildLoginLogo(c)),
                      const SizedBox(height: 18),
                      Center(
                        child: Text(
                          '登录',
                          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: c.textPrimary),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Center(
                        child: Text(
                          _isPhoneLogin
                              ? '使用已绑定的手机号登录'
                              : '使用账号和密码登录',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13, color: c.textSecondary),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: c.chipBg,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: _LoginModeTab(
                                label: '账号登录',
                                active: !_isPhoneLogin,
                                colors: c,
                                onTap: () => setState(() => _isPhoneLogin = false),
                              ),
                            ),
                            Expanded(
                              child: _LoginModeTab(
                                label: '手机号登录',
                                active: _isPhoneLogin,
                                colors: c,
                                onTap: () => setState(() => _isPhoneLogin = true),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      if (_errorMsg != null)
                        Container(
                          padding: const EdgeInsets.all(14),
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(isLight ? 0.08 : 0.16),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.red.withOpacity(isLight ? 0.25 : 0.35)),
                          ),
                          child: Text(
                            _errorMsg!,
                            style: TextStyle(color: isLight ? Colors.red.shade700 : const Color(0xFFFF8A8A), fontSize: 14),
                          ),
                        ),
                      if (_isPhoneLogin) ...[
                        _buildInputField(
                          c: c,
                          controller: _phoneCtrl,
                          label: '手机号',
                          icon: Icons.phone_rounded,
                          keyboardType: TextInputType.phone,
                        ),
                      ] else ...[
                        _buildInputField(
                          c: c,
                          controller: _accountCtrl,
                          label: '账号',
                          icon: Icons.person_rounded,
                          hintText: '请输入账号',
                        ),
                      ],
                      const SizedBox(height: 14),
                      _buildInputField(
                        c: c,
                        controller: _passwordCtrl,
                        label: '密码',
                        icon: Icons.lock_rounded,
                        obscureText: _obscurePassword,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => FocusScope.of(context).unfocus(),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                            color: c.textHint,
                          ),
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        height: 52,
                        child: FilledButton(
                          onPressed: _isLoading ? null : _login,
                          child: _isLoading
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                                )
                              : const Text('登录', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                        ),
                      ),
                      if (_canGuestLogin) ...[
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 48,
                          child: OutlinedButton(
                            onPressed: _isLoading ? null : _autoRegister,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: c.accent,
                              side: BorderSide(color: c.accent.withOpacity(0.55)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            child: const Text('游客登录', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                          ),
                        ),
                      ],
                      if (!_canGuestLogin) ...[
                        const SizedBox(height: 6),
                        TextButton(
                          onPressed: _isLoading ? null : _autoRegister,
                          child: Text(_secondaryActionLabel, style: TextStyle(color: c.accent)),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputField({
    required AppColors c,
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hintText,
    TextInputType? keyboardType,
    TextInputAction? textInputAction,
    bool obscureText = false,
    Widget? suffixIcon,
    ValueChanged<String>? onSubmitted,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      textInputAction: textInputAction,
      onSubmitted: onSubmitted,
      style: TextStyle(color: c.textPrimary),
      cursorColor: c.accent,
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        labelStyle: TextStyle(color: c.textSecondary),
        hintStyle: TextStyle(color: c.textHint),
        prefixIcon: Icon(icon, color: c.textHint),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: c.chipBg,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: c.cardStroke),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: c.accent, width: 1.4),
        ),
      ),
    );
  }
}

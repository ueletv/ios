import 'dart:math';

import 'package:dio/dio.dart';
import 'package:videoweb_flutter/api/api_result.dart';
import 'package:videoweb_flutter/api/api_service.dart';
import 'package:videoweb_flutter/services/app_prefs.dart';

/// 游客自动注册 / 登录态管理（对齐 Vue autoRegister.js + 原生 GuestAuthHelper.kt）
class GuestAuthHelper {
  static final ApiService _api = ApiService();
  static bool _registering = false;
  static Future<bool>? _registerFuture;
  static String? lastError;

  /// 确保有有效 token（本机恢复 → 账号密码登录 → 同 IP 恢复 → 新建游客）
  static Future<bool> ensureToken(AppPrefs prefs) async {
    if (_registering && _registerFuture != null) {
      return _registerFuture!;
    }
    _registerFuture = _ensureTokenInternal(prefs);
    _registering = true;
    try {
      return await _registerFuture!;
    } finally {
      _registering = false;
      _registerFuture = null;
    }
  }

  /// 游客一键登录（登录页专用，忽略输入框里预填的账号）
  static Future<bool> guestLogin(AppPrefs prefs) {
    prefs.autoGuestLoginPaused = false;
    return ensureToken(prefs);
  }

  static Future<bool> _ensureTokenInternal(AppPrefs prefs) async {
    lastError = null;

    if (prefs.autoGuestLoginPaused) {
      return false;
    }

    if (prefs.isLoggedIn) {
      if (await _validateToken()) return true;
      prefs.clearToken();
    }

    if (_isMobilePhone(prefs.phone) && (prefs.password?.isNotEmpty ?? false)) {
      if (await _tryPhoneLogin(prefs)) return true;
    }

    final username = prefs.username?.trim();
    if (username != null &&
        username.isNotEmpty &&
        !_isMobilePhone(username) &&
        (prefs.password?.isNotEmpty ?? false)) {
      if (await _tryUsernameLogin(prefs, username)) return true;
    }

    if (!await _isAutoRegisterEnabled()) {
      lastError ??= '自动注册已关闭，请登录';
      return false;
    }

    return autoRegister(prefs);
  }

  /// 账号 + 密码手动注册
  static Future<bool> registerWithUsername(
    AppPrefs prefs, {
    required String username,
    required String password,
  }) async {
    lastError = null;
    final u = username.trim();
    final p = password.trim();
    if (u.isEmpty) {
      lastError = '请输入账号';
      return false;
    }
    if (p.isEmpty) {
      lastError = '请设置登录密码';
      return false;
    }
    try {
      final res = await _api.register(_registerBody(prefs, {
        'username': u,
        'password': p,
      }));
      if (!ApiResult.isSuccess(res)) {
        lastError = ApiResult.getErrorMessage(res) ?? '注册失败';
        return false;
      }
      final ok = await _applyAuthResponse(prefs, res, fallbackPassword: p);
      if (ok) {
        prefs.username = u;
        prefs.password = p;
        prefs.lastLoginMode = AppPrefs.loginModeAccount;
      }
      return ok;
    } on DioException catch (e) {
      lastError = ApiResult.parseDioError(e) ?? '网络错误';
      return false;
    } catch (e) {
      lastError = e.toString();
      return false;
    }
  }

  /// 手机号手动注册（auto_register 关闭时必须带手机号）
  static Future<bool> registerWithPhone(
    AppPrefs prefs, {
    required String phone,
    required String password,
  }) async {
    lastError = null;
    final p = phone.trim();
    if (!_isMobilePhone(p)) {
      lastError = '请输入正确的11位手机号';
      return false;
    }
    if (password.trim().isEmpty) {
      lastError = '请设置登录密码';
      return false;
    }
    try {
      final res = await _api.register(_registerBody(prefs, {
        'username': '',
        'password': password.trim(),
        'phone': p,
      }));
      if (!ApiResult.isSuccess(res)) {
        lastError = ApiResult.getErrorMessage(res) ?? '注册失败';
        return false;
      }
      final ok = await _applyAuthResponse(prefs, res, fallbackPassword: password.trim());
      if (ok) {
        prefs.phone = p;
        prefs.password = password.trim();
        prefs.lastLoginMode = AppPrefs.loginModePhone;
      }
      return ok;
    } on DioException catch (e) {
      lastError = ApiResult.parseDioError(e) ?? '网络错误';
      return false;
    } catch (e) {
      lastError = e.toString();
      return false;
    }
  }

  /// 游客自动注册 / 同 IP 恢复（无需填表）
  static Future<bool> autoRegister(AppPrefs prefs) async {
    lastError = null;

    if (!await _isAutoRegisterEnabled()) {
      lastError = '自动注册已关闭，请使用手机号注册';
      return false;
    }

    final savedPassword = prefs.password;
    final password = _generatePassword();
    try {
      final res = await _api.register(_registerBody(prefs, {
        'username': '',
        'password': password,
      }));
      if (!ApiResult.isSuccess(res)) {
        lastError = ApiResult.getErrorMessage(res) ?? '注册失败';
        return false;
      }
      final data = res.data;
      if (data is! Map) return false;
      final payload = data['data'];
      final autoLogin = payload is Map &&
          (payload['auto_login'] == true || payload['auto_login']?.toString() == '1');

      if (autoLogin) {
        final ok = await _applyAuthResponse(prefs, res);
        if (ok && savedPassword != null && savedPassword.isNotEmpty) {
          prefs.password = savedPassword;
        }
        return ok;
      }
      return _applyAuthResponse(prefs, res, fallbackPassword: password);
    } on DioException catch (e) {
      lastError = ApiResult.parseDioError(e) ?? '网络错误';
      return false;
    } catch (e) {
      lastError = e.toString();
      return false;
    }
  }

  static Future<bool> _applyAuthResponse(
    AppPrefs prefs,
    Response res, {
    String? fallbackPassword,
  }) async {
    final data = res.data;
    if (data is! Map) return false;
    final payload = data['data'];
    if (payload is! Map) {
      lastError = '注册/登录返回数据异常';
      return false;
    }

    final map = Map<String, dynamic>.from(payload);
    final token = map['token']?.toString();
    if (token == null || token.isEmpty) {
      lastError = '未返回 token';
      return false;
    }

    prefs.token = token;
    prefs.autoGuestLoginPaused = false;

    final autoLogin = map['auto_login'] == true || map['auto_login']?.toString() == '1';
    Map<String, dynamic>? user;
    if (map['user'] is Map) {
      user = Map<String, dynamic>.from(map['user'] as Map);
    }

    if (user == null) {
      user = await _fetchUserMap();
    }

    if (user != null) {
      final username = user['username']?.toString();
      if (username != null && username.isNotEmpty) {
        prefs.username = username;
        if (!_isMobilePhone(prefs.phone)) {
          prefs.phone = null;
        }
      }
      final boundPhone = user['phone']?.toString();
      if (_isMobilePhone(boundPhone)) {
        prefs.phone = boundPhone;
        if (prefs.lastLoginMode == null) {
          prefs.lastLoginMode = AppPrefs.loginModePhone;
        }
      } else if (username != null && username.isNotEmpty && prefs.lastLoginMode == null) {
        prefs.lastLoginMode = AppPrefs.loginModeAccount;
      }
    }

    if (autoLogin) {
      // 本机恢复已绑定账号：保存手机号/账号，重装后同设备可自动恢复
      if (user != null) {
        final boundPhone = user['phone']?.toString();
        if (_isMobilePhone(boundPhone)) {
          prefs.phone = boundPhone;
        }
      }
    } else if (fallbackPassword != null && fallbackPassword.isNotEmpty) {
      prefs.password = fallbackPassword;
    }

    return true;
  }

  static Future<Map<String, dynamic>?> _fetchUserMap() async {
    try {
      final res = await _api.getUserInfo();
      if (!ApiResult.isSuccess(res)) return null;
      final data = res.data['data'];
      if (data is Map) return Map<String, dynamic>.from(data);
    } catch (_) {}
    return null;
  }

  static Future<bool> _validateToken() async {
    try {
      final res = await _api.getUserInfo();
      return ApiResult.isSuccess(res);
    } catch (_) {
      return false;
    }
  }

  static Future<bool> _tryPhoneLogin(AppPrefs prefs) async {
    final phone = prefs.phone?.trim();
    final password = prefs.password;
    if (!_isMobilePhone(phone) || password == null || password.isEmpty) return false;
    try {
      final res = await _api.loginByPhone(_authBody(prefs, {
        'phone': phone!,
        'password': password,
      }));
      if (!ApiResult.isSuccess(res)) return false;
      return _applyAuthResponse(prefs, res, fallbackPassword: password);
    } catch (_) {
      return false;
    }
  }

  static Future<bool> _tryUsernameLogin(AppPrefs prefs, String username) async {
    final password = prefs.password;
    if (password == null || password.isEmpty) return false;
    try {
      final res = await _api.login(_authBody(prefs, {
        'username': username,
        'password': password,
      }));
      if (!ApiResult.isSuccess(res)) return false;
      return _applyAuthResponse(prefs, res, fallbackPassword: password);
    } catch (_) {
      return false;
    }
  }

  static Future<bool> _isAutoRegisterEnabled() async {
    try {
      final res = await _api.getConfig();
      if (!ApiResult.isSuccess(res)) return true;
      final data = res.data['data'];
      if (data is Map) {
        if (data['register_enabled']?.toString() == '0') return false;
        if (data['auto_register']?.toString() == '0') return false;
      }
    } catch (_) {}
    return true;
  }

  static bool _isMobilePhone(String? value) {
    if (value == null) return false;
    return RegExp(r'^1[3-9]\d{9}$').hasMatch(value.trim());
  }

  static Map<String, String> _registerBody(AppPrefs prefs, Map<String, String> fields) {
    return _authBody(prefs, fields);
  }

  static Map<String, String> _authBody(AppPrefs prefs, Map<String, String> fields) {
    return {
      ...fields,
      'device_id': prefs.deviceId,
    };
  }

  static String _generatePassword() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random.secure();
    final body = List.generate(12, (_) => chars[random.nextInt(chars.length)]).join();
    return 'p$body';
  }

  /// 401 时清 token 后重试一次
  static Future<Response?> callWithAuthRetry(
    AppPrefs prefs,
    Future<Response> Function() block,
  ) async {
    if (!await ensureToken(prefs)) {
      if (!await autoRegister(prefs)) return null;
    }
    try {
      var res = await block();
      if (res.statusCode == 401) {
        prefs.clearToken();
        if (!await ensureToken(prefs)) return null;
        res = await block();
      }
      return res;
    } catch (_) {
      return null;
    }
  }
}

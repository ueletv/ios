import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:videoweb_flutter/services/device_id_service.dart';

/// 本地持久化存储（对应原生 AppPrefs.kt）
class AppPrefs extends ChangeNotifier {
  static const _keyToken = 'token';
  static const _keyPhone = 'phone';
  static const _keyUsername = 'username';
  static const _keyPassword = 'password';
  static const _keyApiBaseUrl = 'api_base_url';
  static const _keyImageBaseUrl = 'image_base_url';
  static const _keyDefaultAvatarUrl = 'default_avatar_url';
  static const _keyOpenLiveWithFollow = 'open_live_with_follow';
  static const _keySplashAdShownIds = 'splash_ad_shown_ids';
  static const _keyPopupAdShownIds = 'popup_ad_shown_ids';
  static const _keyPopupAdShownDate = 'popup_ad_shown_date';
  static const _keyThemeMode = 'theme_mode';
  static const _keyLoginDayCount = 'login_day_count';
  static const _keyLastLoginDate = 'last_login_record_date';
  static const _keyCachedLevelIcon = 'cached_level_icon';
  static const _keyShareReportDay = 'share_report_day';
  static const _keyShareReportVideoIds = 'share_report_video_ids';
  static const _keyDeviceId = 'device_id';
  static const _keyAutoGuestLoginPaused = 'auto_guest_login_paused';
  static const _keyLastLoginMode = 'last_login_mode';

  static const loginModePhone = 'phone';
  static const loginModeAccount = 'account';

  static const themeLight = 'light';
  static const themeDark = 'dark';
  static const themeSystem = 'system';

  late SharedPreferences _prefs;

  // 单例
  static final AppPrefs _instance = AppPrefs._();
  factory AppPrefs() => _instance;
  AppPrefs._();

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    await _ensureDeviceId();
  }

  Future<void> _ensureDeviceId() async {
    final cached = _prefs.getString(_keyDeviceId);
    if (cached != null && DeviceIdService.isValid(cached)) return;
    final stableId = await DeviceIdService.resolveStableId();
    await _prefs.setString(_keyDeviceId, stableId);
  }

  // ========= Token =========

  String? get token => _prefs.getString(_keyToken);
  set token(String? value) {
    if (value == null) {
      _prefs.remove(_keyToken);
    } else {
      _prefs.setString(_keyToken, value);
    }
    notifyListeners();
  }

  // ========= Phone/Username =========

  String? get phone => _prefs.getString(_keyPhone);
  set phone(String? value) {
    if (value == null) {
      _prefs.remove(_keyPhone);
    } else {
      _prefs.setString(_keyPhone, value);
    }
    notifyListeners();
  }

  String? get username => _prefs.getString(_keyUsername);
  set username(String? value) {
    if (value == null) {
      _prefs.remove(_keyUsername);
    } else {
      _prefs.setString(_keyUsername, value);
    }
    notifyListeners();
  }

  // ========= 本机设备标识（游客恢复用，退出登录不清除）=========

  String get deviceId {
    final id = _prefs.getString(_keyDeviceId);
    if (id != null && DeviceIdService.isValid(id)) return id;
    // init() 应已写入；极端情况下回退随机 ID
    final fallback = DeviceIdService.generate();
    _prefs.setString(_keyDeviceId, fallback);
    return fallback;
  }

  // ========= 上次登录方式（退出后登录页恢复用）=========

  String? get lastLoginMode => _prefs.getString(_keyLastLoginMode);
  set lastLoginMode(String? value) {
    if (value == null || value.isEmpty) {
      _prefs.remove(_keyLastLoginMode);
    } else {
      _prefs.setString(_keyLastLoginMode, value);
    }
    notifyListeners();
  }

  // ========= Password =========

  String? get password => _prefs.getString(_keyPassword);
  set password(String? value) {
    if (value == null) {
      _prefs.remove(_keyPassword);
    } else {
      _prefs.setString(_keyPassword, value);
    }
    notifyListeners();
  }

  // ========= 配置 =========

  String? get apiBaseUrl => _prefs.getString(_keyApiBaseUrl);
  set apiBaseUrl(String? value) {
    if (value == null) {
      _prefs.remove(_keyApiBaseUrl);
    } else {
      _prefs.setString(_keyApiBaseUrl, value);
    }
  }

  String? get imageBaseUrl => _prefs.getString(_keyImageBaseUrl);
  set imageBaseUrl(String? value) {
    if (value == null) {
      _prefs.remove(_keyImageBaseUrl);
    } else {
      _prefs.setString(_keyImageBaseUrl, value);
    }
  }

  String? get defaultAvatarUrl => _prefs.getString(_keyDefaultAvatarUrl);
  set defaultAvatarUrl(String? value) {
    if (value == null) {
      _prefs.remove(_keyDefaultAvatarUrl);
    } else {
      _prefs.setString(_keyDefaultAvatarUrl, value);
    }
  }

  /// 缓存用户等级图标（对齐原生 UserProfileCache KEY_LEVEL_ICON）
  String? get cachedLevelIcon => _prefs.getString(_keyCachedLevelIcon);
  set cachedLevelIcon(String? value) {
    if (value == null || value.trim().isEmpty) {
      _prefs.remove(_keyCachedLevelIcon);
    } else {
      _prefs.setString(_keyCachedLevelIcon, value.trim());
    }
  }

  // ========= 其他 =========

  bool get openLiveWithFollow => _prefs.getBool(_keyOpenLiveWithFollow) ?? false;
  set openLiveWithFollow(bool value) => _prefs.setBool(_keyOpenLiveWithFollow, value);

  Set<String> get splashAdShownIds =>
      _prefs.getStringList(_keySplashAdShownIds)?.toSet() ?? {};

  void markSplashAdShown(int adId) {
    final ids = splashAdShownIds.toList()..add(adId.toString());
    _prefs.setStringList(_keySplashAdShownIds, ids);
  }

  bool hasSplashAdBeenShown(int adId) => splashAdShownIds.contains(adId.toString());

  void _resetPopupAdShownIfDayChanged() {
    final today = _todayDateKey();
    final last = _prefs.getString(_keyPopupAdShownDate);
    if (last == today) return;
    _prefs.remove(_keyPopupAdShownIds);
    _prefs.setString(_keyPopupAdShownDate, today);
  }

  Set<String> get popupAdShownIds {
    _resetPopupAdShownIfDayChanged();
    return _prefs.getStringList(_keyPopupAdShownIds)?.toSet() ?? {};
  }

  void markPopupAdShown(int adId) {
    if (adId <= 0) return;
    _resetPopupAdShownIfDayChanged();
    final ids = popupAdShownIds.toList();
    final key = adId.toString();
    if (!ids.contains(key)) ids.add(key);
    _prefs.setStringList(_keyPopupAdShownIds, ids);
    _prefs.setString(_keyPopupAdShownDate, _todayDateKey());
  }

  bool hasPopupAdBeenShown(int adId) {
    if (adId <= 0) return false;
    _resetPopupAdShownIfDayChanged();
    return popupAdShownIds.contains(adId.toString());
  }

  String get themeMode => _prefs.getString(_keyThemeMode) ?? themeDark;
  set themeMode(String value) => _prefs.setString(_keyThemeMode, value);

  int get loginDayCount => _prefs.getInt(_keyLoginDayCount) ?? 0;

  String _todayDateKey() => DateTime.now().toIso8601String().substring(0, 10);

  Set<String> _shareReportedVideoIdsToday() {
    if (_prefs.getString(_keyShareReportDay) != _todayDateKey()) return {};
    return _prefs.getStringList(_keyShareReportVideoIds)?.toSet() ?? {};
  }

  bool hasShareReportedToday(String videoId) {
    final id = videoId.trim();
    if (id.isEmpty) return false;
    return _shareReportedVideoIdsToday().contains(id);
  }

  void markShareReportedToday(String videoId) {
    final id = videoId.trim();
    if (id.isEmpty) return;
    final today = _todayDateKey();
    if (_prefs.getString(_keyShareReportDay) != today) {
      _prefs.setString(_keyShareReportDay, today);
      _prefs.setStringList(_keyShareReportVideoIds, [id]);
      return;
    }
    final ids = _shareReportedVideoIdsToday().toList();
    if (!ids.contains(id)) {
      ids.add(id);
      _prefs.setStringList(_keyShareReportVideoIds, ids);
    }
  }

  void recordDailyLogin() {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final last = _prefs.getString(_keyLastLoginDate);
    if (last == today) return;
    final count = last == null ? 1 : loginDayCount + 1;
    _prefs.setInt(_keyLoginDayCount, count);
    _prefs.setString(_keyLastLoginDate, today);
  }

  /// 用户主动退出后暂停自动游客登录（须手动点「游客登录」）
  bool get autoGuestLoginPaused => _prefs.getBool(_keyAutoGuestLoginPaused) ?? false;
  set autoGuestLoginPaused(bool value) {
    if (value) {
      _prefs.setBool(_keyAutoGuestLoginPaused, true);
    } else {
      _prefs.remove(_keyAutoGuestLoginPaused);
    }
    notifyListeners();
  }

  /// 仅清除 token（401 后保留账号密码以便重新登录）
  void clearToken() {
    if (token == null) return;
    _prefs.remove(_keyToken);
    notifyListeners();
  }

  /// 退出登录：保留本机账号信息，但不再自动恢复登录
  void logoutKeepingAccount() {
    autoGuestLoginPaused = true;
    clearToken();
  }

  /// 切换账号时调用：生成新的本机设备标识，避免仍关联旧游客
  void resetDeviceId() {
    _prefs.setString(_keyDeviceId, DeviceIdService.generate());
  }

  /// 清除登录状态（不含 device_id；切换账号请用 [resetForAccountSwitch]）
  void clearLogin() {
    _prefs.remove(_keyToken);
    _prefs.remove(_keyPhone);
    _prefs.remove(_keyUsername);
    _prefs.remove(_keyPassword);
    _prefs.remove(_keyAutoGuestLoginPaused);
    notifyListeners();
  }

  /// 切换账号：清除登录信息并更换本机设备标识
  void resetForAccountSwitch() {
    clearLogin();
    resetDeviceId();
  }

  /// 是否已登录（是否有 token）
  bool get isLoggedIn => token != null && token!.isNotEmpty;

}

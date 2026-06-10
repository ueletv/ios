import 'package:flutter/material.dart';
import 'package:videoweb_flutter/services/app_prefs.dart';
import 'package:videoweb_flutter/theme/app_theme.dart';

/// 主题切换（对应 ThemeManager.kt）
class ThemeController extends ChangeNotifier {
  ThemeController(this._prefs);

  final AppPrefs _prefs;

  String get themeMode => _prefs.themeMode;

  ThemeMode get materialThemeMode => AppTheme.themeModeFromPrefs(_prefs.themeMode);

  String get themeHint => AppTheme.themeHint(_prefs.themeMode);

  void setThemeMode(String mode) {
    if (_prefs.themeMode == mode) return;
    _prefs.themeMode = mode;
    notifyListeners();
  }
}

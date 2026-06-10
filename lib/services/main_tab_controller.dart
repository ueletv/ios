import 'package:flutter/foundation.dart';

/// 主界面底部 Tab 切换（对应原生 MainActivity.switchMainTab）
class MainTabController extends ChangeNotifier {
  static const tabHome = 0;
  static const tabHot = 1;
  static const tabGame = 2;
  static const tabLive = 3;
  static const tabProfile = 4;

  int _index = tabHome;
  bool _openLiveFollow = false;
  int _reselectToken = 0;

  int get index => _index;
  bool get openLiveFollow => _openLiveFollow;
  int get reselectToken => _reselectToken;

  void switchTo(int index) {
    if (_index == index) {
      _reselectToken++;
      notifyListeners();
      return;
    }
    _index = index;
    notifyListeners();
  }

  /// 个人中心「关注」→ 直播 Tab 并加载关注列表
  void switchToLiveFollow() {
    _openLiveFollow = true;
    _index = tabLive;
    notifyListeners();
  }

  bool consumeLiveFollow() {
    if (!_openLiveFollow) return false;
    _openLiveFollow = false;
    return true;
  }
}

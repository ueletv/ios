/// 弹窗广告当次启动去重（show_once=1 仅在本进程内生效，下次冷启动重新展示）
class PopupAdSession {
  PopupAdSession._();

  static final Set<int> _shownIds = {};

  static bool canShow(int adId, int showOnce) {
    if (adId <= 0) return false;
    if (showOnce != 1) return true;
    return !_shownIds.contains(adId);
  }

  static void markShown(int adId, int showOnce) {
    if (adId <= 0 || showOnce != 1) return;
    _shownIds.add(adId);
  }
}

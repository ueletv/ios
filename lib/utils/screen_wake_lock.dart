import 'package:wakelock_plus/wakelock_plus.dart';

/// 播放视频/直播时保持屏幕常亮，避免系统按息屏时间自动锁屏。
class ScreenWakeLock {
  ScreenWakeLock._();

  static int _holdCount = 0;

  static Future<void> acquire() async {
    _holdCount++;
    if (_holdCount == 1) {
      try {
        await WakelockPlus.enable();
      } catch (_) {}
    }
  }

  static Future<void> release() async {
    if (_holdCount <= 0) return;
    _holdCount--;
    if (_holdCount == 0) {
      try {
        await WakelockPlus.disable();
      } catch (_) {}
    }
  }
}

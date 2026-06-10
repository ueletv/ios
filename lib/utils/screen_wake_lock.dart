import 'package:flutter/services.dart';

/// 播放视频/直播时保持屏幕常亮（Android FLAG_KEEP_SCREEN_ON / iOS 关闭 idleTimer）
class ScreenWakeLock {
  ScreenWakeLock._();

  static const _channel = MethodChannel('com.video.videoweb/player_controls');
  static int _holdCount = 0;

  static Future<void> acquire() async {
    _holdCount++;
    if (_holdCount == 1) {
      try {
        await _channel.invokeMethod<void>('enableWakeLock');
      } catch (_) {}
    }
  }

  static Future<void> release() async {
    if (_holdCount <= 0) return;
    _holdCount--;
    if (_holdCount == 0) {
      try {
        await _channel.invokeMethod<void>('disableWakeLock');
      } catch (_) {}
    }
  }
}

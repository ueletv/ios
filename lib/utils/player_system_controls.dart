import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 播放器系统亮度/音量（对齐原生 VideoPlayerGestureController + AudioManager）
class PlayerSystemControls {
  static const _channel = MethodChannel('com.video.videoweb/player_controls');

  static Future<double> getBrightness() async {
    if (kIsWeb) return 0.5;
    try {
      final value = await _channel.invokeMethod<double>('getBrightness');
      return (value ?? 0.5).clamp(0.02, 1.0);
    } catch (_) {
      return 0.5;
    }
  }

  static Future<void> setBrightness(double value) async {
    if (kIsWeb) return;
    try {
      await _channel.invokeMethod('setBrightness', {
        'value': value.clamp(0.02, 1.0),
      });
    } catch (_) {}
  }

  static Future<({int volume, int max})> getVolume() async {
    if (kIsWeb) return (volume: 5, max: 15);
    try {
      final map = await _channel.invokeMethod<Map>('getVolume');
      final volume = map?['volume'];
      final max = map?['max'];
      final maxVol = max is int ? max : (max is num ? max.toInt() : 15);
      final cur = volume is int ? volume : (volume is num ? volume.toInt() : 0);
      return (volume: cur, max: maxVol.clamp(1, 100));
    } catch (_) {
      return (volume: 5, max: 15);
    }
  }

  static Future<void> setVolume(int volume) async {
    if (kIsWeb) return;
    try {
      await _channel.invokeMethod('setVolume', {'volume': volume});
    } catch (_) {}
  }
}

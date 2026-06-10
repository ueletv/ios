import 'dart:io';
import 'dart:math';

import 'package:flutter/services.dart';

/// 本机设备标识（游客恢复用）
///
/// Android 使用 ANDROID_ID；iOS 使用 Keychain + IDFV；其他平台回退随机 UUID。
class DeviceIdService {
  static const _channel = MethodChannel('com.video.videoweb/device_id');
  static final RegExp _validPattern = RegExp(r'^[a-zA-Z0-9\-]{8,64}$');

  static bool isValid(String id) {
    final s = id.trim();
    return s.length >= 8 && s.length <= 64 && _validPattern.hasMatch(s);
  }

  /// 获取可跨重装保持稳定的设备 ID（与 Go validDeviceID 规则一致）
  static Future<String> resolveStableId() async {
    if (Platform.isAndroid || Platform.isIOS) {
      try {
        final method = Platform.isAndroid ? 'getAndroidId' : 'getStableDeviceId';
        final id = await _channel.invokeMethod<String>(method);
        final trimmed = id?.trim() ?? '';
        if (isValid(trimmed)) return trimmed;
      } catch (_) {}
    }
    return generate();
  }

  /// 切换账号时生成新的随机标识，避免关联旧游客
  static String generate() {
    final r = Random.secure();
    final bytes = List<int>.generate(16, (_) => r.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-'
        '${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-'
        '${hex.substring(16, 20)}-'
        '${hex.substring(20, 32)}';
  }
}

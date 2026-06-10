import 'dart:io';

import 'package:flutter/services.dart';

/// 注册/登录时上报设备型号（后台 device_type 展示用）
class DeviceInfoService {
  static const _channel = MethodChannel('com.video.videoweb/device_id');

  static String? _cachedUserAgent;

  /// 与 PHP parseDeviceInfo 兼容的 User-Agent（含 Android 型号）
  static Future<String> appUserAgent() async {
    if (_cachedUserAgent != null) return _cachedUserAgent!;
    if (Platform.isAndroid) {
      try {
        final ua = await _channel.invokeMethod<String>('getUserAgent');
        final trimmed = ua?.trim() ?? '';
        if (trimmed.isNotEmpty) {
          _cachedUserAgent = trimmed;
          return trimmed;
        }
      } catch (_) {}
      _cachedUserAgent =
          'Mozilla/5.0 (Linux; Android; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36 VideoWebApp/1.0';
      return _cachedUserAgent!;
    }
    if (Platform.isIOS) {
      try {
        final ua = await _channel.invokeMethod<String>('getUserAgent');
        final trimmed = ua?.trim() ?? '';
        if (trimmed.isNotEmpty) {
          _cachedUserAgent = trimmed;
          return trimmed;
        }
      } catch (_) {}
      _cachedUserAgent =
          'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148 VideoWebApp/1.0';
      return _cachedUserAgent!;
    }
    _cachedUserAgent = 'VideoWebApp/1.0';
    return _cachedUserAgent!;
  }
}

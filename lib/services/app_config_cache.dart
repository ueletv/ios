import 'package:videoweb_flutter/api/api_result.dart';
import 'package:videoweb_flutter/api/api_service.dart';

/// 全局 config 缓存，避免各页面重复请求 /config 导致连接堆积
class AppConfigCache {
  AppConfigCache._();

  static Map<String, dynamic>? _data;
  static DateTime? _fetchedAt;
  static Future<Map<String, dynamic>?>? _inflight;
  static const _ttl = Duration(minutes: 5);

  static Map<String, dynamic>? get cached => _data;

  static Future<Map<String, dynamic>?> fetch({bool force = false}) async {
    final cached = _data;
    final at = _fetchedAt;
    if (!force && cached != null && at != null && DateTime.now().difference(at) < _ttl) {
      return cached;
    }
    if (_inflight != null) return _inflight!;

    _inflight = _load();
    try {
      return await _inflight!;
    } finally {
      _inflight = null;
    }
  }

  static Future<Map<String, dynamic>?> _load() async {
    try {
      final res = await ApiService().getConfig();
      if (ApiResult.isSuccess(res)) {
        final data = res.data['data'];
        if (data is Map) {
          _data = Map<String, dynamic>.from(data);
          _fetchedAt = DateTime.now();
          return _data;
        }
      }
    } catch (_) {}
    return _data;
  }

  static void clear() {
    _data = null;
    _fetchedAt = null;
    _inflight = null;
  }
}

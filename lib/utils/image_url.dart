import 'package:videoweb_flutter/api/api_client.dart';
import 'package:videoweb_flutter/services/app_config_cache.dart';
import 'package:videoweb_flutter/services/app_prefs.dart';

/// 图片 URL 处理工具（对应原生 ImageUrl.kt + Vue utils/imageUrl.ts）
class ImageUrl {
  static String? _baseUrl;

  static void setBaseUrl(String? url) {
    final trimmed = url?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      _baseUrl = null;
      return;
    }
    _baseUrl = trimmed.endsWith('/') ? trimmed.substring(0, trimmed.length - 1) : trimmed;
  }

  static String? get baseUrl => _baseUrl;

  /// 与原生 normalizeImageBase 对齐
  static String normalizeImageBase(String raw) {
    final t = raw.trim().replaceAll(RegExp(r'/+$'), '');
    if (t.isEmpty) return '';
    if (t.startsWith('http://') || t.startsWith('https://')) return t;
    if (RegExp(r'^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}(/.*)?$').hasMatch(t)) {
      return 'https://$t';
    }
    return t;
  }

  /// 从后台 config 同步 cover_domain、default_avatar（对应原生 refreshFromConfig）
  static Future<bool> refreshFromConfig(AppPrefs prefs) async {
    var updated = false;
    try {
      final map = await AppConfigCache.fetch();
      if (map != null) {
        final cover = map['cover_domain']?.toString().trim() ?? '';
        final platform = map['platform_url']?.toString().trim() ?? '';
        final imageBase = normalizeImageBase(cover.isNotEmpty ? cover : platform);
        if (imageBase.isNotEmpty) {
          prefs.imageBaseUrl = imageBase;
          setBaseUrl(imageBase);
          updated = true;
        }
        final defaultAvatar = map['default_avatar']?.toString().trim() ?? '';
        if (defaultAvatar.isNotEmpty) {
          prefs.defaultAvatarUrl = defaultAvatar;
        }
      }
    } catch (_) {
      final cached = prefs.imageBaseUrl;
      if (cached != null && cached.isNotEmpty) {
        setBaseUrl(cached);
        updated = true;
      }
    }
    return updated;
  }

  static String? _inferBaseFromApi() {
    final apiBase = ApiClient.baseUrl.trim().replaceAll(RegExp(r'/+$'), '');
    if (apiBase.isEmpty) return null;
    final withoutIndex = apiBase.replaceAll('/index.php', '').replaceAll(RegExp(r'/+$'), '');
    return withoutIndex.isEmpty ? null : withoutIndex;
  }

  static String? _getCoverBase() {
    if (_baseUrl != null && _baseUrl!.isNotEmpty) return _baseUrl;
    return _inferBaseFromApi();
  }

  /// Go 后端 uploads 目录挂在 API 同源 /uploads（router.Static），与 Vue getApiOrigin 一致
  static String? _getUploadsBase() => _inferBaseFromApi() ?? _getCoverBase();

  static bool _isUploadAssetPath(String path) {
    final lower = path.toLowerCase();
    return lower.startsWith('/uploads/') || lower.startsWith('uploads/');
  }

  /// 后台可能存完整 URL，但文件实际在 API 同源 /uploads
  static String? _rewriteUploadFullUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.path.isEmpty || !_isUploadAssetPath(uri.path)) return null;
    final base = _getUploadsBase();
    if (base == null || base.isEmpty) return null;
    return '$base${uri.path}';
  }

  /// 等级图标等用户资产：始终走 API 域名（对齐 Vue getApiOrigin + Go /uploads）
  static String getLevelIconUrl(String? path) {
    if (path == null || path.trim().isEmpty) return '';
    final trimmed = path.trim();
    if (trimmed.toLowerCase() == 'null') return '';

    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return _rewriteUploadFullUrl(trimmed) ?? trimmed;
    }
    if (trimmed.startsWith('//')) {
      return _rewriteUploadFullUrl('https:$trimmed') ?? 'https:$trimmed';
    }

    final normalized = trimmed.startsWith('/') ? trimmed : '/$trimmed';
    final base = _getUploadsBase();
    if (base != null && base.isNotEmpty) {
      return '$base$normalized';
    }
    return normalized;
  }

  /// 后端历史占位图，图床上不存在，应按无封面处理
  static bool isPlaceholderCover(String? path) {
    if (path == null || path.trim().isEmpty) return true;
    final t = path.trim().toLowerCase();
    return t == '/default-video.jpg' ||
        t == 'default-video.jpg' ||
        t.endsWith('/default-video.jpg');
  }

  static String getCoverUrl(String? path) {
    if (isPlaceholderCover(path)) return '';
    return getImageUrl(path);
  }

  /// 获取完整的图片 URL
  static String getImageUrl(String? path) {
    if (path == null || path.trim().isEmpty) return '';
    if (isPlaceholderCover(path)) return '';

    final trimmed = path.trim();
    if (trimmed.toLowerCase() == 'null') return '';

    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return _rewriteUploadFullUrl(trimmed) ?? trimmed;
    }
    if (trimmed.startsWith('//')) {
      final url = 'https:$trimmed';
      return _rewriteUploadFullUrl(url) ?? url;
    }
    if (RegExp(r'^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}(/.*)?$').hasMatch(trimmed)) {
      return 'https://$trimmed';
    }

    if (trimmed.startsWith('/')) {
      final base = _isUploadAssetPath(trimmed) ? _getUploadsBase() : _getCoverBase();
      if (base != null && base.isNotEmpty) {
        return '$base$trimmed';
      }
      return trimmed;
    }

    if (_isUploadAssetPath(trimmed)) {
      final base = _getUploadsBase();
      if (base != null && base.isNotEmpty) {
        return '$base/${trimmed.startsWith('uploads/') ? trimmed : trimmed.replaceFirst(RegExp(r'^/+'), '')}';
      }
    }

    final base = _getCoverBase();
    if (base == null || base.isEmpty) return trimmed;
    return '$base/$trimmed';
  }
}

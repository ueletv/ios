import 'package:videoweb_flutter/api/api_parse.dart';
import 'package:videoweb_flutter/api/api_result.dart';
import 'package:videoweb_flutter/api/api_service.dart';
import 'package:videoweb_flutter/api/models/banner.dart';
import 'package:videoweb_flutter/api/models/video.dart';

/// 启动阶段预取首页数据，进入首页时直接展示
class HomePrefetchCache {
  HomePrefetchCache._();

  static List<VideoCategory>? _categories;
  static Future<void>? _inflight;

  static List<Video>? _recommendVideos;
  static int _recommendTotalPages = 1;
  static int _recommendApiTotal = 0;
  static bool _recommendUseDefaultList = false;
  static List<BannerModel>? _banners;
  static List<BannerModel>? _gridAds;

  static List<VideoCategory>? get cached => _categories;

  static RecommendPrefetch? get recommendPrefetch {
    if (_recommendVideos == null) return null;
    return RecommendPrefetch(
      videos: List<Video>.unmodifiable(_recommendVideos!),
      totalPages: _recommendTotalPages,
      apiTotal: _recommendApiTotal,
      recommendUseDefaultList: _recommendUseDefaultList,
      banners: _banners == null ? const [] : List<BannerModel>.unmodifiable(_banners!),
      gridAds: _gridAds == null ? null : List<BannerModel>.unmodifiable(_gridAds!),
    );
  }

  static Future<List<VideoCategory>> prefetch() async {
    await prefetchAll();
    return _categories ?? [];
  }

  static Future<void> prefetchAll() async {
    if (_inflight != null) return _inflight!;
    _inflight = _loadAll();
    try {
      await _inflight!;
    } finally {
      _inflight = null;
    }
  }

  static Future<void> _loadAll() async {
    final api = ApiService();
    await Future.wait([
      _loadCategories(api),
      _loadRecommendContent(api),
    ]);
  }

  static Future<void> _loadCategories(ApiService api) async {
    if (_categories != null && _categories!.isNotEmpty) return;
    try {
      final res = await api.getCategoryList();
      if (ApiResult.isSuccess(res)) {
        final data = res.data['data'];
        final list = ApiParse.extractList(data).map(VideoCategory.fromJson).toList();
        if (list.isNotEmpty) {
          _categories = list;
        }
      }
    } catch (_) {}
  }

  static Future<void> _loadRecommendContent(ApiService api) async {
    if (_recommendVideos != null && _recommendVideos!.isNotEmpty) return;
    try {
      final results = await Future.wait([
        api.getRecommend(page: 1, pageSize: 20),
        api.getBannerList(),
        api.getConfigAds('home_grid'),
      ]);

      final recommendRes = results[0];
      if (ApiResult.isSuccess(recommendRes)) {
        final rows = ApiParse.extractList(recommendRes.data['data']);
        if (rows.isNotEmpty) {
          final body = Map<String, dynamic>.from(recommendRes.data as Map);
          _recommendVideos = rows.map(Video.fromJson).toList();
          _recommendTotalPages = ApiParse.extractTotalPages(body);
          _recommendApiTotal = _extractApiTotal(body);
          _recommendUseDefaultList = false;
        }
      }

      if (_recommendVideos == null || _recommendVideos!.isEmpty) {
        final listRes = await api.getVideoList(page: 1, pageSize: 20, sort: 'latest');
        if (ApiResult.isSuccess(listRes)) {
          final rows = ApiParse.extractList(listRes.data['data']);
          if (rows.isNotEmpty) {
            final body = Map<String, dynamic>.from(listRes.data as Map);
            _recommendVideos = rows.map(Video.fromJson).toList();
            _recommendTotalPages = ApiParse.extractTotalPages(body);
            _recommendApiTotal = _extractApiTotal(body);
            _recommendUseDefaultList = true;
          }
        }
      }

      final bannerRes = results[1];
      if (ApiResult.isSuccess(bannerRes)) {
        final data = bannerRes.data['data'];
        if (data is List) {
          _banners = data
              .map((e) => BannerModel.fromJson(e as Map<String, dynamic>))
              .toList();
        } else if (data is Map && data['list'] != null) {
          _banners = (data['list'] as List)
              .map((e) => BannerModel.fromJson(e as Map<String, dynamic>))
              .toList();
        }
      }

      final gridRes = results[2];
      if (ApiResult.isSuccess(gridRes)) {
        final data = gridRes.data['data'];
        if (data is List) {
          _gridAds = data
              .whereType<Map>()
              .map((e) => BannerModel.fromJson(Map<String, dynamic>.from(e)))
              .toList()
            ..sort((a, b) {
              final ap = a.position;
              final bp = b.position;
              final apos = ap != null && ap > 0 ? ap : 1 << 30;
              final bpos = bp != null && bp > 0 ? bp : 1 << 30;
              final byPosition = apos.compareTo(bpos);
              return byPosition != 0 ? byPosition : (a.id ?? 0).compareTo(b.id ?? 0);
            });
        }
      }
    } catch (_) {}
  }

  static int _extractApiTotal(Map<String, dynamic> body) {
    final pagination = body['pagination'];
    if (pagination is Map) {
      return ApiParse.asInt(pagination['total']) ?? 0;
    }
    return ApiParse.asInt(body['total']) ?? 0;
  }

  static void clear() {
    _categories = null;
    _recommendVideos = null;
    _recommendTotalPages = 1;
    _recommendApiTotal = 0;
    _recommendUseDefaultList = false;
    _banners = null;
    _gridAds = null;
    _inflight = null;
  }
}

class RecommendPrefetch {
  final List<Video> videos;
  final int totalPages;
  final int apiTotal;
  final bool recommendUseDefaultList;
  final List<BannerModel> banners;
  final List<BannerModel>? gridAds;

  const RecommendPrefetch({
    required this.videos,
    required this.totalPages,
    required this.apiTotal,
    required this.recommendUseDefaultList,
    required this.banners,
    this.gridAds,
  });
}

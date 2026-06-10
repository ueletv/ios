import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:videoweb_flutter/api/api_parse.dart';
import 'package:videoweb_flutter/api/api_result.dart';
import 'package:videoweb_flutter/api/api_service.dart';
import 'package:videoweb_flutter/api/models/banner.dart';
import 'package:videoweb_flutter/api/models/video.dart';
import 'package:videoweb_flutter/utils/image_url.dart';
import 'package:videoweb_flutter/pages/home/home_layout_metrics.dart';
import 'package:videoweb_flutter/pages/home/widgets/banner_carousel.dart';
import 'package:videoweb_flutter/pages/home/widgets/video_card.dart';
import 'package:videoweb_flutter/services/home_prefetch_cache.dart';
import 'package:videoweb_flutter/services/theme_controller.dart';
import 'package:videoweb_flutter/theme/app_theme.dart';
import 'package:videoweb_flutter/pages/video/video_detail_page.dart';
import 'package:videoweb_flutter/utils/ad_link_helper.dart';
import 'package:videoweb_flutter/utils/video_grid_layout.dart';

/// 首页单个分类页面（对应原生 HomeFragment + VideoAdapter + BannerAdapter）
class HomeCategoryPage extends StatefulWidget {
  final String? categoryId;
  final String? categoryIds;
  final bool isRecommend;
  final bool isNewFilms;
  final String sort;
  final List<VideoCategory> subCategories;
  final String? selectedSubCategoryId;
  final ValueChanged<String?>? onSubCategorySelected;
  final bool showBanner;
  final bool showGridAds;
  final bool showSortRow;
  final ValueChanged<String>? onSortChanged;

  const HomeCategoryPage({
    super.key,
    this.categoryId,
    this.categoryIds,
    this.isRecommend = false,
    this.isNewFilms = false,
    this.sort = 'latest',
    this.showBanner = false,
    this.showGridAds = true,
    this.showSortRow = false,
    this.subCategories = const [],
    this.selectedSubCategoryId,
    this.onSubCategorySelected,
    this.onSortChanged,
  });

  @override
  State<HomeCategoryPage> createState() => _HomeCategoryPageState();
}

class _HomeCategoryPageState extends State<HomeCategoryPage>
    with AutomaticKeepAliveClientMixin {
  final ApiService _api = ApiService();
  final ScrollController _scrollController = ScrollController();

  List<Video> _videos = [];
  List<BannerModel> _banners = [];
  List<BannerModel>? _gridAds;

  static const _pageSize = 20;

  int _currentPage = 1;
  int _totalPages = 1;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _isInitialized = false;
  bool _feedFinished = false;
  String? _error;
  bool _showBackToTop = false;

  bool get _isFeedTab => widget.isRecommend || widget.isNewFilms;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadData();
  }

  @override
  void didUpdateWidget(HomeCategoryPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final filterChanged = oldWidget.categoryId != widget.categoryId ||
        oldWidget.categoryIds != widget.categoryIds;
    final sortChanged = oldWidget.sort != widget.sort;
    final modeChanged = oldWidget.isRecommend != widget.isRecommend ||
        oldWidget.isNewFilms != widget.isNewFilms;
    if (modeChanged) {
      _videos = [];
      _currentPage = 1;
      _totalPages = 1;
      _feedFinished = false;
      _isInitialized = false;
      _error = null;
      _recommendUseDefaultList = false;
      _loadData();
    } else if (filterChanged || sortChanged) {
      _reloadVideoList();
    }
  }

  /// 切换二级分类 / 排序：只刷新视频列表，保留轮播与广告
  Future<void> _reloadVideoList() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      _error = null;
      _videos = [];
      _currentPage = 1;
      _totalPages = 1;
      _feedFinished = false;
    });
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
    try {
      await _loadVideos(append: false);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    // 滚动监听：显示/隐藏回到顶部按钮（延后到帧末，避免布局阶段 hit test 报错）
    final show = _scrollController.position.pixels > 600;
    if (show != _showBackToTop) {
      final next = show;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _showBackToTop != next) {
          setState(() => _showBackToTop = next);
        }
      });
    }
    // 触底加载更多
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  bool _applyRecommendPrefetchIfReady() {
    if (!widget.isRecommend) return false;
    final cached = HomePrefetchCache.recommendPrefetch;
    if (cached == null || cached.videos.isEmpty) return false;
    setState(() {
      _currentPage = 1;
      _videos = List<Video>.from(cached.videos);
      _totalPages = cached.totalPages;
      _recommendUseDefaultList = cached.recommendUseDefaultList;
      _feedFinished = _computeFeedFinished(
        videosOnPage: cached.videos.length,
        loadedVideos: cached.videos.length,
        apiTotal: cached.apiTotal,
        recommendFirstPage: !cached.recommendUseDefaultList,
      );
      if (widget.showBanner && cached.banners.isNotEmpty) {
        _banners = List<BannerModel>.from(cached.banners);
      }
      if (widget.showGridAds && cached.gridAds != null) {
        _gridAds = List<BannerModel>.from(cached.gridAds!);
      }
      _isLoading = false;
      _isInitialized = true;
      _error = null;
    });
    return true;
  }

  Future<void> _loadData() async {
    if (_isLoading) return;
    if (_applyRecommendPrefetchIfReady()) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      if (widget.showBanner) {
        await _loadBanners();
      }
      if (widget.showGridAds) {
        await _loadGridAds();
      }
      await _loadVideos(append: false);
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString());
      }
    }
    setState(() {
      _isLoading = false;
      _isInitialized = true;
    });
  }

  Future<void> _loadBanners() async {
    try {
      final res = await _api.getBannerList();
      if (ApiResult.isSuccess(res)) {
        final data = res.data['data'];
        if (data is List) {
          setState(() {
            _banners = data
                .map((e) => BannerModel.fromJson(e as Map<String, dynamic>))
                .toList();
          });
        } else if (data is Map && data['list'] != null) {
          setState(() {
            _banners = (data['list'] as List)
                .map((e) => BannerModel.fromJson(e as Map<String, dynamic>))
                .toList();
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _loadGridAds() async {
    try {
      final res = await _api.getConfigAds('home_grid');
      if (ApiResult.isSuccess(res)) {
        final data = res.data['data'];
        if (data is List) {
          final ads = data
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
          setState(() {
            _gridAds = ads;
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _loadVideos({required bool append}) async {
    try {
      final res = await _fetchVideosResponse();
      if (res == null) return;
      if (!ApiResult.isSuccess(res)) return;
      final rows = ApiParse.extractList(res.data['data']);
      _applyVideoResponse(res, rows, append: append);
    } catch (e) {
      if (mounted && _videos.isEmpty) {
        setState(() => _error = e.toString());
      }
    }
  }

  /// 对齐原生 HomeFragment.fetchVideosResponse：推荐优先，翻页无数据时回退全站列表
  Future<Response?> _fetchVideosResponse() async {
    if (widget.isRecommend && !_recommendUseDefaultList) {
      final recommendRes = await _api.getRecommend(page: _currentPage, pageSize: _pageSize);
      if (ApiResult.isSuccess(recommendRes)) {
        final rows = ApiParse.extractList(recommendRes.data['data']);
        if (rows.isNotEmpty) {
          return recommendRes;
        }
        if (_currentPage == 1) {
          _recommendUseDefaultList = true;
        }
      } else if (_currentPage == 1) {
        _recommendUseDefaultList = true;
      }
    }

    return _api.getVideoList(
      page: _currentPage,
      pageSize: _pageSize,
      categoryId: widget.isRecommend || widget.isNewFilms ? null : widget.categoryId,
      categoryIds: widget.categoryIds,
      sort: widget.isNewFilms ? 'latest' : widget.sort,
    );
  }

  bool _recommendUseDefaultList = false;

  int _extractApiTotal(Map<String, dynamic> body) {
    final pagination = body['pagination'];
    if (pagination is Map) {
      return ApiParse.asInt(pagination['total']) ?? 0;
    }
    return ApiParse.asInt(body['total']) ?? 0;
  }

  bool _computeFeedFinished({
    required int videosOnPage,
    required int loadedVideos,
    required int apiTotal,
    required bool recommendFirstPage,
  }) {
    if (videosOnPage == 0) return true;
    if (widget.isRecommend && recommendFirstPage && _currentPage == 1) {
      return false;
    }
    if (apiTotal > 0) return loadedVideos >= apiTotal;
    return videosOnPage < _pageSize;
  }

  void _applyVideoResponse(Response res, List<Map<String, dynamic>> rows, {required bool append}) {
    final list = rows.map(Video.fromJson).toList();
    final body = Map<String, dynamic>.from(res.data as Map);
    final apiTotal = _extractApiTotal(body);
    final videosOnPage = list.length;

    if (_isFeedTab) {
      setState(() {
        if (append) {
          _videos.addAll(list);
        } else {
          _videos = list;
        }
        _feedFinished = _computeFeedFinished(
          videosOnPage: videosOnPage,
          loadedVideos: _videos.length,
          apiTotal: apiTotal,
          recommendFirstPage: widget.isRecommend && !_recommendUseDefaultList,
        );
        if (apiTotal > 0) {
          _totalPages = (apiTotal + _pageSize - 1) ~/ _pageSize;
        }
      });
      return;
    }

    final totalPages = ApiParse.extractTotalPages(body);
    setState(() {
      if (append) {
        _videos.addAll(list);
      } else {
        _videos = list;
      }
      _totalPages = totalPages;
    });
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore) return;
    if (_isFeedTab) {
      if (_feedFinished) return;
    } else if (_currentPage >= _totalPages) {
      return;
    }
    setState(() => _isLoadingMore = true);
    _currentPage++;
    await _loadVideos(append: true);
    if (mounted) setState(() => _isLoadingMore = false);
  }

  Future<void> _onRefresh() async {
    _currentPage = 1;
    _totalPages = 1;
    _feedFinished = false;
    _videos = [];
    _banners = [];
    _gridAds = null;
    _isInitialized = false;
    _recommendUseDefaultList = false;
    await _loadData();
  }

  void _scrollToTop() {
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    context.watch<ThemeController>();
    final colors = context.appColors;

    if (!_isInitialized && _isLoading) {
      return _buildSkeleton(colors);
    }

    if (_error != null && _videos.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded, size: 44, color: colors.textHint),
            const SizedBox(height: 10),
            Text('加载失败', style: TextStyle(color: colors.textSecondary)),
            const SizedBox(height: 10),
            FilledButton.tonal(onPressed: _onRefresh, child: const Text('重试')),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.subCategories.isNotEmpty) _buildSubCategoryBar(colors),
        Expanded(
          child: Stack(
            children: [
              RefreshIndicator(
                color: colors.accent,
                onRefresh: _onRefresh,
                child: CustomScrollView(
                  controller: _scrollController,
                  primary: false,
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    if (widget.showBanner || widget.showGridAds)
                      SliverToBoxAdapter(child: _buildFeedHeader()),
                    if (widget.showSortRow)
                      SliverToBoxAdapter(child: _buildSortRow(colors)),
                    if (_isLoading && _videos.isEmpty && _isInitialized)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 48),
                          child: Center(
                            child: CircularProgressIndicator(strokeWidth: 2, color: colors.accent),
                          ),
                        ),
                      )
                    else
                      SliverPadding(
                        padding: VideoGridLayout.gridPadding,
                        sliver: SliverGrid(
                          gridDelegate: VideoGridLayout.sliverDelegate(context),
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final video = _videos[index];
                              return VideoCard(
                                video: video,
                                onTap: () => _openVideoDetail(video),
                              );
                            },
                            childCount: _videos.length,
                          ),
                        ),
                      ),
                    if (_isLoadingMore)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          child: Center(
                            child: CircularProgressIndicator(strokeWidth: 2, color: colors.accent),
                          ),
                        ),
                      ),
                    if (!_isLoadingMore &&
                        (_isFeedTab ? _feedFinished : _currentPage >= _totalPages) &&
                        _videos.isNotEmpty)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          child: Center(
                            child: Text(
                              '— 已经到底了 —',
                              style: TextStyle(color: colors.textHint, fontSize: 13),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (_showBackToTop)
                Positioned(
                  right: 16,
                  bottom: 16,
                  child: Material(
                    color: colors.cardBg,
                    elevation: 4,
                    shadowColor: Colors.black26,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: _scrollToTop,
                      child: SizedBox(
                        width: 42,
                        height: 42,
                        child: Icon(Icons.arrow_upward, color: colors.accent, size: 22),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSubCategoryBar(AppColors colors) {
    final children = widget.subCategories;
    final selectedId = widget.selectedSubCategoryId;
    return SingleChildScrollView(
      primary: false,
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(
        HomeLayoutMetrics.subCategoryPaddingH,
        HomeLayoutMetrics.subCategoryPaddingTop,
        HomeLayoutMetrics.subCategoryPaddingH,
        HomeLayoutMetrics.subCategoryPaddingBottom,
      ),
      child: Row(
        children: [
          for (var index = 0; index < children.length + 1; index++) ...[
            if (index > 0) const SizedBox(width: HomeLayoutMetrics.subCategoryChipGap),
            Builder(
              builder: (context) {
                final isAll = index == 0;
                final sub = isAll ? null : children[index - 1];
                final subId = sub == null ? null : ApiParse.asInt(sub.id)?.toString();
                final selected = isAll ? selectedId == null : selectedId == subId;
                final label = isAll ? '全部' : (sub?.name?.trim().isNotEmpty == true ? sub!.name! : '分类');
                return _HomeFilterChip(
                  label: label,
                  selected: selected,
                  colors: colors,
                  fontSize: HomeLayoutMetrics.subCategoryFontSize,
                  onTap: () {
                    if (selected) return;
                    widget.onSubCategorySelected?.call(isAll ? null : subId);
                  },
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSortRow(AppColors colors) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
      child: Container(
        height: 34,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: colors.homeFilterChipBg,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          children: [
            _sortSegment(colors, 'latest', '最新'),
            _sortSegment(colors, 'hot', '最热'),
          ],
        ),
      ),
    );
  }

  Widget _sortSegment(AppColors colors, String field, String label) {
    final selected = widget.sort == field;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (selected) return;
          widget.onSortChanged?.call(field);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? colors.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
            boxShadow: selected
                ? [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 4, offset: const Offset(0, 1))]
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? colors.homeFilterChipTextSelected : colors.homeFilterChipText,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeedHeader() {
    final hasBanner = widget.showBanner && _banners.isNotEmpty;
    final hasGrid = widget.showGridAds && _gridAds != null && _gridAds!.isNotEmpty;
    if (!hasBanner && !hasGrid) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        HomeLayoutMetrics.feedPaddingH,
        HomeLayoutMetrics.bannerPaddingTop,
        HomeLayoutMetrics.feedPaddingH,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (hasBanner)
            Padding(
              padding: const EdgeInsets.only(bottom: HomeLayoutMetrics.bannerPaddingBottom),
              child: BannerCarousel(
                items: _banners
                    .map((b) => BannerCarouselItem(
                          imageUrl: b.coverImage ?? b.image,
                          title: b.title,
                          link: b.link,
                          linkType: b.linkType,
                          linkId: b.linkId,
                        ))
                    .toList(),
                onTap: _onBannerTap,
              ),
            ),
          if (hasGrid)
            Padding(
              padding: EdgeInsets.only(
                top: hasBanner ? HomeLayoutMetrics.gridPaddingTop : 0,
                bottom: HomeLayoutMetrics.gridPaddingBottom,
              ),
              child: _buildGridAds(),
            ),
        ],
      ),
    );
  }

  Widget _buildGridAds() {
    final colors = context.appColors;
    const int columns = 5;
    final ads = [..._gridAds!]..sort((a, b) {
      final ap = a.position ?? a.sort ?? 1 << 30;
      final bp = b.position ?? b.sort ?? 1 << 30;
      final pc = ap.compareTo(bp);
      return pc != 0 ? pc : (a.id ?? 0).compareTo(b.id ?? 0);
    });
    final rows = (ads.length / columns).ceil();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: List.generate(rows, (row) {
          final start = row * columns;
          final end = (start + columns > ads.length) ? ads.length : start + columns;
          final colCount = end - start;
          return Padding(
            padding: EdgeInsets.only(top: row == 0 ? 0 : 4),
            child: Row(
              children: [
                ...List.generate(colCount, (i) {
                  final ad = ads[start + i];
                  final cover = ad.coverImage ?? ad.image ?? '';
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => _onAdTap(ad),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 1, vertical: 4),
                        child: Column(
                          children: [
                            SizedBox(
                              width: 52,
                              height: 52,
                              child: ColoredBox(
                                color: colors.chipBg,
                                child: CachedNetworkImage(
                                  imageUrl: cover.isEmpty ? '' : ImageUrl.getImageUrl(cover),
                                  width: 52,
                                  height: 52,
                                  fit: BoxFit.cover,
                                  placeholder: (_, __) => const SizedBox.shrink(),
                                  errorWidget: (_, __, ___) => Icon(
                                    Icons.image_outlined,
                                    size: 24,
                                    color: colors.textHint,
                                  ),
                                ),
                              ),
                            ),
                            if ((ad.title ?? '').isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                ad.title!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: colors.textPrimary,
                                  fontWeight: FontWeight.w400,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                }),
                if (colCount < columns)
                  ...List.generate(columns - colCount, (_) => const Expanded(child: SizedBox())),
              ],
            ),
          );
        }),
    );
  }

  Widget _buildSkeleton(AppColors colors) {
    final coverHeight = VideoGridLayout.coverHeight(context);
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: VideoGridLayout.gridPadding,
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: VideoGridLayout.boxDelegate(context),
        itemCount: 8,
        itemBuilder: (_, __) {
          return Padding(
            padding: const EdgeInsets.all(VideoGridLayout.cardMargin),
            child: Material(
              color: colors.cardBg,
              elevation: 2,
              shadowColor: Colors.black.withOpacity(0.06),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(color: colors.cardStroke, width: 0.5),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(height: coverHeight, color: colors.placeholderBg),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          height: 12,
                          decoration: BoxDecoration(
                            color: colors.chipBg,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          height: 12,
                          margin: const EdgeInsets.only(right: 72),
                          decoration: BoxDecoration(
                            color: colors.chipBg,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _onBannerTap(BannerCarouselItem item) {
    AdLinkHelper.openLink(
      context,
      linkType: item.linkType,
      linkUrl: item.link,
      linkId: item.linkId,
    );
  }

  void _onAdTap(BannerModel ad) {
    AdLinkHelper.openLink(
      context,
      linkType: ad.linkType,
      linkUrl: ad.link,
      linkId: ad.linkId,
    );
  }

  void _openVideoDetail(Video video) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => VideoDetailPage(video: video)),
    );
  }
}

class _HomeFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final AppColors colors;
  final double fontSize;
  final VoidCallback onTap;

  const _HomeFilterChip({
    required this.label,
    required this.selected,
    required this.colors,
    required this.fontSize,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(
          horizontal: HomeLayoutMetrics.subCategoryChipPaddingH,
          vertical: HomeLayoutMetrics.subCategoryChipPaddingV,
        ),
        decoration: BoxDecoration(
          color: selected ? colors.homeFilterChipSelectedBg : colors.homeFilterChipBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? colors.homeFilterChipTextSelected.withOpacity(0.35) : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? colors.homeFilterChipTextSelected : colors.homeFilterChipText,
          ),
        ),
      ),
    );
  }
}

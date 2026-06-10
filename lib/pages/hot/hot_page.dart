import 'package:flutter/material.dart';
import 'package:videoweb_flutter/utils/app_toast.dart';

import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:videoweb_flutter/api/api_result.dart';
import 'package:videoweb_flutter/api/api_service.dart';
import 'package:videoweb_flutter/api/models/video.dart';
import 'package:videoweb_flutter/api/models/video_id_body.dart';
import 'package:videoweb_flutter/services/app_prefs.dart';
import 'package:videoweb_flutter/services/global_trial_service.dart';
import 'package:videoweb_flutter/services/guest_auth_helper.dart';
import 'package:videoweb_flutter/services/main_tab_controller.dart';
import 'package:videoweb_flutter/pages/hot/widgets/video_player_item.dart';
import 'package:videoweb_flutter/pages/hot/widgets/hot_comment_sheet.dart';
import 'package:videoweb_flutter/utils/share_report_helper.dart';
import 'package:videoweb_flutter/utils/video_interact_helper.dart';

/// 短视频 Tab（对应原生 HotFragment.kt + fragment_hot.xml）
class HotPage extends StatefulWidget {
  const HotPage({super.key});

  @override
  State<HotPage> createState() => _HotPageState();
}

class _HotPageState extends State<HotPage> with AutomaticKeepAliveClientMixin {
  final ApiService _api = ApiService();
  late PageController _pageController;

  /// 原生默认 LATEST
  String _feedMode = 'latest';
  List<Video> _videos = [];
  bool _loading = false;
  bool _hasMore = true;
  bool _noMoreToastShown = false;
  bool _userHasSwiped = false;
  int _page = 1;
  int _currentIndex = 0;
  static const _pageSize = 15;
  bool _likeBusy = false;
  bool _favoriteBusy = false;
  bool _shareBusy = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final prefs = context.read<AppPrefs>();
    await GuestAuthHelper.ensureToken(prefs);
    if (!mounted) return;
    await context.read<GlobalTrialService>().refreshFromServer();
    if (!mounted) return;
    await _loadVideos(reset: true);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadVideos({bool reset = false, bool quiet = false}) async {
    if (_loading) return;
    if (!reset && !_hasMore) return;

    setState(() => _loading = true);
    final requestPage = reset ? 1 : _page + 1;

    if (reset) {
      _noMoreToastShown = false;
      if (!quiet) _userHasSwiped = false;
    }

    try {
      final res = await _api.getHotList(
        page: requestPage,
        pageSize: _pageSize,
        feed: _feedMode,
      );
      if (!ApiResult.isSuccess(res)) {
        if (reset && mounted) {
          AppToast.show(ApiResult.getErrorMessage(res) ?? '加载失败', context: context);
        }
        setState(() => _loading = false);
        return;
      }

      final raw = res.data['data'];
      List<dynamic> list = [];
      if (raw is List) {
        list = raw;
      } else if (raw is Map && raw['data'] is List) {
        list = raw['data'] as List;
      }

      // 不因 VIP 剥离播放地址而过滤条目，由 VideoPlayerItem 展示封面与 VIP 遮罩
      final playable = list
          .whereType<Map>()
          .map((e) => Video.fromJson(Map<String, dynamic>.from(e)))
          .toList();

      if (mounted) {
        setState(() {
          if (reset) {
            _videos = playable;
            _page = 1;
            _hasMore = playable.length >= _pageSize;
            _currentIndex = 0;
            if (_videos.isNotEmpty) {
              _jumpToPageWhenReady(0);
            }
          } else {
            if (playable.isEmpty && list.isEmpty) {
              _hasMore = false;
            } else if (playable.isNotEmpty) {
              _page = requestPage;
              _videos.addAll(playable);
              _hasMore = playable.length >= _pageSize;
            } else {
              _page = requestPage;
            }
            if (list.length < _pageSize) _hasMore = false;
          }
          _loading = false;
        });

        if (!_hasMore && !reset && _userHasSwiped && !_noMoreToastShown && mounted) {
          _noMoreToastShown = true;
          AppToast.show('没有更多了', context: context);
        }
      }
    } catch (e) {
      if (reset && mounted) {
        AppToast.show('加载失败: $e', context: context);
      }
      if (mounted) setState(() => _loading = false);
    }
  }

  /// PageView 可能尚未挂载（IndexedStack 预加载热门 Tab 时），需等下一帧再跳转
  void _jumpToPageWhenReady(int page) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_pageController.hasClients) return;
      if (_pageController.page?.round() == page) return;
      _pageController.jumpToPage(page);
    });
  }

  void _switchFeed(String mode) {
    if (_feedMode == mode || _loading) return;
    setState(() {
      _feedMode = mode;
      _videos = [];
      _currentIndex = 0;
      _hasMore = true;
    });
    _loadVideos(reset: true);
  }

  void _handleHorizontalSwipe(DragUpdateDetails details) {
    if (details.primaryDelta == null) return;
    if (details.primaryDelta! < -12) {
      if (_feedMode != 'latest') _switchFeed('latest');
    } else if (details.primaryDelta! > 12) {
      if (_feedMode != 'recommend') _switchFeed('recommend');
    }
  }

  void _maybeLoadMore(int index) {
    if (_loading || !_hasMore || _videos.isEmpty) return;
    if (index < _videos.length - 3) return;
    _loadVideos();
  }

  void _updateVideoAt(int index, Video video) {
    if (index < 0 || index >= _videos.length) return;
    setState(() => _videos[index] = video);
  }

  void _showCommentSheet(int index) {
    final video = _videos[index];
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => HotCommentSheet(
        videoId: video.id?.toString() ?? '',
        onCommentAdded: () {
          _updateVideoAt(
            index,
            video.copyWith(commentCount: (video.commentCount ?? 0) + 1),
          );
        },
        onCommentCountChanged: (count) {
          _updateVideoAt(index, video.copyWith(commentCount: count));
        },
      ),
    );
  }

  Future<void> _toggleLike(int index) async {
    if (_likeBusy) return;
    final video = _videos[index];
    if (video.id == null) return;
    final id = int.tryParse(video.id.toString()) ?? 0;
    if (id <= 0) return;

    _likeBusy = true;
    final wasLiked = VideoInteractHelper.isTruthy(video.isLiked);
    final oldCount = video.likeCount ?? 0;
    final optimistic = video.copyWith(
      isLiked: !wasLiked,
      likeCount: (oldCount + (wasLiked ? -1 : 1)).clamp(0, 999999999),
    );
    _updateVideoAt(index, optimistic);

    try {
      final prefs = context.read<AppPrefs>();
      final res = await GuestAuthHelper.callWithAuthRetry(
        prefs,
        () => _api.toggleLike(VideoIdBody(videoId: id)),
      );
      if (res != null && ApiResult.isSuccess(res)) {
        final data = VideoInteractHelper.parseToggleData(res.data['data']);
        final message = res.data is Map ? res.data['message']?.toString() : null;
        final liked = VideoInteractHelper.jsonBool(data, ['liked', 'is_liked']) ??
            VideoInteractHelper.stateFromMessage(message) ??
            !wasLiked;
        final count = VideoInteractHelper.jsonInt(data, ['like_count']) ?? optimistic.likeCount;
        _updateVideoAt(index, optimistic.copyWith(isLiked: liked, likeCount: count));
      } else {
        _updateVideoAt(index, video);
        if (mounted) {
          final msg = res != null ? ApiResult.getErrorMessage(res) : null;
          AppToast.show(msg ?? '点赞失败', context: context);
        }
      }
    } catch (e) {
      _updateVideoAt(index, video);
      if (mounted) {
        AppToast.show('点赞失败: $e', context: context);
      }
    } finally {
      _likeBusy = false;
    }
  }

  Future<void> _toggleFavorite(int index) async {
    if (_favoriteBusy) return;
    final video = _videos[index];
    if (video.id == null) return;
    final id = int.tryParse(video.id.toString()) ?? 0;
    if (id <= 0) return;

    _favoriteBusy = true;
    final wasFav = VideoInteractHelper.isTruthy(video.isFavorited);
    final oldCount = video.favoriteCount ?? 0;
    final optimistic = video.copyWith(
      isFavorited: !wasFav,
      favoriteCount: (oldCount + (wasFav ? -1 : 1)).clamp(0, 999999999),
    );
    _updateVideoAt(index, optimistic);

    try {
      final prefs = context.read<AppPrefs>();
      final res = await GuestAuthHelper.callWithAuthRetry(
        prefs,
        () => _api.toggleFavorite(VideoIdBody(videoId: id)),
      );
      if (res != null && ApiResult.isSuccess(res)) {
        final data = VideoInteractHelper.parseToggleData(res.data['data']);
        final message = res.data is Map ? res.data['message']?.toString() : null;
        final favorited = VideoInteractHelper.jsonBool(data, ['favorited', 'is_favorited']) ??
            VideoInteractHelper.stateFromMessage(message?.replaceAll('点赞', '收藏')) ??
            !wasFav;
        final count =
            VideoInteractHelper.jsonInt(data, ['favorite_count']) ?? optimistic.favoriteCount;
        _updateVideoAt(
          index,
          optimistic.copyWith(isFavorited: favorited, favoriteCount: count),
        );
      } else {
        _updateVideoAt(index, video);
        if (mounted) {
          final msg = res != null ? ApiResult.getErrorMessage(res) : null;
          AppToast.show(msg ?? '收藏失败', context: context);
        }
      }
    } catch (e) {
      _updateVideoAt(index, video);
      if (mounted) {
        AppToast.show('收藏失败: $e', context: context);
      }
    } finally {
      _favoriteBusy = false;
    }
  }

  Future<void> _shareVideo(Video video) async {
    if (_shareBusy || video.id == null) return;
    final id = video.id.toString().trim();
    if (id.isEmpty) return;
    final videoId = int.tryParse(id) ?? 0;
    if (videoId <= 0) return;

    _shareBusy = true;
    final prefs = context.read<AppPrefs>();
    try {
      final url = VideoInteractHelper.buildHotShareUrl(id);
      await Clipboard.setData(ClipboardData(text: url));
      if (mounted) {
        AppToast.show('复制成功，赶快分享给你的好友吧！', context: context);
      }

      final reported = await ShareReportHelper.reportIfNeeded(
        prefs: prefs,
        api: _api,
        videoId: videoId,
      );
      if (reported && mounted) {
        final index = _videos.indexWhere((v) => v.id?.toString() == id);
        if (index >= 0) {
          final v = _videos[index];
          _updateVideoAt(
            index,
            v.copyWith(shareCount: (v.shareCount ?? 0) + 1),
          );
        }
      }
    } finally {
      _shareBusy = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isRecommend = _feedMode == 'recommend';
    // IndexedStack 会预加载热门页；仅当前 Tab 为「热门」时才允许播放（对齐原生 onHiddenChanged）
    final isHotTabVisible = context.watch<MainTabController>().index == MainTabController.tabHot;

    return ColoredBox(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (_loading && _videos.isEmpty)
            const Center(child: CircularProgressIndicator(color: Colors.white))
          else if (_videos.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  '暂无短视频\n请确认后台有「短视频」分类且已上架视频',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white54, height: 1.5),
                ),
              ),
            )
          else
            GestureDetector(
              onHorizontalDragUpdate: _handleHorizontalSwipe,
              child: PageView.builder(
                controller: _pageController,
                scrollDirection: Axis.vertical,
                itemCount: _videos.length,
                onPageChanged: (index) {
                  setState(() {
                    _currentIndex = index;
                    _userHasSwiped = true;
                  });
                  _maybeLoadMore(index);
                },
                itemBuilder: (context, index) {
                  final video = _videos[index];
                  return VideoPlayerItem(
                    video: video,
                    isActive: isHotTabVisible && index == _currentIndex,
                    onLike: () => _toggleLike(index),
                    onComment: () => _showCommentSheet(index),
                    onFavorite: () => _toggleFavorite(index),
                    onShare: () => _shareVideo(video),
                  );
                },
              ),
            ),
          // 顶部 推荐 / 最新 Tab（原生 hot_feed_tabs）
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _FeedTabWrap(
                  label: '推荐',
                  selected: isRecommend,
                  onTap: () => _switchFeed('recommend'),
                ),
                const SizedBox(width: 8),
                _FeedTabWrap(
                  label: '最新',
                  selected: !isRecommend,
                  onTap: () => _switchFeed('latest'),
                ),
              ],
            ),
          ),
          if (_loading && _videos.isNotEmpty)
            const Positioned(
              bottom: 24,
              left: 0,
              right: 0,
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white54),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _FeedTabWrap extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FeedTabWrap({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : const Color(0x99FFFFFF),
                fontSize: selected ? 20 : 17,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 22,
              height: 3,
              decoration: BoxDecoration(
                color: selected ? Colors.white : Colors.transparent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


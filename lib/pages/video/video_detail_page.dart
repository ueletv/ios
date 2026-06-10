import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:videoweb_flutter/utils/app_toast.dart';

import 'package:flutter/services.dart';
import 'package:fijkplayer/fijkplayer.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:videoweb_flutter/api/api_client.dart';
import 'package:videoweb_flutter/api/api_parse.dart';
import 'package:videoweb_flutter/api/api_result.dart';
import 'package:videoweb_flutter/api/api_service.dart';
import 'package:videoweb_flutter/api/models/banner.dart';
import 'package:videoweb_flutter/api/models/video.dart';
import 'package:videoweb_flutter/api/models/video_id_body.dart';
import 'package:videoweb_flutter/api/models/comment.dart';
import 'package:videoweb_flutter/services/app_prefs.dart';
import 'package:videoweb_flutter/services/global_trial_service.dart';
import 'package:videoweb_flutter/services/guest_auth_helper.dart';
import 'package:videoweb_flutter/pages/home/widgets/video_card.dart';
import 'package:videoweb_flutter/theme/app_theme.dart';
import 'package:videoweb_flutter/utils/ad_link_helper.dart';
import 'package:videoweb_flutter/utils/comment_time_util.dart';
import 'package:videoweb_flutter/utils/fijk_player_helper.dart';
import 'package:videoweb_flutter/utils/screen_wake_lock.dart';
import 'package:videoweb_flutter/utils/image_url.dart';
import 'package:videoweb_flutter/widgets/user_avatar.dart';
import 'package:videoweb_flutter/utils/share_report_helper.dart';
import 'package:videoweb_flutter/utils/video_interact_helper.dart';
import 'package:videoweb_flutter/utils/vip_access_helper.dart';
import 'package:videoweb_flutter/widgets/detail_player_gesture_layer.dart';
import 'package:videoweb_flutter/widgets/fijk_video_view.dart';
import 'package:videoweb_flutter/widgets/player_buffered_progress_bar.dart';
import 'package:videoweb_flutter/widgets/player_loading_overlay.dart';
import 'package:videoweb_flutter/utils/video_grid_layout.dart';

/// 视频详情页（对应原生 VideoDetailActivity.kt）
class VideoDetailPage extends StatefulWidget {
  final Video video;

  const VideoDetailPage({super.key, required this.video});

  @override
  State<VideoDetailPage> createState() => _VideoDetailPageState();
}

class _VideoDetailPageState extends State<VideoDetailPage> {
  final ApiService _api = ApiService();
  final GlobalKey _playerViewKey = GlobalKey();

  // 播放器
  final FijkPlayer _player = FijkPlayer();
  bool _isPlaying = false;
  bool _wakeLockHeld = false;

  // 视频信息（可能从详情接口获取更完整数据）
  late Video _video;

  // 点赞/收藏状态
  bool _isLiked = false;
  bool _isFavorited = false;
  int _likeCount = 0;
  int _favoriteCount = 0;
  int _shareCount = 0;
  bool _favoriteBusy = false;

  // 评论
  List<Comment> _comments = [];
  bool _loadingComments = false;
  bool _commentsLoaded = false;
  bool _submittingComment = false;
  final TextEditingController _commentCtrl = TextEditingController();
  Set<int> _expandedReplyParents = {};
  Comment? _replyTarget;

  // 详情页广告宫格
  List<BannerModel> _gridAds = [];

  // 更多视频
  List<Video> _recommendList = [];
  bool _loadingRecommend = false;

  // 横竖屏
  bool _isLandscape = false;

  // Tab：0 视频 1 评论
  int _detailTab = 0;
  int _commentTotal = 0;

  // 播放器
  Duration _position = Duration.zero;
  Duration _bufferPosition = Duration.zero;
  Duration _duration = Duration.zero;
  double _playbackSpeed = 1.0;
  bool _controlsVisible = true;
  bool _isLoading = false;
  bool _userPaused = false;
  bool _isScrubbing = false;
  bool _isScreenLocked = false;
  bool _isGestureSeeking = false;
  bool _vipBlocked = false;
  bool _trialPlaying = false;
  String _vipOverlayTitle = '需要 VIP 会员';
  String _vipOverlayMessage = '观看视频需开通 VIP 会员后观看完整内容';
  Timer? _controlsHideTimer;
  StreamSubscription<Duration>? _posSub;
  StreamSubscription<bool>? _bufferSub;
  StreamSubscription<Duration>? _bufferPosSub;
  final GlobalKey _controlsKey = GlobalKey();

  // 获取 videoId 的 int 值
  int get _videoId {
    final id = widget.video.id ?? _video.id;
    if (id is int) return id;
    if (id is String) return int.tryParse(id) ?? 0;
    if (id is double) return id.toInt();
    return 0;
  }

  @override
  void initState() {
    super.initState();
    _video = widget.video;
    _isLiked = widget.video.isLiked == true;
    _isFavorited = widget.video.isFavorited == true;
    _likeCount = widget.video.likeCount ?? 0;
    _favoriteCount = widget.video.favoriteCount ?? 0;
    _shareCount = widget.video.shareCount ?? 0;
    _player.addListener(_onPlayerUpdate);
    _posSub = _player.onCurrentPosUpdate.listen((pos) {
      if (!mounted || _isScrubbing || _isGestureSeeking) return;
      setState(() => _position = pos);
    });
    _bufferSub = _player.onBufferStateUpdate.listen((_) => _syncPlayerUi());
    _bufferPosSub = _player.onBufferPosUpdate.listen((pos) {
      if (!mounted || _isScrubbing || _isGestureSeeking) return;
      setState(() => _bufferPosition = pos);
    });
    _loadVideoDetail().then((_) => _preparePlayback());
    _loadHomeGridAds();
    _loadMoreVideos();
    _recordView();
  }

  void _onPlayerUpdate() {
    if (!mounted) return;
    _syncPlayerUi();
  }

  void _syncPlayerUi() {
    if (!mounted) return;
    final value = _player.value;
    final playing = FijkPlayerHelper.isPlaying(value) && value.state != FijkState.completed;
    final loading = FijkPlayerHelper.isLoading(_player, userPaused: _userPaused);
    setState(() {
      _isPlaying = playing;
      _isLoading = loading;
      _duration = value.duration;
      if (!_isScrubbing) _position = _player.currentPos;
      if (!_isScrubbing && !_isGestureSeeking) _bufferPosition = _player.bufferPos;
    });
    if (playing && _controlsVisible) {
      _scheduleHideControls();
    }
    _updateWakeLock(playing);
  }

  void _updateWakeLock(bool enable) {
    if (enable == _wakeLockHeld) return;
    _wakeLockHeld = enable;
    if (enable) {
      unawaited(ScreenWakeLock.acquire());
    } else {
      unawaited(ScreenWakeLock.release());
    }
  }

  void _scheduleHideControls() {
    _controlsHideTimer?.cancel();
    if (!_isPlaying || !_controlsVisible) return;
    _controlsHideTimer = Timer(const Duration(seconds: 4), () {
      if (!mounted || !_isPlaying) return;
      setState(() => _controlsVisible = false);
    });
  }

  void _showPlayerControls({bool autoHide = true}) {
    setState(() => _controlsVisible = true);
    if (autoHide && _isPlaying) {
      _scheduleHideControls();
    } else {
      _controlsHideTimer?.cancel();
    }
  }

  void _hidePlayerControls() {
    _controlsHideTimer?.cancel();
    setState(() => _controlsVisible = false);
  }

  void _toggleControlsVisibility() {
    if (_isScreenLocked) {
      _onLockedScreenTap();
      return;
    }
    if (_controlsVisible) {
      _hidePlayerControls();
    } else {
      _showPlayerControls(autoHide: _isPlaying);
    }
  }

  void _toggleScreenLock() {
    setState(() => _isScreenLocked = !_isScreenLocked);
    if (_isScreenLocked) {
      _controlsHideTimer?.cancel();
      _hidePlayerControls();
      AppToast.show('屏幕已锁定', context: context);
    } else {
      AppToast.show('已解锁', context: context);
      _showPlayerControls(autoHide: _isPlaying);
    }
  }

  void _onLockedScreenTap() {
    if (!_isScreenLocked) return;
    AppToast.show('屏幕已锁定，点击左侧锁图标解锁', context: context);
  }

  void _handlePlayerBack() {
    if (_isLandscape) {
      if (_isScreenLocked) {
        _toggleScreenLock();
      } else {
        _toggleOrientation();
      }
      return;
    }
    Navigator.of(context).pop();
  }

  bool get _showCenterPlayButton {
    if (_isScreenLocked) return false;
    if (_isLoading || _player.value.state == FijkState.idle) return false;
    return !_isPlaying || _controlsVisible;
  }

  @override
  void dispose() {
    try {
      context.read<GlobalTrialService>().stopWatching();
    } catch (_) {}
    _controlsHideTimer?.cancel();
    _posSub?.cancel();
    _bufferSub?.cancel();
    _bufferPosSub?.cancel();
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _updateWakeLock(false);
    _player.removeListener(_onPlayerUpdate);
    _player.release();
    _commentCtrl.dispose();
    super.dispose();
  }

  bool get _canPlayVideo {
    if (_vipBlocked) return false;
    if (_video.hasAccess != false) return true;
    return _trialPlaying && _video.resolvedPlayUrl != null;
  }

  Future<void> _preparePlayback() async {
    if (_video.hasAccess != false) {
      await _initPlayer();
      return;
    }
    final trialSvc = context.read<GlobalTrialService>();
    final secs = _video.videoTrialSeconds ?? trialSvc.videoTrialRemaining;
    if (secs > 0 && _video.resolvedPlayUrl != null) {
      setState(() {
        _trialPlaying = true;
        _vipBlocked = false;
      });
      await _initPlayer();
      trialSvc.startWatching(
        type: TrialContentType.video,
        onExhausted: () {
          if (!mounted) return;
          _onGlobalTrialExhausted();
        },
      );
      return;
    }
    if (mounted) {
      setState(() {
        _vipBlocked = true;
        _vipOverlayTitle = '需要 VIP 会员';
        _vipOverlayMessage = trialSvc.videoTrialRemaining <= 0
            ? '视频试看时长已用完，开通 VIP 可继续观看'
            : '观看视频需开通 VIP 会员后观看完整内容';
      });
    }
  }

  Future<void> _onGlobalTrialExhausted() async {
    context.read<GlobalTrialService>().stopWatching();
    await _player.pause();
    if (!mounted) return;
    setState(() {
      _vipBlocked = true;
      _trialPlaying = false;
      _vipOverlayTitle = '试看结束';
      _vipOverlayMessage = '视频试看时长已用完，开通 VIP 可继续观看';
    });
  }

  Future<void> _onOpenVipFromPlayer() async {
    context.read<GlobalTrialService>().stopWatching();
    await VipAccessHelper.openVipPage(context);
    if (!mounted) return;
    await _loadVideoDetail();
    await context.read<GlobalTrialService>().refreshFromServer();
    if (_video.hasAccess != false) {
      setState(() {
        _vipBlocked = false;
        _trialPlaying = false;
      });
      await _initPlayer();
    }
  }

  Future<void> _initPlayer() async {
    if (!_canPlayVideo) return;
    final playUrl = _video.resolvedPlayUrl;
    if (playUrl == null || playUrl.isEmpty) return;
    try {
      _userPaused = false;
      await FijkPlayerHelper.openUrl(_player, playUrl, isLive: false);
      if (mounted) {
        _syncPlayerUi();
        _showPlayerControls(autoHide: true);
      }
    } catch (e) {
      debugPrint('播放器初始化失败: $e');
    }
  }

  Future<void> _loadVideoDetail() async {
    try {
      final res = await _api.getVideoDetail(_videoId.toString());
      if (ApiResult.isSuccess(res)) {
        final data = res.data['data'];
        if (data != null) {
          final detail = Video.fromJson(data as Map<String, dynamic>);
          if (detail.videoTrialSeconds != null && mounted) {
            context.read<GlobalTrialService>().updateRemaining(
              detail.videoTrialSeconds!,
              type: TrialContentType.video,
            );
          }
          setState(() {
            _video = detail;
            _isLiked = detail.isLiked == true;
            _isFavorited = detail.isFavorited == true;
            _likeCount = detail.likeCount ?? 0;
            _favoriteCount = detail.favoriteCount ?? 0;
            _shareCount = detail.shareCount ?? 0;
            _commentTotal = detail.commentCount ?? _commentTotal;
            final noTrial = (detail.videoTrialSeconds ?? 0) <= 0;
            _vipBlocked = detail.hasAccess == false && noTrial;
            _trialPlaying = false;
            if (_vipBlocked) {
              _vipOverlayTitle = '需要 VIP 会员';
              _vipOverlayMessage = noTrial
                  ? '视频试看时长已用完，开通 VIP 可继续观看'
                  : '观看视频需开通 VIP 会员后观看完整内容';
            }
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _loadComments() async {
    setState(() => _loadingComments = true);
    try {
      final res = await _api.getCommentList(_videoId.toString(), page: 1, pageSize: 50);
      if (ApiResult.isSuccess(res)) {
        final root = Map<String, dynamic>.from(res.data as Map);
        final list = ApiParse.extractList(root['data']).map(Comment.fromJson).toList();
        int total = list.fold<int>(0, (s, c) => s + 1 + (c.replies?.length ?? 0));
        final pagination = root['pagination'];
        if (pagination is Map) {
          final t = ApiParse.asInt(pagination['comment_total']) ?? ApiParse.asInt(pagination['total']);
          if (t != null && t > 0) total = t;
        }
        setState(() {
          _comments = list;
          _commentTotal = total;
          _commentsLoaded = true;
          _expandedReplyParents = {};
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _loadingComments = false);
  }

  Future<void> _loadHomeGridAds() async {
    try {
      final res = await _api.getConfigAds('home_grid');
      if (!ApiResult.isSuccess(res)) return;
      final data = res.data['data'];
      if (data is! List) return;
      final ads = data
          .whereType<Map>()
          .map((e) => BannerModel.fromJson(Map<String, dynamic>.from(e)))
          .toList()
        ..sort((a, b) {
          final ap = a.position ?? a.sort ?? 1 << 30;
          final bp = b.position ?? b.sort ?? 1 << 30;
          final pc = ap.compareTo(bp);
          return pc != 0 ? pc : (a.id ?? 0).compareTo(b.id ?? 0);
        });
      if (mounted) setState(() => _gridAds = ads);
    } catch (_) {}
  }

  /// 更多视频（对应 loadMoreVideos：随机页 + 过滤 + 最多 8 条）
  Future<void> _loadMoreVideos() async {
    setState(() => _loadingRecommend = true);
    try {
      final randomPage = Random().nextInt(10) + 1;
      List<Video> list = [];
      final listRes = await _api.getVideoList(page: randomPage, pageSize: 20);
      if (ApiResult.isSuccess(listRes)) {
        list = ApiParse.extractList(listRes.data['data']).map(Video.fromJson).toList();
      }
      if (list.isEmpty) {
        final recRes = await _api.getRecommend(page: 1, pageSize: 20);
        if (ApiResult.isSuccess(recRes)) {
          list = ApiParse.extractList(recRes.data['data']).map(Video.fromJson).toList();
        }
      }
      final vidStr = _videoId.toString();
      list = list.where((v) {
        final id = v.id?.toString() ?? '';
        return id != vidStr && v.type != 'ad' && !id.startsWith('ad_');
      }).toList();
      list.shuffle();
      if (mounted) setState(() => _recommendList = list.take(8).toList());
    } catch (_) {}
    if (mounted) setState(() => _loadingRecommend = false);
  }

  void _selectDetailTab(int index) {
    setState(() => _detailTab = index);
    if (index == 1 && !_commentsLoaded && !_loadingComments) {
      _loadComments();
    }
  }

  Future<void> _recordView() async {
    final prefs = context.read<AppPrefs>();
    await GuestAuthHelper.callWithAuthRetry(prefs, () {
      return _api.recordVideoView(VideoIdBody(videoId: _videoId));
    });
  }

  Future<void> _toggleLike() async {
    final prefs = context.read<AppPrefs>();
    final res = await GuestAuthHelper.callWithAuthRetry(prefs, () {
      return _api.toggleLike(VideoIdBody(videoId: _videoId));
    });
    if (res != null && ApiResult.isSuccess(res)) {
      final data = res.data['data'];
      if (data is Map) {
        setState(() {
          _isLiked = data['is_liked'] == true;
          _likeCount = (data['like_count'] as num?)?.toInt() ?? _likeCount;
        });
      }
    }
  }

  Future<void> _toggleFavorite() async {
    if (_favoriteBusy) return;
    _favoriteBusy = true;
    final wasFav = _isFavorited;
    final oldCount = _favoriteCount;
    setState(() {
      _isFavorited = !wasFav;
      _favoriteCount = (oldCount + (wasFav ? -1 : 1)).clamp(0, 999999999);
    });

    try {
      final prefs = context.read<AppPrefs>();
      final res = await GuestAuthHelper.callWithAuthRetry(prefs, () {
        return _api.toggleFavorite(VideoIdBody(videoId: _videoId));
      });
      if (res != null && ApiResult.isSuccess(res)) {
        final data = VideoInteractHelper.parseToggleData(res.data['data']);
        final message = res.data is Map ? res.data['message']?.toString() : null;
        final favorited = VideoInteractHelper.jsonBool(data, ['favorited', 'is_favorited']) ??
            VideoInteractHelper.stateFromMessage(message?.replaceAll('点赞', '收藏')) ??
            !wasFav;
        final count = VideoInteractHelper.jsonInt(data, ['favorite_count']) ?? _favoriteCount;
        if (mounted) {
          setState(() {
            _isFavorited = favorited;
            _favoriteCount = count;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isFavorited = wasFav;
            _favoriteCount = oldCount;
          });
          AppToast.show(ApiResult.getErrorMessage(res!) ?? '收藏失败', context: context);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isFavorited = wasFav;
          _favoriteCount = oldCount;
        });
        AppToast.show('收藏失败: $e', context: context);
      }
    } finally {
      _favoriteBusy = false;
    }
  }

  String _buildShareUrl() {
    final origin = ApiClient.baseUrl
        .trim()
        .replaceAll(RegExp(r'/+$'), '')
        .replaceAll(RegExp(r'/index\.php/?$'), '');
    return '$origin/home/video/$_videoId';
  }

  Future<void> _shareVideo() async {
    await Clipboard.setData(ClipboardData(text: _buildShareUrl()));
    if (mounted) {
      AppToast.show('复制成功，赶快分享给你的好友吧！', context: context);
    }
    final prefs = context.read<AppPrefs>();
    final reported = await ShareReportHelper.reportIfNeeded(
      prefs: prefs,
      api: _api,
      videoId: _videoId,
    );
    if (reported && mounted) {
      setState(() => _shareCount++);
    }
  }

  Future<void> _addComment() async {
    final content = _commentCtrl.text.trim();
    if (content.isEmpty) return;

    setState(() => _submittingComment = true);
    try {
      final prefs = context.read<AppPrefs>();
      final body = CommentAddBody(
        videoId: _videoId,
        content: content,
        parentId: _replyTarget?.threadParentId ?? 0,
        replyCommentId: _replyTarget?.commentIdLong ?? 0,
      );
      final res = await GuestAuthHelper.callWithAuthRetry(prefs, () => _api.addComment(body));
      if (res != null && ApiResult.isSuccess(res)) {
        _commentCtrl.clear();
        setState(() => _replyTarget = null);
        _loadComments();
        if (mounted) {
          AppToast.show('评论成功', context: context);
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _submittingComment = false);
  }

  Future<void> _toggleCommentLike(Comment comment) async {
    final cid = comment.commentIdLong;
    if (cid == null) return;
    final prefs = context.read<AppPrefs>();
    final res = await GuestAuthHelper.callWithAuthRetry(
      prefs,
      () => _api.toggleCommentLike(CommentIdBody(commentId: cid)),
    );
    if (res != null && ApiResult.isSuccess(res)) {
      _loadComments();
    }
  }

  void _startCommentReply(Comment comment) {
    setState(() => _replyTarget = comment);
  }

  void _toggleOrientation() {
    if (_isLandscape && _isScreenLocked) {
      setState(() => _isScreenLocked = false);
    }
    setState(() => _isLandscape = !_isLandscape);
    if (_isLandscape) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      _showPlayerControls(autoHide: _isPlaying);
    } else {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      _showPlayerControls(autoHide: _isPlaying);
    }
  }

  Future<void> _playPause() async {
    if (_isLoading || _isScreenLocked) return;
    final trialSvc = context.read<GlobalTrialService>();
    if (_isPlaying) {
      _userPaused = true;
      if (_trialPlaying) trialSvc.stopWatching();
      await _player.pause();
      _showPlayerControls(autoHide: false);
    } else {
      _userPaused = false;
      if (_player.value.state == FijkState.completed) {
        setState(() => _position = Duration.zero);
      }
      try {
        await FijkPlayerHelper.resumeOrReplay(_player);
      } catch (_) {}
      if (_trialPlaying && !_vipBlocked) {
        trialSvc.startWatching(
          type: TrialContentType.video,
          onExhausted: () {
            if (!mounted) return;
            _onGlobalTrialExhausted();
          },
        );
      }
      _showPlayerControls(autoHide: true);
    }
    _syncPlayerUi();
  }

  @override
  Widget build(BuildContext context) {
    final playerHeight = MediaQuery.of(context).size.width * 9 / 16;
    return PopScope(
      canPop: !_isLandscape,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handlePlayerBack();
      },
      child: Scaffold(
        backgroundColor: _isLandscape ? Colors.black : context.appColors.pageBg,
        body: Stack(
          fit: StackFit.expand,
          children: [
            if (!_isLandscape)
              Column(
                children: [
                  SizedBox(height: playerHeight),
                  _buildDetailTabBar(),
                  Divider(height: 1, color: context.appColors.divider),
                  Expanded(
                    child: _detailTab == 0 ? _buildVideoTab() : _buildCommentTab(),
                  ),
                ],
              ),
            // 播放器始终保留在同一层，避免横竖屏切换时 Texture 被销毁（对齐原生 expand playerHolder）
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              bottom: _isLandscape ? 0 : null,
              height: _isLandscape ? null : playerHeight,
              child: ColoredBox(
                color: Colors.black,
                child: _buildPlayerStack(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 播放器层（横竖屏共用同一 FijkVideoView 实例）
  Widget _buildPlayerStack() {
    return Stack(
      fit: StackFit.expand,
      children: [
        FijkVideoView(
          key: _playerViewKey,
          player: _player,
          fit: FijkFit.contain,
        ),
        Positioned.fill(
          child: DetailPlayerGestureLayer(
            player: _player,
            duration: _duration,
            isScreenLocked: _isScreenLocked,
            controlsKey: _controlsKey,
            onSingleTap: _toggleControlsVisibility,
            onLockedTap: _onLockedScreenTap,
            onControlsShow: () => _showPlayerControls(autoHide: _isPlaying),
            onControlsHide: _hidePlayerControls,
            onSeekPreview: (pos) {
              setState(() {
                _isGestureSeeking = true;
                _position = pos;
              });
            },
            onSeekEnd: () {
              if (mounted) setState(() => _isGestureSeeking = false);
            },
          ),
        ),
        PlayerLoadingOverlay(visible: _isLoading),
        if (_vipBlocked)
          VipPlayerOverlay(
            title: _vipOverlayTitle,
            message: _vipOverlayMessage,
            onOpenVip: _onOpenVipFromPlayer,
          ),
        if (_trialPlaying)
          Consumer<GlobalTrialService>(
            builder: (context, trial, _) {
              if (trial.videoTrialRemaining <= 0) return const SizedBox.shrink();
              return Positioned(
                top: MediaQuery.of(context).padding.top + 48,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.amber.shade400.withOpacity(0.6)),
                  ),
                  child: Text(
                    '试看剩余 ${trial.videoTrialRemaining} 秒',
                    style: TextStyle(color: Colors.amber.shade200, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              );
            },
          ),
        if (_showCenterPlayButton && !_vipBlocked)
          Center(
            child: GestureDetector(
              onTap: _playPause,
              child: Icon(
                _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                color: Colors.white.withOpacity(0.88),
                size: _isLandscape ? 64 : 56,
              ),
            ),
          ),
        if (_duration > Duration.zero && !_vipBlocked) _buildPlayerBottomBar(),
        Positioned(
          top: MediaQuery.of(context).padding.top + 4,
          left: 8,
          child: _buildRoundOverlayButton(
            icon: Icons.arrow_back,
            onTap: _handlePlayerBack,
          ),
        ),
        if (_isLandscape)
          Positioned(
            left: 8,
            top: 0,
            bottom: 0,
            child: Center(
              child: _buildRoundOverlayButton(
                icon: _isScreenLocked ? Icons.lock : Icons.lock_open,
                onTap: _toggleScreenLock,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildVideoTab() {
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        _buildVideoInfo(),
        if (_gridAds.isNotEmpty) _buildHomeGridSection(),
        _buildRecommendSection(),
      ],
    );
  }

  Widget _buildHomeGridSection() {
    final colors = context.appColors;
    const columns = 5;
    final ads = [..._gridAds]..sort((a, b) {
        final ap = a.position ?? a.sort ?? 1 << 30;
        final bp = b.position ?? b.sort ?? 1 << 30;
        final pc = ap.compareTo(bp);
        return pc != 0 ? pc : (a.id ?? 0).compareTo(b.id ?? 0);
      });
    final rows = (ads.length / columns).ceil();

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
      child: Column(
        children: List.generate(rows, (row) {
          final start = row * columns;
          final end = start + columns > ads.length ? ads.length : start + columns;
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
                      onTap: () => AdLinkHelper.openLink(
                        context,
                        linkType: ad.linkType,
                        linkUrl: ad.link,
                        linkId: ad.linkId,
                      ),
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
                                  errorWidget: (_, __, ___) => Icon(
                                    Icons.image_outlined,
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
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 13, color: colors.textPrimary),
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
      ),
    );
  }

  Widget _buildCommentTab() {
    final colors = context.appColors;
    final rows = _buildCommentDisplayRows();
    return Column(
      children: [
        Expanded(
          child: _loadingComments
              ? const Center(child: CircularProgressIndicator())
              : rows.isEmpty
                  ? Center(
                      child: Text(
                        '暂无评论，快来抢沙发',
                        style: TextStyle(color: colors.textHint, fontSize: 14),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                      itemCount: rows.length,
                      itemBuilder: (context, index) => _buildCommentDisplayRow(rows[index], colors),
                    ),
        ),
        _buildCommentInput(),
      ],
    );
  }

  List<_DetailCommentRow> _buildCommentDisplayRows() {
    const visibleReplies = 1;
    final rows = <_DetailCommentRow>[];
    for (final main in _comments) {
      rows.add(_DetailCommentRow(comment: main, isReply: false));
      final parentId = main.commentIdLong;
      if (parentId == null) continue;
      final replies = main.replies ?? [];
      if (replies.isEmpty) continue;
      final expanded = _expandedReplyParents.contains(parentId);
      if (!expanded && replies.length > visibleReplies) {
        for (final r in replies.take(visibleReplies)) {
          rows.add(_DetailCommentRow(comment: r, isReply: true));
        }
        rows.add(_DetailCommentRow.expand(parentId, replies.length - visibleReplies));
      } else {
        for (final r in replies) {
          rows.add(_DetailCommentRow(comment: r, isReply: true));
        }
        if (expanded && replies.length > visibleReplies) {
          rows.add(_DetailCommentRow.collapse(parentId));
        }
      }
    }
    return rows;
  }

  Widget _buildCommentDisplayRow(_DetailCommentRow row, AppColors colors) {
    if (row.kind == _DetailCommentRowKind.expand) {
      return GestureDetector(
        onTap: () => setState(() => _expandedReplyParents.add(row.parentId!)),
        child: Padding(
          padding: const EdgeInsets.only(left: 46, bottom: 10),
          child: Text(
            '展开${row.hiddenCount}条回复',
            style: TextStyle(color: colors.accent, fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
      );
    }
    if (row.kind == _DetailCommentRowKind.collapse) {
      return GestureDetector(
        onTap: () => setState(() => _expandedReplyParents.remove(row.parentId!)),
        child: Padding(
          padding: const EdgeInsets.only(left: 46, bottom: 10),
          child: Text('收起回复', style: TextStyle(color: colors.accent, fontSize: 13, fontWeight: FontWeight.w600)),
        ),
      );
    }
    return _buildCommentItem(row.comment!, isReply: row.isReply);
  }

  Widget _buildPlayerBottomBar() {
    final maxMs = _duration.inMilliseconds;
    if (maxMs <= 0) return const SizedBox.shrink();
    final showControls = _controlsVisible && !_isScreenLocked;
    // 控制条隐藏时，进度条与底部渐变一并隐藏（避免只剩一条细线）
    if (!showControls) return const SizedBox.shrink();

    final posMs = _position.inMilliseconds.clamp(0, maxMs);
    final bufMs = _bufferPosition.inMilliseconds.clamp(posMs, maxMs);

    return Positioned(
      key: _controlsKey,
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [Colors.black.withOpacity(0.72), Colors.transparent],
          ),
        ),
        child: Row(
          children: [
            IconButton(
              icon: Icon(
                _isPlaying ? Icons.pause : Icons.play_arrow,
                color: Colors.white,
              ),
              onPressed: _playPause,
            ),
            Text(
              _formatDuration(_position),
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
            Expanded(
              child: PlayerBufferedProgressBar(
                value: posMs.toDouble(),
                bufferValue: bufMs.toDouble(),
                max: maxMs.toDouble(),
                bufferedColor: const Color(0x99FFFFFF),
                showThumb: true,
                onChangeStart: (_) {
                  _isScrubbing = true;
                  _controlsHideTimer?.cancel();
                  _showPlayerControls(autoHide: false);
                  _player.pause();
                },
                onChanged: (v) {
                  setState(() => _position = Duration(milliseconds: v.round()));
                },
                onChangeEnd: (v) async {
                  _isScrubbing = false;
                  _userPaused = false;
                  try {
                    await _player.seekTo(v.round());
                    await Future<void>.delayed(const Duration(milliseconds: 80));
                    await _player.start();
                  } catch (_) {}
                  _syncPlayerUi();
                  _showPlayerControls(autoHide: true);
                },
              ),
            ),
            Text(
              _formatDuration(_duration),
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
            TextButton(
              onPressed: _cycleSpeed,
              style: TextButton.styleFrom(
                minimumSize: const Size(36, 28),
                padding: const EdgeInsets.symmetric(horizontal: 6),
                backgroundColor: Colors.white24,
              ),
              child: Text(
                '${_playbackSpeed}x',
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
            IconButton(
              icon: Icon(
                _isLandscape ? Icons.fullscreen_exit : Icons.fullscreen,
                color: Colors.white,
              ),
              onPressed: _toggleOrientation,
            ),
          ],
        ),
      ),
    );
  }

  void _cycleSpeed() {
    if (_isScreenLocked) return;
    const speeds = [1.0, 1.25, 1.5, 2.0];
    final idx = speeds.indexOf(_playbackSpeed);
    _playbackSpeed = speeds[(idx + 1) % speeds.length];
    _player.setSpeed(_playbackSpeed);
    setState(() {});
    _showPlayerControls(autoHide: _isPlaying);
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Widget _buildDetailTabBar() {
    final colors = context.appColors;
    final commentLabel = _commentTotal > 0 ? _commentTotal : _comments.length;
    return Container(
      height: 48,
      padding: const EdgeInsets.only(left: 16, right: 8),
      color: colors.pageBg,
      child: Row(
        children: [
          GestureDetector(
            onTap: () => _selectDetailTab(0),
            child: _DetailTab(label: '视频', selected: _detailTab == 0, colors: colors),
          ),
          const SizedBox(width: 20),
          GestureDetector(
            onTap: () => _selectDetailTab(1),
            child: _DetailTab(
              label: _commentTotal > 0 ? '评论 $commentLabel' : '评论',
              selected: _detailTab == 1,
              colors: colors,
            ),
          ),
          const Spacer(),
          _DetailTabAction(
            icon: _isFavorited ? Icons.star_rounded : Icons.star_border_rounded,
            label: _isFavorited ? '已收藏' : '收藏',
            colors: colors,
            active: _isFavorited,
            animateTap: true,
            onTap: _toggleFavorite,
          ),
          _DetailTabAction(
            icon: Icons.share_outlined,
            label: '分享',
            colors: colors,
            onTap: _shareVideo,
          ),
        ],
      ),
    );
  }

  Widget _buildVideoInfo() {
    final colors = context.appColors;
    final durationText = _formatVideoDuration(_video.duration);
    final dateText = _formatDetailDate(_video.createdAt);
    final showMeta = durationText.isNotEmpty || dateText.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(16),
      color: colors.pageBg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _video.displayName,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              height: 1.25,
              color: colors.textPrimary,
            ),
          ),
          if (showMeta) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                if (durationText.isNotEmpty)
                  Text(durationText, style: TextStyle(color: colors.textHint, fontSize: 13)),
                if (durationText.isNotEmpty && dateText.isNotEmpty) const SizedBox(width: 12),
                if (dateText.isNotEmpty)
                  Text(dateText, style: TextStyle(color: colors.textHint, fontSize: 13)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _formatVideoDuration(int? seconds) {
    if (seconds == null || seconds <= 0) return '';
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String _formatDetailDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '';
    try {
      final dt = DateTime.parse(dateStr);
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return dateStr.length > 10 ? dateStr.substring(0, 10) : dateStr;
    }
  }

  Widget _buildInfoChip(IconData icon, String text) {
    final colors = context.appColors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colors.chipBg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: colors.textSecondary),
          const SizedBox(width: 5),
          Text(text, style: TextStyle(color: colors.textSecondary, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildRoundOverlayButton({required IconData icon, required VoidCallback onTap}) {
    return Material(
      color: Colors.black.withOpacity(0.35),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(icon, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildActionBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildActionButton(
            icon: _isLiked ? Icons.thumb_up : Icons.thumb_up_alt_outlined,
            label: _formatCount(_likeCount),
            color: _isLiked ? Colors.blue : null,
            onTap: _toggleLike,
          ),
          _buildActionButton(
            icon: Icons.chat_bubble_outline,
            label: _formatCount(_comments.length),
            onTap: () {
              FocusScope.of(context).requestFocus(FocusNode());
            },
          ),
          _buildActionButton(
            icon: _isFavorited ? Icons.bookmark : Icons.bookmark_border,
            label: _formatCount(_favoriteCount),
            color: _isFavorited ? Colors.orange : null,
            onTap: _toggleFavorite,
          ),
          _buildActionButton(
            icon: Icons.share,
            label: _formatCount(_shareCount),
            onTap: _shareVideo,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    Color? color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color ?? Colors.grey[600], size: 24),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(color: color ?? Colors.grey[600], fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildCommentHeader() {
    return const Padding(
      padding: EdgeInsets.fromLTRB(24, 18, 16, 8),
      child: Text(
        '评论',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
      ),
    );
  }

  Widget _buildCommentInput() {
    final colors = context.appColors;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.divider)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _commentCtrl,
              maxLines: null,
              style: TextStyle(color: colors.textPrimary),
              decoration: InputDecoration(
                hintText: _replyTarget != null
                    ? '回复 @${_replyTarget!.authorName}'
                    : '说点什么...',
                hintStyle: TextStyle(color: colors.textHint),
                filled: true,
                fillColor: colors.chipBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                isDense: true,
              ),
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _addComment(),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: _submittingComment ? null : _addComment,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: _submittingComment
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('发送'),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentItem(Comment comment, {bool isReply = false}) {
    final colors = context.appColors;
    final avatarSize = isReply ? 28.0 : 36.0;

    return Padding(
      padding: EdgeInsets.only(left: isReply ? 46 : 0, bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          UserAvatar(
            rawAvatar: comment.avatar,
            size: avatarSize,
            useServerDefault: true,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        comment.authorName,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: colors.textPrimary,
                        ),
                      ),
                    ),
                    Text(
                      CommentTimeUtil.format(comment.createdAt),
                      style: TextStyle(color: colors.textHint, fontSize: 11),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                if (comment.replyTo != null && comment.replyTo!.isNotEmpty)
                  RichText(
                    text: TextSpan(
                      style: TextStyle(fontSize: 14, height: 1.35, color: colors.textPrimary),
                      children: [
                        TextSpan(
                          text: '回复 ${comment.replyTo} ',
                          style: TextStyle(color: colors.textSecondary, fontSize: 13),
                        ),
                        TextSpan(text: comment.content),
                      ],
                    ),
                  )
                else
                  Text(
                    comment.content,
                    style: TextStyle(fontSize: 14, height: 1.35, color: colors.textPrimary),
                  ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => _toggleCommentLike(comment),
                      child: Row(
                        children: [
                          Icon(
                            comment.isLiked == true ? Icons.favorite : Icons.favorite_border,
                            size: 14,
                            color: comment.isLiked == true ? Colors.redAccent : colors.textHint,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            '${comment.likeCount ?? 0}',
                            style: TextStyle(color: colors.textHint, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    GestureDetector(
                      onTap: () => _startCommentReply(comment),
                      child: Row(
                        children: [
                          Icon(Icons.reply, size: 14, color: colors.textHint),
                          const SizedBox(width: 3),
                          Text('回复', style: TextStyle(color: colors.textHint, fontSize: 11)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendSection() {
    final colors = context.appColors;
    return Container(
      color: colors.pageBg,
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 16, 12),
            child: Text(
              '更多视频',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: colors.textPrimary,
              ),
            ),
          ),
          if (_loadingRecommend)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_recommendList.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Text('暂无更多视频', style: TextStyle(color: colors.textHint, fontSize: 14)),
              ),
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: VideoGridLayout.gridPadding,
              gridDelegate: VideoGridLayout.boxDelegate(context),
              itemCount: _recommendList.length,
              itemBuilder: (context, index) {
                final video = _recommendList[index];
                return VideoCard(
                  video: video,
                  onTap: () {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => VideoDetailPage(video: video)),
                    );
                  },
                );
              },
            ),
        ],
      ),
    );
  }

  String _formatCount(int count) {
    if (count >= 10000) return '${(count / 10000).toStringAsFixed(1)}w';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}k';
    return count.toString();
  }

}

enum _DetailCommentRowKind { comment, expand, collapse }

class _DetailCommentRow {
  final _DetailCommentRowKind kind;
  final Comment? comment;
  final bool isReply;
  final int? parentId;
  final int? hiddenCount;

  _DetailCommentRow({required this.comment, required this.isReply})
      : kind = _DetailCommentRowKind.comment,
        parentId = null,
        hiddenCount = null;

  _DetailCommentRow.expand(int parentId, int hidden)
      : kind = _DetailCommentRowKind.expand,
        comment = null,
        isReply = false,
        parentId = parentId,
        hiddenCount = hidden;

  _DetailCommentRow.collapse(int parentId)
      : kind = _DetailCommentRowKind.collapse,
        comment = null,
        isReply = false,
        parentId = parentId,
        hiddenCount = null;
}

class _DetailTab extends StatelessWidget {
  final String label;
  final bool selected;
  final AppColors colors;

  const _DetailTab({required this.label, required this.selected, required this.colors});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Expanded(
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                  color: selected ? colors.textPrimary : colors.textHint,
                ),
              ),
            ),
          ),
          Container(
            width: 20,
            height: 3,
            decoration: BoxDecoration(
              color: selected ? const Color(0xFFFFC94D) : Colors.transparent,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailTabAction extends StatefulWidget {
  final IconData icon;
  final String label;
  final AppColors colors;
  final bool active;
  final bool animateTap;
  final VoidCallback onTap;

  const _DetailTabAction({
    required this.icon,
    required this.label,
    required this.colors,
    this.active = false,
    this.animateTap = false,
    required this.onTap,
  });

  @override
  State<_DetailTabAction> createState() => _DetailTabActionState();
}

class _DetailTabActionState extends State<_DetailTabAction> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _scale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.78), weight: 18),
      TweenSequenceItem(tween: Tween(begin: 0.78, end: 1.18), weight: 42),
      TweenSequenceItem(tween: Tween(begin: 1.18, end: 1.0), weight: 40),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (widget.animateTap) _controller.forward(from: 0);
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.active ? widget.colors.accent : widget.colors.textSecondary;
    return InkWell(
      onTap: _handleTap,
      child: SizedBox(
        height: 48,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              AnimatedBuilder(
                animation: _scale,
                builder: (context, child) {
                  return Transform.scale(
                    scale: widget.animateTap ? _scale.value : 1.0,
                    child: child,
                  );
                },
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  switchInCurve: Curves.easeOutBack,
                  switchOutCurve: Curves.easeIn,
                  transitionBuilder: (child, animation) {
                    return ScaleTransition(scale: animation, child: child);
                  },
                  child: Icon(
                    widget.icon,
                    key: ValueKey('${widget.icon}_${widget.active}'),
                    size: 18,
                    color: color,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: Text(
                  widget.label,
                  key: ValueKey(widget.label),
                  style: TextStyle(fontSize: 13, color: color),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 推荐视频横向卡片
class _RecommendCard extends StatelessWidget {
  final Video video;
  final VoidCallback onTap;

  const _RecommendCard({required this.video, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 160,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        child: Card(
          clipBehavior: Clip.antiAlias,
          elevation: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: CachedNetworkImage(
                  imageUrl: ImageUrl.getImageUrl(video.vodPic),
                  width: double.infinity,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(color: Colors.grey[200]),
                  errorWidget: (_, __, ___) => Container(
                    color: Colors.grey[300],
                    child: const Icon(Icons.broken_image, color: Colors.grey),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(6),
                child: Text(
                  video.displayName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

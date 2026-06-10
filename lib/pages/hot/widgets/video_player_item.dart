import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:videoweb_flutter/api/models/video.dart';
import 'package:videoweb_flutter/pages/hot/widgets/hot_action_button.dart';
import 'package:videoweb_flutter/pages/hot/widgets/hot_douyin_icons.dart';
import 'package:videoweb_flutter/utils/progressive_video_helper.dart';
import 'package:videoweb_flutter/utils/screen_wake_lock.dart';
import 'package:videoweb_flutter/utils/image_url.dart';
import 'package:videoweb_flutter/utils/video_interact_helper.dart';
import 'package:videoweb_flutter/widgets/progressive_video_view.dart';
import 'package:videoweb_flutter/widgets/player_buffered_progress_bar.dart';
import 'package:videoweb_flutter/widgets/player_loading_overlay.dart';
import 'package:videoweb_flutter/services/global_trial_service.dart';
import 'package:videoweb_flutter/utils/vip_access_helper.dart';

/// 短视频播放项（对应原生 HotPagerAdapter + ExoPlayer，Flutter 侧统一用 IJK）
class VideoPlayerItem extends StatefulWidget {
  final Video video;
  final bool isActive;
  final VoidCallback? onLike;
  final VoidCallback? onComment;
  final VoidCallback? onFavorite;
  final VoidCallback? onShare;

  const VideoPlayerItem({
    super.key,
    required this.video,
    this.isActive = false,
    this.onLike,
    this.onComment,
    this.onFavorite,
    this.onShare,
  });

  @override
  State<VideoPlayerItem> createState() => _VideoPlayerItemState();
}

class _VideoPlayerItemState extends State<VideoPlayerItem> {
  VideoPlayerController? _player;
  bool _isPlaying = false;
  bool _isLoading = false;
  bool _userPaused = false;
  bool _isScrubbing = false;
  Duration _duration = Duration.zero;
  final ValueNotifier<double> _progressMs = ValueNotifier(0);
  final ValueNotifier<double> _bufferMs = ValueNotifier(0);
  int _lastProgressUiMs = 0;
  bool _vipBlocked = false;
  bool _trialPlaying = false;
  bool _wakeLockHeld = false;
  String _vipOverlayTitle = '需要 VIP 会员';
  String _vipOverlayMessage = '开通 VIP 后可观看短视频';
  GlobalTrialService? _trialService;

  @override
  void initState() {
    super.initState();
    if (widget.isActive) _initPlayer();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final trial = context.read<GlobalTrialService>();
    if (_trialService == trial) return;
    _trialService?.removeListener(_onTrialServiceChanged);
    _trialService = trial;
    _trialService!.addListener(_onTrialServiceChanged);
  }

  void _onTrialServiceChanged() {
    if (!mounted) return;
    final trial = _trialService;
    if (trial == null) return;
    if (!trial.isActiveVip) return;
    trial.stopWatching();
    if (!_vipBlocked && !_trialPlaying) return;
    setState(() {
      _vipBlocked = false;
      _trialPlaying = false;
    });
    if (!widget.isActive) return;
    final player = _player;
    if (player != null && !_userPaused) {
      unawaited(ProgressiveVideoHelper.resumeOrReplay(player));
    } else if (player == null) {
      unawaited(_initPlayer());
    }
  }

  @override
  void didUpdateWidget(VideoPlayerItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _initPlayer();
    } else if (!widget.isActive && oldWidget.isActive) {
      _disposePlayer();
    }
  }

  void _onPlayerUpdate() {
    if (!mounted || _player == null) return;
    final player = _player!;
    final value = player.value;
    if (!_isScrubbing && value.isInitialized) {
      final durMs = value.duration.inMilliseconds;
      final ms = value.position.inMilliseconds;
      final now = DateTime.now().millisecondsSinceEpoch;
      final nearEnd = durMs > 0 && ms >= durMs - 300;
      if (nearEnd || now - _lastProgressUiMs >= 200) {
        _lastProgressUiMs = now;
        final max = durMs > 0 ? durMs.toDouble() : ms.toDouble();
        _progressMs.value = ms.clamp(0, max.round()).toDouble();
      }
      _bufferMs.value = ProgressiveVideoHelper.bufferedEndMs(value).toDouble();
    }
    _syncPlayerUi();
  }

  void _syncPlayerUi() {
    final player = _player;
    if (player == null || !mounted) return;
    final value = player.value;
    final playing = ProgressiveVideoHelper.isPlaying(value);
    final loading = ProgressiveVideoHelper.isLoading(
      player,
      userPaused: _userPaused,
      isScrubbing: _isScrubbing,
    );
    final dur = value.duration;
    setState(() {
      _isPlaying = playing;
      _isLoading = loading;
      _duration = dur;
    });
    _updateWakeLock(widget.isActive && playing && !_vipBlocked);
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

  void _showVipBlock({String? title, String? message}) {
    if (!mounted) return;
    context.read<GlobalTrialService>().stopWatching();
    setState(() {
      _vipBlocked = true;
      _trialPlaying = false;
      if (title != null) _vipOverlayTitle = title;
      if (message != null) _vipOverlayMessage = message;
    });
  }

  void _startGlobalTrialWatching() {
    if (!mounted || !_trialPlaying) return;
    context.read<GlobalTrialService>().startWatching(
      type: TrialContentType.video,
      onExhausted: () {
      if (!mounted) return;
      _player?.pause();
      _showVipBlock(
        title: '试看结束',
        message: '视频试看时长已用完，开通 VIP 可继续观看',
      );
    });
  }

  Future<void> _onOpenVip() async {
    await VipAccessHelper.openVipPage(context);
  }

  Future<void> _initPlayer() async {
    if (_player != null) return;

    final url = widget.video.resolvedPlayUrl ?? '';
    final hasAccess = widget.video.hasAccess != false;
    final trialSvc = context.read<GlobalTrialService>();
    final trial = widget.video.videoTrialSeconds ?? trialSvc.videoTrialRemaining;

    if (url.isEmpty) {
      if (!hasAccess) {
        _showVipBlock(
          message: trialSvc.videoTrialRemaining <= 0
              ? '视频试看时长已用完，开通 VIP 可继续观看'
              : '开通 VIP 后可观看短视频',
        );
      }
      return;
    }
    if (!hasAccess && trial <= 0) {
      _showVipBlock(
        message: trialSvc.videoTrialRemaining <= 0
            ? '视频试看时长已用完，开通 VIP 可继续观看'
            : '开通 VIP 后可观看短视频',
      );
      return;
    }

    _userPaused = false;
    _isLoading = true;
    if (mounted) setState(() {});
    try {
      final player = await ProgressiveVideoHelper.openUrl(url);
      player.addListener(_onPlayerUpdate);
      _player = player;
      await player.play();
      if (!mounted) return;
      setState(() => _isPlaying = ProgressiveVideoHelper.isPlaying(player.value));
      if (!hasAccess && trial > 0) {
        _trialPlaying = true;
        _startGlobalTrialWatching();
      }
    } catch (e) {
      debugPrint('短视频播放器初始化失败: $e');
    }
  }

  void _disposePlayer({bool rebuild = true}) {
    _trialService?.stopWatching();
    _vipBlocked = false;
    _trialPlaying = false;
    final player = _player;
    if (player != null) {
      player.removeListener(_onPlayerUpdate);
      unawaited(player.dispose());
    }
    _player = null;
    _progressMs.value = 0;
    _bufferMs.value = 0;
    _lastProgressUiMs = 0;
    _duration = Duration.zero;
    _isPlaying = false;
    _isLoading = false;
    _userPaused = false;
    _isScrubbing = false;
    _updateWakeLock(false);
    if (rebuild && mounted) setState(() {});
  }

  Future<void> _togglePlay() async {
    final player = _player;
    if (player == null || _isLoading) return;
    if (ProgressiveVideoHelper.isPlaying(player.value)) {
      _userPaused = true;
      await player.pause();
    } else {
      _userPaused = false;
      if (ProgressiveVideoHelper.isCompleted(player.value)) {
        _progressMs.value = 0;
        _lastProgressUiMs = 0;
      }
      try {
        await ProgressiveVideoHelper.resumeOrReplay(player);
      } catch (e) {
        debugPrint('短视频重播失败: $e');
      }
    }
    _syncPlayerUi();
  }

  @override
  void dispose() {
    _trialService?.removeListener(_onTrialServiceChanged);
    _disposePlayer(rebuild: false);
    _progressMs.dispose();
    _bufferMs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final liked = VideoInteractHelper.isTruthy(widget.video.isLiked);
    final favorited = VideoInteractHelper.isTruthy(widget.video.isFavorited);

    return Stack(
      fit: StackFit.expand,
      children: [
        _buildVideo(),
        if (_vipBlocked)
          VipPlayerOverlay(
            title: _vipOverlayTitle,
            message: _vipOverlayMessage,
            onOpenVip: _onOpenVip,
          ),
        if (_trialPlaying)
          Consumer<GlobalTrialService>(
            builder: (context, trial, _) {
              if (trial.videoTrialRemaining <= 0) return const SizedBox.shrink();
              return Positioned(
                top: MediaQuery.of(context).padding.top + 56,
                right: 14,
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
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Color(0xCC000000)],
                stops: [0.48, 1],
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: _togglePlay,
          ),
        ),
        PlayerLoadingOverlay(visible: _isLoading && !_vipBlocked),
        if (!_isLoading && !_isPlaying && _player != null && !_vipBlocked)
          Center(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _togglePlay,
              child: SizedBox(
                width: 72,
                height: 72,
                child: Opacity(
                  opacity: 0.9,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.28),
                      shape: BoxShape.circle,
                    ),
                    child: HotDouyinIcons.play(size: 48),
                  ),
                ),
              ),
            ),
          ),
        Positioned(
          right: 12,
          bottom: 100,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              HotActionButton(
                kind: HotActionKind.like,
                active: liked,
                count: widget.video.likeCount ?? 0,
                onTap: widget.onLike,
              ),
              const SizedBox(height: 14),
              HotActionButton(
                kind: HotActionKind.comment,
                count: widget.video.commentCount ?? 0,
                onTap: widget.onComment,
              ),
              const SizedBox(height: 14),
              HotActionButton(
                kind: HotActionKind.favorite,
                active: favorited,
                count: widget.video.favoriteCount ?? 0,
                onTap: widget.onFavorite,
              ),
              const SizedBox(height: 14),
              HotActionButton(
                kind: HotActionKind.share,
                count: widget.video.shareCount ?? 0,
                onTap: widget.onShare,
              ),
            ],
          ),
        ),
        Positioned(
          left: 14,
          right: 92,
          bottom: 34,
          child: _VideoInfo(video: widget.video),
        ),
        if (_player != null && _duration > Duration.zero)
          Positioned(
            left: 8,
            right: 8,
            bottom: 4,
            child: ValueListenableBuilder<double>(
              valueListenable: _progressMs,
              builder: (context, progress, _) {
                return ValueListenableBuilder<double>(
                  valueListenable: _bufferMs,
                  builder: (context, buffer, __) {
                    final maxMs = _duration.inMilliseconds.toDouble();
                    return PlayerBufferedProgressBar(
                      value: progress.clamp(0, maxMs > 0 ? maxMs : progress),
                      bufferValue: buffer.clamp(0, maxMs > 0 ? maxMs : buffer),
                      max: maxMs > 0 ? maxMs : 1,
                      playedColor: Colors.white,
                      bufferedColor: Colors.white.withOpacity(0.6),
                      minAheadPixels: 0,
                      trackColor: Colors.white.withOpacity(0.2),
                      thumbColor: Colors.white,
                      onChangeStart: (_) {
                        _isScrubbing = true;
                        final p = _player;
                        if (p != null && ProgressiveVideoHelper.isPlaying(p.value)) {
                          p.pause();
                        }
                      },
                      onChanged: (v) => _progressMs.value = v,
                      onChangeEnd: (v) async {
                        _isScrubbing = false;
                        _userPaused = false;
                        final p = _player;
                        if (p == null) return;
                        try {
                          await p.seekTo(Duration(milliseconds: v.round()));
                          await p.play();
                        } catch (_) {}
                        _lastProgressUiMs = 0;
                        _syncPlayerUi();
                      },
                    );
                  },
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildVideo() {
    final player = _player;
    final cover = widget.video.vodPic?.trim() ?? '';
    return Stack(
      fit: StackFit.expand,
      children: [
        if (cover.isNotEmpty)
          CachedNetworkImage(
            imageUrl: ImageUrl.getImageUrl(cover),
            fit: BoxFit.cover,
            placeholder: (_, __) => const ColoredBox(color: Colors.black),
            errorWidget: (_, __, ___) => const ColoredBox(color: Colors.black),
          )
        else
          const ColoredBox(color: Colors.black),
        if (player != null)
          ProgressiveVideoView(controller: player, fit: BoxFit.cover),
      ],
    );
  }
}

class _VideoInfo extends StatelessWidget {
  final Video video;

  const _VideoInfo({required this.video});

  static const _infoShadow = [
    Shadow(color: Color(0x80000000), offset: Offset(0, 1), blurRadius: 3),
  ];

  @override
  Widget build(BuildContext context) {
    final category = video.categoryName ?? video.category?.name ?? '短视频';
    final avatar = video.categoryIcon ?? video.category?.avatar ?? video.category?.icon;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _CategoryAvatar(imageUrl: avatar),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                category,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  shadows: _infoShadow,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          video.vodName ?? '',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xF0FFFFFF),
            fontSize: 14,
            fontWeight: FontWeight.w400,
            height: 1.35,
            shadows: _infoShadow,
          ),
        ),
      ],
    );
  }
}

class _CategoryAvatar extends StatelessWidget {
  final String? imageUrl;

  const _CategoryAvatar({this.imageUrl});

  @override
  Widget build(BuildContext context) {
    final url = imageUrl;
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withOpacity(0.88), width: 1.2),
      ),
      child: ClipOval(
        child: url == null || url.isEmpty
            ? Container(
                color: Colors.white24,
                alignment: Alignment.center,
                child: HotDouyinIcons.play(size: 20),
              )
            : CachedNetworkImage(
                imageUrl: ImageUrl.getImageUrl(url),
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(color: Colors.white24),
                errorWidget: (_, __, ___) => Container(
                  color: Colors.white24,
                  alignment: Alignment.center,
                  child: HotDouyinIcons.play(size: 20),
                ),
              ),
      ),
    );
  }
}

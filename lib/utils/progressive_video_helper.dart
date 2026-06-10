import 'package:video_player/video_player.dart';
import 'package:videoweb_flutter/services/device_info_service.dart';

/// 点播播放器工具（Android ExoPlayer / iOS AVPlayer，对齐原生 VideoDetail + Hot）
class ProgressiveVideoHelper {
  static Future<VideoPlayerController> openUrl(String url) async {
    final trimmed = url.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('empty play url');
    }
    final userAgent = await DeviceInfoService.appUserAgent();
    final controller = VideoPlayerController.networkUrl(
      Uri.parse(trimmed),
      httpHeaders: {'User-Agent': userAgent},
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );
    await controller.initialize();
    await controller.setVolume(1.0);
    return controller;
  }

  static bool isPlaying(VideoPlayerValue value) =>
      value.isInitialized && value.isPlaying;

  static bool isCompleted(VideoPlayerValue value) {
    if (!value.isInitialized || value.duration <= Duration.zero) return false;
    return value.position >= value.duration - const Duration(milliseconds: 400);
  }

  /// ExoPlayer [bufferedPosition] 等价：当前播放点所在缓冲区间的末端
  static int bufferedEndMs(VideoPlayerValue value) {
    if (!value.isInitialized) return 0;
    final pos = value.position.inMilliseconds;
    final ranges = value.buffered;
    if (ranges.isEmpty) return pos;

    for (final range in ranges) {
      final start = range.start.inMilliseconds;
      final end = range.end.inMilliseconds;
      if (start <= pos && end >= pos) return end;
    }

    var best = pos;
    for (final range in ranges) {
      final end = range.end.inMilliseconds;
      if (end > best) best = end;
    }
    return best;
  }

  static bool isPositionBuffered(VideoPlayerValue value, int targetMs) {
    if (!value.isInitialized) return false;
    final target = Duration(milliseconds: targetMs);
    return value.buffered.any(
      (range) => range.start <= target && target <= range.end,
    );
  }

  /// 对齐原生 PlayerLoadingHint：拖动/用户暂停时不显示转圈
  static bool isLoading(
    VideoPlayerController controller, {
    required bool userPaused,
    bool isScrubbing = false,
    bool isGestureSeeking = false,
  }) {
    if (userPaused || isScrubbing || isGestureSeeking) return false;
    final value = controller.value;
    if (!value.isInitialized) return true;
    if (value.hasError) return false;
    return value.isBuffering;
  }

  static Future<void> resumeOrReplay(VideoPlayerController controller) async {
    if (isCompleted(controller.value)) {
      await controller.seekTo(Duration.zero);
    }
    await controller.play();
  }
}

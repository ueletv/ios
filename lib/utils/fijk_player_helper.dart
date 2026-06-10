import 'package:fijkplayer/fijkplayer.dart';
import 'package:videoweb_flutter/services/device_info_service.dart';

/// fijkplayer / ijkplayer 配置（对齐原生 IJK 直播 + HotExoPlayer UA）
class FijkPlayerHelper {
  static Future<void> applyCommonOptions(FijkPlayer player) async {
    final userAgent = await DeviceInfoService.appUserAgent();
    await player.setOption(FijkOption.hostCategory, 'user-agent', userAgent);
    await player.setOption(
      FijkOption.hostCategory,
      'headers',
      'User-Agent: $userAgent\r\n',
    );
  }

  /// 直播 FLV（对齐原生 VideoView.setLiveSource(true)）
  static Future<void> applyLiveOptions(FijkPlayer player) async {
    await applyCommonOptions(player);
    await player.setOption(FijkOption.playerCategory, 'packet-buffering', 0);
    await player.setOption(FijkOption.playerCategory, 'framedrop', 1);
    await player.setOption(FijkOption.playerCategory, 'max_cached_duration', 3000);
    await player.setOption(FijkOption.playerCategory, 'infbuf', 1);
    await player.setOption(FijkOption.playerCategory, 'start-on-prepared', 1);
    await player.setOption(FijkOption.playerCategory, 'reconnect', 1);
  }

  /// 点播预缓冲（对齐 ExoPlayer DefaultLoadControl：播放时持续向后缓存，快进少卡顿）
  static Future<void> applyProgressiveOptions(FijkPlayer player) async {
    await applyCommonOptions(player);
    await player.setOption(FijkOption.playerCategory, 'start-on-prepared', 1);
    await player.setOption(FijkOption.playerCategory, 'enable-accurate-seek', 1);
    await player.setOption(FijkOption.playerCategory, 'packet-buffering', 1);
    await player.setOption(FijkOption.playerCategory, 'infbuf', 0);
    // 最大缓冲约 50MB（IJK 默认 15MB），可缓存更长的后续片段
    await player.setOption(FijkOption.playerCategory, 'max-buffer-size', 50 * 1024 * 1024);
    // 向后预加载时长上限（毫秒），约 2 分钟
    await player.setOption(FijkOption.playerCategory, 'max_cached_duration', 120000);
    // 水位线：起播 / 播放中 / 目标缓冲量
    await player.setOption(FijkOption.playerCategory, 'first-high-water-mark-ms', 100);
    await player.setOption(FijkOption.playerCategory, 'next-high-water-mark-ms', 1000);
    await player.setOption(FijkOption.playerCategory, 'last-high-water-mark-ms', 5000);
  }

  static Future<void> openUrl(
    FijkPlayer player,
    String url, {
    bool isLive = false,
    bool autoPlay = true,
  }) async {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return;
    if (isLive) {
      await applyLiveOptions(player);
    } else {
      await applyProgressiveOptions(player);
    }
    await player.setDataSource(trimmed, autoPlay: autoPlay);
    await player.setVolume(1.0);
  }

  static bool hasVideoSize(FijkValue value) {
    final size = value.size;
    return size != null && size.width > 0 && size.height > 0;
  }

  static bool isPlaying(FijkValue value) =>
      value.state == FijkState.started;

  /// 暂停恢复 / 播放结束后重播（completed 需先 seek 再 start，且 seek 完成前不能立刻 start）
  static Future<void> resumeOrReplay(FijkPlayer player) async {
    if (player.value.state == FijkState.completed) {
      try {
        await player.seekTo(0);
      } catch (_) {}
      await Future<void>.delayed(const Duration(milliseconds: 120));
    }
    await player.start();
  }

  static bool isBuffering(FijkValue value) =>
      value.state == FijkState.asyncPreparing;

  /// 是否显示加载转圈（对齐原生 PlayerLoadingHint：用户主动暂停/拖动时不显示）
  static bool isLoading(
    FijkPlayer player, {
    required bool userPaused,
    bool isScrubbing = false,
    bool isGestureSeeking = false,
    int? seekTargetMs,
    int? trustedBufferEndMs,
  }) {
    if (userPaused || isScrubbing || isGestureSeeking) return false;

    // 拖到已确认可播缓冲内：多为解码同步，不显示网络加载转圈
    if (seekTargetMs != null &&
        trustedBufferEndMs != null &&
        trustedBufferEndMs > 0 &&
        seekTargetMs <= trustedBufferEndMs + 600) {
      final value = player.value;
      if (value.state == FijkState.asyncPreparing) return false;
      if (value.state == FijkState.prepared && !value.videoRenderStart) {
        return false;
      }
      if (value.state == FijkState.started) return false;
    }

    final value = player.value;
    switch (value.state) {
      case FijkState.idle:
      case FijkState.initialized:
      case FijkState.asyncPreparing:
        return true;
      case FijkState.prepared:
        return !value.videoRenderStart;
      case FijkState.started:
        return player.isBuffering;
      default:
        return false;
    }
  }
}

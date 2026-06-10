import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:videoweb_flutter/pages/live/gift_svga_util.dart';
import 'package:videoweb_flutter/utils/image_url.dart';

/// 屏幕中央 SVGA 礼物动画（Android/iOS 原生 SVGAPlayer；仅在播放时挂载 PlatformView）
class LiveGiftSvgaOverlay extends StatefulWidget {
  const LiveGiftSvgaOverlay({super.key});

  @override
  State<LiveGiftSvgaOverlay> createState() => LiveGiftSvgaOverlayState();
}

class LiveGiftSvgaOverlayState extends State<LiveGiftSvgaOverlay> {
  static const _channel = MethodChannel('com.video.videoweb/live_gift_svga');
  static const _viewType = 'com.video.videoweb/live_gift_svga_view';

  bool _platformViewActive = false;
  Timer? _hideTimer;

  bool get _useNativeSvga =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  Future<void> play(String svgaUrl, int durationSeconds) async {
    final raw = svgaUrl.trim();
    if (raw.isEmpty || !GiftSvgaUtil.isSvgaUrl(raw)) return;

    final fullUrl = ImageUrl.getImageUrl(raw);
    if (fullUrl.isEmpty || !GiftSvgaUtil.isSvgaUrl(fullUrl)) return;

    if (!_useNativeSvga) return;

    final seconds = durationSeconds.clamp(1, 30);
    _hideTimer?.cancel();
    if (mounted) setState(() => _platformViewActive = true);

    try {
      await _channel.invokeMethod<void>('clear');
      await _channel.invokeMethod<void>('play', {
        'url': fullUrl,
        'duration': seconds,
      });
    } catch (e) {
      debugPrint('SVGA play failed: $e url=$fullUrl');
      if (mounted) setState(() => _platformViewActive = false);
      return;
    }

    _hideTimer = Timer(Duration(seconds: seconds), () {
      if (!mounted) return;
      setState(() => _platformViewActive = false);
      _channel.invokeMethod<void>('clear').catchError((_) {});
    });
  }

  Future<void> clear() async {
    _hideTimer?.cancel();
    if (mounted) setState(() => _platformViewActive = false);
    if (!_useNativeSvga) return;
    try {
      await _channel.invokeMethod<void>('clear');
    } catch (_) {}
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    if (_useNativeSvga) {
      _channel.invokeMethod<void>('clear').catchError((_) {});
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_useNativeSvga || !_platformViewActive) {
      return const SizedBox.shrink();
    }

    final gestureRecognizers = const <Factory<OneSequenceGestureRecognizer>>{};

    return IgnorePointer(
      child: Platform.isIOS
          ? UiKitView(
              viewType: _viewType,
              layoutDirection: TextDirection.ltr,
              creationParamsCodec: const StandardMessageCodec(),
              gestureRecognizers: gestureRecognizers,
              hitTestBehavior: PlatformViewHitTestBehavior.transparent,
            )
          : AndroidView(
              viewType: _viewType,
              layoutDirection: TextDirection.ltr,
              creationParamsCodec: const StandardMessageCodec(),
              gestureRecognizers: gestureRecognizers,
              hitTestBehavior: PlatformViewHitTestBehavior.transparent,
            ),
    );
  }
}

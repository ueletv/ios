import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// 无控制栏的点播画面（对齐原生 PlayerView / ExoPlayer 纹理）
class ProgressiveVideoView extends StatelessWidget {
  final VideoPlayerController controller;
  final BoxFit fit;
  final Color color;

  const ProgressiveVideoView({
    super.key,
    required this.controller,
    this.fit = BoxFit.contain,
    this.color = Colors.black,
  });

  @override
  Widget build(BuildContext context) {
    final value = controller.value;
    if (!value.isInitialized || value.size.width <= 0 || value.size.height <= 0) {
      return ColoredBox(color: color);
    }

    final video = SizedBox(
      width: value.size.width,
      height: value.size.height,
      child: VideoPlayer(controller),
    );

    if (fit == BoxFit.contain) {
      return ColoredBox(
        color: color,
        child: Center(
          child: AspectRatio(
            aspectRatio: value.aspectRatio,
            child: video,
          ),
        ),
      );
    }

    return ColoredBox(
      color: color,
      child: FittedBox(
        fit: fit,
        clipBehavior: Clip.hardEdge,
        child: video,
      ),
    );
  }
}

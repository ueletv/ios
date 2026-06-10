import 'package:flutter/material.dart';
import 'package:fijkplayer/fijkplayer.dart';

/// 无控制栏的 fijkplayer 画面（Texture 渲染，对齐原生 IJK VideoView）
class FijkVideoView extends StatelessWidget {
  final FijkPlayer player;
  final FijkFit fit;
  final Color color;

  const FijkVideoView({
    super.key,
    required this.player,
    this.fit = FijkFit.cover,
    this.color = Colors.black,
  });

  @override
  Widget build(BuildContext context) {
    return FijkView(
      player: player,
      color: color,
      fit: fit,
      panelBuilder: (FijkPlayer p, FijkData data, BuildContext ctx, Size viewSize, Rect texturePos) {
        return const SizedBox.shrink();
      },
    );
  }
}

import 'package:flutter/material.dart';

/// 播放器加载转圈（对齐原生 IncludePlayerLoadingHint）
class PlayerLoadingOverlay extends StatelessWidget {
  final bool visible;

  const PlayerLoadingOverlay({super.key, required this.visible});

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();
    return const Center(
      child: SizedBox(
        width: 36,
        height: 36,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          color: Colors.white,
        ),
      ),
    );
  }
}

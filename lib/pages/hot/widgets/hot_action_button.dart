import 'package:flutter/material.dart';
import 'package:videoweb_flutter/pages/hot/widgets/hot_douyin_icons.dart';
import 'package:videoweb_flutter/utils/video_interact_helper.dart';

/// 抖音色：已赞 #FE2C55，已收藏 #FACE15
class HotActionColors {
  static const likeActive = HotDouyinIcons.likeActive;
  static const favoriteActive = HotDouyinIcons.favoriteActive;
}

enum HotActionKind { like, comment, favorite, share }

/// 短视频右侧互动按钮（点击缩放 + 状态切换动画，对应原生 ic_hot_*）
class HotActionButton extends StatefulWidget {
  final HotActionKind kind;
  final bool active;
  final int count;
  final VoidCallback? onTap;

  const HotActionButton({
    super.key,
    required this.kind,
    this.active = false,
    this.count = 0,
    this.onTap,
  });

  @override
  State<HotActionButton> createState() => _HotActionButtonState();
}

class _HotActionButtonState extends State<HotActionButton>
    with SingleTickerProviderStateMixin {
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

  void _handleTap() {
    _controller.forward(from: 0);
    widget.onTap?.call();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final label = VideoInteractHelper.formatCount(widget.count);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _handleTap,
      child: SizedBox(
        width: 52,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _scale,
              builder: (context, child) {
                return Transform.scale(scale: _scale.value, child: child);
              },
              child: SizedBox(
                width: 36,
                height: 36,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  switchInCurve: Curves.easeOutBack,
                  switchOutCurve: Curves.easeIn,
                  transitionBuilder: (child, animation) {
                    return ScaleTransition(scale: animation, child: child);
                  },
                  child: KeyedSubtree(
                    key: ValueKey('${widget.kind}_${widget.active}'),
                    child: _HotActionIcon(kind: widget.kind, active: widget.active),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              transitionBuilder: (child, animation) {
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.35),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                );
              },
              child: Text(
                label,
                key: ValueKey(label),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  shadows: [
                    Shadow(color: Color(0x80000000), offset: Offset(0, 1), blurRadius: 2),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HotActionIcon extends StatelessWidget {
  final HotActionKind kind;
  final bool active;

  const _HotActionIcon({required this.kind, required this.active});

  @override
  Widget build(BuildContext context) {
    switch (kind) {
      case HotActionKind.like:
        return HotDouyinIcons.like(active: active);
      case HotActionKind.comment:
        return HotDouyinIcons.comment();
      case HotActionKind.favorite:
        return HotDouyinIcons.favorite(active: active);
      case HotActionKind.share:
        return HotDouyinIcons.share();
    }
  }
}

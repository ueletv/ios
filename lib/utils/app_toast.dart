import 'dart:async';

import 'package:flutter/material.dart';

/// 全局轻提示（对齐原生 Android Toast：屏幕中部小条，自动消失，非底部 SnackBar）
class AppToast {
  AppToast._();

  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  static OverlayEntry? _entry;
  static Timer? _hideTimer;

  /// [context] 可选；未传时使用 [navigatorKey] 根 Overlay
  static void show(
    String message, {
    BuildContext? context,
    Duration duration = const Duration(milliseconds: 2000),
  }) {
    final text = message.trim();
    if (text.isEmpty) return;

    OverlayState? overlay;
    if (context != null) {
      overlay = Overlay.maybeOf(context, rootOverlay: true);
    }
    overlay ??= navigatorKey.currentState?.overlay;
    if (overlay == null) return;

    _hideTimer?.cancel();
    _hideTimer = null;
    _entry?.remove();
    _entry = null;

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _AppToastBubble(
        message: text,
        duration: duration,
        onDismiss: () {
          if (_entry == entry) {
            entry.remove();
            _entry = null;
          }
        },
      ),
    );
    _entry = entry;
    overlay.insert(entry);
  }
}

class _AppToastBubble extends StatefulWidget {
  final String message;
  final Duration duration;
  final VoidCallback onDismiss;

  const _AppToastBubble({
    required this.message,
    required this.duration,
    required this.onDismiss,
  });

  @override
  State<_AppToastBubble> createState() => _AppToastBubbleState();
}

class _AppToastBubbleState extends State<_AppToastBubble> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
      reverseDuration: const Duration(milliseconds: 160),
    );
    _opacity = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _controller.forward();

    final fadeLead = const Duration(milliseconds: 160);
    final hold = widget.duration > fadeLead ? widget.duration - fadeLead : widget.duration;
    _timer = Timer(hold, _fadeOut);
  }

  Future<void> _fadeOut() async {
    if (!mounted) return;
    await _controller.reverse();
    if (mounted) widget.onDismiss();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: Center(
          child: FadeTransition(
            opacity: _opacity,
            child: Material(
              color: Colors.transparent,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 260),
                margin: const EdgeInsets.symmetric(horizontal: 36),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xCC1C1C1E),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  widget.message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    height: 1.35,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

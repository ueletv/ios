import 'package:flutter/material.dart';

/// 加载页面（对应原生 LoadingFragment.kt）
class LoadingPage extends StatelessWidget {
  final String? message;

  const LoadingPage({super.key, this.message});

  /// 全屏加载遮罩
  static OverlayEntry showOverlay(
    BuildContext context, {
    String? message,
    bool dismissible = false,
  }) {
    final entry = OverlayEntry(
      builder: (_) => LoadingOverlay(message: message, dismissible: dismissible),
    );
    Overlay.of(context).insert(entry);
    return entry;
  }

  /// 以底部弹窗形式显示加载
  static Future<T?> showModal<T>(
    BuildContext context, {
    String? message,
  }) {
    return showDialog<T>(
      context: context,
      barrierDismissible: false,
      builder: (_) => LoadingPage(message: message),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        color: Colors.black54,
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 48,
              height: 48,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: Colors.white,
              ),
            ),
            if (message != null && message!.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                message!,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 加载遮罩（用于 Overlay）
class LoadingOverlay extends StatelessWidget {
  final String? message;
  final bool dismissible;

  const LoadingOverlay({
    super.key,
    this.message,
    this.dismissible = false,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 遮罩（可点击关闭）
        GestureDetector(
          onTap: dismissible ? () {} : null,
          child: Container(color: Colors.black54),
        ),
        // 加载指示器
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 48,
                height: 48,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: Colors.white,
                ),
              ),
              if (message != null && message!.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  message!,
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';

/// Telegram 品牌图标（圆形蓝底纸飞机）
class TelegramIcon extends StatelessWidget {
  final double size;

  const TelegramIcon({super.key, this.size = 26});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _TelegramIconPainter()),
    );
  }
}

class _TelegramIconPainter extends CustomPainter {
  static const _blue = Color(0xFF229ED9);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2;
    canvas.drawCircle(center, radius, Paint()..color = _blue);

    final w = size.width;
    final h = size.height;
    final plane = Path()
      ..moveTo(w * 0.30, h * 0.50)
      ..lineTo(w * 0.76, h * 0.34)
      ..lineTo(w * 0.54, h * 0.70)
      ..lineTo(w * 0.44, h * 0.56)
      ..lineTo(w * 0.34, h * 0.62)
      ..close();
    canvas.drawPath(plane, Paint()..color = Colors.white);

    final tail = Path()
      ..moveTo(w * 0.44, h * 0.56)
      ..lineTo(w * 0.50, h * 0.48)
      ..lineTo(w * 0.62, h * 0.58)
      ..close();
    canvas.drawPath(tail, Paint()..color = const Color(0xFFD4ECFF));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

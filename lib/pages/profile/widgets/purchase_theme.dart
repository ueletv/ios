import 'package:flutter/material.dart';

/// 购买页配色
class PurchaseColors {
  PurchaseColors._();

  static const vipAccent = Color(0xFFFFB300);
  static const vipAccentDark = Color(0xFFFF8F00);
  static const rechargeAccent = Color(0xFF7C4DFF);
  static const rechargeAccentDark = Color(0xFF651FFF);
  static const rechargeSurfaceTint = Color(0xFFEDE7F6);
  static const price = Color(0xFFE91E63);
}

class PurchaseGradients {
  PurchaseGradients._();

  static const vipHero = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFFB74D), Color(0xFFFF8F00), Color(0xFFF57C00)],
  );

  static const rechargeHero = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF9575CD), Color(0xFF7E57C2), Color(0xFF5E35B1)],
  );
}

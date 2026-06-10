import 'package:flutter/material.dart';
import 'package:videoweb_flutter/theme/app_theme.dart';

/// 对应原生 bg_profile_header_card.xml（渐变 + 右上/左下光晕 + 描边）
class ProfileHeaderBackground extends StatelessWidget {
  final AppColors colors;
  final Widget child;

  const ProfileHeaderBackground({
    super.key,
    required this.colors,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final isLight = colors.pageBg.computeLuminance() > 0.5;
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        clipBehavior: Clip.antiAlias,
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: const Alignment(-0.85, -0.55),
                  end: const Alignment(0.85, 0.55),
                  colors: [colors.profileHeaderStart, colors.profileHeaderEnd],
                ),
              ),
            ),
          ),
          Positioned(
            top: 0,
            right: 0,
            child: Container(
              width: 96,
              height: 72,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0.85, -0.15),
                  radius: 0.95,
                  colors: [colors.profileHeaderGlow, colors.profileHeaderGlow.withOpacity(0)],
                ),
              ),
            ),
          ),
          if (isLight)
            Positioned(
              left: 0,
              bottom: 0,
              child: Container(
                width: 72,
                height: 48,
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 0.9,
                    colors: [const Color(0x0AFF6B35), const Color(0x00FF6B35)],
                  ),
                ),
              ),
            ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: colors.cardStroke, width: 1),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

/// 原生 ic_vip_badge：32×18 琥珀色 VIP 标
class ProfileVipBadge extends StatelessWidget {
  const ProfileVipBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 18,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFFFC107),
        borderRadius: BorderRadius.circular(2),
      ),
      child: const Text(
        'VIP',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w900,
          color: Color(0xFF3E2723),
          height: 1,
        ),
      ),
    );
  }
}

/// 原生 bg_level_badge：18dp 高、绿色等级数字
class ProfileLevelBadge extends StatelessWidget {
  final String level;

  const ProfileLevelBadge({super.key, required this.level});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 22, minHeight: 18),
      height: 18,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFF4CAF50),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        level,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.bold,
          height: 1,
        ),
      ),
    );
  }
}

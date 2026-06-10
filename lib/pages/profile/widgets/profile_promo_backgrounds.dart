import 'package:flutter/material.dart';
import 'package:videoweb_flutter/pages/profile/widgets/profile_assets.dart';
import 'package:videoweb_flutter/pages/profile/widgets/purchase_theme.dart';
/// 个人中心 / 购买页促销背景（图片缺失时自动降级为渐变，不显示报错文字）
class ProfilePromoBackgrounds {
  static Widget vipCardOverlay({required Widget child}) {
    return _promoCard(
      gradient: PurchaseGradients.vipHero,
      asset: ProfileAssets.cardVip,
      child: child,
    );
  }

  static Widget rechargeCardOverlay({required Widget child}) {
    return _promoCard(
      gradient: PurchaseGradients.rechargeHero,
      asset: ProfileAssets.cardRecharge,
      child: child,
    );
  }

  static Widget inviteBannerOverlay({required Widget child}) {
    return _promoCard(
      gradient: const LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [Color(0xFFE91E63), Color(0xFFC2185B)],
      ),
      asset: ProfileAssets.bannerInvite,
      child: child,
    );
  }

  static Widget vipHeroOverlay({required Widget child}) {
    return _promoCard(
      gradient: PurchaseGradients.vipHero,
      asset: ProfileAssets.heroVip,
      child: child,
    );
  }

  static Widget rechargeHeroOverlay({required Widget child}) {
    return _promoCard(
      gradient: PurchaseGradients.rechargeHero,
      asset: ProfileAssets.heroRecharge,
      child: child,
    );
  }

  static Widget _promoCard({
    required Gradient gradient,
    String? asset,
    required Widget child,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        clipBehavior: Clip.antiAlias,
        fit: StackFit.passthrough,
        children: [
          Positioned.fill(child: _BackgroundLayer(gradient: gradient, asset: asset)),
          child,
        ],
      ),
    );
  }

  static BoxDecoration promoActionBtn() {
    return BoxDecoration(
      color: Colors.black.withOpacity(0.45),
      borderRadius: BorderRadius.circular(999),
    );
  }
}

class _BackgroundLayer extends StatelessWidget {
  final Gradient gradient;
  final String? asset;

  const _BackgroundLayer({required this.gradient, this.asset});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(gradient: gradient),
      child: Stack(
        fit: StackFit.expand,
        children: [
          _DecorBlobs(gradient: gradient),
          if (asset != null)
            Image.asset(
              asset!,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                if (frame == null && !wasSynchronouslyLoaded) return const SizedBox.shrink();
                return child;
              },
            ),
        ],
      ),
    );
  }
}

class _DecorBlobs extends StatelessWidget {
  final Gradient gradient;

  const _DecorBlobs({required this.gradient});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            right: -28,
            top: -32,
            child: _blob(110, Colors.white.withOpacity(0.10)),
          ),
          Positioned(
            left: -18,
            bottom: -24,
            child: _blob(72, Colors.white.withOpacity(0.06)),
          ),
        ],
      ),
    );
  }

  Widget _blob(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

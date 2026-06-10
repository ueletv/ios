import 'package:flutter/material.dart';
import 'package:videoweb_flutter/api/models/recharge.dart';
import 'package:videoweb_flutter/api/models/vip_info.dart';
import 'package:videoweb_flutter/pages/profile/widgets/profile_promo_backgrounds.dart';
import 'package:videoweb_flutter/pages/profile/widgets/purchase_theme.dart';
import 'package:videoweb_flutter/theme/app_theme.dart';

/// 购买页通用组件
class PurchaseWidgets {
  static Widget vipHero({required String title, required String desc}) {
    return ProfilePromoBackgrounds.vipHeroOverlay(
      child: SizedBox(
        width: double.infinity,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.22),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.workspace_premium_rounded, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _heroTag('VIP 会员'),
                    const SizedBox(height: 8),
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      desc,
                      style: TextStyle(color: Colors.white.withOpacity(0.92), fontSize: 13, height: 1.35),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget rechargeHero({
    required String balance,
    required bool refreshing,
    required VoidCallback onRefresh,
  }) {
    return ProfilePromoBackgrounds.rechargeHeroOverlay(
      child: SizedBox(
        width: double.infinity,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.22),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.diamond_outlined, color: Colors.white, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _heroTag('直播钱包'),
                    const SizedBox(height: 10),
                    Text('当前钻石余额', style: TextStyle(color: Colors.white.withOpacity(0.88), fontSize: 12)),
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          balance,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            height: 1.0,
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.only(left: 4),
                          child: Text('钻石', style: TextStyle(color: Color(0xE6FFFFFF), fontSize: 13)),
                        ),
                        const SizedBox(width: 8),
                        _heroIconBtn(
                          icon: Icons.refresh_rounded,
                          loading: refreshing,
                          onTap: refreshing ? null : onRefresh,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _heroTag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.22),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }

  static Widget _heroIconBtn({
    required IconData icon,
    required bool loading,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.black.withOpacity(0.22),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: SizedBox(
          width: 36,
          height: 36,
          child: loading
              ? const Padding(
                  padding: EdgeInsets.all(8),
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }

  static Widget sectionTitle(String text, {String? subtitle, AppColors? colors}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          text,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: colors?.textPrimary ?? Colors.black87,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(subtitle, style: TextStyle(fontSize: 12, color: colors?.textHint ?? Colors.black45)),
        ],
      ],
    );
  }

  static Widget vipPlanCard({
    required VipInfo plan,
    required bool recommend,
    required VoidCallback onTap,
    required AppColors colors,
  }) {
    return Material(
      color: colors.cardBg,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: recommend ? PurchaseColors.vipAccent.withOpacity(0.55) : colors.cardStroke,
              width: recommend ? 1.5 : 1,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          plan.name ?? 'VIP',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: colors.textPrimary),
                        ),
                        if (recommend) ...[
                          const SizedBox(width: 8),
                          _smallBadge('推荐', const [PurchaseColors.vipAccent, PurchaseColors.vipAccentDark]),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      plan.timeText.isEmpty ? '—' : plan.timeText,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: PurchaseColors.vipAccentDark),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text('¥', style: TextStyle(color: PurchaseColors.price, fontSize: 13, fontWeight: FontWeight.w700)),
                      Text(
                        plan.priceDisplay.replaceFirst('¥', ''),
                        style: const TextStyle(color: PurchaseColors.price, fontSize: 22, fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text('立即开通', style: TextStyle(fontSize: 11, color: colors.textHint)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget vipBenefitsCard(AppColors colors) {
    const items = [
      (Icons.play_circle_outline, '付费视频免费看'),
      (Icons.hd_outlined, '高清画质优先'),
      (Icons.block_outlined, '减少广告打扰'),
      (Icons.support_agent_outlined, '专属客服通道'),
    ];
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      decoration: BoxDecoration(
        color: colors.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.cardStroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('会员权益', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: colors.textPrimary)),
          const SizedBox(height: 4),
          ...items.map(
            (item) => ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 0),
              dense: true,
              leading: Icon(item.$1, size: 20, color: PurchaseColors.vipAccentDark),
              title: Text(item.$2, style: TextStyle(fontSize: 14, color: colors.textSecondary)),
            ),
          ),
        ],
      ),
    );
  }

  static Widget rechargeRuleCard({
    required RechargeRule rule,
    required bool selected,
    required bool recommend,
    required AppColors colors,
    required VoidCallback onTap,
  }) {
    final accent = PurchaseColors.rechargeAccentDark;
    return Material(
      color: selected ? PurchaseColors.rechargeSurfaceTint.withOpacity(0.45) : colors.cardBg,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: selected ? accent : colors.cardStroke, width: selected ? 2 : 1),
          ),
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (recommend) _smallBadge('热门', const [PurchaseColors.rechargeAccent, PurchaseColors.rechargeAccentDark]),
                  const Spacer(),
                  if (selected) Icon(Icons.check_circle_rounded, size: 18, color: accent),
                ],
              ),
              if (recommend) const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${rule.totalCoins}',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: selected ? accent : colors.textPrimary,
                      height: 1.0,
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(left: 3, bottom: 2),
                    child: Text('钻石', style: TextStyle(fontSize: 12, color: PurchaseColors.rechargeAccent)),
                  ),
                ],
              ),
              if (rule.bonusCoins > 0) ...[
                const SizedBox(height: 6),
                Text(
                  '含赠送 ${rule.bonusCoins}',
                  style: TextStyle(fontSize: 11, color: selected ? accent : colors.textHint),
                ),
              ],
              const Spacer(),
              Align(
                alignment: Alignment.bottomRight,
                child: Text(
                  '¥${rule.amount}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: selected ? accent : PurchaseColors.price,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _smallBadge(String text, List<Color> gradientColors) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: gradientColors),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
    );
  }

  static Widget rechargeTipsCard(AppColors colors) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.chipBg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, size: 18, color: colors.textHint),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '钻石用于直播间打赏等消费；充值到账后可在「我的」查看余额。如有疑问请联系客服。',
              style: TextStyle(fontSize: 12, height: 1.5, color: colors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  static Widget rechargeBottomBar({
    required RechargeRule? rule,
    required bool loading,
    required VoidCallback onSubmit,
    AppColors? colors,
  }) {
    if (rule == null) return const SizedBox.shrink();
    final surface = colors?.cardBg ?? Colors.white;
    final hint = colors?.textHint ?? Colors.black45;
    final secondary = colors?.textSecondary ?? Colors.black54;
    return Container(
      decoration: BoxDecoration(
        color: surface,
        border: Border(top: BorderSide(color: colors?.cardStroke ?? const Color(0xFFE0E0E0))),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('禁止未成年人充值消费', style: TextStyle(fontSize: 11, color: hint)),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('应付金额', style: TextStyle(fontSize: 12, color: secondary)),
                      Text(
                        '¥${rule.amount}',
                        style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: PurchaseColors.rechargeAccentDark),
                      ),
                      Text('到账 ${rule.totalCoins} 钻石', style: TextStyle(fontSize: 12, color: hint)),
                    ],
                  ),
                ),
                FilledButton(
                  onPressed: loading ? null : onSubmit,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(120, 48),
                    backgroundColor: PurchaseColors.rechargeAccentDark,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('立即充值', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

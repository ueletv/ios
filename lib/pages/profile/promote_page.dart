import 'package:flutter/material.dart';
import 'package:videoweb_flutter/utils/app_toast.dart';

import 'package:provider/provider.dart';
import 'package:videoweb_flutter/pages/profile/widgets/profile_subpage_scaffold.dart';
import 'package:videoweb_flutter/services/theme_controller.dart';
import 'package:videoweb_flutter/theme/app_theme.dart';

/// 推广页（对应原生 PromoteActivity.kt）
class PromotePage extends StatefulWidget {
  const PromotePage({super.key});

  @override
  State<PromotePage> createState() => _PromotePageState();
}

class _PromotePageState extends State<PromotePage> {
  final _linkCtrl = TextEditingController(text: 'https://app.16kkk.cc/invite?code=');

  @override
  void dispose() {
    _linkCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    context.watch<ThemeController>();
    final colors = context.appColors;
    return ProfileSubpageScaffold(
      title: '推广中心',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.green.shade400, Colors.green.shade700],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Column(
              children: [
                Icon(Icons.share, size: 48, color: Colors.white),
                SizedBox(height: 12),
                Text('邀请好友赚收益', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                Text('分享给好友，好友注册后你可获得丰厚的奖励', textAlign: TextAlign.center, style: TextStyle(color: Colors.white70, fontSize: 14)),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text('推广链接', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: colors.textPrimary)),
          const SizedBox(height: 8),
          ProfileThemedCard(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _linkCtrl,
                    readOnly: true,
                    style: TextStyle(color: colors.textSecondary, fontSize: 13),
                    decoration: const InputDecoration(border: InputBorder.none, isDense: true),
                  ),
                ),
                IconButton(icon: Icon(Icons.copy, color: colors.textSecondary), onPressed: () => _showToast('链接已复制'), tooltip: '复制链接'),
                IconButton(icon: Icon(Icons.share, color: colors.textSecondary), onPressed: () => _showToast('分享功能待实现'), tooltip: '分享'),
              ],
            ),
          ),
          const SizedBox(height: 32),
          Text('推广规则', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: colors.textPrimary)),
          const SizedBox(height: 12),
          _buildRuleItem(colors, Icons.person_add, '邀请好友注册成为平台用户'),
          _buildRuleItem(colors, Icons.monetization_on, '好友观看内容你可获得收益分成'),
          _buildRuleItem(colors, Icons.card_giftcard, '达到一定邀请数量可获得额外奖励'),
          const SizedBox(height: 32),
          ProfileThemedCard(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(colors, '邀请人数', '0'),
                _buildStatItem(colors, '总收益', '¥0'),
                _buildStatItem(colors, '今日收益', '¥0'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRuleItem(AppColors colors, IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.green.shade400),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: TextStyle(fontSize: 14, color: colors.textPrimary))),
        ],
      ),
    );
  }

  Widget _buildStatItem(AppColors colors, String label, String value) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: colors.textPrimary)),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(color: colors.textSecondary, fontSize: 13)),
      ],
    );
  }

  void _showToast(String msg) {
    if (!mounted) return;
    AppToast.show(msg, context: context);
  }
}

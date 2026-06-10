import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:videoweb_flutter/services/theme_controller.dart';
import 'package:videoweb_flutter/theme/app_theme.dart';

/// 个人中心子页统一脚手架（对应各 Profile*Activity 主题背景）
class ProfileSubpageScaffold extends StatelessWidget {
  final String title;
  final Widget body;
  final List<Widget>? actions;

  const ProfileSubpageScaffold({
    super.key,
    required this.title,
    required this.body,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    context.watch<ThemeController>();
    final colors = context.appColors;
    return Scaffold(
      backgroundColor: colors.pageBg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
              child: Row(
                children: [
                  IconButton.filledTonal(
                    onPressed: () => Navigator.of(context).pop(),
                    style: IconButton.styleFrom(
                      backgroundColor: colors.chipBg,
                      foregroundColor: colors.textPrimary,
                    ),
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                  if (actions != null) ...actions!,
                ],
              ),
            ),
            Expanded(child: body),
          ],
        ),
      ),
    );
  }
}

/// 子页卡片容器
class ProfileThemedCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;

  const ProfileThemedCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: colors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.cardStroke, width: 0.5),
      ),
      child: child,
    );
  }
}

/// 空状态
class ProfileEmptyState extends StatelessWidget {
  final IconData icon;
  final String message;

  const ProfileEmptyState({super.key, required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: colors.textHint),
          const SizedBox(height: 16),
          Text(message, style: TextStyle(color: colors.textSecondary, fontSize: 16)),
        ],
      ),
    );
  }
}

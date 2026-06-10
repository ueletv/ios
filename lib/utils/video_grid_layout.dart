import 'package:flutter/material.dart';

/// 首页双列视频网格（对应 VideoGridLayout.kt + item_video_card.xml）
class VideoGridLayout {
  /// 与原生 columnWidthPx 一致：左右 inset 共 16dp
  static const double horizontalInsets = 16;

  /// item_video_card layout_margin
  static const double cardMargin = 4;

  /// 标题区高度（2 行 14sp + padding 6/8）
  static const double titleBlockHeight = 50;

  static int crossAxisCount(double width) => width > 600 ? 3 : 2;

  static double columnWidth(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    return (screenWidth - horizontalInsets) / crossAxisCount(screenWidth);
  }

  static double coverHeight(BuildContext context) => columnWidth(context) * 9 / 16;

  /// Flutter Grid 的 width / height
  static double childAspectRatio(BuildContext context) {
    final col = columnWidth(context);
    final cover = coverHeight(context);
    return col / (cover + titleBlockHeight + cardMargin * 2);
  }

  static SliverGridDelegateWithFixedCrossAxisCount sliverDelegate(BuildContext context) {
    return SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: crossAxisCount(MediaQuery.sizeOf(context).width),
      mainAxisSpacing: 0,
      crossAxisSpacing: 0,
      childAspectRatio: childAspectRatio(context),
    );
  }

  static SliverGridDelegateWithFixedCrossAxisCount boxDelegate(BuildContext context) {
    return sliverDelegate(context);
  }

  /// fragment_home_category_page recycler paddingHorizontal="2dp"
  static EdgeInsets get gridPadding => const EdgeInsets.fromLTRB(2, 0, 2, 8);
}

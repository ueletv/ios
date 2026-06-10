import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:videoweb_flutter/api/models/video.dart';
import 'package:videoweb_flutter/utils/image_url.dart';
import 'package:videoweb_flutter/utils/video_date_utils.dart';
import 'package:videoweb_flutter/utils/video_grid_layout.dart';
import 'package:videoweb_flutter/theme/app_theme.dart';

/// 首页视频卡片（对应原生 VideoListAdapter.kt + item_video_card.xml）
/// 双列等高：16:9 封面 + 右下角日期 + 标题在下。
class VideoCard extends StatelessWidget {
  final Video video;
  final VoidCallback? onTap;

  const VideoCard({
    super.key,
    required this.video,
    this.onTap,
  });

  bool get _isAd {
    final idText = video.id?.toString() ?? '';
    return video.type == 'ad' ||
        idText.startsWith('ad_') ||
        video.adId != null ||
        video.adTitle != null ||
        video.adCover != null;
  }

  String get _title => _isAd
      ? ((video.adTitle?.trim().isNotEmpty == true)
          ? video.adTitle!.trim()
          : (video.vodName?.trim().isNotEmpty == true ? video.vodName!.trim() : '广告'))
      : (video.vodName ?? '').trim();

  String? get _coverPath => _isAd
      ? ((video.adCover?.trim().isNotEmpty == true) ? video.adCover : video.vodPic)
      : video.vodPic;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final columnWidth = VideoGridLayout.columnWidth(context);
    final coverHeight = VideoGridLayout.coverHeight(context);
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final cacheW = (columnWidth * dpr).round();
    final cacheH = (coverHeight * dpr).round();
    final dateText = _isAd ? '' : VideoDateUtils.formatVideoDate(video);

    return Padding(
      padding: const EdgeInsets.all(VideoGridLayout.cardMargin),
      child: Material(
        color: colors.cardBg,
        elevation: 2,
        shadowColor: Colors.black.withOpacity(colors.pageBg.computeLuminance() > 0.5 ? 0.08 : 0.35),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: colors.cardStroke, width: 0.5),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: coverHeight,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ColoredBox(color: colors.placeholderBg),
                    CachedNetworkImage(
                      imageUrl: ImageUrl.getImageUrl(_coverPath),
                      fit: BoxFit.cover,
                      filterQuality: FilterQuality.medium,
                      fadeInDuration: Duration.zero,
                      fadeOutDuration: Duration.zero,
                      memCacheWidth: cacheW,
                      memCacheHeight: cacheH,
                      placeholder: (_, __) => ColoredBox(color: colors.placeholderBg),
                      errorWidget: (_, __, ___) => ColoredBox(
                        color: colors.placeholderBg,
                        child: Icon(Icons.movie_outlined, size: 34, color: colors.textHint),
                      ),
                    ),
                    if (dateText.isNotEmpty)
                      Positioned(
                        right: 6,
                        bottom: 6,
                        child: _DateBadge(text: dateText),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
                child: Text(
                  _title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: colors.textPrimary,
                    height: 1.14,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 对应 bg_video_date_badge.xml：#99000000，圆角 4dp
class _DateBadge extends StatelessWidget {
  final String text;

  const _DateBadge({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0x99000000),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w400,
          height: 1.1,
        ),
      ),
    );
  }
}

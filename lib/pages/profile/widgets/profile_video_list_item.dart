import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:videoweb_flutter/api/models/video.dart';
import 'package:videoweb_flutter/theme/app_theme.dart';
import 'package:videoweb_flutter/utils/image_url.dart';

/// 收藏/历史等列表项（主题适配）
class ProfileVideoListItem extends StatelessWidget {
  final Video video;
  final VoidCallback? onTap;

  const ProfileVideoListItem({super.key, required this.video, this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: colors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.cardStroke, width: 0.5),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: CachedNetworkImage(
                  imageUrl: ImageUrl.getImageUrl(video.vodPic),
                  width: 118,
                  height: 74,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(width: 118, height: 74, color: colors.placeholderBg),
                  errorWidget: (_, __, ___) => Container(
                    width: 118,
                    height: 74,
                    color: colors.chipBg,
                    child: Icon(Icons.broken_image, color: colors.textHint),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      video.displayName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: colors.textPrimary),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Icon(Icons.remove_red_eye, size: 14, color: colors.textHint),
                        const SizedBox(width: 4),
                        Text('${video.viewCount ?? 0}', style: TextStyle(color: colors.textSecondary, fontSize: 12)),
                        const SizedBox(width: 16),
                        Icon(Icons.favorite_border, size: 14, color: colors.textHint),
                        const SizedBox(width: 4),
                        Text('${video.favoriteCount ?? 0}', style: TextStyle(color: colors.textSecondary, fontSize: 12)),
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
}

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:videoweb_flutter/api/models/ad.dart';
import 'package:videoweb_flutter/services/theme_controller.dart';
import 'package:videoweb_flutter/theme/app_theme.dart';
import 'package:videoweb_flutter/utils/ad_link_helper.dart';
import 'package:videoweb_flutter/utils/image_url.dart';

/// 首页弹窗公告（对齐原生 PopupAnnouncementDialog + APP 主题色）
class AnnouncementDialog extends StatefulWidget {
  final PopupAdItem adItem;
  final int index;
  final int total;

  const AnnouncementDialog({
    super.key,
    required this.adItem,
    this.index = 1,
    this.total = 1,
  });

  static Future<void> show(
    BuildContext context, {
    required PopupAdItem adItem,
    int index = 1,
    int total = 1,
  }) {
    return showDialog<void>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      builder: (_) => AnnouncementDialog(
        adItem: adItem,
        index: index,
        total: total,
      ),
    );
  }

  @override
  State<AnnouncementDialog> createState() => _AnnouncementDialogState();
}

class _AnnouncementDialogState extends State<AnnouncementDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _scaleAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutBack);
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _dismiss() async {
    if (_closing) return;
    _closing = true;
    final navigator = Navigator.of(context, rootNavigator: true);
    try {
      if (_animCtrl.value > 0) {
        await _animCtrl.reverse();
      }
    } catch (_) {}
    if (navigator.canPop()) {
      navigator.pop();
    }
  }

  bool get _clickable => AdLinkHelper.hasLink(
        widget.adItem.linkType,
        widget.adItem.linkUrl,
        widget.adItem.linkId,
      );

  Future<void> _onTapContent() async {
    if (!_clickable) return;
    final ad = widget.adItem;
    await AdLinkHelper.openLink(
      context,
      linkType: ad.linkType,
      linkUrl: ad.linkUrl,
      linkId: ad.linkId,
    );
    await _dismiss();
  }

  @override
  Widget build(BuildContext context) {
    context.watch<ThemeController>();
    final colors = context.appColors;
    final ad = widget.adItem;
    final cover = ad.coverImage?.trim() ?? '';
    final content = ad.content?.trim() ?? '';
    final title = ad.title?.trim() ?? '';
    final hasImage = cover.isNotEmpty;
    final hasText = content.isNotEmpty;
    final isTextOnly = hasText && !hasImage;
    final maxWidth = (MediaQuery.sizeOf(context).width * 0.88).clamp(0.0, 400.0);
    final showTitle = title.isNotEmpty || isTextOnly;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _dismiss();
      },
      child: FadeTransition(
        opacity: _fadeAnim,
        child: Center(
          child: ScaleTransition(
            scale: _scaleAnim,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 14),
                      decoration: BoxDecoration(
                        color: colors.cardBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: colors.cardStroke),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.18),
                            blurRadius: 24,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (showTitle) ...[
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                              decoration: BoxDecoration(
                                color: colors.chipBg,
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(16),
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: colors.accentContainer,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      '公告',
                                      style: TextStyle(
                                        color: colors.accent,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      title.isNotEmpty
                                          ? title
                                          : '系统公告',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: colors.textPrimary,
                                        fontSize: 17,
                                        fontWeight: FontWeight.w700,
                                        height: 1.3,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Divider(height: 1, color: colors.divider),
                          ],
                          ConstrainedBox(
                            constraints: BoxConstraints(
                              maxHeight: MediaQuery.sizeOf(context).height * 0.52,
                            ),
                            child: SingleChildScrollView(
                              padding: EdgeInsets.fromLTRB(
                                16,
                                hasImage || hasText ? 12 : 16,
                                16,
                                12,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  if (hasImage)
                                    GestureDetector(
                                      onTap: _clickable ? _onTapContent : null,
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(10),
                                        child: ColoredBox(
                                          color: colors.placeholderBg,
                                          child: CachedNetworkImage(
                                            imageUrl: ImageUrl.getImageUrl(cover),
                                            width: double.infinity,
                                            fit: BoxFit.contain,
                                            placeholder: (_, __) => SizedBox(
                                              height: 180,
                                              child: Center(
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  color: colors.accent,
                                                ),
                                              ),
                                            ),
                                            errorWidget: (_, __, ___) => SizedBox(
                                              height: 160,
                                              child: Icon(
                                                Icons.broken_image_outlined,
                                                color: colors.textHint,
                                                size: 40,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  if (hasImage && hasText) const SizedBox(height: 12),
                                  if (hasText) ...[
                                    if (isTextOnly)
                                      Padding(
                                        padding: const EdgeInsets.only(bottom: 6),
                                        child: Text(
                                          '系统公告',
                                          style: TextStyle(
                                            color: colors.textHint,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    GestureDetector(
                                      onTap: _clickable ? _onTapContent : null,
                                      child: Text(
                                        content,
                                        style: TextStyle(
                                          color: colors.textSecondary,
                                          fontSize: 15,
                                          height: 1.55,
                                        ),
                                      ),
                                    ),
                                  ],
                                  if (!hasImage && !hasText)
                                    Text(
                                      title.isNotEmpty ? title : '系统公告',
                                      style: TextStyle(
                                        color: colors.textSecondary,
                                        fontSize: 15,
                                        height: 1.55,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          Divider(height: 1, color: colors.divider),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                            child: Column(
                              children: [
                                if (widget.total > 1)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: Text(
                                      '${widget.index} / ${widget.total}',
                                      style: TextStyle(
                                        color: colors.textHint,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                SizedBox(
                                  width: double.infinity,
                                  height: 46,
                                  child: FilledButton(
                                    onPressed: _clickable ? _onTapContent : _dismiss,
                                    style: FilledButton.styleFrom(
                                      backgroundColor: colors.accent,
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(999),
                                      ),
                                    ),
                                    child: Text(
                                      _clickable ? '查看详情' : '我知道了',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _dismiss,
                          customBorder: const CircleBorder(),
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: colors.textPrimary.withValues(alpha: 0.72),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close_rounded,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

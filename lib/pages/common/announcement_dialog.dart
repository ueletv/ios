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

  static const _popupTextStyle = TextStyle(decoration: TextDecoration.none);

  /// 与左上角「公告」角标重复的占位标题，不再在右侧重复展示
  static bool _isGenericPopupTitle(String title) {
    final t = title.trim();
    if (t.isEmpty) return true;
    const generic = {
      '广告', '弹窗广告', '首页弹窗', '弹窗', '公告广告', '系统广告',
      '公告', '系统公告',
    };
    return generic.contains(t);
  }

  static String _meaningfulPopupTitle(String? title) {
    final t = title?.trim() ?? '';
    if (_isGenericPopupTitle(t)) return '';
    return t;
  }

  /// 对齐原生 HtmlCompat：换行保留；去掉 hr / u 标签与纯横线装饰行
  static final _htmlBr = RegExp(r'<br\s*/?>', caseSensitive: false);
  static final _htmlHr = RegExp(r'<hr\s*/?>', caseSensitive: false);
  static final _htmlTag = RegExp(r'<[^>]+>');
  static final _decorativeLine = RegExp(r'^[\s\-_=*─—－~·.。…•|]+$');

  static String _displayPopupContent(String? raw) {
    var text = raw?.trim() ?? '';
    if (text.isEmpty) return '';

    text = text
        .replaceAll(_htmlBr, '\n')
        .replaceAll(_htmlHr, '')
        .replaceAll(_htmlTag, '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"');

    final lines = <String>[];
    for (final line in text.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) {
        if (lines.isEmpty || lines.last.isEmpty) continue;
        lines.add('');
        continue;
      }
      if (_decorativeLine.hasMatch(trimmed)) continue;
      lines.add(trimmed);
    }
    while (lines.isNotEmpty && lines.last.isEmpty) {
      lines.removeLast();
    }
    return lines.join('\n');
  }

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

  Widget _buildCloseButton(AppColors colors) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _dismiss,
        customBorder: const CircleBorder(),
        child: Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: colors.chipBg,
            shape: BoxShape.circle,
            border: Border.all(color: colors.cardStroke),
          ),
          child: Icon(
            Icons.close_rounded,
            size: 18,
            color: colors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildNoticeBadge(AppColors colors) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: colors.accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.accent.withValues(alpha: 0.35)),
      ),
      child: Text(
        '公告',
        style: _popupTextStyle.copyWith(
          color: colors.accent,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          height: 1.2,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    context.watch<ThemeController>();
    final colors = context.appColors;
    final ad = widget.adItem;
    final cover = ad.coverImage?.trim() ?? '';
    final content = _displayPopupContent(ad.content);
    final headerTitle = _meaningfulPopupTitle(ad.title);
    final hasImage = cover.isNotEmpty;
    final hasText = content.isNotEmpty;
    final maxWidth = (MediaQuery.sizeOf(context).width * 0.88).clamp(0.0, 400.0);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _dismiss();
      },
      child: DefaultTextStyle(
        style: _popupTextStyle.copyWith(color: colors.textPrimary),
        child: FadeTransition(
          opacity: _fadeAnim,
          child: Center(
            child: ScaleTransition(
              scale: _scaleAnim,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  child: Container(
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
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 16, 12, 0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                _buildNoticeBadge(colors),
                                if (headerTitle.isNotEmpty) ...[
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      headerTitle,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: _popupTextStyle.copyWith(
                                        color: colors.textPrimary,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        height: 1.35,
                                      ),
                                    ),
                                  ),
                                ] else
                                  const Spacer(),
                                const SizedBox(width: 8),
                                _buildCloseButton(colors),
                              ],
                            ),
                          ),
                          if (hasImage || hasText)
                            ConstrainedBox(
                              constraints: BoxConstraints(
                                maxHeight: MediaQuery.sizeOf(context).height * 0.52,
                              ),
                              child: SingleChildScrollView(
                                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
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
                                    if (hasText)
                                      Text(
                                        content,
                                        style: _popupTextStyle.copyWith(
                                          color: colors.textSecondary,
                                          fontSize: 15,
                                          height: 1.55,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          if (!hasImage && !hasText && headerTitle.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                              child: Text(
                                headerTitle,
                                style: _popupTextStyle.copyWith(
                                  color: colors.textSecondary,
                                  fontSize: 15,
                                  height: 1.55,
                                ),
                              ),
                            ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                            child: Column(
                              children: [
                                if (widget.total > 1)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: Text(
                                      '${widget.index} / ${widget.total}',
                                      style: _popupTextStyle.copyWith(
                                        color: colors.textHint,
                                        fontSize: 12,
                                        height: 1.2,
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
                                      style: _popupTextStyle.copyWith(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
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
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

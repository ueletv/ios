import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:videoweb_flutter/api/models/ad.dart';
import 'package:videoweb_flutter/services/theme_controller.dart';
import 'package:videoweb_flutter/theme/app_theme.dart';
import 'package:videoweb_flutter/utils/ad_link_helper.dart';

/// 首页弹窗公告（仅文字，不展示封面图广告）
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
    final content = ad.content?.trim() ?? '';
    final title = ad.title?.trim() ?? '';
    final hasText = content.isNotEmpty;
    final maxWidth = (MediaQuery.sizeOf(context).width * 0.88).clamp(0.0, 400.0);
    final headline = title.isNotEmpty ? title : '系统公告';
    final body = hasText ? content : headline;

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
                                    headline,
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
                          ConstrainedBox(
                            constraints: BoxConstraints(
                              maxHeight: MediaQuery.sizeOf(context).height * 0.52,
                            ),
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                              child: GestureDetector(
                                onTap: _clickable ? _onTapContent : null,
                                child: Text(
                                  body,
                                  style: TextStyle(
                                    color: colors.textSecondary,
                                    fontSize: 15,
                                    height: 1.55,
                                  ),
                                ),
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

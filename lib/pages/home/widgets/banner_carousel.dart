import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:videoweb_flutter/utils/image_url.dart';
import 'package:videoweb_flutter/theme/app_theme.dart';

/// Banner 轮播组件（对应原生 BannerAdapter.kt）
class BannerCarousel extends StatefulWidget {
  final List<BannerCarouselItem> items;
  final void Function(BannerCarouselItem item)? onTap;

  const BannerCarousel({
    super.key,
    required this.items,
    this.onTap,
  });

  @override
  State<BannerCarousel> createState() => _BannerCarouselState();
}

class _BannerCarouselState extends State<BannerCarousel> {
  late PageController _pageController;
  Timer? _timer;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    if (widget.items.length > 1) {
      _startAutoScroll();
    }
  }

  void _startAutoScroll() {
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (_pageController.hasClients) {
        final next = (_currentPage + 1) % widget.items.length;
        _pageController.animateToPage(
          next,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) return const SizedBox.shrink();
    final colors = context.appColors;

    return LayoutBuilder(
      builder: (context, constraints) {
        final height = (constraints.maxWidth * 2 / 5).clamp(1.0, 150.0);
        return SizedBox(
          height: height,
          child: Stack(
            children: [
              PageView.builder(
                controller: _pageController,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemCount: widget.items.length,
                itemBuilder: (context, index) {
                  final item = widget.items[index];
                  return GestureDetector(
                    onTap: () => widget.onTap?.call(item),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          CachedNetworkImage(
                            imageUrl: ImageUrl.getImageUrl(item.imageUrl),
                            width: double.infinity,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => Container(color: colors.placeholderBg),
                            errorWidget: (_, __, ___) => Container(
                              color: colors.chipBg,
                              child: Icon(Icons.broken_image, color: colors.textHint),
                            ),
                          ),
                          if (item.title != null)
                            Positioned(
                              left: 8,
                              bottom: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.24),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  item.title!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 3,
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(widget.items.length, (i) {
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 240),
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        width: _currentPage == i ? 13 : 4,
                        height: 4,
                        decoration: BoxDecoration(
                          color: _currentPage == i ? Colors.white : Colors.white54,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      );
                    }),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Banner 数据项
class BannerCarouselItem {
  final String? imageUrl;
  final String? title;
  final String? link;
  final String? linkType;
  final dynamic linkId;

  const BannerCarouselItem({
    this.imageUrl,
    this.title,
    this.link,
    this.linkType,
    this.linkId,
  });
}

import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:videoweb_flutter/api/models/ad.dart';
import 'package:videoweb_flutter/services/app_prefs.dart';
import 'package:videoweb_flutter/utils/ad_link_helper.dart';
import 'package:videoweb_flutter/utils/image_url.dart';

/// 开屏广告序列（对应原生 SplashActivity 广告逻辑）
class SplashAdView extends StatefulWidget {
  final List<SplashAdItem> ads;
  final VoidCallback onComplete;

  const SplashAdView({
    super.key,
    required this.ads,
    required this.onComplete,
  });

  @override
  State<SplashAdView> createState() => _SplashAdViewState();
}

class _SplashAdViewState extends State<SplashAdView> {
  static const _maxPerLaunch = 3;

  late final List<SplashAdItem> _queue;
  Timer? _timer;
  int _secondsLeft = 0;
  int _displayedIndex = -1;
  bool _waitingTapToEnter = false;

  @override
  void initState() {
    super.initState();
    _queue = widget.ads.take(_maxPerLaunch).toList();
    if (_queue.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => widget.onComplete());
      return;
    }
    _startSequence();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startSequence() {
    final durations = _queue.map((e) => e.duration.clamp(1, 15)).toList();
    final total = durations.fold<int>(0, (a, b) => a + b).clamp(1, 999);
    final segmentEnds = <int>[];
    var acc = 0;
    for (final d in durations) {
      acc += d;
      segmentEnds.add(acc);
    }

    final skipDuring = _queue.any((e) => e.manualSkip == 1);
    final autoEnterAtEnd = _queue.any((e) => e.autoSkip == 1);
    final tapToEnterAtEnd = _queue.any((e) => e.tapToEnter == 1);

    int adIndexForLeft(int left) {
      final elapsed = total - left;
      for (var i = 0; i < segmentEnds.length; i++) {
        if (elapsed < segmentEnds[i]) return i;
      }
      return _queue.length - 1;
    }

    void showAdAt(int index) {
      if (index == _displayedIndex || index < 0 || index >= _queue.length) return;
      setState(() => _displayedIndex = index);
    }

    void finish() {
      final prefs = context.read<AppPrefs>();
      for (final ad in _queue) {
        if (ad.showOnce == 1) prefs.markSplashAdShown(ad.id);
      }
      widget.onComplete();
    }

    void onCountdownFinished() {
      showAdAt(adIndexForLeft(0));
      if (tapToEnterAtEnd && !autoEnterAtEnd) {
        setState(() => _waitingTapToEnter = true);
      } else {
        finish();
      }
    }

    showAdAt(0);
    _secondsLeft = total;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _secondsLeft--);
      if (_secondsLeft > 0) {
        showAdAt(adIndexForLeft(_secondsLeft));
      } else {
        t.cancel();
        onCountdownFinished();
      }
    });

    _skipDuring = skipDuring;
  }

  bool _skipDuring = true;

  void _onSkipPressed() {
    _timer?.cancel();
    final prefs = context.read<AppPrefs>();
    for (final ad in _queue) {
      if (ad.showOnce == 1) prefs.markSplashAdShown(ad.id);
    }
    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    if (_queue.isEmpty || _displayedIndex < 0) {
      return const SizedBox.shrink();
    }
    final ad = _queue[_displayedIndex];
    final cover = ad.coverImage?.trim() ?? '';
    final canSkip = _waitingTapToEnter || (_secondsLeft > 0 && _skipDuring);

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (cover.isNotEmpty)
            GestureDetector(
              onTap: AdLinkHelper.hasLink(ad.linkType, ad.linkUrl, ad.linkId)
                  ? () => AdLinkHelper.openLink(
                        context,
                        linkType: ad.linkType,
                        linkUrl: ad.linkUrl,
                        linkId: ad.linkId,
                      )
                  : null,
              child: CachedNetworkImage(
                imageUrl: ImageUrl.getImageUrl(cover),
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
              ),
            )
          else
            const ColoredBox(color: Color(0xFFF6F7FB)),
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            right: 16,
            child: _SplashSkipChip(
              enabled: canSkip,
              label: _waitingTapToEnter
                  ? '进入APP'
                  : _secondsLeft > 0
                      ? '广告 ${_secondsLeft}s${_skipDuring ? ' 跳过' : ''}'
                      : '进入APP',
              onTap: _onSkipPressed,
            ),
          ),
        ],
      ),
    );
  }
}

/// 右上角倒计时/跳过（对齐原生 activity_splash.xml：高 36dp、左右 16dp 内边距）
class _SplashSkipChip extends StatelessWidget {
  final bool enabled;
  final String label;
  final VoidCallback onTap;

  const _SplashSkipChip({
    required this.enabled,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(4),
        child: Ink(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: const Color(0xCC000000),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white.withOpacity(enabled ? 1 : 0.55),
                fontSize: 14,
                height: 1,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

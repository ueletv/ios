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
            child: TextButton(
              onPressed: canSkip ? _onSkipPressed : null,
              style: TextButton.styleFrom(
                backgroundColor: Colors.black45,
                foregroundColor: Colors.white,
              ),
              child: Text(
                _waitingTapToEnter
                    ? '进入APP'
                    : _secondsLeft > 0
                        ? '广告 ${_secondsLeft}s${_skipDuring ? ' 跳过' : ''}'
                        : '进入APP',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

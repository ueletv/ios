import 'package:flutter/material.dart';

/// 带预缓冲进度的播放进度条（对齐原生 DefaultTimeBar：已播 / 已缓存未播 / 未加载）
class PlayerBufferedProgressBar extends StatefulWidget {
  final double value;
  final double bufferValue;
  final double max;
  final Color playedColor;
  final Color bufferedColor;
  final Color trackColor;
  final Color thumbColor;
  final bool showThumb;
  final double minAheadPixels;
  final ValueChanged<double>? onChangeStart;
  final ValueChanged<double>? onChanged;
  final ValueChanged<double>? onChangeEnd;

  const PlayerBufferedProgressBar({
    super.key,
    required this.value,
    required this.bufferValue,
    required this.max,
    this.playedColor = const Color(0xFFFF6B6B),
    this.bufferedColor = const Color(0x66FFFFFF),
    this.trackColor = const Color(0x33FFFFFF),
    this.thumbColor = const Color(0xFFFF6B6B),
    this.showThumb = true,
    this.minAheadPixels = 8,
    this.onChangeStart,
    this.onChanged,
    this.onChangeEnd,
  });

  @override
  State<PlayerBufferedProgressBar> createState() => _PlayerBufferedProgressBarState();
}

class _PlayerBufferedProgressBarState extends State<PlayerBufferedProgressBar> {
  bool _dragging = false;
  double _dragValue = 0;

  double get _effectiveMax => widget.max > 0 ? widget.max : 1;

  double get _displayValue => _dragging ? _dragValue : widget.value;

  bool get _interactive =>
      widget.onChanged != null || widget.onChangeStart != null || widget.onChangeEnd != null;

  void _updateByDx(double dx, double width) {
    final usable = (width - 16).clamp(1.0, double.infinity);
    final local = (dx - 8).clamp(0.0, usable);
    final ratio = local / usable;
    final next = (ratio * _effectiveMax).clamp(0.0, _effectiveMax);
    setState(() => _dragValue = next);
    widget.onChanged?.call(next);
  }

  @override
  Widget build(BuildContext context) {
    final maxV = _effectiveMax;
    final played = _displayValue.clamp(0, maxV);
    final buffered = widget.bufferValue.clamp(played, maxV);
    final hasAhead = buffered > played + 0.5;

    return SizedBox(
      height: widget.showThumb ? 28 : 16,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final barWidth = constraints.maxWidth;
          final innerW = (barWidth - 16).clamp(1.0, double.infinity);
          final playedW = innerW * (played / maxV);
          var aheadW = hasAhead ? innerW * ((buffered - played) / maxV) : 0.0;
          if (hasAhead && aheadW < widget.minAheadPixels) {
            aheadW = widget.minAheadPixels.clamp(0, innerW - playedW);
          }
          final bufferEndW = (playedW + aheadW).clamp(0.0, innerW);

          final bar = Stack(
            alignment: Alignment.centerLeft,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Container(
                  height: 3,
                  width: innerW,
                  decoration: BoxDecoration(
                    color: widget.trackColor,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              if (bufferEndW > playedW)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Container(
                    height: 3,
                    width: bufferEndW,
                    decoration: BoxDecoration(
                      color: widget.bufferedColor,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Container(
                  height: 3,
                  width: playedW,
                  decoration: BoxDecoration(
                    color: widget.playedColor,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              if (widget.showThumb)
                Positioned(
                  left: 8 + playedW - 6,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: widget.thumbColor,
                      shape: BoxShape.circle,
                      boxShadow: const [
                        BoxShadow(color: Colors.black26, blurRadius: 2, offset: Offset(0, 1)),
                      ],
                    ),
                  ),
                ),
            ],
          );

          if (!_interactive) return bar;

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragStart: (d) {
              setState(() => _dragging = true);
              _updateByDx(d.localPosition.dx, barWidth);
              widget.onChangeStart?.call(_dragValue);
            },
            onHorizontalDragUpdate: (d) => _updateByDx(d.localPosition.dx, barWidth),
            onHorizontalDragEnd: (_) {
              final endValue = _dragValue;
              setState(() => _dragging = false);
              widget.onChangeEnd?.call(endValue);
            },
            onTapDown: (d) {
              widget.onChangeStart?.call(widget.value);
              _updateByDx(d.localPosition.dx, barWidth);
              widget.onChangeEnd?.call(_dragValue);
            },
            child: bar,
          );
        },
      ),
    );
  }
}

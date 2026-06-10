import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:videoweb_flutter/utils/player_system_controls.dart';

/// 详情页播放器手势层（对齐原生 VideoPlayerGestureController）
/// 横向滑动快进/快退，左侧上下滑亮度，右侧上下滑音量，双击左/右 ±10s，单击显隐控制条。
class DetailPlayerGestureLayer extends StatefulWidget {
  final VideoPlayerController controller;
  final Duration duration;
  final bool isScreenLocked;
  final GlobalKey? controlsKey;
  final VoidCallback onSingleTap;
  final VoidCallback onLockedTap;
  final VoidCallback onControlsShow;
  final VoidCallback onControlsHide;
  final ValueChanged<Duration>? onSeekPreview;
  final VoidCallback? onSeekEnd;

  const DetailPlayerGestureLayer({
    super.key,
    required this.controller,
    required this.duration,
    required this.isScreenLocked,
    this.controlsKey,
    required this.onSingleTap,
    required this.onLockedTap,
    required this.onControlsShow,
    required this.onControlsHide,
    this.onSeekPreview,
    this.onSeekEnd,
  });

  @override
  State<DetailPlayerGestureLayer> createState() => _DetailPlayerGestureLayerState();
}

class _DetailPlayerGestureLayerState extends State<DetailPlayerGestureLayer> {
  static const _seekStepMs = 10000;

  _GestureMode _mode = _GestureMode.none;
  double _startX = 0;
  double _startY = 0;
  int _startPositionMs = 0;
  int _previewPositionMs = 0;
  double _startBrightness = 0.5;
  int _startVolume = 0;
  int _maxVolume = 15;
  String? _seekHintText;
  String? _sideHintText;
  bool _panActive = false;

  int get _durationMs {
    final ms = widget.duration.inMilliseconds;
    return ms > 0 ? ms : 0;
  }

  int get _currentPositionMs {
    final value = widget.controller.value;
    if (!value.isInitialized) return 0;
    return value.position.inMilliseconds;
  }

  bool _isOnControls(Offset globalPosition) {
    final key = widget.controlsKey;
    if (key?.currentContext == null) return false;
    final box = key!.currentContext!.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return false;
    final local = box.globalToLocal(globalPosition);
    return local.dx >= 0 &&
        local.dx <= box.size.width &&
        local.dy >= 0 &&
        local.dy <= box.size.height;
  }

  void _hideHints() {
    if (_seekHintText != null || _sideHintText != null) {
      setState(() {
        _seekHintText = null;
        _sideHintText = null;
      });
    }
  }

  void _showSeekHint(int positionMs, int durationMs, int deltaMs) {
    final sign = deltaMs >= 0 ? '+' : '';
    final deltaSec = (deltaMs.abs()) ~/ 1000;
    setState(() {
      _seekHintText =
          '${_formatTime(positionMs)} / ${_formatTime(durationMs)}\n$sign${deltaSec}秒';
      _sideHintText = null;
    });
  }

  void _showSideHint(String text) {
    setState(() {
      _sideHintText = text;
      _seekHintText = null;
    });
  }

  String _formatTime(int ms) {
    if (ms <= 0) return '00:00';
    final totalSec = ms ~/ 1000;
    final min = totalSec ~/ 60;
    final sec = totalSec % 60;
    return '${min.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  Future<void> _refreshSideGestureBaselines() async {
    final brightness = await PlayerSystemControls.getBrightness();
    final volume = await PlayerSystemControls.getVolume();
    _startBrightness = brightness;
    _startVolume = volume.volume;
    _maxVolume = volume.max;
  }

  void _onDoubleTapDown(TapDownDetails details, BoxConstraints constraints) {
    if (widget.isScreenLocked) return;
    if (_isOnControls(details.globalPosition)) return;
    final durationMs = _durationMs;
    if (durationMs <= 0) return;

    final w = constraints.maxWidth;
    final x = details.localPosition.dx;
    int? stepMs;
    if (x < w / 3) {
      stepMs = -_seekStepMs;
    } else if (x > w * 2 / 3) {
      stepMs = _seekStepMs;
    } else {
      widget.onSingleTap();
      return;
    }

    final current = _currentPositionMs;
    final target = (current + stepMs).clamp(0, durationMs);
    widget.controller.seekTo(Duration(milliseconds: target));
    widget.onSeekPreview?.call(Duration(milliseconds: target));
    widget.onSeekEnd?.call();
    _showSeekHint(target, durationMs, stepMs);
    widget.onControlsShow();
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) _hideHints();
    });
  }

  void _onPanStart(DragStartDetails details) {
    if (_isOnControls(details.globalPosition)) return;
    if (widget.isScreenLocked) return;

    _mode = _GestureMode.none;
    _startX = details.localPosition.dx;
    _startY = details.localPosition.dy;
    _startPositionMs = _currentPositionMs;
    _previewPositionMs = _startPositionMs;
    _panActive = true;
    _refreshSideGestureBaselines();
  }

  void _onPanUpdate(DragUpdateDetails details, BoxConstraints constraints) {
    if (!_panActive || widget.isScreenLocked) return;

    final dx = details.localPosition.dx - _startX;
    final dy = details.localPosition.dy - _startY;
    final touchSlop = MediaQuery.of(context).gestureSettings.touchSlop ?? 18.0;
    final height = constraints.maxHeight.clamp(1.0, double.infinity);
    final width = constraints.maxWidth.clamp(1.0, double.infinity);

    if (_mode == _GestureMode.none) {
      if (dx.abs() < touchSlop && dy.abs() < touchSlop) return;
      if (dx.abs() > dy.abs()) {
        _mode = _GestureMode.seek;
      } else {
        _mode = _startX < width / 2 ? _GestureMode.brightness : _GestureMode.volume;
      }
      widget.onControlsHide();
    }

    switch (_mode) {
      case _GestureMode.seek:
        final durationMs = _durationMs;
        if (durationMs <= 0) return;
        final delta = (dx / width * durationMs).round();
        _previewPositionMs = (_startPositionMs + delta).clamp(0, durationMs);
        _showSeekHint(_previewPositionMs, durationMs, delta);
        widget.onSeekPreview?.call(Duration(milliseconds: _previewPositionMs));
      case _GestureMode.brightness:
        final delta = -dy / height;
        final value = (_startBrightness + delta).clamp(0.02, 1.0);
        PlayerSystemControls.setBrightness(value);
        _showSideHint('亮度 ${(value * 100).round()}%');
      case _GestureMode.volume:
        final delta = (-dy / height * _maxVolume).round();
        final vol = (_startVolume + delta).clamp(0, _maxVolume);
        PlayerSystemControls.setVolume(vol);
        final percent = _maxVolume > 0 ? (vol * 100 / _maxVolume).round() : 0;
        _showSideHint('音量 $percent%');
      case _GestureMode.none:
        break;
    }
  }

  void _onPanEnd(DragEndDetails details) {
    if (!_panActive) return;
    _panActive = false;

    if (_mode == _GestureMode.seek && _durationMs > 0) {
      widget.controller.seekTo(Duration(milliseconds: _previewPositionMs));
      widget.onSeekPreview?.call(Duration(milliseconds: _previewPositionMs));
      widget.onControlsShow();
    }
    widget.onSeekEnd?.call();
    _hideHints();
    _mode = _GestureMode.none;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          fit: StackFit.expand,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: widget.isScreenLocked ? widget.onLockedTap : widget.onSingleTap,
              onDoubleTapDown: (d) => _onDoubleTapDown(d, constraints),
              onPanStart: _onPanStart,
              onPanUpdate: (d) => _onPanUpdate(d, constraints),
              onPanEnd: _onPanEnd,
              onPanCancel: () {
                _panActive = false;
                _hideHints();
                _mode = _GestureMode.none;
              },
            ),
            if (_seekHintText != null || _sideHintText != null)
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.55),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _seekHintText ?? _sideHintText ?? '',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      height: 1.35,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

enum _GestureMode { none, seek, brightness, volume }

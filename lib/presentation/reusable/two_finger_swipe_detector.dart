import 'package:flutter/material.dart';

class TwoFingerSwipeDetector extends StatefulWidget {
  const TwoFingerSwipeDetector({
    required this.child,
    required this.onSwipeLeft,
    required this.onSwipeRight,
    this.onSwipeUp,
    this.onSwipeDown,
    super.key,
  });

  final Widget child;
  final VoidCallback onSwipeLeft;
  final VoidCallback onSwipeRight;
  final VoidCallback? onSwipeUp;
  final VoidCallback? onSwipeDown;

  @override
  State<TwoFingerSwipeDetector> createState() => _TwoFingerSwipeDetectorState();
}

class _TwoFingerSwipeDetectorState extends State<TwoFingerSwipeDetector> {
  static const _swipeThreshold = 72.0;

  final Map<int, Offset> _positions = {};
  double? _startAverageX;
  double? _startAverageY;
  var _hasTriggered = false;

  @override
  Widget build(BuildContext context) {
    final isScreenReaderActive = MediaQuery.maybeOf(context)?.accessibleNavigation ?? false;
    if (isScreenReaderActive) {
      return widget.child;
    }

    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: _handlePointerDown,
      onPointerMove: _handlePointerMove,
      onPointerUp: _handlePointerEnd,
      onPointerCancel: _handlePointerEnd,
      child: widget.child,
    );
  }

  void _handlePointerDown(PointerDownEvent event) {
    _positions[event.pointer] = event.position;
    _resetSwipeStartIfReady();
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (!_positions.containsKey(event.pointer)) {
      return;
    }

    _positions[event.pointer] = event.position;

    if (_positions.length != 2 || _startAverageX == null || _startAverageY == null || _hasTriggered) {
      return;
    }

    final deltaX = _averageX - _startAverageX!;
    final deltaY = _averageY - _startAverageY!;

    // Check which axis has the stronger movement and exceeds the threshold
    if (deltaX.abs() >= _swipeThreshold && deltaX.abs() > deltaY.abs()) {
      _hasTriggered = true;
      // In RTL layouts Flutter already mirrors the Directionality so we mirror
      // left/right callbacks to keep "swipe towards start = previous" natural.
      final isRtl = Directionality.of(context) == TextDirection.rtl;
      if (deltaX.isNegative) {
        isRtl ? widget.onSwipeRight() : widget.onSwipeLeft();
      } else {
        isRtl ? widget.onSwipeLeft() : widget.onSwipeRight();
      }
    } else if (deltaY.abs() >= _swipeThreshold && deltaY.abs() > deltaX.abs()) {
      final onSwipeUp = widget.onSwipeUp;
      final onSwipeDown = widget.onSwipeDown;
      if (deltaY.isNegative && onSwipeUp != null) {
        _hasTriggered = true;
        onSwipeUp();
      } else if (!deltaY.isNegative && onSwipeDown != null) {
        _hasTriggered = true;
        onSwipeDown();
      }
    }
  }

  void _handlePointerEnd(PointerEvent event) {
    _positions.remove(event.pointer);
    _startAverageX = null;
    _startAverageY = null;
    _hasTriggered = false;
  }

  void _resetSwipeStartIfReady() {
    if (_positions.length == 2) {
      _startAverageX = _averageX;
      _startAverageY = _averageY;
      _hasTriggered = false;
    }
  }

  double get _averageX {
    final total = _positions.values.fold<double>(
      0,
      (sum, position) => sum + position.dx,
    );

    return total / _positions.length;
  }

  double get _averageY {
    final total = _positions.values.fold<double>(
      0,
      (sum, position) => sum + position.dy,
    );

    return total / _positions.length;
  }
}

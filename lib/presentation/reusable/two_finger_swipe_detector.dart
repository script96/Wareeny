import 'package:flutter/material.dart';

class TwoFingerSwipeDetector extends StatefulWidget {
  const TwoFingerSwipeDetector({
    required this.child,
    required this.onSwipeLeft,
    required this.onSwipeRight,
    super.key,
  });

  final Widget child;
  final VoidCallback onSwipeLeft;
  final VoidCallback onSwipeRight;

  @override
  State<TwoFingerSwipeDetector> createState() => _TwoFingerSwipeDetectorState();
}

class _TwoFingerSwipeDetectorState extends State<TwoFingerSwipeDetector> {
  static const _swipeThreshold = 72.0;

  final Map<int, Offset> _positions = {};
  double? _startAverageX;
  var _hasTriggered = false;

  @override
  Widget build(BuildContext context) {
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

    if (_positions.length != 2 || _startAverageX == null || _hasTriggered) {
      return;
    }

    final delta = _averageX - _startAverageX!;
    if (delta.abs() < _swipeThreshold) {
      return;
    }

    _hasTriggered = true;
    delta.isNegative ? widget.onSwipeLeft() : widget.onSwipeRight();
  }

  void _handlePointerEnd(PointerEvent event) {
    _positions.remove(event.pointer);
    _startAverageX = null;
    _hasTriggered = false;
  }

  void _resetSwipeStartIfReady() {
    if (_positions.length == 2) {
      _startAverageX = _averageX;
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
}

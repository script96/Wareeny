import 'dart:async';

import 'package:flutter/material.dart';

class HoldToListenDetector extends StatelessWidget {
  const HoldToListenDetector({
    required this.child,
    required this.onHoldStart,
    required this.onHoldEnd,
    required this.onHoldCancel,
    super.key,
  });

  final Widget child;
  final Future<void> Function() onHoldStart;
  final Future<void> Function() onHoldEnd;
  final Future<void> Function() onHoldCancel;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onLongPressStart: (_) => unawaited(onHoldStart()),
      onLongPressEnd: (_) => unawaited(onHoldEnd()),
      onLongPressCancel: () => unawaited(onHoldCancel()),
      child: child,
    );
  }
}

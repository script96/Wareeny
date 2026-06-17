import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wareeny/presentation/reusable/hold_to_listen_detector.dart';

void main() {
  testWidgets('starts listening while held and ends on release', (
    tester,
  ) async {
    var starts = 0;
    var ends = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: HoldToListenDetector(
          onHoldStart: () async => starts++,
          onHoldEnd: () async => ends++,
          onHoldCancel: () async {},
          child: const ColoredBox(color: Colors.black),
        ),
      ),
    );

    final gesture = await tester.startGesture(const Offset(200, 300));
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));

    expect(starts, 1);
    expect(ends, 0);

    await gesture.up();
    await tester.pump();

    expect(ends, 1);
  });
}

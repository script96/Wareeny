import 'package:flutter_test/flutter_test.dart';

import 'package:wareeny/core/emergency/emergency_motion_detector.dart';

void main() {
  test('does not trigger for normal movement or a single strong peak', () {
    final detector = EmergencyMotionDetector();
    final start = DateTime(2026);

    expect(_sample(detector, 9.8, start), isNull);
    expect(
      _sample(detector, 29, start.add(const Duration(milliseconds: 100))),
      isNull,
    );
    expect(
      _sample(detector, 9.8, start.add(const Duration(milliseconds: 150))),
      isNull,
    );
  });

  test('triggers after two separate hard-shake peaks', () {
    final detector = EmergencyMotionDetector();
    final start = DateTime(2026);

    expect(_sample(detector, 30, start), isNull);
    expect(
      _sample(detector, 9.8, start.add(const Duration(milliseconds: 100))),
      isNull,
    );
    expect(
      _sample(detector, 31, start.add(const Duration(milliseconds: 300))),
      EmergencyMotionType.hardShake,
    );
  });

  test('triggers when sustained free fall is followed by impact', () {
    final detector = EmergencyMotionDetector();
    final start = DateTime(2026);

    for (var milliseconds = 0; milliseconds <= 50; milliseconds += 10) {
      expect(
        _sample(detector, 1, start.add(Duration(milliseconds: milliseconds))),
        isNull,
      );
    }

    expect(
      _sample(detector, 24, start.add(const Duration(milliseconds: 100))),
      EmergencyMotionType.fallImpact,
    );
  });

  test('does not treat a one-sample dip as free fall', () {
    final detector = EmergencyMotionDetector();
    final start = DateTime(2026);

    expect(_sample(detector, 1, start), isNull);
    expect(
      _sample(detector, 9.8, start.add(const Duration(milliseconds: 10))),
      isNull,
    );
    expect(
      _sample(detector, 25, start.add(const Duration(milliseconds: 100))),
      isNull,
    );
  });

  test('does not use stale hard-shake peaks', () {
    final detector = EmergencyMotionDetector();
    final start = DateTime(2026);

    expect(_sample(detector, 30, start), isNull);
    expect(
      _sample(detector, 9.8, start.add(const Duration(milliseconds: 100))),
      isNull,
    );
    expect(
      _sample(detector, 31, start.add(const Duration(milliseconds: 900))),
      isNull,
    );
  });
}

EmergencyMotionType? _sample(
  EmergencyMotionDetector detector,
  double magnitude,
  DateTime timestamp,
) {
  return detector.addSample(x: magnitude, y: 0, z: 0, timestamp: timestamp);
}

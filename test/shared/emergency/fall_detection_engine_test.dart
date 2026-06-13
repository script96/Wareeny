import 'package:flutter_test/flutter_test.dart';
import 'package:wareeny/shared/emergency/fall_detection_engine.dart';

void main() {
  MotionSample sample(
    DateTime timestamp, {
    double acceleration = 9.81,
    double rotation = 0,
  }) {
    return MotionSample(
      timestamp: timestamp,
      accelerationX: acceleration,
      accelerationY: 0,
      accelerationZ: 0,
      rotationMagnitude: rotation,
    );
  }

  test('detects free fall, impact, rotation, and inactivity sequence', () {
    final engine = FallDetectionEngine(
      settlingDuration: const Duration(milliseconds: 500),
    );
    final start = DateTime(2026);

    expect(engine.add(sample(start, acceleration: 1)), isFalse);
    expect(
      engine.add(
        sample(
          start.add(const Duration(milliseconds: 200)),
          acceleration: 30,
          rotation: 3,
        ),
      ),
      isFalse,
    );
    expect(
      engine.add(sample(start.add(const Duration(milliseconds: 500)))),
      isFalse,
    );
    expect(
      engine.add(sample(start.add(const Duration(milliseconds: 1000)))),
      isTrue,
    );
  });

  test('does not trigger for impact without free fall', () {
    final engine = FallDetectionEngine();
    final start = DateTime(2026);

    expect(engine.add(sample(start, acceleration: 35, rotation: 4)), isFalse);
    expect(engine.stage, FallDetectionStage.idle);
  });

  test('does not trigger without orientation change', () {
    final engine = FallDetectionEngine(
      settlingDuration: const Duration(milliseconds: 300),
    );
    final start = DateTime(2026);

    engine.add(sample(start, acceleration: 1));
    engine.add(
      sample(start.add(const Duration(milliseconds: 100)), acceleration: 30),
    );
    engine.add(sample(start.add(const Duration(milliseconds: 400))));

    expect(
      engine.add(sample(start.add(const Duration(milliseconds: 800)))),
      isFalse,
    );
  });

  test('resets when movement continues after impact', () {
    final engine = FallDetectionEngine();
    final start = DateTime(2026);

    engine.add(sample(start, acceleration: 1));
    engine.add(
      sample(
        start.add(const Duration(milliseconds: 100)),
        acceleration: 30,
        rotation: 3,
      ),
    );
    engine.add(
      sample(start.add(const Duration(milliseconds: 400)), acceleration: 15),
    );
    engine.add(
      sample(start.add(const Duration(milliseconds: 800)), acceleration: 15),
    );

    expect(engine.stage, FallDetectionStage.idle);
  });
}

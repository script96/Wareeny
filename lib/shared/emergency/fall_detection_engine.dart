import 'dart:math' as math;

enum FallDetectionStage { idle, freeFall, impact, settling, cooldown }

class MotionSample {
  const MotionSample({
    required this.timestamp,
    required this.accelerationX,
    required this.accelerationY,
    required this.accelerationZ,
    required this.rotationMagnitude,
  });

  final DateTime timestamp;
  final double accelerationX;
  final double accelerationY;
  final double accelerationZ;
  final double rotationMagnitude;

  double get accelerationMagnitude => math.sqrt(
    accelerationX * accelerationX +
        accelerationY * accelerationY +
        accelerationZ * accelerationZ,
  );
}

class FallDetectionEngine {
  FallDetectionEngine({
    this.freeFallThreshold = 3.0,
    this.impactThreshold = 24.0,
    this.rotationThreshold = 2.2,
    this.inactivityTolerance = 2.0,
    this.freeFallWindow = const Duration(milliseconds: 1200),
    this.settlingDuration = const Duration(milliseconds: 1500),
    this.cooldown = const Duration(minutes: 2),
  });

  final double freeFallThreshold;
  final double impactThreshold;
  final double rotationThreshold;
  final double inactivityTolerance;
  final Duration freeFallWindow;
  final Duration settlingDuration;
  final Duration cooldown;

  FallDetectionStage _stage = FallDetectionStage.idle;
  DateTime? _stageStartedAt;
  bool _orientationChanged = false;

  FallDetectionStage get stage => _stage;

  bool add(MotionSample sample) {
    switch (_stage) {
      case FallDetectionStage.idle:
        if (sample.accelerationMagnitude < freeFallThreshold) {
          _transition(FallDetectionStage.freeFall, sample.timestamp);
        }
      case FallDetectionStage.freeFall:
        if (_elapsed(sample.timestamp) > freeFallWindow) {
          reset();
        } else if (sample.accelerationMagnitude > impactThreshold) {
          _orientationChanged = sample.rotationMagnitude >= rotationThreshold;
          _transition(FallDetectionStage.impact, sample.timestamp);
        }
      case FallDetectionStage.impact:
        _orientationChanged =
            _orientationChanged ||
            sample.rotationMagnitude >= rotationThreshold;
        if (_elapsed(sample.timestamp) >= const Duration(milliseconds: 250)) {
          _transition(FallDetectionStage.settling, sample.timestamp);
        }
      case FallDetectionStage.settling:
        final nearGravity =
            (sample.accelerationMagnitude - 9.81).abs() <= inactivityTolerance;
        if (!nearGravity) {
          reset();
        } else if (_elapsed(sample.timestamp) >= settlingDuration &&
            _orientationChanged) {
          _transition(FallDetectionStage.cooldown, sample.timestamp);
          return true;
        }
      case FallDetectionStage.cooldown:
        if (_elapsed(sample.timestamp) >= cooldown) reset();
    }
    return false;
  }

  void reset() {
    _stage = FallDetectionStage.idle;
    _stageStartedAt = null;
    _orientationChanged = false;
  }

  Duration _elapsed(DateTime timestamp) =>
      timestamp.difference(_stageStartedAt ?? timestamp);

  void _transition(FallDetectionStage stage, DateTime timestamp) {
    _stage = stage;
    _stageStartedAt = timestamp;
  }
}

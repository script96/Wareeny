import 'dart:math';

enum EmergencyMotionType { hardShake, fallImpact }

/// Classifies raw accelerometer samples into deliberate emergency motions.
///
/// Raw samples include gravity, so a resting phone measures about 9.8 m/s².
/// A fall is identified by sustained near-zero acceleration followed by an
/// impact. A hard shake requires two separate high-force peaks.
class EmergencyMotionDetector {
  static const double _freeFallThresholdMs2 = 3.0;
  static const double _fallImpactThresholdMs2 = 20.0;
  static const double _hardShakeThresholdMs2 = 28.0;
  static const double _hardShakeReleaseThresholdMs2 = 20.0;
  static const Duration _minimumFreeFall = Duration(milliseconds: 40);
  static const Duration _fallImpactWindow = Duration(milliseconds: 1200);
  static const Duration _hardShakeWindow = Duration(milliseconds: 700);

  DateTime? _freeFallStartedAt;
  bool _freeFallConfirmed = false;
  DateTime? _lastHardPeakAt;
  int _hardPeakCount = 0;
  bool _aboveHardShakeThreshold = false;

  EmergencyMotionType? addSample({
    required double x,
    required double y,
    required double z,
    required DateTime timestamp,
  }) {
    final magnitude = sqrt(x * x + y * y + z * z);

    final fall = _detectFall(magnitude, timestamp);
    if (fall != null) {
      reset();
      return fall;
    }

    final hardShake = _detectHardShake(magnitude, timestamp);
    if (hardShake != null) {
      reset();
      return hardShake;
    }
    return null;
  }

  EmergencyMotionType? _detectFall(double magnitude, DateTime timestamp) {
    if (_freeFallStartedAt != null &&
        timestamp.difference(_freeFallStartedAt!) > _fallImpactWindow) {
      _clearFreeFall();
    }

    if (magnitude <= _freeFallThresholdMs2) {
      _freeFallStartedAt ??= timestamp;
      if (timestamp.difference(_freeFallStartedAt!) >= _minimumFreeFall) {
        _freeFallConfirmed = true;
      }
      return null;
    }

    if (!_freeFallConfirmed) {
      _clearFreeFall();
      return null;
    }

    if (magnitude >= _fallImpactThresholdMs2) {
      return EmergencyMotionType.fallImpact;
    }
    return null;
  }

  EmergencyMotionType? _detectHardShake(double magnitude, DateTime timestamp) {
    if (magnitude < _hardShakeReleaseThresholdMs2) {
      _aboveHardShakeThreshold = false;
      return null;
    }
    if (magnitude < _hardShakeThresholdMs2 || _aboveHardShakeThreshold) {
      return null;
    }

    _aboveHardShakeThreshold = true;
    if (_lastHardPeakAt == null ||
        timestamp.difference(_lastHardPeakAt!) > _hardShakeWindow) {
      _hardPeakCount = 1;
    } else {
      _hardPeakCount++;
    }
    _lastHardPeakAt = timestamp;

    return _hardPeakCount >= 2 ? EmergencyMotionType.hardShake : null;
  }

  void reset() {
    _clearFreeFall();
    _lastHardPeakAt = null;
    _hardPeakCount = 0;
    _aboveHardShakeThreshold = false;
  }

  void _clearFreeFall() {
    _freeFallStartedAt = null;
    _freeFallConfirmed = false;
  }
}

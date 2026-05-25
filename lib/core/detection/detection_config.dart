import 'package:wareny/core/detection/detection_result.dart';

class DetectionConfig {
  const DetectionConfig({
    this.frameSampleInterval = 3,
    this.confidenceThreshold = 0.45,
    this.cooldownDuration = const Duration(seconds: 2),
    this.nearHapticInterval = const Duration(milliseconds: 400),
    this.midHapticInterval = const Duration(milliseconds: 800),
    this.farHapticInterval = const Duration(milliseconds: 1500),
    this.lostTargetDelay = const Duration(seconds: 3),
  }) : assert(frameSampleInterval > 0),
       assert(confidenceThreshold >= 0 && confidenceThreshold <= 1);

  final int frameSampleInterval;
  final double confidenceThreshold;
  final Duration cooldownDuration;
  final Duration nearHapticInterval;
  final Duration midHapticInterval;
  final Duration farHapticInterval;
  final Duration lostTargetDelay;

  Duration hapticIntervalFor(ObjectProximity proximity) {
    return switch (proximity) {
      ObjectProximity.near => nearHapticInterval,
      ObjectProximity.mid => midHapticInterval,
      ObjectProximity.far => farHapticInterval,
    };
  }
}

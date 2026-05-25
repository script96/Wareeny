import 'dart:collection';

import 'package:wareny/core/detection/detection_result.dart';

class DetectionFrame {
  DetectionFrame({
    required Iterable<DetectionResult> detections,
    required this.latencyMs,
    required this.frameIndex,
  }) : detections = UnmodifiableListView<DetectionResult>(detections);

  DetectionFrame.empty({required int frameIndex})
    : detections = UnmodifiableListView<DetectionResult>(const []),
      latencyMs = 0,
      frameIndex = frameIndex;

  final UnmodifiableListView<DetectionResult> detections;
  final int latencyMs;
  final int frameIndex;
}

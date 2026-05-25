import 'dart:math' as math;
import 'dart:ui';

enum ObjectDirection { left, center, right }

enum ObjectProximity { near, mid, far }

class DetectionResult {
  const DetectionResult({
    required this.label,
    required this.confidence,
    required this.boundingBox,
    required this.direction,
    required this.proximity,
    required this.timestampMs,
  });

  final String label;
  final double confidence;
  final Rect boundingBox;
  final ObjectDirection direction;
  final ObjectProximity proximity;
  final int timestampMs;

  factory DetectionResult.fromRawBox({
    required String label,
    required double confidence,
    required Rect rawBox,
    required Size frameSize,
    required int timestampMs,
  }) {
    assert(frameSize.width > 0, 'frame width must be greater than 0');
    assert(frameSize.height > 0, 'frame height must be greater than 0');

    final left = _ratio(rawBox.left, frameSize.width);
    final right = _ratio(rawBox.right, frameSize.width);
    final top = _ratio(rawBox.top, frameSize.height);
    final bottom = _ratio(rawBox.bottom, frameSize.height);

    return DetectionResult.fromNormalizedBox(
      label: label,
      confidence: confidence,
      boundingBox: Rect.fromLTRB(
        math.min(left, right),
        math.min(top, bottom),
        math.max(left, right),
        math.max(top, bottom),
      ),
      timestampMs: timestampMs,
    );
  }

  factory DetectionResult.fromNormalizedBox({
    required String label,
    required double confidence,
    required Rect boundingBox,
    required int timestampMs,
  }) {
    final normalizedBox = _clampBox(boundingBox);

    return DetectionResult(
      label: label,
      confidence: confidence.clamp(0.0, 1.0).toDouble(),
      boundingBox: normalizedBox,
      direction: directionForBox(normalizedBox),
      proximity: proximityForBox(normalizedBox),
      timestampMs: timestampMs,
    );
  }

  static ObjectDirection directionForBox(Rect normalizedBox) {
    final centerX = normalizedBox.center.dx.clamp(0.0, 1.0).toDouble();

    if (centerX < 0.4) {
      return ObjectDirection.left;
    }
    if (centerX > 0.6) {
      return ObjectDirection.right;
    }
    return ObjectDirection.center;
  }

  static ObjectProximity proximityForBox(Rect normalizedBox) {
    final area =
        math.max(0.0, normalizedBox.width) *
        math.max(0.0, normalizedBox.height);

    if (area >= 0.24) {
      return ObjectProximity.near;
    }
    if (area >= 0.08) {
      return ObjectProximity.mid;
    }
    return ObjectProximity.far;
  }

  static Rect _clampBox(Rect box) {
    final left = box.left.clamp(0.0, 1.0).toDouble();
    final right = box.right.clamp(0.0, 1.0).toDouble();
    final top = box.top.clamp(0.0, 1.0).toDouble();
    final bottom = box.bottom.clamp(0.0, 1.0).toDouble();

    return Rect.fromLTRB(
      math.min(left, right),
      math.min(top, bottom),
      math.max(left, right),
      math.max(top, bottom),
    );
  }

  static double _ratio(double value, double maxValue) {
    return (value / maxValue).clamp(0.0, 1.0).toDouble();
  }
}

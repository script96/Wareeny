import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:wareny/core/detection/detection_result.dart';

void main() {
  group('DetectionResult.fromRawBox', () {
    test('normalizes raw boxes and computes left direction', () {
      final result = DetectionResult.fromRawBox(
        label: 'cup',
        confidence: 0.8,
        rawBox: const Rect.fromLTWH(0, 20, 160, 180),
        frameSize: const Size(800, 600),
        timestampMs: 10,
      );

      expect(result.boundingBox.left, 0);
      expect(result.boundingBox.right, 0.2);
      expect(result.direction, ObjectDirection.left);
      expect(result.proximity, ObjectProximity.far);
    });

    test('computes center and right directions from normalized boxes', () {
      final center = DetectionResult.fromNormalizedBox(
        label: 'book',
        confidence: 0.7,
        boundingBox: const Rect.fromLTWH(0.42, 0.2, 0.16, 0.2),
        timestampMs: 20,
      );
      final right = DetectionResult.fromNormalizedBox(
        label: 'book',
        confidence: 0.7,
        boundingBox: const Rect.fromLTWH(0.7, 0.2, 0.16, 0.2),
        timestampMs: 20,
      );

      expect(center.direction, ObjectDirection.center);
      expect(right.direction, ObjectDirection.right);
    });

    test('estimates proximity by normalized box area', () {
      final far = DetectionResult.fromNormalizedBox(
        label: 'phone',
        confidence: 0.9,
        boundingBox: const Rect.fromLTWH(0.1, 0.1, 0.1, 0.1),
        timestampMs: 30,
      );
      final mid = DetectionResult.fromNormalizedBox(
        label: 'phone',
        confidence: 0.9,
        boundingBox: const Rect.fromLTWH(0.1, 0.1, 0.3, 0.3),
        timestampMs: 30,
      );
      final near = DetectionResult.fromNormalizedBox(
        label: 'phone',
        confidence: 0.9,
        boundingBox: const Rect.fromLTWH(0.1, 0.1, 0.55, 0.5),
        timestampMs: 30,
      );

      expect(far.proximity, ObjectProximity.far);
      expect(mid.proximity, ObjectProximity.mid);
      expect(near.proximity, ObjectProximity.near);
    });
  });
}

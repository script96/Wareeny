import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:wareeny/shared/object_detection/detection_coordinate_mapper.dart';
import 'package:wareeny/shared/object_detection/detection_models.dart';

void main() {
  const mapper = DetectionCoordinateMapper();

  test('rotates source boxes clockwise into upright coordinates', () {
    final frame = ObjectDetectionFrame(
      frameId: 1,
      sourceSize: const Size(200, 100),
      rotationDegrees: 90,
      detections: const [
        ObjectDetection(
          label: 'chair',
          confidence: 0.9,
          boundingBox: Rect.fromLTWH(0, 0, 20, 10),
        ),
      ],
      timestamp: DateTime(2026),
    );

    final upright = mapper.orient(frame);

    expect(upright.imageSize, const Size(100, 200));
    expect(
      upright.detections.single.normalizedBox,
      const Rect.fromLTRB(0.9, 0, 1, 0.1),
    );
  });

  test('applies mirroring after rotation', () {
    final frame = ObjectDetectionFrame(
      frameId: 1,
      sourceSize: const Size(200, 100),
      rotationDegrees: 90,
      mirrored: true,
      detections: const [
        ObjectDetection(
          label: 'chair',
          confidence: 0.9,
          boundingBox: Rect.fromLTWH(0, 0, 20, 10),
        ),
      ],
      timestamp: DateTime(2026),
    );

    final box = mapper.orient(frame).detections.single.normalizedBox;

    expect(box.left, closeTo(0, 1e-9));
    expect(box.top, closeTo(0, 1e-9));
    expect(box.right, closeTo(0.1, 1e-9));
    expect(box.bottom, closeTo(0.1, 1e-9));
  });

  test('projects boxes using the same center crop as BoxFit.cover', () {
    final box = mapper.projectRect(
      normalizedRect: const Rect.fromLTWH(0, 0, 1, 1),
      imageSize: const Size(100, 200),
      viewportSize: const Size(100, 100),
    );

    expect(box, const Rect.fromLTRB(0, -50, 100, 150));
  });
}

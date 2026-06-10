import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:wareeny/shared/navigation/navigation_models.dart';
import 'package:wareeny/shared/navigation/navigation_risk_engine.dart';
import 'package:wareeny/shared/object_detection/detection_coordinate_mapper.dart';
import 'package:wareeny/shared/object_detection/detection_models.dart';

void main() {
  const engine = NavigationRiskEngine();

  test('ignores detections outside the walking path', () {
    final assessment = engine.assess(
      _frame(const Rect.fromLTWH(0.01, 0.45, 0.10, 0.20)),
    );

    expect(assessment.highestRisk, NavigationRisk.safe);
    expect(assessment.objects.single.insidePath, isFalse);
  });

  test('classifies partial path overlap as caution', () {
    final assessment = engine.assess(
      _frame(const Rect.fromLTWH(0.32, 0.60, 0.14, 0.20)),
    );

    expect(assessment.highestRisk, NavigationRisk.caution);
    expect(assessment.objects.single.centerInsidePath, isFalse);
    expect(assessment.objects.single.overlapRatio, greaterThan(0.08));
  });

  test('classifies an object center inside the path as danger', () {
    final assessment = engine.assess(
      _frame(const Rect.fromLTWH(0.44, 0.48, 0.12, 0.20)),
    );

    expect(assessment.highestRisk, NavigationRisk.danger);
    expect(assessment.selected?.zone, NavigationZone.center);
    expect(assessment.selected?.centerInsidePath, isTrue);
  });

  test('ignores tiny and low-confidence boxes', () {
    final tiny = engine.assess(
      _frame(const Rect.fromLTWH(0.49, 0.70, 0.01, 0.01)),
    );
    final lowConfidence = engine.assess(
      _frame(const Rect.fromLTWH(0.40, 0.60, 0.20, 0.20), confidence: 0.2),
    );

    expect(tiny.objects.single.ignoreReason, 'tiny bounding box');
    expect(lowConfidence.objects.single.ignoreReason, 'low confidence');
  });

  test('prioritizes a close center obstacle over caution objects', () {
    final frame = UprightDetectionFrame(
      source: _rawFrame(),
      imageSize: const Size(100, 100),
      detections: [
        _detection(const Rect.fromLTWH(0.32, 0.60, 0.14, 0.20), 'chair'),
        _detection(const Rect.fromLTWH(0.35, 0.76, 0.30, 0.23), 'person'),
      ],
    );

    final assessment = engine.assess(frame);

    expect(assessment.selected?.detection.source.label, 'person');
    expect(assessment.selected?.isBottomDanger, isTrue);
  });
}

UprightDetectionFrame _frame(Rect box, {double confidence = 0.9}) {
  return UprightDetectionFrame(
    source: _rawFrame(),
    imageSize: const Size(100, 100),
    detections: [
      UprightDetection(
        source: ObjectDetection(
          label: 'chair',
          confidence: confidence,
          boundingBox: Rect.fromLTRB(
            box.left * 100,
            box.top * 100,
            box.right * 100,
            box.bottom * 100,
          ),
        ),
        normalizedBox: box,
      ),
    ],
  );
}

UprightDetection _detection(Rect box, String label) {
  return UprightDetection(
    source: ObjectDetection(label: label, confidence: 0.9, boundingBox: box),
    normalizedBox: box,
  );
}

ObjectDetectionFrame _rawFrame() {
  return ObjectDetectionFrame(
    frameId: 1,
    sourceSize: const Size(100, 100),
    detections: const [],
    timestamp: DateTime(2026),
  );
}

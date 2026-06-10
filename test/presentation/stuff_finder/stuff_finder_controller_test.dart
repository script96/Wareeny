import 'dart:async';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:wareeny/presentation/stuff_finder/coco_classes.dart';
import 'package:wareeny/presentation/stuff_finder/stuff_finder_controller.dart';
import 'package:wareeny/shared/object_detection/detection_models.dart';
import 'package:wareeny/shared/object_detection/object_detection_source.dart';

void main() {
  test('COCO menu contains the 80 unique model classes', () {
    expect(cocoClasses, hasLength(80));
    expect(cocoClasses.toSet(), hasLength(80));
    expect(cocoClasses, containsAll(<String>['person', 'chair', 'cell phone']));
  });

  test('starts finder mode and keeps only the selected COCO class', () async {
    final source = _FakeDetectionSource();
    final controller = StuffFinderController(detectionSource: source);

    await controller.selectTarget('chair');
    source.emit(
      _frame([
        const ObjectDetection(
          label: 'person',
          confidence: 0.92,
          boundingBox: Rect.fromLTWH(20, 30, 80, 160),
        ),
        const ObjectDetection(
          label: 'Chair',
          confidence: 0.87,
          boundingBox: Rect.fromLTWH(100, 120, 200, 220),
        ),
      ]),
    );
    await Future<void>.delayed(Duration.zero);

    expect(source.startedMode, 'stuff_finder');
    expect(controller.matchCount, 1);
    expect(controller.latestFrame!.detections.single.source.label, 'Chair');
    expect(controller.status, '1 match found');
  });

  test(
    'changing the target clears old matches and filters future frames',
    () async {
      final source = _FakeDetectionSource();
      final controller = StuffFinderController(detectionSource: source);

      await controller.selectTarget('chair');
      controller.processFrame(
        _frame([
          const ObjectDetection(
            label: 'chair',
            confidence: 0.8,
            boundingBox: Rect.fromLTWH(0, 0, 100, 100),
          ),
        ]),
      );

      await controller.selectTarget('bottle');
      expect(controller.latestFrame, isNull);

      controller.processFrame(
        _frame([
          const ObjectDetection(
            label: 'chair',
            confidence: 0.8,
            boundingBox: Rect.fromLTWH(0, 0, 100, 100),
          ),
          const ObjectDetection(
            label: 'bottle',
            confidence: 0.75,
            boundingBox: Rect.fromLTWH(200, 100, 60, 140),
          ),
        ]),
      );

      expect(controller.matchCount, 1);
      expect(controller.latestFrame!.detections.single.source.label, 'bottle');
    },
  );

  test('rejects targets that the model cannot detect', () {
    final controller = StuffFinderController(
      detectionSource: _FakeDetectionSource(),
    );

    expect(
      () => controller.selectTarget('wallet'),
      throwsA(isA<ArgumentError>()),
    );
  });
}

ObjectDetectionFrame _frame(List<ObjectDetection> detections) {
  return ObjectDetectionFrame(
    frameId: 1,
    sourceSize: const Size(640, 480),
    detections: detections,
    timestamp: DateTime(2026),
  );
}

class _FakeDetectionSource implements ObjectDetectionSource {
  final _frames = StreamController<ObjectDetectionFrame>.broadcast();

  String? startedMode;

  @override
  String get displayName => 'Fake YOLO';

  @override
  Stream<ObjectDetectionFrame> get frames => _frames.stream;

  void emit(ObjectDetectionFrame frame) => _frames.add(frame);

  @override
  Future<void> start({required String mode}) async {
    startedMode = mode;
  }

  @override
  Future<void> stop() async {}
}

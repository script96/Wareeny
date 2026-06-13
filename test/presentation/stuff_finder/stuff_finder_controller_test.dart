import 'dart:async';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:wareeny/presentation/stuff_finder/coco_classes.dart';
import 'package:wareeny/presentation/stuff_finder/stuff_finder_controller.dart';
import 'package:wareeny/shared/object_detection/detection_models.dart';
import 'package:wareeny/shared/object_detection/object_detection_source.dart';

void main() {
  test(
    'menu prioritizes custom and common objects before all COCO classes',
    () {
      expect(cocoClasses, hasLength(80));
      expect(stuffFinderClasses, hasLength(83));
      expect(stuffFinderClasses.toSet(), hasLength(83));
      expect(stuffFinderClasses.take(4), <String>[
        'wallet',
        'glasses',
        'keys',
        'bottle',
      ]);
      expect(
        popularCocoClasses,
        containsAll(<String>[
          'cell phone',
          'remote',
          'refrigerator',
          'toothbrush',
          'bicycle',
        ]),
      );
      expect(stuffFinderClasses, containsAll(cocoClasses));
    },
  );

  test('starts finder mode and keeps only the selected custom class', () async {
    final source = _FakeDetectionSource();
    final controller = StuffFinderController(detectionSource: source);

    await controller.selectTarget('wallet');
    source.emit(
      _frame([
        const ObjectDetection(
          label: 'keys',
          confidence: 0.92,
          boundingBox: Rect.fromLTWH(20, 30, 80, 160),
        ),
        const ObjectDetection(
          label: 'Wallet',
          confidence: 0.87,
          boundingBox: Rect.fromLTWH(100, 120, 200, 220),
        ),
      ]),
    );
    await Future<void>.delayed(Duration.zero);

    expect(source.startedMode, 'stuff_finder');
    expect(controller.matchCount, 1);
    expect(controller.latestFrame!.detections.single.source.label, 'Wallet');
    expect(controller.status, '1 match found');
  });

  test('speaks when searching starts and when target is found', () async {
    final source = _FakeDetectionSource();
    final feedback = _FakeStuffFinderFeedback();
    final controller = StuffFinderController(
      detectionSource: source,
      feedback: feedback,
    );

    await controller.selectTarget('chair');
    controller.processFrame(
      _frame([
        const ObjectDetection(
          label: 'chair',
          confidence: 0.87,
          boundingBox: Rect.fromLTWH(100, 120, 200, 220),
        ),
      ]),
    );
    await Future<void>.delayed(Duration.zero);

    expect(feedback.spoken, ['Searching for chair', 'Found chair']);
  });

  test(
    'changing the target clears old matches and filters future frames',
    () async {
      final source = _FakeDetectionSource();
      final controller = StuffFinderController(detectionSource: source);

      await controller.selectTarget('keys');
      controller.processFrame(
        _frame([
          const ObjectDetection(
            label: 'keys',
            confidence: 0.8,
            boundingBox: Rect.fromLTWH(0, 0, 100, 100),
          ),
        ]),
      );

      await controller.selectTarget('glasses');
      expect(controller.latestFrame, isNull);

      controller.processFrame(
        _frame([
          const ObjectDetection(
            label: 'keys',
            confidence: 0.8,
            boundingBox: Rect.fromLTWH(0, 0, 100, 100),
          ),
          const ObjectDetection(
            label: 'glasses',
            confidence: 0.75,
            boundingBox: Rect.fromLTWH(200, 100, 60, 140),
          ),
        ]),
      );

      expect(controller.matchCount, 1);
      expect(controller.latestFrame!.detections.single.source.label, 'glasses');
    },
  );

  test('accepts COCO targets and rejects unsupported targets', () async {
    final controller = StuffFinderController(
      detectionSource: _FakeDetectionSource(),
    );

    await controller.selectTarget('bottle');
    expect(controller.selectedTarget, 'bottle');

    expect(
      () => controller.selectTarget('wallet chain'),
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

class _FakeStuffFinderFeedback implements StuffFinderFeedback {
  final List<String> spoken = [];

  @override
  Future<void> speak(String message) async {
    spoken.add(message);
  }

  @override
  Future<void> stopSpeech() async {}
}

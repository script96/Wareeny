import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wareny/core/detection/detection_frame.dart';
import 'package:wareny/core/detection/detection_pipeline.dart';
import 'package:wareny/core/detection/detection_result.dart';
import 'package:wareny/core/detection/object_detector.dart';
import 'package:wareny/core/detection/target_labels.dart';

void main() {
  test('phone target matches cell phone detections and returns grouped label', () async {
    final detector = _QueueDetector([
      DetectionFrame(
        detections: [
          DetectionResult.fromNormalizedBox(
            label: 'cell phone',
            confidence: 0.91,
            boundingBox: const Rect.fromLTWH(0.2, 0.2, 0.2, 0.2),
            timestampMs: 1,
          ),
        ],
        latencyMs: 12,
        frameIndex: 1,
      ),
    ]);
    final pipeline = DetectionPipeline(detector: detector);

    await pipeline.initialize();
    pipeline.setTargetLabel('phone');
    pipeline.start();
    await pipeline.processFrame(_FakeCameraImage());

    expect(pipeline.currentTarget?.label, 'phone');
  });

  test('bag target matches handbag detector labels', () {
    final bag = TargetLabels.stuffFinderById('bag');

    expect(bag, isNotNull);
    expect(bag!.matchesDetectorLabel('handbag'), isTrue);
    expect(bag.matchesDetectorLabel('suitcase'), isTrue);
    expect(bag.matchesDetectorLabel('cell phone'), isFalse);
  });
}

class _QueueDetector implements ObjectDetector {
  _QueueDetector(this.frames);

  final List<DetectionFrame> frames;
  var _isReady = false;

  @override
  bool get isReady => _isReady;

  @override
  Future<void> initialize() async {
    _isReady = true;
  }

  @override
  Future<DetectionFrame> detect(CameraImage image) async {
    return frames.removeAt(0);
  }

  @override
  Future<void> dispose() async {
    _isReady = false;
  }
}

class _FakeCameraImage implements CameraImage {
  @override
  int get height => 480;

  @override
  int get width => 640;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

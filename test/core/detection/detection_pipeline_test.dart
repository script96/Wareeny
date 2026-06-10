import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wareny/core/detection/detection_config.dart';
import 'package:wareny/core/detection/detection_frame.dart';
import 'package:wareny/core/detection/detection_pipeline.dart';
import 'package:wareny/core/detection/detection_result.dart';
import 'package:wareny/core/detection/object_detector.dart';

void main() {
  test('does not invoke detector until a target is selected', () async {
    final detector = _QueueDetector([_frame(1)]);
    final pipeline = DetectionPipeline(detector: detector);

    await pipeline.initialize();
    pipeline.start();
    await pipeline.processFrame(_FakeCameraImage());

    expect(detector.detectCalls, 0);
    expect(pipeline.currentTarget, isNull);

    pipeline.dispose();
  });

  test('filters by target label and confidence', () async {
    final detector = _QueueDetector([
      DetectionFrame(
        detections: [
          _detection(label: 'cup', confidence: 0.9),
          _detection(label: 'book', confidence: 0.99),
          _detection(label: 'cup', confidence: 0.2),
        ],
        latencyMs: 12,
        frameIndex: 1,
      ),
    ]);
    final pipeline = DetectionPipeline(
      detector: detector,
      config: const DetectionConfig(frameSampleInterval: 1),
    );

    await pipeline.initialize();
    pipeline.setTargetLabel('cup');
    pipeline.start();
    await pipeline.processFrame(_FakeCameraImage());

    expect(pipeline.currentTarget?.label, 'cup');
    expect(pipeline.currentTarget?.confidence, 0.9);

    pipeline.dispose();
  });

  test(
    'never exposes detections for objects other than the selected target',
    () async {
      final detector = _QueueDetector([
        DetectionFrame(
          detections: [
            _detection(label: 'book', confidence: 0.99),
            _detection(label: 'bottle', confidence: 0.95),
          ],
          latencyMs: 12,
          frameIndex: 1,
        ),
      ]);
      final pipeline = DetectionPipeline(
        detector: detector,
        config: const DetectionConfig(frameSampleInterval: 1),
      );

      await pipeline.initialize();
      pipeline.setTargetLabel('cup');
      pipeline.start();
      await pipeline.processFrame(_FakeCameraImage());

      expect(pipeline.currentTarget, isNull);

      pipeline.dispose();
    },
  );

  test('suppresses same label and direction within cooldown', () async {
    var now = DateTime(2026);
    final detector = _QueueDetector([_frame(1), _frame(2), _frame(3)]);
    final pipeline = DetectionPipeline(
      detector: detector,
      config: const DetectionConfig(
        frameSampleInterval: 1,
        cooldownDuration: Duration(seconds: 2),
      ),
      clock: () => now,
    );
    final emitted = <DetectionResult>[];
    final subscription = pipeline.targetResults.listen(emitted.add);

    await pipeline.initialize();
    pipeline.setTargetLabel('cup');
    pipeline.start();

    await pipeline.processFrame(_FakeCameraImage());
    await pipeline.processFrame(_FakeCameraImage());
    await Future<void>.delayed(Duration.zero);
    expect(emitted, hasLength(1));

    now = now.add(const Duration(seconds: 3));
    await pipeline.processFrame(_FakeCameraImage());
    await Future<void>.delayed(Duration.zero);
    expect(emitted, hasLength(2));

    await subscription.cancel();
    pipeline.dispose();
  });
}

DetectionFrame _frame(int index) {
  return DetectionFrame(
    detections: [_detection(label: 'cup', confidence: 0.9)],
    latencyMs: 8,
    frameIndex: index,
  );
}

DetectionResult _detection({
  required String label,
  required double confidence,
}) {
  return DetectionResult.fromNormalizedBox(
    label: label,
    confidence: confidence,
    boundingBox: const Rect.fromLTWH(0.1, 0.2, 0.2, 0.2),
    timestampMs: 1,
  );
}

class _QueueDetector implements ObjectDetector {
  _QueueDetector(this.frames);

  final List<DetectionFrame> frames;
  var _isReady = false;
  var detectCalls = 0;

  @override
  bool get isReady => _isReady;

  @override
  Future<void> initialize() async {
    _isReady = true;
  }

  @override
  Future<DetectionFrame> detect(
    CameraImage image, {
    int rotationDegrees = 0,
  }) async {
    detectCalls += 1;
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
